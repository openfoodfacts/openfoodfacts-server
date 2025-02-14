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
			nutriments => {
				energy_100g => 3460,
				fat_100g => 90,
				"saturated-fat_100g" => 15,
				sugars_100g => 0,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
			}
		}
	],
	[
		"olive-oil",
		{
			lc => "en",
			categories => "olive oils",
			nutriments => {
				energy_100g => 3460,
				fat_100g => 92,
				"saturated-fat_100g" => 14,
				sugars_100g => 0,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
			}
		}
	],
	[
		"colza-oil",
		{
			lc => "en",
			categories => "colza oils",
			nutriments => {
				energy_100g => 3760,
				fat_100g => 100,
				"saturated-fat_100g" => 7,
				sugars_100g => 0,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
			}
		}
	],
	[
		"walnut-oil",
		{
			lc => "en",
			categories => "walnut oils",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 100,
				"saturated-fat_100g" => 10,
				sugars_100g => 0,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
			}
		}
	],
	[
		"sunflower-oil",
		{
			lc => "en",
			categories => "sunflower oils",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 100,
				"saturated-fat_100g" => 10,
				sugars_100g => 0,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
			}
		}
	],

	# if no sugar but carbohydrates is 0, consider sugar 0
	[
		"sunflower-oil-no-sugar",
		{
			lc => "en",
			categories => "sunflower oils",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 100,
				"saturated-fat_100g" => 10,
				carbohydrates_100g => 0,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
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
			nutriments => {
				energy_100g => 3378,
				fat_100g => 100,
				carbohydrates_100g => 0,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
			}
		}
	],

	# saturated fat 1.03 should be rounded to 1.0 which is not strictly greater than 1.0
	[
		"breakfast-cereals",
		{
			lc => "en",
			categories => "breakfast cereals",
			nutriments => {
				energy_100g => 2450,
				fat_100g => 100,
				"saturated-fat_100g" => 1.03,
				sugars_100g => 31,
				sodium_100g => 0.221,
				fiber_100g => 6.9,
				proteins_100g => 10.3
			}
		}
	],

	# dairy drink with milk >= 80% are considered food and not beverages

	[
		"dairy-drinks-without-milk",
		{
			lc => "en",
			categories => "dairy drinks",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 10,
				"saturated-fat_100g" => 5,
				sugars_100g => 10,
				sodium_100g => 0,
				fiber_100g => 2,
				proteins_100g => 5
			},
			ingredients_text => "Water, sugar"
		}
	],
	[
		"milk",
		{
			lc => "en",
			categories => "milk",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 10,
				"saturated-fat_100g" => 5,
				sugars_100g => 10,
				sodium_100g => 0,
				fiber_100g => 2,
				proteins_100g => 5
			},
			ingredients_text => "Milk"
		}
	],
	[
		"dairy-drink-with-80-percent-milk",
		{
			lc => "en",
			categories => "dairy drinks",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 10,
				"saturated-fat_100g" => 5,
				sugars_100g => 10,
				sodium_100g => 0,
				fiber_100g => 2,
				proteins_100g => 5
			},
			ingredients_text => "Fresh milk 80%, sugar"
		}
	],
	[
		"beverage-with-80-percent-milk",
		{
			lc => "en",
			categories => "beverages",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 10,
				"saturated-fat_100g" => 5,
				sugars_100g => 20,
				sodium_100g => 0,
				fiber_100g => 2,
				proteins_100g => 5
			},
			ingredients_text => "Fresh milk 80%, sugar"
		}
	],

	[
		"dairy-drink-with-less-than-80-percent-milk",
		{
			lc => "en",
			categories => "dairy drinks",
			nutriments => {
				energy_100g => 3378,
				fat_100g => 10,
				"saturated-fat_100g" => 5,
				sugars_100g => 20,
				sodium_100g => 0,
				fiber_100g => 2,
				proteins_100g => 5
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
			nutriments => {
				energy_100g => 667,
				fat_100g => 8.4,
				"saturated-fat_100g" => 1.2,
				sugars_100g => 1.1,
				sodium_100g => 0.4,
				fiber_100g => 10.9,
				proteins_100g => 2.4
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
			nutriments => {
				energy_100g => 148,
				fat_100g => 10,
				"saturated-fat_100g" => 0.2,
				sugars_100g => 3,
				sodium_100g => 0.2,
				fiber_100g => 1.1,
				proteins_100g => 0.9
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
			nutriments => {
				energy_100g => 250,
				fat_100g => 0,
				sugars_100g => 12,
				sodium_100g => 0.2,
				fiber_100g => 0,
				proteins_100g => 0.5
			},
		}

	],

	# spring waters
	["spring-water-no-nutrition", {lc => "en", categories => "spring water", nutriments => {}}],
	["flavored-spring-water-no-nutrition", {lc => "en", categories => "flavoured spring water", nutriments => {}}],
	[
		"flavored-spring-with-nutrition",
		{
			lc => "en",
			categories => "flavoured spring water",
			nutriments => {
				energy_100g => 378,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 3,
				sodium_100g => 0,
				fiber_100g => 0,
				proteins_100g => 0
			}
		}
	],

	# Cocoa and chocolate powders
	[
		"cocoa-and-chocolate-powders",
		{
			lc => "en",
			"categories" => "cocoa and chocolate powders",
			nutriments => {
				energy_prepared_100g => 287,
				fat_prepared_100g => 0,
				"saturated-fat_prepared_100g" => 1.1,
				sugars_prepared_100g => 6.3,
				sodium_prepared_100g => 0.045,
				fiber_prepared_100g => 1.9,
				proteins_prepared_100g => 3.8
			}
		}
	],

	# fruits and vegetables estimates from category or from ingredients
	[
		"en-orange-juice-category-and-ingredients",
		{
			lc => "en",
			categories => "orange juices",
			ingredients_text => "orange juice 50%, water, sugar",
			nutriments => {
				energy_100g => 182,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 8.9,
				sodium_100g => 0.2,
				fiber_100g => 0.5,
				proteins_100g => 0.2
			},
		}
	],
	[
		"en-orange-juice-category",
		{
			lc => "en",
			categories => "orange juices",
			nutriments => {
				energy_100g => 182,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 8.9,
				sodium_100g => 0.2,
				fiber_100g => 0.5,
				proteins_100g => 0.2
			},
		}
	],
	# potatoes should not count as vegetables
	[
		"en-potatoes-category",
		{
			lc => "en",
			categories => "potatoes, vegetables",
			nutriments => {
				energy_100g => 182,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 8.9,
				sodium_100g => 0.2,
				fiber_100g => 0.5,
				proteins_100g => 0.2
			},
		}
	],

	# categories without Nutri-Score

	[
		"en-beers-category",
		{
			lc => "en",
			categories => "beers",
			nutriments => {
				energy_100g => 182,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 8.9,
				sodium_100g => 0.2,
				fiber_100g => 0.5,
				proteins_100g => 0.2
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
			nutriments => {
				energy_100g => 82,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 4.5,
				sodium_100g => 0.01,
				proteins_100g => 0,
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
			nutriments => {
				energy_100g => 82,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 4.5,
				sodium_100g => 0.01,
				proteins_100g => 0,
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
			nutriments => {
				energy_100g => 82,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 4.5,
				sodium_100g => 0.01,
				proteins_100g => 0,
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
			nutriments => {
				energy_100g => 82,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 1.5,
				sodium_100g => 0.01,
				proteins_100g => 20,
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
			nutriments => {
				energy_100g => 82,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 1.5,
				sodium_100g => 0.01,
				proteins_100g => 20,
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
			nutriments => {
				energy_100g => 82,
				fat_100g => 0,
				"saturated-fat_100g" => 0,
				sugars_100g => 1.5,
				sodium_100g => 0.01,
				proteins_100g => 20,
			},
		}
	],
	# For red meat products, the number of maximum protein points is set at 2 points
	[
		"en-red-meat-category-no-ingredients",
		{
			lc => "en",
			categories => "beef steaks",
			nutriments => {
				energy_100g => 82,
				fat_100g => 20,
				"saturated-fat_100g" => 10,
				sugars_100g => 0,
				sodium_100g => 0,
				proteins_100g => 50,
			},
		}
	],
	[
		"en-red-meat-ambiguous-category-no-ingredients",
		{
			lc => "en",
			categories => "sausages",
			nutriments => {
				energy_100g => 82,
				fat_100g => 20,
				"saturated-fat_100g" => 10,
				sugars_100g => 0,
				sodium_100g => 0,
				proteins_100g => 50,
			},
		}
	],
	[
		"en-red-meat-ambiguous-category-ingredients-with-lots-of-meat",
		{
			lc => "en",
			categories => "sausages",
			ingredients_text => "pork meat, lamb meat, chicken meat, salt 1%",
			nutriments => {
				energy_100g => 82,
				fat_100g => 20,
				"saturated-fat_100g" => 10,
				sugars_100g => 0,
				sodium_100g => 0,
				proteins_100g => 50,
			},
		}
	],
	[
		"en-red-meat-ambiguous-category-ingredients-with-no-meat",
		{
			lc => "en",
			categories => "sausages",
			ingredients_text => "salmon, wheat flour, salt 1%",
			nutriments => {
				energy_100g => 82,
				fat_100g => 20,
				"saturated-fat_100g" => 10,
				sugars_100g => 0,
				sodium_100g => 0,
				proteins_100g => 50,
			},
		}
	],
	[
		"en-red-meat-ambiguous-category-ingredients-with-very-little-meat",
		{
			lc => "en",
			categories => "sausages",
			ingredients_text => "eggs, wheat flour, water, rice flour, lamb 2%, salt 1%",
			nutriments => {
				energy_100g => 82,
				fat_100g => 20,
				"saturated-fat_100g" => 10,
				sugars_100g => 0,
				sodium_100g => 0,
				proteins_100g => 50,
			},
		}
	],
	# Milk: considered a beverage in 2023 Nutri-Score
	[
		"en-milk",
		{
			lc => "en",
			categories => "milk",
			nutriments => {
				energy_100g => 195,
				fat_100g => 1.6,
				"saturated-fat_100g" => 1,
				sugars_100g => 4.8,
				salt_100g => 0.1,
				proteins_100g => 3.3,
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
			nutriments => {
				energy_100g => 178,
				fat_100g => 2.6,
				"saturated-fat_100g" => 0.6,
				sugars_100g => 0.5,
				salt_100g => 0.03,
				fiber_100g => 0.5,
				proteins_100g => 3.9,
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
			nutriments => {
				energy_100g => 81,
				fat_100g => 0.26,
				"saturated-fat_100g" => 0.056,
				sugars_100g => 2.48,
				fiber_100g => 1.2,
				salt_100g => 0,
				proteins_100g => 0.86,
			}
		}
	],
	# olive oil
	[
		"en-olive-oil",
		{
			lc => "en",
			categories => "olive oil",
			ingredients_text => "olive oil",
			nutriments => {
				energy_100g => 3367,
				fat_100g => 91,
				"saturated-fat_100g" => 17,
				sugars_100g => 0,
				fiber_100g => 0,
				salt_100g => 0,
				proteins_100g => 0,
			}
		}
	],
	# olive oil, no ingredients specified
	[
		"en-olive-oil-no-ingredients",
		{
			lc => "en",
			categories => "olive oil",
			nutriments => {
				energy_100g => 3367,
				fat_100g => 91,
				"saturated-fat_100g" => 17,
				sugars_100g => 0,
				fiber_100g => 0,
				salt_100g => 0,
				proteins_100g => 0,
			}
		}
	],
	# olive oil, unrecognized ingredients specified
	[
		"en-olive-oil-unrecognized-ingredients",
		{
			lc => "en",
			categories => "olive oil",
			ingredients_text => "some very fancy but unrecognized way of writing olive oil",
			nutriments => {
				energy_100g => 3367,
				fat_100g => 91,
				"saturated-fat_100g" => 17,
				sugars_100g => 0,
				fiber_100g => 0,
				salt_100g => 0,
				proteins_100g => 0,
			}
		}
	],
	# avocado oil
	[
		"en-avocado-oil",
		{
			lc => "en",
			categories => "avocado oil",
			ingredients_text => "avocado",
			nutriments => {
				energy_100g => 3448,
				fat_100g => 91.6,
				"saturated-fat_100g" => 16.4,
				sugars_100g => 0,
				fiber_100g => 0,
				salt_100g => 0,
				proteins_100g => 0,
			}
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
			nutriments => {
				energy_100g => 3700,
				fat_100g => 100,
				"saturated-fat_100g" => 9.8,
				sugars_100g => 0,
				fiber_100g => 0,
				salt_100g => 0,
				proteins_100g => 0,
			}
		}
	],
	# rapeseed oil
	[
		"fr-rapeseed-oil",
		{
			lc => "fr",
			categories => "huile de colza",
			ingredients_text => "Huile de colza",
			nutriments => {
				energy_100g => 3400,
				fat_100g => 92,
				"saturated-fat_100g" => 7.3,
				sugars_100g => 0,
				fiber_100g => 0,
				salt_100g => 0,
				proteins_100g => 0,
			}
		}
	],
	# Coconut milk -> for cooking, not considered a beverage in 2023 Nutri-Score
	[
		"fr-coconut-milk",
		{
			lc => "fr",
			categories => "lait de coco",
			ingredients_text => "Noix de coco 60%, eau",
			nutriments => {
				energy_100g => 178,
				fat_100g => 2.6,
				"saturated-fat_100g" => 0.6,
				sugars_100g => 0.5,
				salt_100g => 0.03,
				fiber_100g => 0.5,
				proteins_100g => 3.9,
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
			nutriments => {
				energy_100g => 315,
				fat_100g => 0.9,
				"saturated-fat_100g" => 0.1,
				sugars_100g => 3.6,
				salt_100g => 0.80,
				fiber_100g => 5.3,
				proteins_100g => 5.0,
			},
		}
	],
	[
		"fr-canned-green-beans",
		{
			lc => "fr",
			ingredients_text => "eau 80%, sucre 10%, haricots verts 10%",
			categories => "haricots verts en conserve",
			nutriments => {
				energy_100g => 315,
				fat_100g => 0.9,
				"saturated-fat_100g" => 0.1,
				sugars_100g => 3.6,
				salt_100g => 1.2,
				fiber_100g => 5.3,
				proteins_100g => 5.0,
			},
		},
	],
	# canned fruits: water is counted as it is consumed
	[
		"fr-canned-pineapple",
		{
			lc => "fr",
			ingredients_text => "eau 80%, sucre 10%, ananas 10%",
			categories => "ananas en conserve",
			nutriments => {
				energy_100g => 315,
				fat_100g => 0.9,
				"saturated-fat_100g" => 0.1,
				sugars_100g => 3.6,
				salt_100g => 1.2,
				fiber_100g => 5.3,
				proteins_100g => 5.0,
			},
		},
	],
	# Flavored syrup: beverage preparations should use the beverage formula
	[
		"en-beverage-preparation-flavored-syrup",
		{
			lc => "en",
			categories => "flavored syrup",
			ingredients_text => "apple juice, water, sugar, aspartame",
			nutriments => {
				energy_prepared_100g => 82,
				fat_prepared_100g => 0,
				"saturated-fat_prepared_100g" => 0,
				sugars_prepared_100g => 4.5,
				sodium_prepared_100g => 0.01,
				proteins_prepared_100g => 0,
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
			nutriments => {
				energy_100g => 53,
				fat_100g => 0.1,
				"saturated-fat_100g" => 0,
				sugars_100g => 0,
				sodium_100g => 2,
				proteins_100g => 0.7,
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
);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# We need salt_value to compute sodium_100g with fix_salt_equivalent
	foreach my $prepared ('', '_prepared') {
		if (deep_exists($product_ref, "nutriments", "salt${prepared}_100g")) {
			$product_ref->{nutriments}{"salt${prepared}_value"} = $product_ref->{nutriments}{"salt${prepared}_100g"};
		}
		if (deep_exists($product_ref, "nutriments", "sodium${prepared}_100g")) {
			$product_ref->{nutriments}{"sodium${prepared}_value"}
				= $product_ref->{nutriments}{"sodium${prepared}_100g"};
		}
	}

	compute_nutrition_data_per_100g_and_per_serving($product_ref);
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
