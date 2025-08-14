#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

#use Test::MockClass qw{Nutrition};
use Test2::V0;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::ProductSchemaChanges qw/convert_product_schema/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results normalize_product_for_test_comparison/;

#use Test::MockTime qw(set_fixed_time);
#set_fixed_time(1650000000);  # freeze time to a known epoch

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

#my $mockNutrition = MockClass->new('Nutrition');

my @tests = (

	[
		'1002-to-1003-new-nutrition-schema',
		1003,
		{
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data_prepared" => "on",
			"nutrition_data" => "on",
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
		'1002-to-1003-new-nutrition-schema-no-prepared',
		1003,
		{
			"serving_quantity" => 250,
			"serving_quantity_unit" => "g",
			"nutrition_data" => "on",
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

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $target_schema_version = $test_ref->[1];
	my $product_ref = $test_ref->[2];

	convert_product_schema($product_ref, $target_schema_version);
	if (substr($testid, 0, 12) eq "1002-to-1003") {
		normalize_product_for_test_comparison($product_ref);
	}

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
