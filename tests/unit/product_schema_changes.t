#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

#use Test::MockClass qw{Nutrition};
use Test2::V0;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::ProductSchemaChanges qw/convert_product_schema/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results normalize_product_for_test_comparison/;
use ProductOpener::Tags qw/init_taxonomies/;

# We need to load taxonomies (nutrients) for some schema upgrades
init_taxonomies(1);

#use Test::MockTime qw(set_fixed_time);
#set_fixed_time(1650000000);  # freeze time to a known epoch

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

#my $mockNutrition = MockClass->new('Nutrition');

my @tests = (

	# Very old schema, some missing fields like nutrition_data_per
	[
		'998-to-1003-new-nutrition-schema-bug',
		1003,
		{
		          'nutriments' => {
                            'carbohydrates_unit' => 'g',
                            'proteins' => 0,
                            'saturated-fat_value' => 0,
                            'sugars' => '8.8',
                            'sugars_value' => '8.8',
                            'energy' => 255,
                            'proteins_value' => 0,
                            'fat' => 0,
                            'energy_value' => '60.866796666667',
                            'saturated-fat' => 0,
                            'carbohydrates_100g' => '8.8',
                            'energy-kcal_value_computed' => '35.2',
                            'energy-kcal_unit' => 'kcal',
                            'energy-kcal' => '60.866796666667',
                            'proteins_100g' => 0,
                            'saturated-fat_unit' => 'g',
                            'energy_unit' => 'kcal',
                            'carbohydrates_value' => '8.8',
                            'energy_100g' => 255,
                            'energy-kcal_100g' => '60.866796666667',
                            'saturated-fat_100g' => 0,
                            'sugars_unit' => 'g',
                            'proteins_unit' => 'g',
                            'fat_100g' => 0,
                            'sugars_100g' => '8.8',
                            'fat_unit' => 'g',
                            'fat_value' => 0,
                            'energy-kcal_value' => '60.866796666667',
                            'carbohydrates' => '8.8'
                          },
						'product_type' => 'food',
						'product_name' => 'Ice guava',
						'_id' => '9310495085590',
						'id' => '9310495085590',
						'code' => '9310495085590',
						'lc' => 'en',
		},
	],

	[
		'1002-to-1003-new-nutrition-schema-with-nutriments-estimated-from-ingredients',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data_prepared" => "on",
			"nutrition_data_prepared_per" => "100g",
			"nutrition_data" => "on",
			"nutrition_data_per" => "100g",
			"nutriments" => {
				"energy-kcal_100g" => 386,
				"energy-kj_100g" => 1634,
				"carbohydrates_100g" => 78.9,
			},
			"nutriments_estimated" => {
				"alcohol_100g" => 0,
				"beta-carotene_100g" => 0.0000048596,
				"calcium_100g" => 0.12227384,
				"carbohydrates_100g" => 56.5243,
				"cholesterol_100g" => 0,
			}
		}
	],

	[
		'1002-to-1003-new-nutrition-schema-energy-in-kj-without-energy-kj-or-energy-kcal',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data_prepared" => "on",
			"nutrition_data_prepared_per" => "100g",
			"nutrition_data" => "on",
			"nutrition_data_per" => "100g",
			"nutriments" => {

				"energy" => 1634,
				"energy_100g" => 1634,
				"energy_prepared" => 304,
				"energy_prepared_100g" => 304,
				"energy_prepared_unit" => "kJ",
				"energy_prepared_value" => 304,
				"energy_unit" => "kJ",
				"energy_value" => 1634,
			},
		}
	],

	[
		'1002-to-1003-new-nutrition-schema-energy-in-kcal-without-energy-kj-or-energy-kcal',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data_prepared" => "on",
			"nutrition_data_prepared_per" => "100g",
			"nutrition_data" => "on",
			"nutrition_data_per" => "100g",
			"nutriments" => {

				"energy" => 340,
				"energy_100g" => 340,
				"energy_prepared" => 44,
				"energy_prepared_100g" => 44,
				"energy_prepared_unit" => "kcal",
				"energy_prepared_value" => 44,
				"energy_unit" => "kcal",
				"energy_value" => 340,
			},
		}
	],

	# In the old nutrition schema, we allowed unknown nutrients that were not in the taxonomy
	[
		'1002-to-1003-new-nutrition-schema-unknown-nutrients',
		1003,
		{
			"lang" => "da",
			"schema_version" => 1002,
			"nutrition_data" => "on",
			"nutrition_data_per" => "100g",
			"serving_quantity" => 1000,
			"serving_quantity_unit" => "ml",
			"nutriments" => {

				# unknown nutrient prefixed with language
				'fr-nitrate' => 0.38,
				'fr-nitrate_100g' => 0.38,
				'fr-nitrate_label' => "Nitrate",
				'fr-nitrate_serving' => 0.0038,
				'fr-nitrate_unit' => "g",
				'fr-nitrate_value' => 0.38,

				# unknown nutrient not prefixed with language (old fields)
				'sulfat' => 0.0141,
				'sulfat_100g' => 0.0141,
				'sulfat_label' => "Sulfat",
				'sulfat_serving' => 0.141,
				'sulfat_unit' => "mg",
				'sulfat_value' => 14.1,

				# unknown nutrient that is not in the taxonomy
				'en-some-unknown-nutrient' => 1.23,
				'en-some-unknown-nutrient_100g' => 1.23,
				'en-some-unknown-nutrient_label' => "Some unknown nutrient",
				'en-some-unknown-nutrient_unit' => "g",
				'en-some-unknown-nutrient_value' => 1.23,
			},
		}
	],

	[
		'1002-to-1003-new-nutrition-schema-per-100g',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data_prepared" => "on",
			"nutrition_data_prepared_per" => "100g",
			"nutrition_data" => "on",
			"nutrition_data_per" => "100g",
			"nutriments" => {
				"calcium_label" => "Calcium",
				"calcium_prepared" => 0.118,
				"calcium_prepared_100g" => 0.118,
				"calcium_prepared_unit" => "mg",
				"calcium_prepared_value" => 118,

				"carbohydrates" => 78.9,
				"carbohydrates_100g" => 78.9,
				"carbohydrates_prepared" => 9.8,
				"carbohydrates_prepared_100g" => 9.8,
				"carbohydrates_prepared_serving" => 9.9,
				"carbohydrates_prepared_unit" => "g",
				"carbohydrates_prepared_value" => 9.8,
				"carbohydrates_unit" => "g",
				"carbohydrates_value" => 78.9,

				"energy-kcal" => 386,
				"energy-kcal_100g" => 386,
				"energy-kcal_prepared" => 72,
				"energy-kcal_prepared_100g" => 72,
				"energy-kcal_prepared_unit" => "kcal",
				"energy-kcal_prepared_value" => 72,
				"energy-kcal_unit" => "kcal",
				"energy-kcal_value" => 386,
				"energy-kcal_value_computed" => 383.8,

				"energy-kj" => 1634,
				"energy-kj_100g" => 1634,
				"energy-kj_prepared" => 304,
				"energy-kj_prepared_100g" => 304,
				"energy-kj_prepared_unit" => "kJ",
				"energy-kj_prepared_value" => 304,
				"energy-kj_unit" => "kJ",
				"energy-kj_value" => 1634,
				"energy-kj_value_computed" => 1622.8,

				"energy" => 1634,
				"energy_100g" => 1634,
				"energy_prepared" => 304,
				"energy_prepared_100g" => 304,
				"energy_prepared_unit" => "kJ",
				"energy_prepared_value" => 304,
				"energy_unit" => "kJ",
				"energy_value" => 1634,

				"fat" => 3.6,
				"fat_100g" => 3.6,
				"fat_prepared" => 1.8,
				"fat_prepared_100g" => 1.8,
				"fat_prepared_unit" => "g",
				"fat_prepared_value" => 1.8,
				"fat_unit" => "g",
				"fat_value" => 3.6,

				"fiber" => 7.7,
				"fiber_100g" => 7.7,
				"fiber_prepared" => 0.5,
				"fiber_prepared_100g" => 0.5,
				"fiber_prepared_modifier" => "\x{003C}",
				"fiber_prepared_unit" => "g",
				"fiber_prepared_value" => 0.5,
				"fiber_unit" => "g",
				"fiber_value" => 7.7,

				"fruits-vegetables-legumes-estimate-from-ingredients_100g" => 0,
				"fruits-vegetables-legumes-estimate-from-ingredients_serving" => 0,

				"fruits-vegetables-nuts-estimate-from-ingredients_100g" => 0,
				"fruits-vegetables-nuts-estimate-from-ingredients_serving" => 0,

				"nova-group" => 4,
				"nova-group_100g" => 4,
				"nova-group_serving" => 4,

				"nutrition-score-fr" => 9,
				"nutrition-score-fr_100g" => 9,

				"proteins" => 5.1,
				"proteins_100g" => 5.1,
				"proteins_prepared" => 3.6,
				"proteins_prepared_100g" => 3.6,
				"proteins_prepared_unit" => "g",
				"proteins_prepared_value" => 3.6,
				"proteins_unit" => "g",
				"proteins_value" => 5.1,

				"salt" => 0.41,
				"salt_100g" => 0.41,
				"salt_prepared" => 0.14,
				"salt_prepared_100g" => 0.14,
				"salt_prepared_unit" => "g",
				"salt_prepared_value" => 0.14,
				"salt_unit" => "g",
				"salt_value" => 0.41,
				"salt_modifier" => "\x{007E}",

				"saturated-fat" => 1.6,
				"saturated-fat_100g" => 1.6,
				"saturated-fat_prepared" => 1.1,
				"saturated-fat_prepared_100g" => 1.1,
				"saturated-fat_prepared_unit" => "g",
				"saturated-fat_prepared_value" => 1.1,
				"saturated-fat_unit" => "g",
				"saturated-fat_value" => 1.6,

				"sodium" => 0.164,
				"sodium_100g" => 0.164,
				"sodium_prepared" => 0.056,
				"sodium_prepared_100g" => 0.056,
				"sodium_prepared_unit" => "g",
				"sodium_prepared_value" => 0.056,
				"sodium_unit" => "g",
				"sodium_value" => 0.164,

				"sugars" => 75.1,
				"sugars_100g" => 75.1,
				"sugars_prepared" => 9.5,
				"sugars_prepared_100g" => 9.5,
				"sugars_prepared_unit" => "g",
				"sugars_prepared_value" => 9.5,
				"sugars_unit" => "g",
				"sugars_value" => 75.1,

				"vitamin-c" => 0.15,
				"vitamin-c_100g" => 0.15,
				"vitamin-c_label" => "Vitamin C (ascorbic acid)",
				"vitamin-c_prepared" => 0.011,
				"vitamin-c_prepared_100g" => 0.011,
				"vitamin-c_prepared_unit" => "mg",
				"vitamin-c_prepared_value" => 11,
				"vitamin-c_unit" => "mg",
				"vitamin-c_value" => 150,

				"vitamin-d" => 0.000011,
				"vitamin-d_100g" => 0.000011,
				"vitamin-d_label" => "Vitamin D",
				"vitamin-d_prepared" => 7.3e-7,
				"vitamin-d_prepared_100g" => 7.3e-7,
				"vitamin-d_prepared_unit" => "µg",
				"vitamin-d_prepared_value" => 0.73,
				"vitamin-d_unit" => "µg",
				"vitamin-d_value" => 11,

				"added-sugars_modifier" => "-",
				"alcohol_prepared_modifier" => "-",
			},
		}
	],

	[
		'1002-to-1003-new-nutrition-schema-as-sold-100g',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data" => "on",
			"nutrition_data_per" => "100g",
			"nutriments" => {
				"calcium_label" => "Calcium",
				"calcium_prepared" => 0.118,
				"calcium_prepared_100g" => 0.118,
				"calcium_prepared_unit" => "mg",
				"calcium_prepared_value" => 118,

				"carbohydrates" => 78.9,
				"carbohydrates_100g" => 78.9,
				"carbohydrates_prepared" => 9.8,
				"carbohydrates_prepared_100g" => 9.8,
				"carbohydrates_prepared_unit" => "g",
				"carbohydrates_prepared_value" => 9.8,
				"carbohydrates_unit" => "g",
				"carbohydrates_value" => 78.9,

				"energy-kcal" => 386,
				"energy-kcal_100g" => 386,
				"energy-kcal_prepared" => 72,
				"energy-kcal_prepared_100g" => 72,
				"energy-kcal_prepared_unit" => "kcal",
				"energy-kcal_prepared_value" => 72,
				"energy-kcal_unit" => "kcal",
				"energy-kcal_value" => 386,
				"energy-kcal_value_computed" => 383.8,

				"energy-kj" => 1634,
				"energy-kj_100g" => 1634,
				"energy-kj_prepared" => 304,
				"energy-kj_prepared_100g" => 304,
				"energy-kj_prepared_unit" => "kJ",
				"energy-kj_prepared_value" => 304,
				"energy-kj_unit" => "kJ",
				"energy-kj_value" => 1634,
				"energy-kj_value_computed" => 1622.8,

				"energy" => 1634,
				"energy_100g" => 1634,
				"energy_prepared" => 304,
				"energy_prepared_100g" => 304,
				"energy_prepared_unit" => "kJ",
				"energy_prepared_value" => 304,
				"energy_unit" => "kJ",
				"energy_value" => 1634,

				"fat" => 3.6,
				"fat_100g" => 3.6,
				"fat_prepared" => 1.8,
				"fat_prepared_100g" => 1.8,
				"fat_prepared_unit" => "g",
				"fat_prepared_value" => 1.8,
				"fat_unit" => "g",
				"fat_value" => 3.6,

				"fiber" => 7.7,
				"fiber_100g" => 7.7,
				"fiber_prepared" => 0.5,
				"fiber_prepared_100g" => 0.5,
				"fiber_prepared_modifier" => "\x{003C}",
				"fiber_prepared_unit" => "g",
				"fiber_prepared_value" => 0.5,
				"fiber_unit" => "g",
				"fiber_value" => 7.7,

				"fruits-vegetables-legumes-estimate-from-ingredients_100g" => 0,
				"fruits-vegetables-legumes-estimate-from-ingredients_serving" => 0,

				"fruits-vegetables-nuts-estimate-from-ingredients_100g" => 0,
				"fruits-vegetables-nuts-estimate-from-ingredients_serving" => 0,

				"nova-group" => 4,
				"nova-group_100g" => 4,
				"nova-group_serving" => 4,

				"nutrition-score-fr" => 9,
				"nutrition-score-fr_100g" => 9,

				"proteins" => 5.1,
				"proteins_100g" => 5.1,
				"proteins_prepared" => 3.6,
				"proteins_prepared_100g" => 3.6,
				"proteins_prepared_unit" => "g",
				"proteins_prepared_value" => 3.6,
				"proteins_unit" => "g",
				"proteins_value" => 5.1,

				"salt" => 0.41,
				"salt_100g" => 0.41,
				"salt_prepared" => 0.14,
				"salt_prepared_100g" => 0.14,
				"salt_prepared_unit" => "g",
				"salt_prepared_value" => 0.14,
				"salt_unit" => "g",
				"salt_value" => 0.41,
				"salt_modifier" => "\x{007E}",

				"saturated-fat" => 1.6,
				"saturated-fat_100g" => 1.6,
				"saturated-fat_prepared" => 1.1,
				"saturated-fat_prepared_100g" => 1.1,
				"saturated-fat_prepared_unit" => "g",
				"saturated-fat_prepared_value" => 1.1,
				"saturated-fat_unit" => "g",
				"saturated-fat_value" => 1.6,

				"sodium" => 0.164,
				"sodium_100g" => 0.164,
				"sodium_prepared" => 0.056,
				"sodium_prepared_100g" => 0.056,
				"sodium_prepared_unit" => "g",
				"sodium_prepared_value" => 0.056,
				"sodium_unit" => "g",
				"sodium_value" => 0.164,

				"sugars" => 75.1,
				"sugars_100g" => 75.1,
				"sugars_prepared" => 9.5,
				"sugars_prepared_100g" => 9.5,
				"sugars_prepared_unit" => "g",
				"sugars_prepared_value" => 9.5,
				"sugars_unit" => "g",
				"sugars_value" => 75.1,

				"vitamin-c" => 0.15,
				"vitamin-c_100g" => 0.15,
				"vitamin-c_label" => "Vitamin C (ascorbic acid)",
				"vitamin-c_prepared" => 0.011,
				"vitamin-c_prepared_100g" => 0.011,
				"vitamin-c_prepared_unit" => "mg",
				"vitamin-c_prepared_value" => 11,
				"vitamin-c_unit" => "mg",
				"vitamin-c_value" => 150,

				"vitamin-d" => 0.000011,
				"vitamin-d_100g" => 0.000011,
				"vitamin-d_label" => "Vitamin D",
				"vitamin-d_prepared" => 7.3e-7,
				"vitamin-d_prepared_100g" => 7.3e-7,
				"vitamin-d_prepared_unit" => "µg",
				"vitamin-d_prepared_value" => 0.73,
				"vitamin-d_unit" => "µg",
				"vitamin-d_value" => 11,

				"added-sugars_modifier" => "-",
			},
		}
	],

	[
		'1002-to-1003-new-nutrition-schema-no-nutrition-data',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"no_nutrition_data" => "on",
			"nutrition_data" => "on",
			"nutrition_data_per" => "100g",
			"nutriments" => {
				"calcium_label" => "Calcium",
				"calcium_prepared" => 0.118,
				"calcium_prepared_100g" => 0.118,
				"calcium_prepared_unit" => "mg",
				"calcium_prepared_value" => 118,

				"energy-kcal" => 386,
				"energy-kcal_100g" => 386,
				"energy-kcal_prepared" => 72,
				"energy-kcal_prepared_100g" => 72,
				"energy-kcal_prepared_unit" => "kcal",
				"energy-kcal_prepared_value" => 72,
				"energy-kcal_unit" => "kcal",
				"energy-kcal_value" => 386,
				"energy-kcal_value_computed" => 383.8,

				"energy-kj" => 1634,
				"energy-kj_100g" => 1634,
				"energy-kj_prepared" => 304,
				"energy-kj_prepared_100g" => 304,
				"energy-kj_prepared_unit" => "kJ",
				"energy-kj_prepared_value" => 304,
				"energy-kj_unit" => "kJ",
				"energy-kj_value" => 1634,
				"energy-kj_value_computed" => 1622.8,

				"energy" => 1634,
				"energy_100g" => 1634,
				"energy_prepared" => 304,
				"energy_prepared_100g" => 304,
				"energy_prepared_unit" => "kJ",
				"energy_prepared_value" => 304,
				"energy_unit" => "kJ",
				"energy_value" => 1634,

				"fruits-vegetables-legumes-estimate-from-ingredients_100g" => 0,
				"fruits-vegetables-legumes-estimate-from-ingredients_serving" => 0,

				"fruits-vegetables-nuts-estimate-from-ingredients_100g" => 0,
				"fruits-vegetables-nuts-estimate-from-ingredients_serving" => 0,

				"added-sugars_modifier" => "-",
			},
		}
	],

	[
		'1002-to-1003-new-nutrition-schema-prepared-serving',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data_prepared" => "on",
			"nutrition_data_prepared_per" => "serving",
			"nutriments" => {
				"calcium_label" => "Calcium",
				"calcium_prepared" => 0.118,
				"calcium_prepared_100g" => 0.118,
				"calcium_prepared_serving" => 0.295,
				"calcium_prepared_unit" => "mg",
				"calcium_prepared_value" => 118,

				"energy-kcal" => 386,
				"energy-kcal_100g" => 386,
				"energy-kcal_prepared" => 72,
				"energy-kcal_prepared_100g" => 72,
				"energy-kcal_prepared_serving" => 180,
				"energy-kcal_prepared_unit" => "kcal",
				"energy-kcal_prepared_value" => 72,
				"energy-kcal_unit" => "kcal",
				"energy-kcal_value" => 386,
				"energy-kcal_value_computed" => 383.8,

				"energy-kj" => 1634,
				"energy-kj_100g" => 1634,
				"energy-kj_prepared" => 304,
				"energy-kj_prepared_100g" => 304,
				"energy-kj_prepared_serving" => 760,
				"energy-kj_prepared_unit" => "kJ",
				"energy-kj_prepared_value" => 304,
				"energy-kj_unit" => "kJ",
				"energy-kj_value" => 1634,
				"energy-kj_value_computed" => 1622.8,

				"energy" => 1634,
				"energy_100g" => 1634,
				"energy_prepared" => 304,
				"energy_prepared_100g" => 304,
				"energy_prepared_serving" => 760,
				"energy_prepared_unit" => "kJ",
				"energy_prepared_value" => 304,
				"energy_unit" => "kJ",
				"energy_value" => 1634,

				"fruits-vegetables-legumes-estimate-from-ingredients_100g" => 0,
				"fruits-vegetables-legumes-estimate-from-ingredients_serving" => 0,

				"added-sugars_modifier" => "-",
			},
		}
	],

	[
		'1002-to-1003-new-nutrition-schema-no-serving-quantity',
		1003,
		{
			"schema_version" => 1002,
			"serving_quantity" => undef,
			"serving_quantity_unit" => undef,
			"nutrition_data" => "on",
			"nutrition_data_per" => "serving",
			"nutrition_data_prepared" => "",
			"nutriments" => {
				"alcohol" => 0,
				"alcohol_serving" => 0,
				"alcohol_unit" => "% vol",
				"alcohol_value" => 0,

				"carbohydrates" => 100,
				"carbohydrates_serving" => 100,
				"carbohydrates_unit" => "g",
				"carbohydrates_value" => 100,

				"energy-kcal" => 400,
				"energy-kcal_serving" => 400,
				"energy-kcal_unit" => "kcal",
				"energy-kcal_value" => 400,
				"energy-kcal_value_computed" => 400,

				"energy-kj" => 1700,
				"energy-kj_serving" => 1700,
				"energy-kj_unit" => "kJ",
				"energy-kj_value" => 1700,
				"energy-kj_value_computed" => 1700,

				"energy" => 1700,
				"energy_serving" => 1700,
				"energy_unit" => "kJ",
				"energy_value" => 1700,

				"fat" => 0,
				"fat_serving" => 0,
				"fat_unit" => "g",
				"fat_value" => 0,

				"fiber" => 0,
				"fiber_serving" => 0,
				"fiber_unit" => "g",
				"fiber_value" => 0,

				"sugars" => 100,
				"sugars_serving" => 100,
				"sugars_unit" => "g",
				"sugars_value" => 100
			},
		}
	],

	[
		'1003-to-1002-no_nutrition_data_on_packaging',
		1002,
		{
			"schema_version" => 1003,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"no_nutrition_data" => "on",
			"nutrition" => {
				"aggregated_set" => undef,
				"nutrient_sets" => []
			},
		}
	],

	[
		'1003-to-1002-no_nutrition',
		1002,
		{
			"schema_version" => 1003,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
		}
	],

	[
		'1003-to-1002-no-aggregated-set-input-set-per-serving-without-serving-quantity',
		1002,
		{
			"schema_version" => 1003,
			"nutrition" => {
				"nutrient_sets" => [
					{
						"nutrients" => {
							"carbohydrates" => {
								"source" => "manufacturer",
								"source_per" => "serving",
								"unit" => "g",
								"value" => 100,
								"value_string" => "100"
							},
						},
						"per" => "serving",
						"preparation" => "as_sold"
					}
				]
			},
		}
	],

	[
		'1003-to-1002-prepared-serving-nutrients',
		1002,
		{
			"schema_version" => 1003,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition" => {
				"aggregated_set" => {
					"nutrients" => {
						"alcohol" => {
							"source" => "packaging",
							"source_per" => "100g",
							"unit" => "% vol",
							"value" => 0,
							"value_string" => "0"
						},
						"carbohydrates" => {
							"source" => "manufacturer",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 100,
							"value_string" => "100"
						},
						"energy" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "kJ",
							"value" => 1700,
							"value_string" => "1700"
						},
						"energy-kcal" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "kcal",
							"value" => 400,
							"value_string" => "400"
						},
						"energy-kj" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "kJ",
							"value" => 1700,
							"value_string" => "1700"
						},
						"fat" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 5,
							"value_string" => "5"
						},
						"fiber" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 0,
							"value_string" => "0",
							"modifier" => "\x{007E}"
						},
						"sugars" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 100,
							"value_string" => "100"
						},

					},
					"per" => "serving",
					"per_quantity" => 250,
					"per_unit" => "g",
					"preparation" => "prepared"
				},
				"nutrient_sets" => []
			},
		}
	],

	[
		'1003-to-1002-as-sold-100g-nutrients',
		1002,
		{
			"schema_version" => 1003,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition" => {
				"aggregated_set" => {
					"nutrients" => {
						"alcohol" => {
							"source" => "packaging",
							"source_per" => "100g",
							"unit" => "% vol",
							"value" => 0,
							"value_string" => "0"
						},
						"carbohydrates" => {
							"source" => "manufacturer",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 40,
							"value_string" => "40"
						},
						"energy" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "kJ",
							"value" => 680,
							"value_string" => "680"
						},
						"energy-kcal" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "kcal",
							"value" => 160,
							"value_string" => "160"
						},
						"energy-kj" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "kJ",
							"value" => 680,
							"value_string" => "680"
						},
						"fat" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 2,
							"value_string" => "2",
							"modifier" => "\x{003C}"
						},
						"fiber" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 0,
							"value_string" => "0"
						},
						"sugars" => {
							"source" => "packaging",
							"source_per" => "serving",
							"unit" => "g",
							"value" => 40,
							"value_string" => "40"
						},

					},
					"per" => "100g",
					"per_quantity" => 100,
					"per_unit" => "g",
					"preparation" => "as_sold"
				},
				"nutrient_sets" => []
			},
		}
	],

	[
		'1003-to-1002-no-aggregated-set',
		1002,
		{
			"schema_version" => 1003,
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition" => {
				"aggregated_set" => {},
				"nutrient_sets" => [
					{
						"nutrients" => {
							"alcohol" => {
								"unit" => "% vol",
								"value" => 0,
								"value_string" => "0"
							},
							"carbohydrates" => {
								"unit" => "g",
								"value" => 40,
								"value_string" => "40"
							},
							"energy" => {
								"unit" => "kJ",
								"value" => 680,
								"value_string" => "680"
							},
							"energy-kcal" => {
								"unit" => "kcal",
								"value" => 160,
								"value_string" => "160"
							},
							"energy-kj" => {
								"unit" => "kJ",
								"value" => 680,
								"value_string" => "680"
							},
							"fat" => {
								"unit" => "g",
								"value" => 2,
								"value_string" => "2"
							},
							"fiber" => {
								"unit" => "g",
								"value" => 0,
								"value_string" => "0"
							},
							"sugars" => {
								"unit" => "g",
								"value" => 40,
								"value_string" => "40"
							},
						},
						"per" => "100g",
						"per_quantity" => 100,
						"per_unit" => "g",
						"preparation" => "as_sold",
						"source" => "packaging",
						"unspecified_nutrients" => ["added-sugars"]
					}
				]
			},
		}
	],

	[
		'1002-to-1001-change-images-object',
		1001,
		{
			"images" => {
				"selected" => {
					"front" => {
						"en" => {
							"generation" => {
								"angle" => "0",
								"coordinates_image_size" => "400",
								"geometry" => "0x0-0-0",
								"normalize" => "false",
								"white_magic" => "false",
								"x1" => "0",
								"x2" => "0",
								"y1" => "0",
								"y2" => "0"
							},
							"imgid" => "3",
							"rev" => "14",
							"sizes" => {
								"100" => {
									"h" => 46,
									"w" => 100
								},
								"200" => {
									"h" => 92,
									"w" => 200
								},
								"400" => {
									"h" => 185,
									"w" => 400
								},
								"full" => {
									"h" => 1848,
									"w" => 4000
								}
							}
						},
						"fr" => {
							"generation" => {
								"angle" => "0",
								"coordinates_image_size" => "400",
								"geometry" => "919x1280-424-703",
								"normalize" => "false",
								"white_magic" => "false",
								"x1" => "42.5",
								"x2" => "134.5",
								"y1" => "70.359375",
								"y2" => "198.359375"
							},
							"imgid" => "1",
							"rev" => "10",
							"sizes" => {
								"100" => {
									"h" => 100,
									"w" => 72
								},
								"200" => {
									"h" => 200,
									"w" => 144
								},
								"400" => {
									"h" => 400,
									"w" => 287
								},
								"full" => {
									"h" => 1280,
									"w" => 919
								}
							}
						}
					},
					"ingredients" => {
						"fr" => {
							"generation" => {
								"angle" => 0,
								"coordinates_image_size" => "full",
								"geometry" => "0x0--1--1",
								"normalize" => undef,
								"white_magic" => undef,
								"x1" => "-1",
								"x2" => "-1",
								"y1" => "-1",
								"y2" => "-1"
							},
							"imgid" => "1",
							"rev" => "3",
							"sizes" => {
								"100" => {
									"h" => 100,
									"w" => 46
								},
								"200" => {
									"h" => 200,
									"w" => 92
								},
								"400" => {
									"h" => 400,
									"w" => 185
								},
								"full" => {
									"h" => 4000,
									"w" => 1848
								}
							}
						}
					},
					"nutrition" => {
						"fr" => {
							"generation" => {
								"angle" => "0",
								"coordinates_image_size" => "full",
								"geometry" => "513x730-2511-522",
								"normalize" => "false",
								"white_magic" => "false",
								"x1" => "2511.839967216288",
								"x2" => "3024.7198587148587",
								"y1" => "522.7062563284228",
								"y2" => "1252.7512501737215"
							},
							"imgid" => "2",
							"rev" => "7",
							"sizes" => {
								"100" => {
									"h" => 100,
									"w" => 70
								},
								"200" => {
									"h" => 200,
									"w" => 141
								},
								"400" => {
									"h" => 400,
									"w" => 281
								},
								"full" => {
									"h" => 730,
									"w" => 513
								}
							}
						}
					}
				},
				"uploaded" => {
					"1" => {
						"sizes" => {
							"100" => {
								"h" => 100,
								"w" => 46
							},
							"400" => {
								"h" => 400,
								"w" => 185
							},
							"full" => {
								"h" => 4000,
								"w" => 1848
							}
						},
						"uploaded_t" => 1744032137,
						"uploader" => "stephane2"
					},
					"2" => {
						"sizes" => {
							"100" => {
								"h" => 46,
								"w" => 100
							},
							"400" => {
								"h" => 185,
								"w" => 400
							},
							"full" => {
								"h" => 1848,
								"w" => 4000
							}
						},
						"uploaded_t" => 1744032138,
						"uploader" => "stephane2"
					},
					"3" => {
						"sizes" => {
							"100" => {
								"h" => 46,
								"w" => 100
							},
							"400" => {
								"h" => 185,
								"w" => 400
							},
							"full" => {
								"h" => 1848,
								"w" => 4000
							}
						},
						"uploaded_t" => 1744032360,
						"uploader" => "stephane2"
					}
				}
			},
			"schema_version" => 1002
		}

	],

	[
		'1001-to-1002-change-images-object',
		1002,
		{
			images => {
				1 => {
					sizes => {
						100 => {
							h => 100,
							w => 46
						},
						400 => {
							h => 400,
							w => 185
						},
						full => {
							h => 4000,
							w => 1848
						}
					},
					uploaded_t => 1744032137,
					uploader => "stephane2"
				},
				2 => {
					sizes => {
						100 => {
							h => 46,
							w => 100
						},
						400 => {
							h => 185,
							w => 400
						},
						full => {
							h => 1848,
							w => 4000
						}
					},
					uploaded_t => 1744032138,
					uploader => "stephane2"
				},
				3 => {
					sizes => {
						100 => {
							h => 46,
							w => 100
						},
						400 => {
							h => 185,
							w => 400
						},
						full => {
							h => 1848,
							w => 4000
						}
					},
					uploaded_t => 1744032360,
					uploader => "stephane2"
				},
				front_en => {
					angle => "0",
					coordinates_image_size => "400",
					geometry => "0x0-0-0",
					imgid => "3",
					normalize => "false",
					rev => "14",
					sizes => {
						100 => {
							h => 46,
							w => 100
						},
						200 => {
							h => 92,
							w => 200
						},
						400 => {
							h => 185,
							w => 400
						},
						full => {
							h => 1848,
							w => 4000
						}
					},
					white_magic => "false",
					x1 => "0",
					x2 => "0",
					y1 => "0",
					y2 => "0"
				},
				front_fr => {
					angle => "0",
					coordinates_image_size => "400",
					geometry => "919x1280-424-703",
					imgid => "1",
					normalize => "false",
					rev => "10",
					sizes => {
						100 => {
							h => 100,
							w => 72
						},
						200 => {
							h => 200,
							w => 144
						},
						400 => {
							h => 400,
							w => 287
						},
						full => {
							h => 1280,
							w => 919
						}
					},
					white_magic => "false",
					x1 => "42.5",
					x2 => "134.5",
					y1 => "70.359375",
					y2 => "198.359375"
				},
				ingredients_fr => {
					angle => 0,
					coordinates_image_size => "full",
					geometry => "0x0--1--1",
					imgid => "1",
					normalize => undef,
					rev => "3",
					sizes => {
						100 => {
							h => 100,
							w => 46
						},
						200 => {
							h => 200,
							w => 92
						},
						400 => {
							h => 400,
							w => 185
						},
						full => {
							h => 4000,
							w => 1848
						}
					},
					white_magic => undef,
					x1 => "-1",
					x2 => "-1",
					y1 => "-1",
					y2 => "-1"
				},
				nutrition_fr => {
					angle => "0",
					coordinates_image_size => "full",
					geometry => "513x730-2511-522",
					imgid => "2",
					normalize => "false",
					rev => "7",
					sizes => {
						100 => {
							h => 100,
							w => 70
						},
						200 => {
							h => 200,
							w => 141
						},
						400 => {
							h => 400,
							w => 281
						},
						full => {
							h => 730,
							w => 513
						}
					},
					white_magic => "false",
					x1 => "2511.839967216288",
					x2 => "3024.7198587148587",
					y1 => "522.7062563284228",
					y2 => "1252.7512501737215"
				},
				nutrition_it => {
					angle => "360",
					coordinates_image_size => 400,
					geometry => "513x730-2511-522",
					imgid => "2",
					normalize => 1,
					rev => "7",
					sizes => {
						100 => {
							h => 100,
							w => 70
						},
						200 => {
							h => 200,
							w => 141
						},
						400 => {
							h => 400,
							w => 281
						},
						full => {
							h => 730,
							w => 513
						}
					},
					white_magic => "on",
					x1 => undef,
					x2 => undef,
					y1 => undef,
					y2 => undef,
					some_extra_key => "some_extra_value"
				}

			}
		},
		schema_version => 1001,
	],

	[
		'1000-to-1001-remove-ingredients-hierarchy',
		1001,
		{
			# schema_version field exists only for version 1001+
			lc => "en",
			ingredients_text_en => "Banana",
			ingredients_tags => ["en:fruit", "en:banana"],
			ingredients_hierarchy => ["en:fruit", "en:banana"],
		}
	],

	[
		'1001-to-1000-add-ingredients-hierarchy',
		1000,
		{
			schema_version => 1001,
			lc => "en",
			ingredients_text_en => "Banana",
			ingredients_tags => ["en:fruit", "en:banana"],
		}
	],

	[
		'1000-to-1001-taxonomize-brands',
		1001,
		{
			# schema_version field exists only for version 1001+
			lc => "en",
			brands => "Carrefour, Nestlé, Brând Not In Taxonomy",
			brands_tags => ["carrefour", "nestle"],
		}
	],

	[
		'1001-to-1000-untaxonomize-brands',
		1000,
		{
			schema_version => 1001,
			lc => "en",
			brands => "Carrefour, Nestlé, Brând Not In Taxonomy",
			brands_tags => ["xx:carrefour", "xx:nestle", "xx:brand-not-in-taxonomy"],
			brands_hierarchy => ["xx:Carrefour", "xx:nestle", "xx:Brând Not In Taxonomy"],
		}
	],

	[
		'998-to-1000-barcode-normalization',
		998,
		{
			lc => "en",
			_id => "093270067481501",
			code => "093270067481501",
		}
	],
);

# We run the tests in reverse order so that we output last the most recent tests added on top
foreach my $test_ref (reverse @tests) {

	my $testid = $test_ref->[0];
	my $target_schema_version = $test_ref->[1];
	my $product_ref = $test_ref->[2];
	
	print STDERR "Running test $testid\n";
	convert_product_schema($product_ref, $target_schema_version);
	print STDERR "Finished conversion for test $testid\n";
	if (substr($testid, 0, 12) eq "1002-to-1003") {
		normalize_product_for_test_comparison($product_ref);
	}

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
