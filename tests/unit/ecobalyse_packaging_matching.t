#!/usr/bin/perl -w

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::Test qw/init_expected_results compare_to_expected_results/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::EnvironmentalImpact qw/get_ecobalyse_packaging_entry/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Load taxonomies so that is_a() and get_taxonomy_tag_level() work
ProductOpener::Tags::init_taxonomies(0);

# Each test case: [ $testid, $product_json ]
# The product JSON contains categories_tags, packagings (with material/shape), and product_quantity.
# After matching, the result is stored in $product_ref->{environmental_impact}{ecobalyse_input}{packaging}
# and the whole product_ref is compared against the expected JSON file.

my @tests = (

	# Glass bottle for olive oil: must select the glass bottle entry (exact category match)
	[
		'pkg_olive_oil_glass',
		'{
			"categories_tags": ["en:olive-oils", "en:plant-based-foods"],
			"packagings": [
				{"material": "en:glass", "shape": "en:bottle", "quantity_per_unit": 0.75}
			],
			"product_quantity": 0.75
		}'
	],

	# Plastic bottle for olive oil: material match (100) beats glass, so the plastic bottle entry is selected
	[
		'pkg_olive_oil_plastic',
		'{
			"categories_tags": ["en:olive-oils"],
			"packagings": [
				{"material": "en:plastic", "shape": "en:bottle", "quantity_per_unit": 1}
			],
			"product_quantity": 1
		}'
	],

	# Sardines in a glass jar: Ecobalyse only has sardines in metal box for the exact category,
	# so the category-less glass jar proxy must be selected (material+shape match beats exact-category metal box).
	[
		'pkg_sardines_glass_jar',
		'{
			"categories_tags": ["en:sardines"],
			"packagings": [
				{"material": "en:glass", "shape": "en:jar", "quantity_per_unit": 115}
			],
			"product_quantity": 115
		}'
	],

	# Biscuits in a plastic bag: exact category match for the plastic bag entry
	[
		'pkg_biscuits_bag',
		'{
			"categories_tags": ["en:biscuits"],
			"packagings": [
				{"material": "en:plastic", "shape": "en:bag", "quantity_per_unit": 250}
			],
			"product_quantity": 250
		}'
	],

	# Material is_a (child): green glass is a child of glass, so it matches the glass entry (score 80)
	[
		'pkg_material_is_a_glass',
		'{
			"categories_tags": ["en:olive-oils"],
			"packagings": [
				{"material": "en:green-glass", "shape": "en:bottle", "quantity_per_unit": 0.75}
			],
			"product_quantity": 0.75
		}'
	],

	# Material is_a (parent): PP 5 is a child of plastic, so it matches the plastic entry (score 80)
	[
		'pkg_material_is_a_pp',
		'{
			"categories_tags": ["en:olive-oils"],
			"packagings": [
				{"material": "en:pp-5-polypropylene", "shape": "en:bottle", "quantity_per_unit": 1}
			],
			"product_quantity": 1
		}'
	],

	# Two packaging components (plastic bag + glass bottle): the component with the higher ECS wins on the tiebreaker
	[
		'pkg_two_components',
		'{
			"categories_tags": ["en:biscuits", "en:olive-oils"],
			"packagings": [
				{"material": "en:plastic", "shape": "en:bag", "quantity_per_unit": 250},
				{"material": "en:glass", "shape": "en:bottle", "quantity_per_unit": 0.75}
			],
			"product_quantity": 0.75
		}'
	],

	# Product with no packaging components: no candidate, result is undef (no environmental_impact.pkg key added)
	[
		'pkg_no_packaging',
		'{
			"categories_tags": ["en:biscuits"],
			"packagings": [],
			"product_quantity": 250
		}'
	],

);

my $json = JSON->new->allow_nonref->canonical;

for my $test_ref (@tests) {
	my ($testid, $product_json) = @$test_ref;
	my $product_ref = $json->decode($product_json);

	my $entry = get_ecobalyse_packaging_entry($product_ref);

	if (defined $entry) {
		$product_ref->{environmental_impact}{ecobalyse_input}{packaging} = {
			id => $entry->{id},
			name => $entry->{activityName},
			name_fr => $entry->{displayName},
			ecs => $entry->{ecs},
			category => $entry->{categories_tagid},
		};
	}

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
