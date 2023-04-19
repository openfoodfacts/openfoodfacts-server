#!/usr/bin/perl -w

# Tests of Ingredients::compute_ingredients_percent_values()

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';
use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my @tests = (

	[
		{lc => "en", ingredients_text => "sugar"},
		[
			{
				'id' => 'en:sugar',
				'percent_estimate' => 100,
				'percent_max' => 100,
				'percent_min' => 100,
				'text' => 'sugar'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "sugar, milk"},
		[
			{
				'id' => 'en:sugar',
				'percent_estimate' => 75,
				'percent_max' => 100,
				'percent_min' => 50,
				'text' => 'sugar'
			},
			{
				'id' => 'en:milk',
				'percent_estimate' => 25,
				'percent_max' => 50,
				'percent_min' => 0,
				'text' => 'milk'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "sugar, milk, water"},
		[
			{
				'id' => 'en:sugar',
				'percent_estimate' => '66.6666666666667',
				'percent_max' => 100,
				'percent_min' => '33.3333333333333',
				'text' => 'sugar'
			},
			{
				'id' => 'en:milk',
				'percent_estimate' => '16.6666666666667',
				'percent_max' => 50,
				'percent_min' => 0,
				'text' => 'milk'
			},
			{
				'id' => 'en:water',
				'percent_estimate' => '16.6666666666667',
				'percent_max' => '33.3333333333333',
				'percent_min' => 0,
				'text' => 'water'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "sugar 90%, milk"},
		[
			{
				'id' => 'en:sugar',
				'percent_estimate' => 90,
				'percent' => '90',
				'percent_max' => 90,
				'percent_min' => 90,
				'text' => 'sugar'
			},
			{
				'id' => 'en:milk',
				'percent_estimate' => 10,
				'percent_max' => 10,
				'percent_min' => 10,
				'text' => 'milk'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "sugar, milk 10%"},
		[
			{
				'id' => 'en:sugar',
				'percent_estimate' => 90,
				'percent_max' => 90,
				'percent_min' => 90,
				'text' => 'sugar'
			},
			{
				'id' => 'en:milk',
				'percent' => '10',
				'percent_estimate' => 10,
				'percent_max' => 10,
				'percent_min' => 10,
				'text' => 'milk'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "sugar, milk 10%, water"},
		[
			{
				'id' => 'en:sugar',
				'percent_estimate' => 85,
				'percent_max' => 90,
				'percent_min' => 80,
				'text' => 'sugar'
			},
			{
				'id' => 'en:milk',
				'percent' => '10',
				'percent_estimate' => 10,
				'percent_max' => 10,
				'percent_min' => 10,
				'text' => 'milk'
			},
			{
				'id' => 'en:water',
				'percent_estimate' => 5,
				'percent_max' => 10,
				'percent_min' => 0,
				'text' => 'water'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "sugar, water, milk 10%"},
		[
			{
				'id' => 'en:sugar',
				'percent_estimate' => '62.5',
				'percent_max' => 80,
				'percent_min' => 45,
				'text' => 'sugar'
			},
			{
				'id' => 'en:water',
				'percent_estimate' => '23.75',
				'percent_max' => 45,
				'percent_min' => 10,
				'text' => 'water'
			},
			{
				'id' => 'en:milk',
				'percent' => '10',
				'percent_estimate' => '13.75',
				'percent_max' => 10,
				'percent_min' => 10,
				'text' => 'milk'
			}
		]
	],

	# Ingredients with sub-ingredients

	[
		{lc => "en", ingredients_text => "chocolate (cocoa)"},
		[
			{
				'id' => 'en:chocolate',
				'ingredients' => [
					{
						'id' => 'en:cocoa',
						'percent_estimate' => 100,
						'percent_max' => 100,
						'percent_min' => 100,
						'text' => 'cocoa'
					}
				],
				'percent_estimate' => 100,
				'percent_max' => 100,
				'percent_min' => 100,
				'text' => 'chocolate'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "chocolate (cocoa, sugar), milk"},
		[
			{
				'id' => 'en:chocolate',
				'ingredients' => [
					{
						'id' => 'en:cocoa',
						'percent_estimate' => 50,
						'percent_max' => 100,
						'percent_min' => 25,
						'text' => 'cocoa'
					},
					{
						'id' => 'en:sugar',
						'percent_estimate' => 25,
						'percent_max' => 50,
						'percent_min' => 0,
						'text' => 'sugar'
					}
				],
				'percent_estimate' => 75,
				'percent_max' => 100,
				'percent_min' => 50,
				'text' => 'chocolate'
			},
			{
				'id' => 'en:milk',
				'percent_estimate' => 25,
				'percent_max' => 50,
				'percent_min' => 0,
				'text' => 'milk'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "chocolate (cocoa [cocoa paste 70%, cocoa butter], sugar)"},
		[
			{
				'id' => 'en:chocolate',
				'ingredients' => [
					{
						'id' => 'en:cocoa',
						'ingredients' => [
							{
								'id' => 'en:cocoa-paste',
								'percent' => '70',
								'percent_estimate' => 70,
								'percent_max' => 70,
								'percent_min' => 70,
								'text' => 'cocoa paste'
							},
							{
								'id' => 'en:cocoa-butter',
								'percent_estimate' => 15,
								'percent_max' => 30,
								'percent_min' => 0,
								'text' => 'cocoa butter'
							}
						],
						'percent_estimate' => 85,
						'percent_max' => 100,
						'percent_min' => 70,
						'text' => 'cocoa'
					},
					{
						'id' => 'en:sugar',
						'percent_estimate' => 15,
						'percent_max' => 30,
						'percent_min' => 0,
						'text' => 'sugar'
					}
				],
				'percent_estimate' => 100,
				'percent_max' => 100,
				'percent_min' => 100,
				'text' => 'chocolate'
			}
		]
	],

	# Make sure we can handle impossible values gracefully

	# This ingredient string caused an infinite loop:
	#  "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"

	[
		{lc => "fr", ingredients_text => "beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%"},
		[
			{
				'id' => 'en:cocoa-butter',
				'percent' => '15',
				'percent_estimate' => 15,
				'text' => 'beurre de cacao'
			},
			{
				'id' => 'en:sugar',
				'percent' => '10',
				'percent_estimate' => 10,
				'text' => 'sucre'
			},
			{
				'id' => 'en:milk-proteins',
				'percent_estimate' => '37.5',
				'text' => "prot\x{e9}ines de lait"
			},
			{
				'id' => 'en:egg',
				'percent' => '1',
				'percent_estimate' => '37.5',
				'text' => 'oeuf'
			}
		]
	],

	[
		{
			lc => "fr",
			ingredients_text =>
				"farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%)"
		},
		[
			{
				'id' => 'en:flour',
				'percent' => '12',
				'percent_estimate' => 12,
				'text' => 'farine'
			},
			{
				'id' => 'en:chocolate',
				'ingredients' => [
					{
						'id' => 'en:cocoa-butter',
						'percent' => '15',
						'percent_estimate' => 15,
						'text' => 'beurre de cacao'
					},
					{
						'id' => 'en:sugar',
						'percent' => '10',
						'percent_estimate' => 10,
						'text' => 'sucre'
					},
					{
						'id' => 'en:milk-proteins',
						'percent_estimate' => '31.5',
						'text' => "prot\x{e9}ines de lait"
					},
					{
						'id' => 'en:egg',
						'percent' => '1',
						'percent_estimate' => '31.5',
						'text' => 'oeuf'
					}
				],
				'percent_estimate' => 88,
				'text' => 'chocolat'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "Flour, chocolate (cocoa, sugar, soy lecithin), egg"},
		[
			{
				'id' => 'en:flour',
				'percent_estimate' => '66.6666666666667',
				'percent_max' => 100,
				'percent_min' => '33.3333333333333',
				'text' => 'Flour'
			},
			{
				'id' => 'en:chocolate',
				'ingredients' => [
					{
						'id' => 'en:cocoa',
						'percent_estimate' => '8.33333333333333',
						'percent_max' => 50,
						'percent_min' => 0,
						'text' => 'cocoa'
					},
					{
						'id' => 'en:sugar',
						'percent_estimate' => '4.16666666666667',
						'percent_max' => 25,
						'percent_min' => 0,
						'text' => 'sugar'
					},
					{
						'id' => 'en:soya-lecithin',
						'percent_estimate' => '4.16666666666667',
						'percent_max' => '16.6666666666667',
						'percent_min' => 0,
						'text' => 'soy lecithin'
					}
				],
				'percent_estimate' => '16.6666666666667',
				'percent_max' => 50,
				'percent_min' => 0,
				'text' => 'chocolate'
			},
			{
				'id' => 'en:egg',
				'percent_estimate' => '16.6666666666667',
				'percent_max' => '33.3333333333333',
				'percent_min' => 0,
				'text' => 'egg'
			}
		]
	],

	# For lists like  "Beans (52%), Tomatoes (33%), Water, Sugar, Cornflour, Salt, Spirit Vinegar"
	# we can set a maximum on Sugar, Cornflour etc. that takes into account that all ingredients
	# that appear before will have an higher quantity.
	# e.g. the percent max of Water to be set to 100 - 52 -33 = 15%
	# the max of sugar to be set to 15 / 2 = 7.5 %
	# the max of cornflour to be set to 15 / 3 etc.

	[
		{lc => "en", ingredients_text => "Beans (52%), Tomatoes (33%), Water, Sugar, Cornflour, Salt, Spirit Vinegar"},
		[
			{
				'id' => 'en:beans',
				'percent' => '52',
				'percent_estimate' => 52,
				'percent_max' => 52,
				'percent_min' => 52,
				'text' => 'Beans'
			},
			{
				'id' => 'en:tomato',
				'percent' => '33',
				'percent_estimate' => 33,
				'percent_max' => 33,
				'percent_min' => 33,
				'text' => 'Tomatoes'
			},
			{
				'id' => 'en:water',
				'percent_estimate' => 9,
				'percent_max' => 15,
				'percent_min' => 3,
				'text' => 'Water'
			},
			{
				'id' => 'en:sugar',
				'percent_estimate' => 3,
				'percent_max' => '7.5',
				'percent_min' => 0,
				'text' => 'Sugar'
			},
			{
				'id' => 'en:corn-flour',
				'percent_estimate' => '1.5',
				'percent_max' => 5,
				'percent_min' => 0,
				'text' => 'Cornflour'
			},
			{
				'id' => 'en:salt',
				'percent_estimate' => '0.75',
				'percent_max' => '3.75',
				'percent_min' => 0,
				'text' => 'Salt'
			},
			{
				'id' => 'en:spirit-vinegar',
				'percent_estimate' => '0.75',
				'percent_max' => 3,
				'percent_min' => 0,
				'text' => 'Spirit Vinegar'
			}
		]
	],

	[
		{lc => "es", ingredients_text => "Leche. Cacao: 27% mínimo"},
		[
			{
				'id' => 'en:milk',
				'percent_estimate' => 73,
				'percent_max' => 73,
				'percent_min' => 73,
				'text' => 'Leche'
			},
			{
				'id' => 'en:cocoa',
				'percent' => '27',
				'percent_estimate' => 27,
				'percent_max' => 27,
				'percent_min' => 27,
				'text' => 'Cacao'
			}
		]
	],

	[
		{lc => "es", ingredients_text => "Leche min 12.2%, Cacao: min 7%, Avellanas (mínimo 3%)"},
		[
			{
				'id' => 'en:milk',
				'percent' => '12.2',
				'percent_estimate' => '12.2',
				'text' => 'Leche'
			},
			{
				'id' => 'en:cocoa',
				'percent' => '7',
				'percent_estimate' => '7',
				'text' => 'Cacao'
			},
			{
				'id' => 'en:hazelnut',
				'percent' => '3',
				'percent_estimate' => '80.8',
				'text' => 'Avellanas'
			}
		]
	],

	# bug #3762 "min" in "cumin"
	[
		{lc => "fr", ingredients_text => "sel (min 20%), poivre (min. 10%), piment (min : 5%), cumin 0,4%, ail : 0.1%"},
		[
			{
				'id' => 'en:salt',
				'percent' => '20',
				'percent_estimate' => 20,
				'text' => 'sel'
			},
			{
				'id' => 'en:pepper',
				'percent' => '10',
				'percent_estimate' => 10,
				'text' => 'poivre'
			},
			{
				'id' => 'en:chili-pepper',
				'percent' => '5',
				'percent_estimate' => 5,
				'text' => 'piment'
			},
			{
				'id' => 'en:cumin',
				'percent' => '0.4',
				'percent_estimate' => '0.4',
				'text' => 'cumin'
			},
			{
				'id' => 'en:garlic',
				'percent' => '0.1',
				'percent_estimate' => '64.6',
				'text' => 'ail'
			}
		]
	],

	# Relative percent

	[
		{lc => "en", ingredients_text => "fruits 50% (apple 40%, pear 30%, cranberry, lemon), sugar"},
		[
			{
				'id' => 'en:fruit',
				'ingredients' => [
					{
						'id' => 'en:apple',
						'percent' => 20,
						'percent_estimate' => 20,
						'percent_max' => 20,
						'percent_min' => 20,
						'text' => 'apple'
					},
					{
						'id' => 'en:pear',
						'percent' => 15,
						'percent_estimate' => 15,
						'percent_max' => 15,
						'percent_min' => 15,
						'text' => 'pear'
					},
					{
						'id' => 'en:cranberry',
						'percent_estimate' => '11.25',
						'percent_max' => 15,
						'percent_min' => '7.5',
						'text' => 'cranberry'
					},
					{
						'id' => 'en:lemon',
						'percent_estimate' => '3.75',
						'percent_max' => '7.5',
						'percent_min' => 0,
						'text' => 'lemon'
					}
				],
				'percent' => 50,
				'percent_estimate' => 50,
				'percent_max' => 50,
				'percent_min' => 50,
				'text' => 'fruits'
			},
			{
				'id' => 'en:sugar',
				'percent_estimate' => 50,
				'percent_max' => 50,
				'percent_min' => 50,
				'text' => 'sugar'
			}
		]
	],

	# Absolute percent

	[
		{lc => "en", ingredients_text => "fruits 50% (apple 20%, pear 15%, cranberry, lemon), sugar"},
		[
			{
				'id' => 'en:fruit',
				'ingredients' => [
					{
						'id' => 'en:apple',
						'percent' => 20,
						'percent_estimate' => 20,
						'percent_max' => 20,
						'percent_min' => 20,
						'text' => 'apple'
					},
					{
						'id' => 'en:pear',
						'percent' => 15,
						'percent_estimate' => 15,
						'percent_max' => 15,
						'percent_min' => 15,
						'text' => 'pear'
					},
					{
						'id' => 'en:cranberry',
						'percent_estimate' => '11.25',
						'percent_max' => 15,
						'percent_min' => '7.5',
						'text' => 'cranberry'
					},
					{
						'id' => 'en:lemon',
						'percent_estimate' => '3.75',
						'percent_max' => '7.5',
						'percent_min' => 0,
						'text' => 'lemon'
					}
				],
				'percent' => 50,
				'percent_estimate' => 50,
				'percent_max' => 50,
				'percent_min' => 50,
				'text' => 'fruits'
			},
			{
				'id' => 'en:sugar',
				'percent_estimate' => 50,
				'percent_max' => 50,
				'percent_min' => 50,
				'text' => 'sugar'
			}
		]
	],

	# Relative percent with no indicated percent on the parent ingredient, but with a percent min = percent max on the parent ingredient
	[
		{lc => "en", ingredients_text => "water (60%), fruit concentrate (apple 40%, mango 30%, citrus)"},
		[
			{
				'id' => 'en:water',
				'percent' => 60,
				'percent_estimate' => 60,
				'percent_max' => 60,
				'percent_min' => 60,
				'text' => 'water'
			},
			{
				'id' => 'en:fruit-concentrate',
				'ingredients' => [
					{
						'id' => 'en:apple',
						'percent' => 16,
						'percent_estimate' => 16,
						'percent_max' => 16,
						'percent_min' => 16,
						'text' => 'apple'
					},
					{
						'id' => 'en:mango',
						'percent' => 12,
						'percent_estimate' => 12,
						'percent_max' => 12,
						'percent_min' => 12,
						'text' => 'mango'
					},
					{
						'id' => 'en:citrus-fruit',
						'percent_estimate' => 12,
						'percent_max' => 12,
						'percent_min' => 12,
						'text' => 'citrus'
					}
				],
				'percent_estimate' => 40,
				'percent_max' => 40,
				'percent_min' => 40,
				'text' => 'fruit concentrate'
			}
		]
	],

	# Relative percent with a different percent min and percent max on the parent ingredient
	[
		{lc => "en", ingredients_text => "water (60%), fruit concentrate (apple 40%, mango 30%, citrus), sugar"},
		[
			{
				'id' => 'en:water',
				'percent' => 60,
				'percent_estimate' => 60,
				'percent_max' => 60,
				'percent_min' => 60,
				'text' => 'water'
			},
			{
				'id' => 'en:fruit-concentrate',
				'ingredients' => [
					{
						'id' => 'en:apple',
						'percent_estimate' => 12,
						'percent_max' => 16,
						'percent_min' => 8,
						'text' => 'apple'
					},
					{
						'id' => 'en:mango',
						'percent_estimate' => 9,
						'percent_max' => 12,
						'percent_min' => 6,
						'text' => 'mango'
					},
					{
						'id' => 'en:citrus-fruit',
						'percent_estimate' => 9,
						'percent_max' => 12,
						'percent_min' => 0,
						'text' => 'citrus'
					}
				],
				'percent_estimate' => 30,
				'percent_max' => 40,
				'percent_min' => 20,
				'text' => 'fruit concentrate'
			},
			{
				'id' => 'en:sugar',
				'percent_estimate' => 10,
				'percent_max' => 20,
				'percent_min' => 0,
				'text' => 'sugar'
			}
		]

	],

	# Missing % that is not the first or the last
	[
		{lc => "fr", ingredients_text => "Jus de pomme (57,3%), jus de carotte, jus de gingembre (2,5%)."},
		[
			{
				'id' => 'en:apple-juice',
				'percent' => '57.3',
				'percent_estimate' => '57.3',
				'percent_max' => '57.3',
				'percent_min' => '57.3',
				'text' => 'Jus de pomme'
			},
			{
				'id' => 'en:carrot-juice',
				'percent_estimate' => '40.2',
				'percent_max' => '40.2',
				'percent_min' => '40.2',
				'text' => 'jus de carotte'
			},
			{
				'id' => 'en:ginger',
				'percent' => '2.5',
				'percent_estimate' => '2.5',
				'percent_max' => '2.5',
				'percent_min' => '2.5',
				'processing' => 'en:juice',
				'text' => 'gingembre'
			}
		]
	],

	# Where flavourings or other ingredients with a maximum percentage are not the first ingredient then
	# use their maximum percentage
	[
		{lc => "en", ingredients_text => "milk, flavouring"},
		[
			{
				'id' => 'en:milk',
				'percent_estimate' => 97.5,
				'percent_max' => 100,
				'percent_min' => 95,
				'text' => 'milk'
			},
			{
				'id' => 'en:flavouring',
				'percent_estimate' => 2.5,
				'percent_max' => 5,
				'percent_min' => 0,
				'text' => 'flavouring'
			}
		]
	],

	# Can get percent_max from parent ingredient
	[
		{lc => "en", ingredients_text => "milk, natural flavouring"},
		[
			{
				'id' => 'en:milk',
				'percent_estimate' => 97.5,
				'percent_max' => 100,
				'percent_min' => 95,
				'text' => 'milk'
			},
			{
				'id' => 'en:natural-flavouring',
				'percent_estimate' => 2.5,
				'percent_max' => 5,
				'percent_min' => 0,
				'text' => 'natural flavouring'
			}
		]
	],

	# Where flavourings are the first ingredient then ignore maximum percentages
	[
		{lc => "en", ingredients_text => "flavouring, lemon flavouring"},
		[
			{
				'id' => 'en:flavouring',
				'percent_estimate' => 75,
				'percent_max' => 100,
				'percent_min' => 50,
				'text' => 'flavouring'
			},
			{
				'id' => 'en:lemon-flavouring',
				'percent_estimate' => 25,
				'percent_max' => 50,
				'percent_min' => 0,
				'text' => 'lemon flavouring'
			}
		]
	],

	# Where maximum would prevent ingredients from adding up to 100% then ignore it
	[
		{lc => "en", ingredients_text => "milk 80%, flavouring"},
		[
			{
				'id' => 'en:milk',
				'percent' => 80,
				'percent_estimate' => 80,
				'percent_max' => 80,
				'percent_min' => 80,
				'text' => 'milk'
			},
			{
				'id' => 'en:flavouring',
				'percent_estimate' => 20,
				'percent_max' => 20,
				'percent_min' => 20,
				'text' => 'flavouring'
			}
		]
	],

	# Where maximum is lower than later ingredients then ignore it
	[
		{lc => "en", ingredients_text => "milk, flavouring, sugar 10%"},
		[
			{
				'id' => 'en:milk',
				'percent_estimate' => 62.5,
				'percent_max' => 80,
				'percent_min' => 45,
				'text' => 'milk'
			},
			{
				'id' => 'en:flavouring',
				'percent_estimate' => 23.75,
				'percent_max' => 45,
				'percent_min' => 10,
				'text' => 'flavouring'
			},
			{
				'id' => 'en:sugar',
				'percent' => 10,
				'percent_estimate' => 13.75,
				'percent_max' => 10,
				'percent_min' => 10,
				'text' => 'sugar'
			}
		]
	],

	# Where two ingredients have a maximum then apply it
	[
		{lc => "en", ingredients_text => "milk, lemon flavouring, orange flavouring"},
		[
			{
				'id' => 'en:milk',
				'percent_estimate' => 95,
				'percent_max' => 100,
				'percent_min' => 90,
				'text' => 'milk'
			},
			{
				'id' => 'en:lemon-flavouring',
				'percent_estimate' => 2.5,
				'percent_max' => 5,
				'percent_min' => 0,
				'text' => 'lemon flavouring'
			},
			{
				'id' => 'en:orange-flavouring',
				'percent_estimate' => 2.5,
				'percent_max' => 5,
				'percent_min' => 0,
				'text' => 'orange flavouring'
			}
		]
	],

	# Ingredients indicated in grams, with a sum different than 100
	# Currently this does not work well, as we assume that ingredients are listed for 100g.
	[
		{lc => "en", ingredients_text => "milk (120g), sugar (30g), lemon flavouring (2g)"},
		[
			{
				'id' => 'en:milk',
				'percent' => 120,
				'percent_estimate' => 100,
				'percent_max' => 68,
				'percent_min' => 120,
				'text' => 'milk'
			},
			{
				'id' => 'en:sugar',
				'percent' => 30,
				'percent_estimate' => 0,
				'percent_max' => 30,
				'percent_min' => 30,
				'text' => 'sugar'
			},
			{
				'id' => 'en:lemon-flavouring',
				'percent' => '2',
				'percent_estimate' => 0,
				'percent_max' => 2,
				'percent_min' => 2,
				'text' => 'lemon flavouring'
			}
		]

	],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_ingredients_ref = $test_ref->[1];

	print STDERR "ingredients_text: " . $product_ref->{ingredients_text} . "\n";

	parse_ingredients_text($product_ref);
	if (compute_ingredients_percent_values(100, 100, $product_ref->{ingredients}) < 0) {
		print STDERR "compute_ingredients_percent_values < 0, delete ingredients percent values\n";
		delete_ingredients_percent_values($product_ref->{ingredients});
	}

	compute_ingredients_percent_estimates(100, $product_ref->{ingredients});

	is_deeply($product_ref->{ingredients}, $expected_ingredients_ref)
		# using print + join instead of diag so that we don't have
		# hashtags. It makes copy/pasting the resulting structure
		# inside the test file much easier when tests results need
		# to be updated. Caveat is that it might interfere with
		# test output.
		or print STDERR join("\n", explain $product_ref->{ingredients});
}

done_testing();
