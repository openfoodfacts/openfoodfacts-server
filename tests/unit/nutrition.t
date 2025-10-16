#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Nutrition qw/generate_nutrient_aggregated_set_from_sets/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	[
		# Generated set should be empty given empty list
		"empty_with_no_set",
		{
			nutrition => {
				input_sets => []
			}
		},
	],
	[
		# Generated set should be empty given list with empty sets
		"empty_with_empty_set",
		{
			nutrition => {
				input_sets => [{}]
			}
		}
	],
	[
		# Generated set should be the same as the only set given list with one set
		"keep_only_given_set",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should be the same as the only non empty set given list with only one non empty set
		"keep_only_non_empty_set",
		{
			nutrition => {
				input_sets => [
					{},
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have all given nutrients given sets with different nutrients provided
		"keep_all_nutrients_with_same_properties",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					},
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "usda",
						nutrients => {
							sugars => {
								value_string => "5.2",
								value => 5.2,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have nutrients from most important source given sets with same nutrients with different sources
		"prioritize_by_source",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					},
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "usda",
						nutrients => {
							sodium => {
								value_string => "0.1",
								value => 0.1,
								unit => "g",
							},
							sugars => {
								value_string => "5.2",
								value => 5.2,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have nutrients from most important preparation given sets with same nutrients with different preparations
		"prioritize_by_preparation",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							},
							protein => {
								value_string => "6.2",
								value => 6.2,
								unit => "g",
							}
						}
					},
					{
						preparation => "prepared",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "0.1",
								value => 0.1,
								unit => "g",
							},
							sugars => {
								value_string => "5.2",
								value => 5.2,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have nutrients from most important per given sets with same nutrients with different per
		"prioritize_by_per",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							},
							sugars => {
								value_string => "5.2",
								value => 5.2,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "250",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "0.1",
								value => 0.1,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "100ml",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sugars => {
								value_string => "4.6",
								value => 4.6,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have nutrients from most important source then per given sets with same nutrients with different sources and per
		"prioritize_by_source_then_per",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							protein => {
								value_string => "8.2",
								value => 8.2,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sugars => {
								value_string => "5.2",
								value => 5.2,
								unit => "g",
							},
							protein => {
								value_string => "0",
								value => 0,
								unit => "g"
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "100",
						per_unit => "g",
						source => "manufacturer",
						nutrients => {
							sodium => {
								value_string => "0",
								value => 0,
								unit => "g",
							},
							sugars => {
								value_string => "7.6",
								value => 7.6,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "manufacturer",
						nutrients => {
							sodium => {
								value_string => "2",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have nutrients from most important source then preparation given sets with same nutrients with different sources and preparations
		"prioritize_by_source_then_preparation",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "manufacturer",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					},
					{
						preparation => "prepared",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sugars => {
								value_string => "5.2",
								value => 5.2,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have nutrients from most important per then preparation given sets with same nutrients with different per and preparations
		"prioritize_by_per_then_preparation",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "prepared",
						per => "serving",
						per_quantity => "250",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					},
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sugars => {
								value_string => "5.2",
								value => 5.2,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have normalized weight units for nutrients
		"normalize_nutrient_weights",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "200.0",
								value => 200,
								unit => "mg",
								modifier => "<="
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have normalized unit for energy-kcal nutrient
		"normalize_energy_kcal_nutrient_unit",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"energy-kcal" => {
								value_string => "125",
								value => 125,
								unit => "kJ",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have normalized unit for energy nutrient
		"normalize_energy_nutrient_unit",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							energy => {
								value_string => "30",
								value => 30,
								unit => "kcal",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have normalized unit for energy-kj nutrient
		"normalize_energy_kj_nutrient_unit",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"energy-kj" => {
								value_string => "30",
								value => 30,
								unit => "kcal",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should keep unit if it is standard unit
		"keep_standard_unit",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"energy-kj" => {
								value_string => "30",
								value => 30,
								unit => "kJ",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have converted per when different per in nutrients given nutrient with most priority with per in 100g/ml
		"convert_per_nutrients_when_wanted_per_100g",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.5",
								value => 2.5,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "50",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sugars => {
								value_string => "6.3",
								value => 6.3,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have converted per when different per in nutrients given nutrient with most priority with per in serving
		"convert_per_nutrients_when_wanted_per_serving",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"sodium" => {
								value_string => "2.5",
								value => 2.5,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "50",
						per_unit => "g",
						source => "manufacturer",
						nutrients => {
							"sugars" => {
								value_string => "6.3",
								value => 6.3,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have converted per when different per in nutrients given nutrients per in different servings
		"convert_per_nutrients_when_different_per_serving_quantities",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"sodium" => {
								value_string => "2.5",
								value => 2.5,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "50",
						per_unit => "g",
						source => "manufacturer",
						nutrients => {
							"sugars" => {
								value_string => "6.3",
								value => 6.3,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have converted per nutrients given nutrients per in different serving units with wanted in g
		"convert_per_nutrients_when_different_per_units_g",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "100",
						per_unit => "mg",
						source => "packaging",
						nutrients => {
							"sodium" => {
								value_string => "0.025",
								value => 0.025,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "50",
						per_unit => "g",
						source => "manufacturer",
						nutrients => {
							"sugars" => {
								value_string => "6.3",
								value => 6.3,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have converted per nutrients given nutrients per in different serving units with wanted not in g
		"convert_per_nutrients_when_different_per_units_not_g",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "100",
						per_unit => "mg",
						source => "packaging",
						nutrients => {
							"sodium" => {
								value_string => "0.025",
								value => 0.025,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "5",
						per_unit => "kg",
						source => "manufacturer",
						nutrients => {
							"sugars" => {
								value_string => "6.3",
								value => 6.3,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should have converted per nutrients given nutrients per in different serving units with wanted in volume unit
		"convert_per_nutrients_when_different_per_units_volume",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "1",
						per_unit => "l",
						source => "packaging",
						nutrients => {
							"sodium" => {
								value_string => "0.25",
								value => 0.25,
								unit => "g",
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "50",
						per_unit => "ml",
						source => "manufacturer",
						nutrients => {
							"sugars" => {
								value_string => "0.063",
								value => 0.063,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	[
		# Generated set should not have nutrient values from sets without serving quantity
		"keep_only_nutrients_with_serving_quantity",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
								value_string => "2.0",
								value => 2,
								unit => "g",
								modifier => "<="
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => undef,
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sugars => {
								value_string => "5.60",
								value => 5.6,
								unit => "g"
							}
						}
					},

					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							protein => {
								value_string => "1.2",
								value => 1.2,
								unit => "g"
							}
						}
					},
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							iron => {
								value_string => "0.1",
								value => 0.1,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	my $nutrient_set_preferred_ref
		= generate_nutrient_aggregated_set_from_sets($product_ref->{nutrition}{input_sets});
	if (defined $nutrient_set_preferred_ref) {
		$product_ref->{nutrition}{aggregated_set} = $nutrient_set_preferred_ref;
	}

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});
}

done_testing();
