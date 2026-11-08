#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use List::Util qw/sum0/;
use Log::Any::Adapter 'TAP', filter => 'none';

use ProductOpener::Ingredients qw/parse_ingredients_text_service estimate_ingredients_percent_service/;

# Find groups at any depth so that nested additive groups are checked too.
sub find_ingredient ($ingredients_ref, $id) {

	foreach my $ingredient_ref (@{$ingredients_ref}) {
		return $ingredient_ref if $ingredient_ref->{id} eq $id;
		if (defined $ingredient_ref->{ingredients}) {
			my $found_ref = find_ingredient($ingredient_ref->{ingredients}, $id);
			return $found_ref if defined $found_ref;
		}
	}
	return;
}

my @tests = (
	[
		'reported Danish gum - issue 14723',
		{
			lc => 'da',
			ingredients_text =>
				'63 % sødestoffer (E 965, E 420, E 953, E 951, E 950), 24 % gummibase (indeholder palmeolie), '
				. '8 % fugtighedsbevarende midler (E 422 vegetabilsk, E 1518 vegetabilsk), 2 % fortykningsmidler (E 414, E 466), '
				. 'spearmintaroma, naturlig mentolaroma, aromaer, emulgator (E 322 vegetabilsk), '
				. 'overfladebehandlingsmiddel (E 903), farvestoffer (E 100, E 133).',
		},
		[
			['en:sweetener', 63, ['en:e965', 'en:e420', 'en:e953', 'en:e951', 'en:e950']],
			['en:humectant', 8, ['en:e422', 'en:e1518']],
			['en:thickener', 2, ['en:e414', 'en:e466']],
		],
	],
	[
		'percentage after the additive class',
		{lc => 'en', ingredients_text => 'water, sweeteners 20% (E965, E420), E322'},
		[['en:sweetener', 20, ['en:e965', 'en:e420']]],
	],
	[
		'nested percentage-bearing additive group',
		{lc => 'en', ingredients_text => 'water, chocolate 30% (sweeteners 20% (E965, E420), cocoa), salt'},
		[['en:sweetener', 20, ['en:e965', 'en:e420']]],
	],
	[
		'zero percent is still a specified percentage',
		{lc => 'en', ingredients_text => 'water 100%, sweeteners 0% (E965, E420)'},
		[['en:sweetener', 0, ['en:e965', 'en:e420']]],
	],
	[
		'percentage-bearing group with one additive',
		{lc => 'en', ingredients_text => 'water, humectants 8% (E422)'},
		[['en:humectant', 8, ['en:e422']]],
	],
);

foreach my $test_ref (@tests) {

	my ($description, $product_ref, $groups_ref) = @{$test_ref};
	subtest $description => sub {

		parse_ingredients_text_service($product_ref, {}, []);

		foreach my $group_ref (@{$groups_ref}) {
			my ($id, $percent, $children_ref) = @{$group_ref};
			my $ingredient_ref = find_ingredient($product_ref->{ingredients}, $id);
			ok(defined $ingredient_ref, "$id group is retained");
			next if not defined $ingredient_ref;

			is($ingredient_ref->{percent}, $percent, "$id keeps its declared percentage");
			is([map {$_->{id}} @{$ingredient_ref->{ingredients}}],
				$children_ref, "$id keeps its children in the declared order");
			is(
				[map {$_->{additive_class}} @{$ingredient_ref->{ingredients}}],
				[map {$id} @{$children_ref}],
				"$id children keep their additive class"
			);
		}

		# The parent class must not leak onto a later, unrelated additive.
		if ($description eq 'percentage after the additive class') {
			my $emulsifier_ref = find_ingredient($product_ref->{ingredients}, 'en:e322');
			ok(defined $emulsifier_ref, 'The following additive is retained');
			is($emulsifier_ref->{additive_class}, undef, 'The sweetener class is scoped to its children')
				if defined $emulsifier_ref;
		}

		estimate_ingredients_percent_service($product_ref, {}, []);
		is($product_ref->{ingredients_percent_analysis}, 1, 'Percentage constraints remain valid');

		foreach my $group_ref (@{$groups_ref}) {
			my ($id, $percent) = @{$group_ref};
			my $ingredient_ref = find_ingredient($product_ref->{ingredients}, $id);
			next if not defined $ingredient_ref;

			is($ingredient_ref->{percent_estimate}, $percent, "$id estimate respects the declared percentage");
			my $children_percent = sum0(map {$_->{percent_estimate}} @{$ingredient_ref->{ingredients}});
			cmp_ok(abs($children_percent - $percent), '<', 0.000001, "$id children sum to the parent percentage");
		}

		my $total_percent = sum0(map {$_->{percent_estimate}} @{$product_ref->{ingredients}});
		cmp_ok(abs($total_percent - 100), '<', 0.000001, 'Top-level estimates sum to 100%');
	};
}

subtest 'additive groups without a percentage still flatten' => sub {

	my $product_ref = {lc => 'en', ingredients_text => 'sweeteners (E965, E420), water'};
	parse_ingredients_text_service($product_ref, {}, []);
	is(
		[map {$_->{id}} @{$product_ref->{ingredients}}],
		['en:e965', 'en:e420', 'en:water'],
		'Unquantified additive groups keep their existing flat structure'
	);
	is(
		[map {$_->{additive_class}} @{$product_ref->{ingredients}}[0, 1]],
		['en:sweetener', 'en:sweetener'],
		'Flattened additives keep their class'
	);
};

done_testing();
