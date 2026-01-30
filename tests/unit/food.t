#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/exists_taxonomy_tag has_tag get_property %properties/;
use ProductOpener::Food qw/:all/;
use ProductOpener::FoodProducts qw/:all/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;
use ProductOpener::Nutrition qw/assign_nutrition_values_from_old_request_parameters/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Note: the categories en:unsweetened-beverages, en:sweetened-beverages, en:artificially-sweetened-beverages
# are now only added temporarily when we compute food groups, they are not kept in the product categories

my $product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
};

# without an ingredient list: should not add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

# ok((not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should not add en:unsweetened-beverages')
#	|| diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "unknown") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

#ok( (has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should add en:unsweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_text => "water, sugar",
};

specific_processes_for_food_product($product_ref);

#ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_text => "sugar, e950",
};

specific_processes_for_food_product($product_ref);

#ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
	categories => "beverages",
	ingredients_text => "sugar, e950",
};

specific_processes_for_food_product($product_ref);

#ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag Dumper $product_ref;
#ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
};

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Waters and flavored waters") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:iced-teas"],
};

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Teas and herbal teas and coffees") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:ice-teas"],
	ingredients_text => "sugar, sorbitol",
};

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages"],
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:unsweetened-beverages"],
	ingredients_tags => ["en:water", "en:sugar"],
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag Dumper $product_ref;

is($product_ref->{nutrition_score_beverage}, 1);

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:plant-based-milk-alternatives"],
	ingredients_tags => ["en:water", "en:sugar"],
	ingredients_text => "water, fruit juice",
};

specific_processes_for_food_product($product_ref);

is($product_ref->{nutrition_score_beverage}, 0);

# Check that the nutrients defined in %nutrients_tables are defined in the nutrients taxonomy

foreach (@{$nutrients_tables{europe}}) {

	my $nid = $_;    # Copy instead of alias

	next if $nid =~ /^#/;

	$nid =~ s/^!//;
	$nid =~ s/^-+//;
	$nid =~ s/-+$//;

	# The nutrient ids do not correspond exactly to the English name, so we use zz:[nutrient id]
	# as the canonical tag id instead of en:[English nutrient name]
	my $tagid = "zz:$nid";
	my $error = 0;

	ok(exists_taxonomy_tag("nutrients", $tagid), "$tagid exists in the nutrients taxonomy");
}

# Testing for get_nutrient_unit both for India and a country where no unit is described
# Test case for fetching unit for sodium in India
{
	my $unit_in_india = get_nutrient_unit("sodium", "in");
	is($unit_in_india, "mg", "Check if unit_in is fetched correctly for sodium in India");
}

# Test case for fetching unit for sodium outside India (eg: US)
{
	my $unit_in_us = get_nutrient_unit("sodium", "us");
	is($unit_in_us, "mg", "Check if unit_us is fetched correctly for sodium in US");
}

# Test case for fetching unit for sodium outside India (eg: Canada)
{
	my $unit_in_canada = get_nutrient_unit("sodium", "ca");
	is($unit_in_canada, "g", "Check if unit is fetched correctly for sodium in Canada");
}

# Test case for a product that previously had ingredients and additives, and then has its ingredients removed

$product_ref = {
	lc => "en",
	categories => "beverages",
	ingredients_text => "water, fruit juice, citric acid",
};

specific_processes_for_food_product($product_ref);

ok((has_tag($product_ref, 'additives', 'en:e330')), 'should have en:330') || diag Dumper $product_ref;

delete $product_ref->{ingredients_text};

specific_processes_for_food_product($product_ref);

ok((not has_tag($product_ref, 'additives', 'en:e330')), 'should not have en:330') || diag Dumper $product_ref;

# same logic as in process_product_edit_rules.t:
# the single_param function in Display is overwritten (monkey patch)
# to allow to run the function assign_nid_modifier_value_and_unit
# otherwise the following line prevent tests to run as expected:
# "next if (not defined single_param("nutriment_${enid}${product_type}"));"
my @tests = (
	{
		id => "rm insignificants digits",
		desc => "Should round floats",
		form => {
			'nutriment_energy-kj' => '0.40000000596046',
			'nutriment_energy_unit' => 'kJ',
			'nutriment_fat' => '3.99999',
			'nutriment_fat_unit' => 'g',
			'nutriment_salt' => '1.000001',
			'nutriment_salt_unit' => 'g',
		},
		nutriment_table => "off_europe",
		product_ref => {
			'nutriments' => {}
		},
		expected_product_ref => {
			'nutriments' => {},
			'nutrition' => {
				'input_sets' => [
					{
						'nutrients' => {
							'energy-kj' => {
								'unit' => 'kJ',
								'value' => '0.4',
								'value_string' => '0.4'
							},
							'fat' => {
								'unit' => 'g',
								'value' => 4,
								'value_string' => 4
							},
							'salt' => {
								'unit' => 'g',
								'value' => 1,
								'value_string' => '1'
							}
						},
						'per' => '100g',
						'per_quantity' => 100,
						'per_unit' => 'g',
						'preparation' => 'as_sold',
						'source' => 'packaging'
					}
				]
			}
			}

		,
	}
);
my %form = ();
{
	# monkey patch request_param
	my $products_module = mock 'ProductOpener::Nutrition' => (
		override => [
			request_param => sub {
				my ($request_ref, $name) = @_;
				return scalar $form{$name};
			}
		]
	);
	foreach my $test_ref (@tests) {
		eval {
			my $id = $test_ref->{id};
			my $desc = $test_ref->{desc};
			my %product = %{$test_ref->{product_ref}};
			%form = %{$test_ref->{form}};
			assign_nutrition_values_from_old_request_parameters({}, \%product, $test_ref->{nutriment_table},
				"packaging");

			is(\%product, $test_ref->{expected_product_ref}, "Result for $id - $desc") || diag Dumper \%product;

		};
		if ($@) {
			diag("Error running test: $@");
		}
	}
}

# test compare_nutrients
my @comparison_tests = (
	[
		"nutrients-comparisons",
		{
			nutrition => {
				aggregated_set => {
					nutrients => {
						"fat" => {
							value => 30.9
						},
						"salt" => {
							value => 4
						},
						"energy" => {
							value => 2252
						},
						"saturated-fats" => {
							value => 2.4
						},
						"proteins" => {
							value => 7.2
						}
					},
					preparation => "as_sold",
					per => "100g",
				}
			}
		},
		{
			nutriments => {
				energy_100g => 1055,
				fat_100g => -10,
				"saturated-fats_100g" => 13,
				sugars_100g => 2,
				salt_100g => 4
			}
		}
	]
);

foreach my $test_ref (@comparison_tests) {
	my $testid = $test_ref->[0];
	my $product_test_ref = $test_ref->[1];
	my $reference_test_ref = $test_ref->[2];

	my $comparisons = compare_nutrients($product_test_ref, $reference_test_ref);

	compare_to_expected_results($comparisons, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});

}

done_testing();
