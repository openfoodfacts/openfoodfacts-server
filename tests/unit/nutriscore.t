#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use JSON;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/compute_field_tags/;
use ProductOpener::Food qw/:all/;
use ProductOpener::FoodProducts qw/:all/;
use ProductOpener::ProducersFood qw/:all/;
use ProductOpener::Ingredients qw/extract_additives_from_text extract_ingredients_from_text/;
use ProductOpener::Nutriscore
	qw/compute_nutriscore_grade get_value_with_one_less_negative_point_2023 get_value_with_one_more_positive_point_2023/;
use ProductOpener::NutritionCiqual qw/load_ciqual_data/;
use ProductOpener::NutritionEstimation qw/:all/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

use Data::DeepAccess qw(deep_exists);

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Needed to compute estimated nutrients
load_ciqual_data();

check_nutriscore_categories_exist_in_taxonomy();

my @tests = (

	[
		"cookies",
		{
			lc => "en",
			categories => "cookies",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3460
							},
							fat => {
								unit => "g",
								value => 90
							},
							"saturated-fat" => {
								unit => "g",
								value => 15
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold",
					}
				]
			}
		}
	],
	[
		"olive-oil",
		{
			lc => "en",
			categories => "olive oils",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3460
							},
							fat => {
								unit => "g",
								value => 92
							},
							"saturated-fat" => {
								unit => "g",
								value => 14
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold",
					}
				]
			}
		}
	],
	[
		"colza-oil",
		{
			lc => "en",
			categories => "colza oils",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3760
							},
							fat => {
								unit => "g",
								value => 100
							},
							"saturated-fat" => {
								unit => "g",
								value => 7
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold",
					}
				]
			}
		}
	],
	[
		"walnut-oil",
		{
			lc => "en",
			categories => "walnut oils",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 100
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold",
					}
				]
			}
		}
	],
	[
		"sunflower-oil",
		{
			lc => "en",
			categories => "sunflower oils",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 100
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold",
					}
				]
			}
		}
	],

	# if no sugar but carbohydrates is 0, consider sugar 0
	[
		"sunflower-oil-no-sugar",
		{
			lc => "en",
			categories => "sunflower oils",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 100
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							carbohydrates => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold",
					}
				]
			}
		}
	],

	# if no sugar but carbohydrates is 0, consider sugar 0
	# still saturated fat missing will block
	[
		"sunflower-oil-no-sugar-no-sat-fat",
		{
			lc => "en",
			categories => "sunflower oils",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 100
							},
							carbohydrates => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold",
					}
				]
			}
		}
	],

	# saturated fat 1.03 should be rounded to 1.0 which is not strictly greater than 1.0
	[
		"breakfast-cereals",
		{
			lc => "en",
			categories => "breakfast cereals",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 2450
							},
							fat => {
								unit => "g",
								value => 100
							},
							"saturated-fat" => {
								unit => "g",
								value => 1.03
							},
							sugars => {
								unit => "g",
								value => 31
							},
							sodium => {
								unit => "g",
								value => 0.221
							},
							fiber => {
								unit => "g",
								value => 6.9
							},
							proteins => {
								unit => "g",
								value => 10.3
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				]
			}
		}
	],

	# dairy drink with milk >= 80% are considered food and not beverages

	[
		"dairy-drinks-without-milk",
		{
			lc => "en",
			categories => "dairy drinks",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 10
							},
							"saturated-fat" => {
								unit => "g",
								value => 5
							},
							sugars => {
								unit => "g",
								value => 10
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 2
							},
							proteins => {
								unit => "g",
								value => 5
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
			ingredients_text => "Water, sugar"
		}
	],
	[
		"milk",
		{
			lc => "en",
			categories => "milk",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 10
							},
							"saturated-fat" => {
								unit => "g",
								value => 5
							},
							sugars => {
								unit => "g",
								value => 10
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 2
							},
							proteins => {
								unit => "g",
								value => 5
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
			ingredients_text => "Milk"
		}
	],
	[
		"dairy-drink-with-80-percent-milk",
		{
			lc => "en",
			categories => "dairy drinks",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 10
							},
							"saturated-fat" => {
								unit => "g",
								value => 5
							},
							sugars => {
								unit => "g",
								value => 10
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 2
							},
							proteins => {
								unit => "g",
								value => 5
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
			ingredients_text => "Fresh milk 80%, sugar"
		}
	],
	[
		"beverage-with-80-percent-milk",
		{
			lc => "en",
			categories => "beverages",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 10
							},
							"saturated-fat" => {
								unit => "g",
								value => 5
							},
							sugars => {
								unit => "g",
								value => 20
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 2
							},
							proteins => {
								unit => "g",
								value => 5
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
			ingredients_text => "Fresh milk 80%, sugar"
		}
	],

	[
		"dairy-drink-with-less-than-80-percent-milk",
		{
			lc => "en",
			categories => "dairy drinks",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3378
							},
							fat => {
								unit => "g",
								value => 10
							},
							"saturated-fat" => {
								unit => "g",
								value => 5
							},
							sugars => {
								unit => "g",
								value => 20
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 2
							},
							proteins => {
								unit => "g",
								value => 5
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
			ingredients_text => "Milk, sugar"
		}
	],

	# mushrooms are counted as fruits/vegetables
	[
		"mushrooms",
		{
			lc => "fr",
			categories => "meals",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 667
							},
							fat => {
								unit => "g",
								value => 8.4
							},
							"saturated-fat" => {
								unit => "g",
								value => 1.2
							},
							sugars => {
								unit => "g",
								value => 1.1
							},
							sodium => {
								unit => "g",
								value => 0.4
							},
							fiber => {
								unit => "g",
								value => 10.9
							},
							proteins => {
								unit => "g",
								value => 2.4
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},

			ingredients_text => "Pleurotes* 69% (Origine UE), chapelure de mais"
		}
	],

	# fruit content indicated at the end of the ingredients list
	[
		"fr-gaspacho",
		{
			lc => "fr",
			categories => "gaspachos",
			ingredients_text =>
				"Tomate,concombre,poivron,oignon,eau,huile d'olive vierge extra (1,1%),vinaigre de vin,pain de riz,sel,ail,jus de citron,teneur en légumes: 89%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 148
							},
							fat => {
								unit => "g",
								value => 10
							},
							"saturated-fat" => {
								unit => "g",
								value => 0.2
							},
							sugars => {
								unit => "g",
								value => 3
							},
							sodium => {
								unit => "g",
								value => 0.2
							},
							fiber => {
								unit => "g",
								value => 1.1
							},
							proteins => {
								unit => "g",
								value => 0.9
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],

	# if fat is 0 and we have no saturated fat, we consider it 0
	[
		"fr-orange-nectar-0-fat",
		{
			lc => "en",
			categories => "fruit-nectar",
			ingredients_text => "Orange 47%, Water, Sugar, Carrots 10%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 250
							},
							fat => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 12
							},
							sodium => {
								unit => "g",
								value => 0.2
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0.5
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],

	# spring waters
	["spring-water-no-nutrition", {lc => "en", categories => "spring water"}],
	["flavored-spring-water-no-nutrition", {lc => "en", categories => "flavoured spring water"}],
	[
		"flavored-spring-with-nutrition",
		{
			lc => "en",
			categories => "flavoured spring water",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 378
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 3
							},
							sodium => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],

	# Cocoa and chocolate powders
	[
		"cocoa-and-chocolate-powders",
		{
			lc => "en",
			"categories" => "cocoa and chocolate powders",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 287
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 1.1
							},
							sugars => {
								unit => "g",
								value => 6.3
							},
							sodium => {
								unit => "g",
								value => 0.045
							},
							fiber => {
								unit => "g",
								value => 1.9
							},
							proteins => {
								unit => "g",
								value => 3.8
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "prepared"
					}
				],
			},
		}

	],

	# fruits and vegetables estimates from category or from ingredients
	[
		"en-orange-juice-category-and-ingredients",
		{
			lc => "en",
			categories => "orange juices",
			ingredients_text => "orange juice 50%, water, sugar",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 182
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 8.9
							},
							sodium => {
								unit => "g",
								value => 0.2
							},
							fiber => {
								unit => "g",
								value => 0.5
							},
							proteins => {
								unit => "g",
								value => 0.2
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	[
		"en-orange-juice-category",
		{
			lc => "en",
			categories => "orange juices",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 182
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 8.9
							},
							sodium => {
								unit => "g",
								value => 0.2
							},
							fiber => {
								unit => "g",
								value => 0.5
							},
							proteins => {
								unit => "g",
								value => 0.2
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# potatoes should not count as vegetables
	[
		"en-potatoes-category",
		{
			lc => "en",
			categories => "potatoes, vegetables",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 182
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 8.9
							},
							sodium => {
								unit => "g",
								value => 0.2
							},
							fiber => {
								unit => "g",
								value => 0.5
							},
							proteins => {
								unit => "g",
								value => 0.2
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],

	# categories without Nutri-Score

	[
		"en-beers-category",
		{
			lc => "en",
			categories => "beers",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 182
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 8.9
							},
							sodium => {
								unit => "g",
								value => 0.2
							},
							fiber => {
								unit => "g",
								value => 0.5
							},
							proteins => {
								unit => "g",
								value => 0.2
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],

	# Nutri-Score from estimated nutrients
	[
		"en-sugar-estimated-nutrients",
		{
			lc => "en",
			categories => "sugars",
			ingredients_text => "sugar",
		}
	],
	[
		"en-apple-estimated-nutrients",
		{
			lc => "en",
			categories => "apples",
			ingredients_text => "apples",
		}
	],
	[
		"94-percent-sugar-and-unknown-ingredient",
		{
			lc => "en",
			categories => "sugars",
			ingredients_text => "sugar 94%, strange ingredient",
		}
	],
	# Sweeteners
	[
		"en-sweeteners",
		{
			lc => "en",
			categories => "sodas",
			ingredients_text => "apple juice, water, sugar, aspartame",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 4.5
							},
							sodium => {
								unit => "g",
								value => 0.01
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# Erythritol is not counted as a non-nutritive sweetener
	[
		"en-sweeteners-erythritol",
		{
			lc => "en",
			categories => "sodas",
			ingredients_text => "apple juice, water, sugar, erythritol",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 4.5
							},
							sodium => {
								unit => "g",
								value => 0.01
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	[
		"fr-ice-tea-with-sweetener",
		{
			lc => "fr",
			categories => "ice teas",
			ingredients_text =>
				"Eau, sucre, fructose, acidifiants (acide citrique, acide malique), extrait de the noir (1,2g/l), jus de pêche à base de concentré (0,1%), correcteur d'acidité (citrate trisodique), arômes, antioxydant (acide ascorbique), édulcorant (glycosides de steviol)",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 4.5
							},
							sodium => {
								unit => "g",
								value => 0.01
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# vegetables flour / powder etc. do not count as vegetable for the Nutri-Score
	[
		"en-soy-beans-processed-and-unprocessed",
		{
			lc => "en",
			categories => "soup",
			ingredients_text =>
				"soy beans 30%, cooked soy beans 25%, soy beans powder 20%, cut freeze dried soy beans 15%, soy beans flour 10%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 1.5
							},
							sodium => {
								unit => "g",
								value => 0.01
							},
							proteins => {
								unit => "g",
								value => 20
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# vegetables that are deep fried do not count as vegetables for the Nutri-Score
	[
		"en-vegetable-crisps",
		{
			lc => "en",
			categories => "Parsnip Crisps",
			ingredients_text => "parsnip 70%, red beet 30%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 1.5
							},
							sodium => {
								unit => "g",
								value => 0.01
							},
							proteins => {
								unit => "g",
								value => 20
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# vegetables that are processed (e.g. flour) do not count as vegetables for the Nutri-Score
	# for some categories, we assume the vegetables are processed (e.g. soy beans in tofu)
	[
		"en-tofu",
		{
			lc => "en",
			categories => "tofu",
			ingredients_text => "soy beans 90%, water 9%, salt 1%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 1.5
							},
							sodium => {
								unit => "g",
								value => 0.01
							},
							proteins => {
								unit => "g",
								value => 20
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# For red meat products, the number of maximum protein points is set at 2 points
	[
		"en-red-meat-category-no-ingredients",
		{
			lc => "en",
			categories => "beef steaks",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 20
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 50
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	[
		"en-red-meat-ambiguous-category-no-ingredients",
		{
			lc => "en",
			categories => "sausages",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 20
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 50
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	[
		"en-red-meat-ambiguous-category-ingredients-with-lots-of-meat",
		{
			lc => "en",
			categories => "sausages",
			ingredients_text => "pork meat, lamb meat, chicken meat, salt 1%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 20
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 50
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	[
		"en-red-meat-ambiguous-category-ingredients-with-no-meat",
		{
			lc => "en",
			categories => "sausages",
			ingredients_text => "salmon, wheat flour, salt 1%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 20
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 50
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	[
		"en-red-meat-ambiguous-category-ingredients-with-very-little-meat",
		{
			lc => "en",
			categories => "sausages",
			ingredients_text => "eggs, wheat flour, water, rice flour, lamb 2%, salt 1%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 20
							},
							"saturated-fat" => {
								unit => "g",
								value => 10
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 50
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# Milk: considered a beverage in 2023 Nutri-Score
	[
		"en-milk",
		{
			lc => "en",
			categories => "milk",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 195
							},
							fat => {
								unit => "g",
								value => 1.6
							},
							"saturated-fat" => {
								unit => "g",
								value => 1
							},
							sugars => {
								unit => "g",
								value => 4.8
							},
							salt => {
								unit => "g",
								value => 0.1
							},
							proteins => {
								unit => "g",
								value => 3.3
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# Plant beverages: considered a beverage in 2023 Nutri-Score
	[
		"fr-plant-beverages-soy-milk",
		{
			lc => "fr",
			categories => "boissons végétales de soja",
			ingredients_text => "Eau, fèves de soja 8%",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 178
							},
							fat => {
								unit => "g",
								value => 2.6
							},
							"saturated-fat" => {
								unit => "g",
								value => 0.6
							},
							sugars => {
								unit => "g",
								value => 0.5
							},
							salt => {
								unit => "g",
								value => 0.03
							},
							fiber => {
								unit => "g",
								value => 0.5
							},
							proteins => {
								unit => "g",
								value => 3.9
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# Cherry tomatoes
	[
		"en-cherry-tomatoes",
		{
			lc => "en",
			categories => "cherry tomatoes",
			ingredients_text => "cherry tomatoes",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 81
							},
							fat => {
								unit => "g",
								value => 0.26
							},
							"saturated-fat" => {
								unit => "g",
								value => 0.056
							},
							sugars => {
								unit => "g",
								value => 2.48
							},
							fiber => {
								unit => "g",
								value => 1.2
							},
							salt => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0.86
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# olive oil
	[
		"en-olive-oil",
		{
			lc => "en",
			categories => "olive oil",
			ingredients_text => "olive oil",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3367
							},
							fat => {
								unit => "g",
								value => 91
							},
							"saturated-fat" => {
								unit => "g",
								value => 17
							},
							sugars => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							salt => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# olive oil, no ingredients specified
	[
		"en-olive-oil-no-ingredients",
		{
			lc => "en",
			categories => "olive oil",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3367
							},
							fat => {
								unit => "g",
								value => 91
							},
							"saturated-fat" => {
								unit => "g",
								value => 17
							},
							sugars => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							salt => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# olive oil, unrecognized ingredients specified
	[
		"en-olive-oil-unrecognized-ingredients",
		{
			lc => "en",
			categories => "olive oil",
			ingredients_text => "some very fancy but unrecognized way of writing olive oil",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3367
							},
							fat => {
								unit => "g",
								value => 91
							},
							"saturated-fat" => {
								unit => "g",
								value => 17
							},
							sugars => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							salt => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# avocado oil
	[
		"en-avocado-oil",
		{
			lc => "en",
			categories => "avocado oil",
			ingredients_text => "avocado",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3448
							},
							fat => {
								unit => "g",
								value => 91.6
							},
							"saturated-fat" => {
								unit => "g",
								value => 16.4
							},
							sugars => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							salt => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# mixed oil (isio 4 olive)
	[
		"fr-mixed-oils-with-olive-oil",
		{
			lc => "fr",
			categories => "huile végétale",
			ingredients_text =>
				"Huile de colza 45%, huile de tournesol 30%, huile d'olive vierge extra 20%, huile de lin 5%, vitamine D",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3700
							},
							fat => {
								unit => "g",
								value => 100
							},
							"saturated-fat" => {
								unit => "g",
								value => 9.8
							},
							sugars => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							salt => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# rapeseed oil
	[
		"fr-rapeseed-oil",
		{
			lc => "fr",
			categories => "huile de colza",
			ingredients_text => "Huile de colza",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 3400
							},
							fat => {
								unit => "g",
								value => 92
							},
							"saturated-fat" => {
								unit => "g",
								value => 7.3
							},
							sugars => {
								unit => "g",
								value => 0
							},
							fiber => {
								unit => "g",
								value => 0
							},
							salt => {
								unit => "g",
								value => 0
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# Coconut milk -> for cooking, not considered a beverage in 2023 Nutri-Score
	[
		"fr-coconut-milk",
		{
			lc => "fr",
			categories => "lait de coco",
			ingredients_text => "Noix de coco 60%, eau",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 178
							},
							fat => {
								unit => "g",
								value => 2.6
							},
							"saturated-fat" => {
								unit => "g",
								value => 0.6
							},
							sugars => {
								unit => "g",
								value => 0.5
							},
							salt => {
								unit => "g",
								value => 0.03
							},
							fiber => {
								unit => "g",
								value => 0.5
							},
							proteins => {
								unit => "g",
								value => 3.9
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# For products that contain water that is not consumed (e.g. canned vegetables)
	# the % of fruits/vegetables must be estimated on the product without water
	[
		"fr-green-beans-beverage",
		{
			lc => "fr",
			ingredients_text => "eau 80%, sucre 10%, haricots verts 10%",
			categories => "plat préparé",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 315
							},
							fat => {
								unit => "g",
								value => 0.9
							},
							"saturated-fat" => {
								unit => "g",
								value => 0.1
							},
							sugars => {
								unit => "g",
								value => 3.6
							},
							salt => {
								unit => "g",
								value => 0.80
							},
							fiber => {
								unit => "g",
								value => 5.3
							},
							proteins => {
								unit => "g",
								value => 5.0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	[
		"fr-canned-green-beans",
		{
			lc => "fr",
			ingredients_text => "eau 80%, sucre 10%, haricots verts 10%",
			categories => "haricots verts en conserve",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 315
							},
							fat => {
								unit => "g",
								value => 0.9
							},
							"saturated-fat" => {
								unit => "g",
								value => 0.1
							},
							sugars => {
								unit => "g",
								value => 3.6
							},
							salt => {
								unit => "g",
								value => 1.2
							},
							fiber => {
								unit => "g",
								value => 5.3
							},
							proteins => {
								unit => "g",
								value => 5.0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# canned fruits: water is counted as it is consumed
	[
		"fr-canned-pineapple",
		{
			lc => "fr",
			ingredients_text => "eau 80%, sucre 10%, ananas 10%",
			categories => "ananas en conserve",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 315
							},
							fat => {
								unit => "g",
								value => 0.9
							},
							"saturated-fat" => {
								unit => "g",
								value => 0.1
							},
							sugars => {
								unit => "g",
								value => 3.6
							},
							salt => {
								unit => "g",
								value => 1.2
							},
							fiber => {
								unit => "g",
								value => 5.3
							},
							proteins => {
								unit => "g",
								value => 5.0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				],
			},
		}

	],
	# Flavored syrup: beverage preparations should use the beverage formula
	[
		"en-beverage-preparation-flavored-syrup",
		{
			lc => "en",
			categories => "flavored syrup",
			ingredients_text => "apple juice, water, sugar, aspartame",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 82
							},
							fat => {
								unit => "g",
								value => 0
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 4.5
							},
							sodium => {
								unit => "g",
								value => 0.01
							},
							proteins => {
								unit => "g",
								value => 0
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "prepared"
					}
				],
			},
		}

	],

	# orange
	[
		"en-orange",
		{
			lc => "en",
			categories => "oranges",
			ingredients_text => "orange",
		}
	],

	# pickled vegetable with water and dill: water should not be counted in fruits/vegetables
	# dill should be counted
	[
		"pl-pickled-vegetables",
		{
			lc => "pl",
			categories => "pickled vegetables",
			ingredients_text => "52% rzodkiew biała, woda, koper, 0,6% czosnek, sól, chrzan",
			nutrition => {
				input_sets => [
					{
						nutrients => {
							"energy-kj" => {
								unit => "kJ",
								value => 53
							},
							fat => {
								unit => "g",
								value => 0.1
							},
							"saturated-fat" => {
								unit => "g",
								value => 0
							},
							sugars => {
								unit => "g",
								value => 0
							},
							sodium => {
								unit => "g",
								value => 2
							},
							proteins => {
								unit => "g",
								value => 0.7
							}
						},
						source => "packaging",
						per => "100g",
						preparation => "as_sold"
					}
				]
			},
		}
	],

	# dill
	[
		"en-dill",
		{
			lc => "en",
			categories => "dill",
			ingredients_text => "dill",
		}
	],

	# Ground coffee
	# should not have a Nutri-Score from estimated nutrients from ingredients
	[
		"en-ground-coffee",
		{
			lc => "en",
			categories => "ground coffee",
			ingredients_text => "ground coffee",
		}
	],
);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	compute_field_tags($product_ref, $product_ref->{lc}, "categories");

	specific_processes_for_food_product($product_ref);

	# Detect possible improvements
	detect_possible_improvements_nutriscore($product_ref, 2023);

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});
}

is(compute_nutriscore_grade(1.56, 1, 0), "c");

# Tests for detecting possible improvements

# 2023 thresholds:

#my %points_thresholds_2023 = (
#
#	# negative points
#
#	energy => [335, 670, 1005, 1340, 1675, 2010, 2345, 2680, 3015, 3350],    # kJ / 100g
#	energy_beverages => [30, 90, 150, 210, 240, 270, 300, 330, 360, 390],    # kJ /100g or 100ml
#	sugars => [3.4, 6.8, 10, 14, 17, 20, 24, 27, 31, 34, 37, 41, 44, 48, 51],    # g / 100g
#	sugars_beverages => [0.5, 2, 3.5, 5, 6, 7, 8, 9, 10, 11],    # g / 100g or 100ml
#	saturated_fat => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],    # g / 100g
#	salt => [0.2, 0.4, 0.6, 0.8, 1, 1.2, 1.4, 1.6, 1.8, 2, 2.2, 2.4, 2.6, 2.8, 3, 3.2, 3.4, 3.6, 3.8, 4],    # g / 100g
#
#	# for fats
#	energy_from_saturated_fat => [120, 240, 360, 480, 600, 720, 840, 960, 1080, 1200],    # g / 100g
#	saturated_fat_ratio => [10, 16, 22, 28, 34, 40, 46, 52, 58, 64],    # %
#
#	# positive points
#	fruits_vegetables_legumes => [40, 60, 80, 80, 80],    # %
#	fruits_vegetables_legumes_beverages => [40, 40, 60, 60, 80, 80],
#	fiber => [3.0, 4.1, 5.2, 6.3, 7.4],    # g / 100g - AOAC method
#	proteins => [2.4, 4.8, 7.2, 9.6, 12, 14, 17],    # g / 100g
#	proteins_beverages => [1.2, 1.5, 1.8, 2.1, 2.4, 2.7, 3.0],    # g / 100g
#);

is(get_value_with_one_less_negative_point_2023(0, "sugars", 0), undef);
is(get_value_with_one_less_negative_point_2023(0, "sugars", 3), undef);
is(get_value_with_one_less_negative_point_2023(0, "sugars", 4), 3.4);
is(get_value_with_one_less_negative_point_2023(0, "sugars", 7), 6.8);
is(get_value_with_one_less_negative_point_2023(0, "sugars", 10), 6.8);
is(get_value_with_one_less_negative_point_2023(0, "sugars", 60), 51);
is(get_value_with_one_less_negative_point_2023(1, "sugars", 3), 2);
is(get_value_with_one_less_negative_point_2023(1, "saturated_fat", 7), 6);

is(get_value_with_one_more_positive_point_2023(0, "proteins", 0), 2.5);
is(get_value_with_one_more_positive_point_2023(0, "proteins", 5), 7.3);
is(get_value_with_one_more_positive_point_2023(1, "proteins", 2), 2.2);
is(get_value_with_one_more_positive_point_2023(0, "proteins", 20), undef);

is(get_value_with_one_more_positive_point_2023(0, "fruits_vegetables_legumes", 45), 61);

done_testing();
