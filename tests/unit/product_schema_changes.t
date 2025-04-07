#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::ProductSchemaChanges qw/convert_product_schema/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (

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

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
