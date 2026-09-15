#!/usr/bin/perl -w

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::Test qw/init_expected_results compare_to_expected_results/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::EnvironmentalImpact qw/get_ecobalyse_transformation_entries/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

ProductOpener::Tags::init_taxonomies(0);

my @tests = (

	# Canned vegetables: matches canning transformation
	[
		'canned_vegetables',
		'{
			"categories_tags": ["en:canned-vegetables"]
		}'
	],

	# Cooked meats: matches cooking transformation
	[
		'cooked_meat',
		'{
			"categories_tags": ["en:cooked-meats"]
		}'
	],

	# No transformation category: returns empty list
	[
		'no_transformation',
		'{
			"categories_tags": ["en:olive-oils"]
		}'
	],

	# Multiple applicable transformations: both cooking and canning
	[
		'multiple_transformations',
		'{
			"categories_tags": ["en:canned-vegetables", "en:cooked-meats"]
		}'
	],

);

my $json = JSON->new->allow_nonref->canonical;

for my $test_ref (@tests) {
	my ($testid, $product_json) = @$test_ref;
	my $product_ref = $json->decode($product_json);

	my @entries = get_ecobalyse_transformation_entries($product_ref);

	if (@entries) {
		$product_ref->{environmental_impact}{ecobalyse_input}{transformations} = [];
		for my $entry (@entries) {
			push @{$product_ref->{environmental_impact}{ecobalyse_input}{transformations}},
				{
				id => $entry->{id},
				name => $entry->{name},
				name_fr => $entry->{name_fr},
				ecs => $entry->{ecs},
				unit => $entry->{unit},
				};
		}
	}

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
