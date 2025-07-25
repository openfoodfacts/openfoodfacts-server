#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Nutrition qw/generate_nutrient_set_preferred_from_sets/;

my @tests = (
	[[], {}, "Generated set should be empty given empty list"],
	[[{}], {}, "Generated set should be empty given list with empty sets"],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2.0",
					value => 2,
					unit => "g",
					modifier => "<=",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should be the same as the only set given list with one set",
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2.0",
					value => 2,
					unit => "g",
					modifier => "<=",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should be the same as the only non empty set given list with only one non empty set"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2.0",
					value => 2,
					unit => "g",
					modifier => "<=",
					source => "packaging",
					source_per => "100g",
				},
				sugars => {
					value_string => "5.2",
					value => 5.2,
					unit => "g",
					source => "usda",
					source_per => "100g",
				}
			}
		},
		"Generated set should have all given nutrients given sets with different nutrients provided"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2.0",
					value => 2,
					unit => "g",
					modifier => "<=",
					source => "packaging",
					source_per => "100g",
				},
				sugars => {
					value_string => "5.2",
					value => 5.2,
					unit => "g",
					source => "usda",
					source_per => "100g",
				}
			}
		},
		"Generated set should have nutrients from most important source given sets with same nutrients with different sources"
	],
	[
		[
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
		],
		{
			preparation => "prepared",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "0.1",
					value => 0.1,
					unit => "g",
					source => "packaging",
					source_per => "100g",
				},
				sugars => {
					value_string => "5.2",
					value => 5.2,
					unit => "g",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should have nutrients from most important preparation given sets with same nutrients with different preparations"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2.0",
					value => 2,
					unit => "g",
					modifier => "<=",
					source => "packaging",
					source_per => "100g",
				},
				sugars => {
					value_string => "5.2",
					value => 5.2,
					unit => "g",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should have nutrients from most important per given sets with same nutrients with different per"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2",
					value => 2,
					unit => "g",
					modifier => "<=",
					source => "manufacturer",
					source_per => "100g",
				},
				sugars => {
					value_string => "7.6",
					value => 7.6,
					unit => "g",
					source => "manufacturer",
					source_per => "serving"
				},
				protein => {
					value_string => "0",
					value => 0,
					unit => "g",
					source => "packaging",
					source_per => "100g"
				}
			}
		},
		"Generated set should have nutrients from most important source then per given sets with same nutrients with different sources and per"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2.0",
					value => 2,
					unit => "g",
					modifier => "<=",
					source => "manufacturer",
					source_per => "100g",
				}
			}
		},
		"Generated set should have nutrients from most important source then preparation given sets with same nutrients with different sources and preparations"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sugars => {
					value_string => "5.2",
					value => 5.2,
					unit => "g",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should have nutrients from most important per then preparation given sets with same nutrients with different per and preparations"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "0.2",
					value => 0.2,
					unit => "g",
					source => "packaging",
					source_per => "100g",
					modifier => "<=",
				}
			}
		},
		"Generated set should have normalized weight units for nutrients"
	],
	[
		[
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
						unit => "kj",
					}
				}
			}
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				"energy-kcal" => {
					value_string => "30",
					value => 30,
					unit => "kcal",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should have normalized unit for energy-kcal nutrient"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				energy => {
					value_string => "125",
					value => 125,
					unit => "kj",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should have normalized unit for energy nutrient"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				"energy-kj" => {
					value_string => "125",
					value => 125,
					unit => "kj",
					source => "packaging",
					source_per => "100g",
				}
			}
		},
		"Generated set should have normalized unit for energy-kj nutrient"
	],
	[
		[
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
				source => "packaging",
				nutrients => {
					"sugars" => {
						value_string => "6.3",
						value => 6.3,
						unit => "g",
					}
				}
			}
		],
		{
			preparation => "as_sold",
			per => "100g",
			per_quantity => "100",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "2.5",
					value => 2.5,
					unit => "g",
					source => "packaging",
					source_per => "100g",
				},
				sugars => {
					value_string => "12.6",
					value => 12.6,
					unit => "g",
					source => "packaging",
					source_per => "serving",
				}
			}
		},
		"Generated set should have converted per when different per in nutrients given nutrient with most priority with per in 100g/ml"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "serving",
			per_quantity => "50",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "1.25",
					value => 1.25,
					unit => "g",
					source => "packaging",
					source_per => "100g",
				},
				sugars => {
					value_string => "6.3",
					value => 6.3,
					unit => "g",
					source => "manufacturer",
					source_per => "serving",
				}
			}
		},
		"Generated set should have converted per when different per in nutrients given nutrient with most priority with per in serving"
	],
	[
		[
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
		],
		{
			preparation => "as_sold",
			per => "serving",
			per_quantity => "50",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "1.25",
					value => 1.25,
					unit => "g",
					source => "packaging",
					source_per => "serving",
				},
				sugars => {
					value_string => "6.3",
					value => 6.3,
					unit => "g",
					source => "manufacturer",
					source_per => "serving",
				}
			}
		},
		"Generated set should have converted per when different per in nutrients given nutrients per in different servings"
	],
	[
		[
			{
				preparation => "as_sold",
				per => "serving",
				per_quantity => "100",
				per_unit => "mg",
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
		],
		{
			preparation => "as_sold",
			per => "serving",
			per_quantity => "50",
			per_unit => "g",
			nutrients => {
				sodium => {
					value_string => "1250",
					value => 1250,
					unit => "g",
					source => "packaging",
					source_per => "serving",
				},
				sugars => {
					value_string => "6.3",
					value => 6.3,
					unit => "g",
					source => "manufacturer",
					source_per => "serving",
				}
			}
		},
		"Generated set should have converted per when different per in nutrients given nutrients per in different servings with wanted in g"
	],
	[
		[
			{
				preparation => "as_sold",
				per => "serving",
				per_quantity => "100",
				per_unit => "mg",
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
		],
		{
			preparation => "as_sold",
			per => "serving",
			per_quantity => "5",
			per_unit => "kg",
			nutrients => {
				sodium => {
					value_string => "12500",
					value => 12500,
					unit => "g",
					source => "packaging",
					source_per => "serving",
				},
				sugars => {
					value_string => "6.3",
					value => 6.3,
					unit => "g",
					source => "manufacturer",
					source_per => "serving",
				}
			}
		},
		"Generated set should have converted per when different per in nutrients given nutrients per in different servings with wanted in not in g"
	],
	[
		[
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
						value_string => "6.3",
						value => 6.3,
						unit => "g",
					}
				}
			}
		],
		{
			preparation => "as_sold",
			per => "serving",
			per_quantity => "50",
			per_unit => "ml",
			nutrients => {
				sodium => {
					value_string => "0.0125",
					value => 0.0125,
					unit => "g",
					source => "packaging",
					source_per => "serving",
				},
				sugars => {
					value_string => "6.3",
					value => 6.3,
					unit => "g",
					source => "manufacturer",
					source_per => "serving",
				}
			}
		},
		"Generated set should have converted per when different per in nutrients given nutrients per in different servings with volume units"
	],
);

foreach my $test_ref (@tests) {

	my $nutrient_sets_ref = $test_ref->[0];
	my $nutrient_set_preferred = $test_ref->[1];
	my $test_name = $test_ref->[2];

	is(generate_nutrient_set_preferred_from_sets($nutrient_sets_ref), $nutrient_set_preferred, $test_name);
}

done_testing();
