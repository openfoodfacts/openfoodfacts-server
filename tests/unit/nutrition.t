#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Nutrition qw/:all/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

use Data::DeepAccess qw(deep_get);

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

is(convert_salt_to_sodium(2.5), 1);
is(convert_sodium_to_salt(1), 2.5);

# Test the generation of the aggregated set from input sets

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
	# Vitamin values in International Units (IU), e.g. Vitamin A, or %DV for Vitamin D
	[
		"normalize_vitamin_iu_dv_units",
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
							"vitamin-e" => {
								value_string => "40",
								value => 40,
								unit => "IU",
							},
							"calcium" => {
								value_string => "20",
								value => 20,
								unit => "% DV",
							},
							"vitamin-b1" => {
								value_string => "100",
								value => 100,
								unit => "% DV",
							},
							"vitamin-d" => {
								value_string => "20",
								value => 20,
								unit => "% DV",
							},
							"vitamin-a" => {
								value_string => "40",
								value => 40,
								unit => "IU",
							}
						}
					}
				]
			}
		}
	],
	# If we only have values per serving, and the serving size is less than 5g, we don't extrapolote values to 100g as it is too imprecise
	[
		"no_extrapolation_for_small_serving_size",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "3",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							sodium => {
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
	# If the serving size is 4 fl oz (about 118ml), we extrapolote values to 100ml as it is not too small
	[
		"extrapolation_for_4_fl_oz_serving_size",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "4",
						per_unit => "fl oz",
						source => "packaging",
						nutrients => {
							sodium => {
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
	# Input set per serving, without a serving size and values in per_quantity and per_unit: aggregated set should be empty
	[
		"no_aggregated_set_without_serving_size",
		{
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						source => "packaging",
						nutrients => {
							sodium => {
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
	# Salt and sodium in g
	[
		"salt-and-sodium-in-g",
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
							},
							salt => {
								value_string => "5.0",
								value => 5,
								unit => "g",
							}
						}
					}
				]
			}
		}
	],
	# Salt in g and sodium in mg
	[
		"salt-in-g-and-sodium-in-mg",
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
								value_string => "2000.0",
								value => 2000,
								unit => "mg",
							},
							salt => {
								value_string => "5.0",
								value => 5,
								unit => "g",
							}
						}
					}
				]
			}
		}

	],
	# Sodium in mg and salt in mg
	[
		"sodium-and-salt-in-mg",
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
							salt => {
								value_string => "5000.0",
								value => 5000,
								unit => "mg",
							},
							sodium => {
								value_string => "2000.0",
								value => 2000,
								unit => "mg",
							},
						}
					}
				]
			}
		}
	],
	# Sodium in mg only
	[
		"sodium-in-mg-only",
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
								value_string => "2000.0",
								value => 2000,
								unit => "mg",
							}
						}
					}
				]
			}
		}
	],

	# As sold data per 100g and prepared data for 100ml
	[
		"as_sold_per_100g_and_prepared_per_100ml",
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
							sugars => {
								value_string => "25.0",
								value => 25,
								unit => "g",
							}
						}
					},
					{
						preparation => "prepared",
						per => "100ml",
						per_quantity => "100",
						per_unit => "ml",
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
	]
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	ProductOpener::Nutrition::add_computed_values_to_nutrient_sets($product_ref->{nutrition}{input_sets});

	my $nutrient_set_preferred_ref
		= generate_nutrient_aggregated_set_from_sets($product_ref->{nutrition}{input_sets});
	if (defined $nutrient_set_preferred_ref) {
		$product_ref->{nutrition}{aggregated_set} = $nutrient_set_preferred_ref;
	}

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});
}

# Other tests

# Computing the populated nutrition fields to export to CSV

my $product_ref = {
	nutrition => {
		aggregated_set => {
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			source => "aggregated",
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
					},
					"sugars" => {
						value_string => "2.0",
						value => 2,
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
};

my $populated_fields_ref = {};

ProductOpener::Nutrition::add_nutrition_fields_from_product_to_populated_fields($product_ref, $populated_fields_ref,
	"nutrition");

compare_to_expected_results(
	$populated_fields_ref, "$expected_result_dir/add_nutrition_fields_from_product_to_populated_fields.json",
	$update_expected_results, {id => "add_nutrition_fields_from_product_to_populated_fields"}
);

# Unit tests for normalize_nutrient_value_string_and_modifier function

# Test empty and nan values
{
	my $value = "";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, undef, "empty value becomes undef");
	is($modifier, undef, "empty value modifier is undef");
}

{
	my $value = "   ";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, undef, "whitespace-only value becomes undef");
	is($modifier, undef, "whitespace-only value modifier is undef");
}

{
	my $value = "NaN";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, undef, "NaN value becomes undef");
	is($modifier, undef, "NaN value modifier is undef");
}

{
	my $value = "nan";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, undef, "lowercase nan value becomes undef");
	is($modifier, undef, "lowercase nan value modifier is undef");
}

# Test <= modifier
{
	my $value = "<= 10";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "10", "<= modifier removes sign");
	is($modifier, "\N{U+2264}", "<= modifier sets correct unicode");
}

{
	my $value = "≤ 5.5";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "5.5", "≤ modifier removes sign");
	is($modifier, "\N{U+2264}", "≤ modifier sets correct unicode");
}

{
	my $value = "&lt;=15";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "15", "&lt;= modifier removes sign");
	is($modifier, "\N{U+2264}", "&lt;= modifier sets correct unicode");
}

# Test < modifier
{
	my $value = "< 20";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "20", "< modifier removes sign");
	is($modifier, "<", "< modifier sets correct symbol");
}

{
	my $value = "&lt; 25";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "25", "&lt; modifier removes sign");
	is($modifier, "<", "&lt; modifier sets correct symbol");
}

{
	my $value = "max 30";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "30", "max modifier removes sign");
	is($modifier, "\N{U+2264}", "max modifier sets ≤ symbol");
}

{
	my $value = "maximum 35";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "35", "maximum modifier removes sign");
	is($modifier, "\N{U+2264}", "maximum modifier sets ≤ symbol");
}

{
	my $value = "inf 40";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "40", "inf modifier removes sign");
	is($modifier, "<", "inf modifier sets < symbol");
}

{
	my $value = "inferior 45";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "45", "inferior modifier removes sign");
	is($modifier, "<", "inferior modifier sets < symbol");
}

{
	my $value = "less than 50";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "50", "less than modifier removes sign");
	is($modifier, "<", "less than modifier sets < symbol");
}

{
	my $value = "menos 55";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "55", "menos modifier removes sign");
	is($modifier, "<", "menos modifier sets < symbol");
}

# Test >= modifier
{
	my $value = ">= 60";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "60", ">= modifier removes sign");
	is($modifier, "\N{U+2265}", ">= modifier sets correct unicode");
}

{
	my $value = "≥ 65";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "65", "≥ modifier removes sign");
	is($modifier, "\N{U+2265}", "≥ modifier sets correct unicode");
}

{
	my $value = "&gt;=70";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "70", "&gt;= modifier removes sign");
	is($modifier, "\N{U+2265}", "&gt;= modifier sets correct unicode");
}

# Test > modifier
{
	my $value = "> 75";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "75", "> modifier removes sign");
	is($modifier, ">", "> modifier sets correct symbol");
}

{
	my $value = "&gt; 80";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "80", "&gt; modifier removes sign");
	is($modifier, ">", "&gt; modifier sets correct symbol");
}

{
	my $value = "min 85";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "85", "min modifier removes sign");
	is($modifier, "\N{U+2265}", "min modifier sets ≥ symbol");
}

{
	my $value = "minimum 90";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "90", "minimum modifier removes sign");
	is($modifier, "\N{U+2265}", "minimum modifier sets ≥ symbol");
}

{
	my $value = "greater 95";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "95", "greater modifier removes sign");
	is($modifier, ">", "greater modifier sets > symbol");
}

{
	my $value = "more than 100";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "100", "more than modifier removes sign");
	is($modifier, ">", "more than modifier sets > symbol");
}

{
	my $value = "superior 105";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "105", "superior modifier removes sign");
	is($modifier, ">", "superior modifier sets > symbol");
}

# Test ~ modifier
{
	my $value = "~ 110";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "110", "~ modifier removes sign");
	is($modifier, "~", "~ modifier sets correct symbol");
}

{
	my $value = "≈ 115";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "115", "≈ modifier removes sign");
	is($modifier, "~", "≈ modifier sets correct symbol");
}

{
	my $value = "about 120";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "120", "about modifier removes sign");
	is($modifier, "~", "about modifier sets correct symbol");
}

{
	my $value = "env 125";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "125", "env modifier removes sign");
	is($modifier, "~", "env modifier sets correct symbol");
}

{
	my $value = "environ 130";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "130", "environ modifier removes sign");
	is($modifier, "~", "environ modifier sets correct symbol");
}

{
	my $value = "aprox 135";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "135", "aprox modifier removes sign");
	is($modifier, "~", "aprox modifier sets correct symbol");
}

{
	my $value = "alrededor 140";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "140", "alrededor modifier removes sign");
	is($modifier, "~", "alrededor modifier sets correct symbol");
}

# Test trace values
{
	my $value = "trace";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, 0, "trace value becomes 0");
	is($modifier, "~", "trace value modifier is ~");
}

{
	my $value = "traces";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, 0, "traces value becomes 0");
	is($modifier, "~", "traces value modifier is ~");
}

{
	my $value = "traza";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, 0, "traza value becomes 0");
	is($modifier, "~", "traza value modifier is ~");
}

{
	my $value = "trazas";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, 0, "trazas value becomes 0");
	is($modifier, "~", "trazas value modifier is ~");
}

# Test dash values
{
	my $value = "-";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, undef, "dash value becomes undef");
	is($modifier, "-", "dash value modifier is -");
}

{
	my $value = " - ";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, undef, "spaced dash value becomes undef");
	is($modifier, "-", "spaced dash value modifier is -");
}

# Test normal values without modifiers
{
	my $value = "150";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "150", "normal value stays the same");
	is($modifier, undef, "normal value modifier is undef");
}

{
	my $value = "  155  ";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "155", "value with spaces gets trimmed");
	is($modifier, undef, "value with spaces modifier is undef");
}

{
	my $value = "160.5";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "160.5", "decimal value stays the same");
	is($modifier, undef, "decimal value modifier is undef");
}

# Test edge cases
{
	my $value = "<= 0";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "0", "<= 0 removes sign");
	is($modifier, "\N{U+2264}", "<= 0 modifier sets correct unicode");
}

{
	my $value = "trace amount";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, 0, "trace amount becomes 0");
	is($modifier, "~", "trace amount modifier is ~");
}

{
	my $value = "notrace";
	my $modifier;
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "notrace", "word containing trace stays the same");
	is($modifier, undef, "word containing trace modifier is undef");
}

# Unit tests for input modifier normalization in normalize_nutrient_value_string_and_modifier function

# Test input modifier normalization for <= variants
{
	my $value = "10";
	my $modifier = "&lt;=";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "10", "value unchanged when modifier is input");
	is($modifier, "\N{U+2264}", "&lt;= input modifier normalized to unicode ≤");
}

{
	my $value = "15";
	my $modifier = "<=";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "15", "value unchanged when modifier is input");
	is($modifier, "\N{U+2264}", "<= input modifier normalized to unicode ≤");
}

{
	my $value = "20";
	my $modifier = "≤";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "20", "value unchanged when modifier is input");
	is($modifier, "\N{U+2264}", "≤ input modifier stays as unicode ≤");
}

# Test input modifier normalization for < variants
{
	my $value = "25";
	my $modifier = "&lt;";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "25", "value unchanged when modifier is input");
	is($modifier, "<", "&lt; input modifier normalized to <");
}

{
	my $value = "30";
	my $modifier = "<";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "30", "value unchanged when modifier is input");
	is($modifier, "<", "< input modifier stays as <");
}

# Test input modifier normalization for >= variants
{
	my $value = "35";
	my $modifier = "&gt;=";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "35", "value unchanged when modifier is input");
	is($modifier, "\N{U+2265}", "&gt;= input modifier normalized to unicode ≥");
}

{
	my $value = "40";
	my $modifier = ">=";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "40", "value unchanged when modifier is input");
	is($modifier, "\N{U+2265}", ">= input modifier normalized to unicode ≥");
}

{
	my $value = "45";
	my $modifier = "≥";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "45", "value unchanged when modifier is input");
	is($modifier, "\N{U+2265}", "≥ input modifier stays as unicode ≥");
}

# Test input modifier normalization for > variants
{
	my $value = "50";
	my $modifier = "&gt;";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "50", "value unchanged when modifier is input");
	is($modifier, ">", "&gt; input modifier normalized to >");
}

{
	my $value = "55";
	my $modifier = ">";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "55", "value unchanged when modifier is input");
	is($modifier, ">", "> input modifier stays as >");
}

# Test input modifier normalization for ~ variants
{
	my $value = "60";
	my $modifier = "~";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "60", "value unchanged when modifier is input");
	is($modifier, "~", "~ input modifier stays as ~");
}

{
	my $value = "65";
	my $modifier = "≈";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "65", "value unchanged when modifier is input");
	is($modifier, "~", "≈ input modifier normalized to ~");
}

# Test input modifier normalization for -
{
	my $value = "70";
	my $modifier = "-";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "70", "value unchanged when modifier is input");
	is($modifier, "-", "- input modifier stays as -");
}

# Test unknown input modifier becomes undef
{
	my $value = "75";
	my $modifier = "unknown";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "75", "value unchanged when modifier is input");
	is($modifier, undef, "unknown input modifier becomes undef");
}

{
	my $value = "80";
	my $modifier = "max";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "80", "value unchanged when modifier is input");
	is($modifier, "\N{U+2264}", "max input modifier normalized to unicode ≤");
}

# Test that input modifier normalization happens before value string processing
# When both input modifier and value string have modifiers, value string modifier takes precedence
{
	my $value = "< 85";
	my $modifier = "&lt;=";
	normalize_nutrient_value_string_and_modifier(\$value, \$modifier);
	is($value, "85", "value string changed even though input modifier exists");
	is($modifier, "<", "input modifier normalized, value string modifier ignored");
}

# Unit tests for assign_nutrient_modifier_value_string_and_unit function

# Test basic assignment
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium", "<",
		"2.5", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "modifier"),
		"<", "modifier is set correctly");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"2.5", "value_string is set correctly");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value"),
		2.5, "value is set correctly");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "unit"),
		"g", "unit is set correctly");
}

# Test with modifier normalization
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		"max", "2.5", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "modifier"),
		"\N{U+2264}", "max modifier is normalized to <=");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"2.5", "value_string is set correctly");
}

# Test with value normalization
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "max 2.5", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "modifier"),
		"\N{U+2264}", "max in value string is extracted as modifier");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"2.5", "value is extracted correctly");
}

# Test default unit assignment
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "2.5", undef);
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "unit"),
		"g", "default unit for sodium is g");
}

# Test unit validation - valid unit
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "2.5", "mg");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "unit"),
		"mg", "valid unit mg is accepted");
}

# Test value cleaning and conversion
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "  2,5  ", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"2.5", "comma is converted to dot");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value"),
		2.5, "value is converted correctly");
}

# Test rounding of insignificant digits
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "5.00000001", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"5", "5.00000001 is rounded to 5");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value"), 5, "value is 5");
}

{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "4.999997", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"5", "4.999997 is rounded to 5");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value"), 5, "value is 5");
}

{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "2.0001", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"2", "2.0001 is rounded to 2");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value"), 2, "value is 2");
}

{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "0.0001", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value_string"),
		"0.0001", "0.0001 keeps its precision");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "value"),
		0.0001, "value is 0.0001");
}

# Test modifier cleanup
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium", "",
		"2.5", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "modifier"),
		undef, "empty modifier becomes undef");
}

# Test undefined modifier
{
	my $input_sets_hash_ref = {};
	assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, "packaging", "as_sold", "100g", "sodium",
		undef, "2.5", "g");
	is(deep_get($input_sets_hash_ref, "packaging", "as_sold", "100g", "nutrients", "sodium", "modifier"),
		undef, "undefined modifier stays undef");
}

# Test get_non_estimated_nutrient_per_100g_or_100ml_for_preparation function

# Test with packaging source, as_sold preparation, sodium nutrient
{
	my $product_ref = {
		nutrition => {
			input_sets => [
				{
					source => "packaging",
					preparation => "as_sold",
					per => "100g",
					per_quantity => 100,
					per_unit => "g",
					nutrients => {
						sodium => {
							value => 2.5,
							unit => "g"
						}
					}
				}
			]
		}
	};
	my $value = get_non_estimated_nutrient_per_100g_or_100ml_for_preparation($product_ref, "as_sold", "sodium");
	is($value, 2.5,
		"get_non_estimated_nutrient_per_100g_or_100ml_for_preparation returns correct value for packaging source");
}

# Test with estimate source - should return undef
{
	my $product_ref = {
		nutrition => {
			input_sets => [
				{
					source => "estimate",
					preparation => "as_sold",
					per => "100g",
					per_quantity => 100,
					per_unit => "g",
					nutrients => {
						sodium => {
							value => 2.5,
							unit => "g"
						}
					}
				}
			]
		}
	};
	my $value = get_non_estimated_nutrient_per_100g_or_100ml_for_preparation($product_ref, "as_sold", "sodium");
	is($value, undef, "get_non_estimated_nutrient_per_100g_or_100ml_for_preparation returns undef for estimate source");
}

# Test with different preparation - should return undef
{
	my $product_ref = {
		nutrition => {
			input_sets => [
				{
					source => "packaging",
					preparation => "prepared",
					per => "100g",
					per_quantity => 100,
					per_unit => "g",
					nutrients => {
						sodium => {
							value => 2.5,
							unit => "g"
						}
					}
				}
			]
		}
	};
	my $value = get_non_estimated_nutrient_per_100g_or_100ml_for_preparation($product_ref, "as_sold", "sodium");
	is($value, undef,
		"get_non_estimated_nutrient_per_100g_or_100ml_for_preparation returns undef for different preparation");
}

# Test with nutrient not present - should return undef
{
	my $product_ref = {
		nutrition => {
			input_sets => [
				{
					source => "packaging",
					preparation => "as_sold",
					per => "100g",
					per_quantity => 100,
					per_unit => "g",
					nutrients => {
						sugars => {
							value => 5.0,
							unit => "g"
						}
					}
				}
			]
		}
	};
	my $value = get_non_estimated_nutrient_per_100g_or_100ml_for_preparation($product_ref, "as_sold", "sodium");
	is($value, undef,
		"get_non_estimated_nutrient_per_100g_or_100ml_for_preparation returns undef for missing nutrient");
}

# Test with multiple sets - should return value from highest priority set
{
	my $product_ref = {
		nutrition => {
			input_sets => [
				{
					source => "packaging",
					preparation => "as_sold",
					per => "100g",
					per_quantity => 100,
					per_unit => "g",
					nutrients => {
						sodium => {
							value => 2.5,
							unit => "g"
						}
					}
				},
				{
					source => "manufacturer",
					preparation => "as_sold",
					per => "100g",
					per_quantity => 100,
					per_unit => "g",
					nutrients => {
						sodium => {
							value => 3.0,
							unit => "g"
						}
					}
				}
			]
		}
	};
	my $value = get_non_estimated_nutrient_per_100g_or_100ml_for_preparation($product_ref, "as_sold", "sodium");
	is($value, 3.0,
		"get_non_estimated_nutrient_per_100g_or_100ml_for_preparation returns value from highest priority set (manufacturer over packaging)"
	);
}

done_testing();
