#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use Clone qw/clone/;
use ProductOpener::Nutrition qw/generate_nutrient_aggregated_set add_misc_tags_for_protein_energy/;

my $at_least_tag = 'en:protein-is-at-least-20-percent-of-energy';
my $less_than_tag = 'en:protein-is-less-than-20-percent-of-energy';

sub input_set ($nutrients_ref, $source = 'packaging', $per = '100g', $preparation = 'as_sold') {
	return {
		source => $source,
		preparation => $preparation,
		per => $per,
		per_quantity => $per eq 'serving' ? 20 : 100,
		per_unit => $per eq '100ml' ? 'ml' : 'g',
		nutrients => $nutrients_ref,
	};
}

sub check_tags ($description, $input_sets_ref, $expected_tag, $modify_aggregate = undef) {
	my $product_ref = {
		nutrition => {input_sets => $input_sets_ref},
		misc_tags => ['en:unrelated-tag', $at_least_tag, $less_than_tag],
	};
	generate_nutrient_aggregated_set($product_ref);
	$modify_aggregate->($product_ref->{nutrition}{aggregated_set}{nutrients}) if defined $modify_aggregate;
	my $nutrition_ref = clone($product_ref->{nutrition});
	my $expected_tags_ref = ['en:unrelated-tag'];
	push @$expected_tags_ref, $expected_tag if defined $expected_tag;

	add_misc_tags_for_protein_energy($product_ref);
	is($product_ref->{misc_tags}, $expected_tags_ref, $description);
	add_misc_tags_for_protein_energy($product_ref);
	is($product_ref->{misc_tags}, $expected_tags_ref, "$description: repeated calls do not duplicate tags");
	is($product_ref->{nutrition}, $nutrition_ref, "$description: nutrition values are unchanged");
	return;
}

my @tests = (
	['kcal just below 20 percent', 9.99, 'energy-kcal', 200, $less_than_tag],
	['kcal exactly 20 percent', 10, 'energy-kcal', 200, $at_least_tag],
	['kcal just above 20 percent', 10.01, 'energy-kcal', 200, $at_least_tag],
	['zero protein is below 20 percent', 0, 'energy-kcal', 200, $less_than_tag],
	['kJ just below 20 percent', 9.99, 'energy-kj', 850, $less_than_tag],
	['kJ exactly 20 percent', 10, 'energy-kj', 850, $at_least_tag],
	['kJ just above 20 percent', 10.01, 'energy-kj', 850, $at_least_tag],
	['missing protein is not classified', undef, 'energy-kcal', 200, undef],
	['missing energy is not classified', 10, 'energy-kcal', undef, undef],
	['zero energy is not classified', 10, 'energy-kcal', 0, undef],
	['negative energy is not classified', 10, 'energy-kcal', -200, undef],
	['negative protein is not classified', -10, 'energy-kcal', 200, undef],
);

foreach my $test_ref (@tests) {
	my ($description, $proteins, $energy_nid, $energy, $expected_tag) = @$test_ref;
	my $nutrients_ref = {
		proteins => {value => $proteins, unit => 'g'},
		$energy_nid => {value => $energy, unit => $energy_nid eq 'energy-kcal' ? 'kcal' : 'kJ'},
	};
	check_tags($description, [input_set($nutrients_ref)], $expected_tag);
}

check_tags(
	'protein units are normalized',
	[input_set({proteins => {value => 10000, unit => 'mg'}, 'energy-kcal' => {value => 200, unit => 'kcal'}})],
	$at_least_tag
);

check_tags(
	'serving quantities are normalized',
	[
		input_set(
			{proteins => {value => 2, unit => 'g'}, 'energy-kcal' => {value => 40, unit => 'kcal'}},
			'packaging', 'serving'
		)
	],
	$at_least_tag
);

check_tags(
	'prepared nutrition per 100ml is classified',
	[
		input_set(
			{proteins => {value => 10, unit => 'g'}, 'energy-kcal' => {value => 200, unit => 'kcal'}}, 'packaging',
			'100ml', 'prepared'
		)
	],
	$at_least_tag
);

check_tags(
	'protein and energy from different preparations are not combined',
	[
		input_set({proteins => {value => 10, unit => 'g'}}, 'packaging', '100g', 'as_sold'),
		input_set({'energy-kcal' => {value => 200, unit => 'kcal'}}, 'packaging', '100g', 'prepared'),
	],
	undef
);

check_tags(
	'declared kcal are preferred without converting the denominator to kJ',
	[
		input_set(
			{
				proteins => {value => 9.99, unit => 'g'},
				'energy-kcal' => {value => 200, unit => 'kcal'},
				'energy-kj' => {value => 836, unit => 'kJ'}
			}
		)
	],
	$less_than_tag
);

check_tags(
	'computed kcal do not override declared kJ',
	[
		input_set(
			{
				proteins => {value => 10, unit => 'g'},
				carbohydrates => {value => 10, unit => 'g'},
				fat => {value => 0, unit => 'g'},
				'energy-kj' => {value => 1000, unit => 'kJ'}
			}
		)
	],
	$less_than_tag
);

check_tags(
	'computed energy is usable when declared energy is missing',
	[
		input_set(
			{
				proteins => {value => 10, unit => 'g'},
				carbohydrates => {value => 10, unit => 'g'},
				fat => {value => 0, unit => 'g'}
			}
		)
	],
	$at_least_tag
);

check_tags(
	'lower-priority kcal do not override the selected energy source',
	[
		input_set({proteins => {value => 10, unit => 'g'}, 'energy-kj' => {value => 1000, unit => 'kJ'}}),
		input_set({'energy-kcal' => {value => 100, unit => 'kcal'}}, 'usda'),
	],
	$less_than_tag
);

check_tags(
	'estimated protein is not classified',
	[
		input_set({'energy-kcal' => {value => 200, unit => 'kcal'}}),
		input_set({proteins => {value => 10, unit => 'g'}}, 'estimate'),
	],
	undef
);

check_tags(
	'estimated energy is not classified',
	[
		input_set({proteins => {value => 10, unit => 'g'}}),
		input_set({'energy-kcal' => {value => 200, unit => 'kcal'}}, 'estimate'),
	],
	undef
);

foreach my $nid ('proteins', 'energy') {
	foreach my $modifier ('<', '<=', '>', '>=') {
		check_tags(
			"$nid with an inequality modifier is not classified ($modifier)",
			[input_set({proteins => {value => 10, unit => 'g'}, 'energy-kj' => {value => 850, unit => 'kJ'}})],
			undef,
			sub ($nutrients_ref) {$nutrients_ref->{$nid}{modifier} = $modifier;}
		);
	}
	foreach my $value ('invalid', 'Inf', 'NaN') {
		check_tags(
			"invalid $nid is not classified ($value)",
			[input_set({proteins => {value => 10, unit => 'g'}, 'energy-kj' => {value => 850, unit => 'kJ'}})],
			undef,
			sub ($nutrients_ref) {$nutrients_ref->{$nid}{value} = $value;}
		);
	}
}

check_tags('missing nutrition clears stale threshold tags', [], undef);

done_testing();
