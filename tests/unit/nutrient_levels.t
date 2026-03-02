#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Food qw/compute_nutrient_levels /;
use ProductOpener::Tags qw/compute_field_tags/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (

	# Basic test case for compute_nutrient_levels
	[
		"basic_nutrient_levels",
		{
			categories => "chocolates",
			nutrition => {
				aggregated_set => {
					preparation => "as_sold",
					per => "100g",
					per_quantity => "100",
					per_unit => "g",
					source => "packaging",
					nutrients => {
						salt => {
							value_string => "2.0",
							value => 2,
							unit => "g",
							modifier => "<="
						},
						sugars => {
							value_string => "5.2",
							value => 5.2,
							unit => "g",
						},
						protein => {
							value_string => "6.2",
							value => 6.2,
							unit => "g",
						},
						energy_kcal => {
							value_string => "125",
							value => 125,
							unit => "kcal",
						}
					}
				}
			}
		}
	],

	# Missing category
	[
		"missing_category",
		{
			nutrition => {
				aggregated_set => {
					preparation => "as_sold",
					per => "100g",
					per_quantity => "100",
					per_unit => "g",
					source => "packaging",
					nutrients => {
						salt => {
							value_string => "2.0",
							value => 2,
							unit => "g",
							modifier => "<="
						},
						sugars => {
							value_string => "5.2",
							value => 5.2,
							unit => "g",
						},
						protein => {
							value_string => "6.2",
							value => 6.2,
							unit => "g",
						},
						energy_kcal => {
							value_string => "125",
							value => 125,
							unit => "kcal",
						}
					}
				}
			}
		}
	],

	# Category for which we have prepared nutrients in the aggregated set
	[
		"category_with_prepared_nutrients",
		{
			categories => "flavoured syrups",
			nutrition => {
				aggregated_set => {
					preparation => "prepared",
					per => "100g",
					per_quantity => "100",
					per_unit => "g",
					source => "packaging",
					nutrients => {
						salt => {
							value_string => "2.0",
							value => 2,
							unit => "g",
							modifier => "<="
						},
						sugars => {
							value_string => "5.2",
							value => 5.2,
							unit => "g",
						},
						protein => {
							value_string => "6.2",
							value => 6.2,
							unit => "g",
						},
						energy_kcal => {
							value_string => "125",
							value => 125,
							unit => "kcal",
						}
					}
				}
			}
		}
	],

	# Category for which we should have prepared nutrients in the aggregated set, but we have as_sold nutrients
	[
		"category_needing_prepared_but_only_as_sold_available",
		{
			categories => "dried soups",
			nutrition => {
				aggregated_set => {
					preparation => "as_sold",
					per => "100g",
					per_quantity => "100",
					per_unit => "g",
					source => "packaging",
					nutrients => {
						salt => {
							value_string => "2.0",
							value => 2,
							unit => "g",
							modifier => "<="
						},
						sugars => {
							value_string => "5.2",
							value => 5.2,
							unit => "g",
						},
						protein => {
							value_string => "6.2",
							value => 6.2,
							unit => "g",
						},
						energy_kcal => {
							value_string => "125",
							value => 125,
							unit => "kcal",
						}
					}
				}
			}
		}
	],

);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	compute_field_tags($product_ref, "en", "categories");

	compute_nutrient_levels($product_ref);

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});
}

done_testing();
