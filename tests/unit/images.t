#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Images
	qw/get_code_and_imagefield_from_file_name scan_code get_image_url get_image_in_best_language data_to_display_image normalize_generation_ref process_image_move/;

use File::Basename 'dirname';
use Data::Dumper;
$Data::Dumper::Terse = 1;

# get_code_and_imagefield_from_file_name tests

my @tests = (

	["en", "12345678.jpg", "12345678", "front"],
	["en", "12345678_photo.jpg", "12345678", "front"],
	["en", "12345678_photo-3510.jpg", "12345678", "front"],
	["en", "12345678_2.jpg", "12345678", "other"],
	["en", "12345678901234.jpg", "12345678901234", "front"],
	["en", "12345678901234.ingredients_fr.jpg", "12345678901234", "ingredients_fr"],

	# regexps
	["es", "12345678-Valores_Nutricionales-423.jpg", "12345678", "nutrition"],
	["fr", "12345678.informations nutritionnelles.jpg", "12345678", "nutrition"],
	["fr", "liste-des-ingrédients-12345678jpg", "12345678", "ingredients"],

	# date
	["en", "20200201131743_2.jpg", undef, "other"],

	["en", "4 LR GROS LOUE_3 251 320 080 419_3D avant.png", "3251320080419", "other"],

);

foreach my $test_ref (@tests) {

	# print STDERR $test_ref->[0] . " " . $test_ref->[1] . "\n";
	my ($code, $imagefield) = get_code_and_imagefield_from_file_name($test_ref->[0], $test_ref->[1]);
	is($code, $test_ref->[2]);
	is($imagefield, $test_ref->[3]);
}

# scan_code tests based on GS1-US-Barcode-Capabilities-Test-Kit-Version-1.pdf

my @scan_code_tests = (

	["01_upc_a.jpg", "0725272730706"],
	["02_upc_e.jpg", "01234565"],
	["03_itf_13.jpg", "0012345123456"],
	["04_gs1_128.jpg", "4044782317112"],
	["05_gs1_databar_omni.jpg", "5010029000214"],
	["07_gs1_databar_stacked.jpg", "5010029000214"],
	["08_gs1_databar_stacked_omni.jpg", "5010029000214"],
	["37_gs1_datamatrix.jpg", "0725272730706"],
	["43_gs1_qrcode_digital_link.jpg", "9506000134369"],
	["52_gs1_datamatrix_digital_link.jpg", "5010029000214"]
);

my $sample_products_images_path = dirname(__FILE__) . "/inputs/images/";
foreach my $test_ref (@scan_code_tests) {
	my $code = scan_code($sample_products_images_path . $test_ref->[0]);
	is($code, $test_ref->[1],
		$test_ref->[0] . ' is expected to return "' . $test_ref->[1] . '" instead of "' . $code . '"');
}

# get_image_in_best_language tests

my $product_ref = {
	"code" => "3410123456789",
	"lang" => "fr",
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
				"it" => {
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
	}
};

my $image_lc = undef;
get_image_in_best_language($product_ref, "front", "en", \$image_lc);
is($image_lc, 'en');

get_image_in_best_language($product_ref, "front", "fr", \$image_lc);
is($image_lc, 'fr');

get_image_in_best_language($product_ref, "front", "de", \$image_lc);
is($image_lc, 'fr');

get_image_in_best_language($product_ref, "nutrition", "de", \$image_lc);
is($image_lc, 'it');

is(
	data_to_display_image($product_ref, "front", "en"),
	{
		'type' => 'front',
		'alt' => ' - Product',
		'id' => 'front_en',
		'sizes' => {
			'400' => {
				'h' => 185,
				'w' => 400,
				'url' => 'http://images.openfoodfacts.localhost/images/products/341/012/345/6789/front_en.14.400.jpg'
			},
			'200' => {
				'url' => 'http://images.openfoodfacts.localhost/images/products/341/012/345/6789/front_en.14.200.jpg',
				'w' => 200,
				'h' => 92
			},
			'full' => {
				'url' => 'http://images.openfoodfacts.localhost/images/products/341/012/345/6789/front_en.14.full.jpg',
				'h' => 1848,
				'w' => 4000
			},
			'100' => {
				'h' => 46,
				'w' => 100,
				'url' => 'http://images.openfoodfacts.localhost/images/products/341/012/345/6789/front_en.14.100.jpg'
			}
		},
		'lc' => 'en'
	}
);

is(data_to_display_image($product_ref, "packaging", "en"), undef, "packaging image should be undefined");
# Following line used to fail if data_to_display_image does not return an explicit undef in list context
is(
	{packaging_image => data_to_display_image($product_ref, "packaging", "en")},
	{packaging_image => undef},
	"packaging image should be undefined when assigned to hash"
);

is(normalize_generation_ref(undef), undef, "normalize_generation_ref should return undef when passed undef");
is(normalize_generation_ref({}), undef, "normalize_generation_ref should return undef when passed empty hash");

# process_image_move permission tests
{
	use ProductOpener::Users qw/%User/;
	my $now = time();
	my $test_prod = {
		code => "12345678",
		id => "12345678",
		images => {
			uploaded => {
				"1" => {uploader => "user_a", uploaded_t => $now - 100},
				"2" => {uploader => "user_b", uploaded_t => $now - 100},
				"3" => {uploader => "user_a", uploaded_t => $now - 90000},
				"4" => {uploader => "user_a", uploaded_t => $now - 3600},    # 1 hour ago - should be deletable
			}
		}
	};

	my $mock_images = mock 'ProductOpener::Images' => (
		override => [
			retrieve_product => sub {
				my ($id) = @_;
				return $test_prod if (defined $id and $id =~ /12345678/);
				return;
			},
			remove_images_by_prefix => sub {
				return 1;
			},
			delete_uploaded_image_and_associated_selected_images => sub {
				return 1;
			},
			store_product => sub {
				return 1;
			},
		]
	);
	my $mock_products = mock 'ProductOpener::Products' => (
		override => [
			retrieve_product => sub {
				my ($id) = @_;
				return $test_prod if (defined $id and $id =~ /12345678/);
				return;
			},
			store_product => sub {
				return 1;
			},
		]
	);

	# Test that $test_prod is properly set up
	is($test_prod->{code}, "12345678", "test product code is set correctly");
	is($test_prod->{images}{uploaded}{"1"}{uploader}, "user_a", "test product has correct uploader");
	is($test_prod->{images}{uploaded}{"1"}{uploaded_t}, $now - 100, "test product has correct upload time");

	# Non-moderator trying to move image to another product -> error
	$User{moderator} = 0;
	my $err1 = process_image_move("user_a", "12345678", "1", "87654321", "off");
	is(
		$err1,
		"You must be a moderator to move images to another product.",
		"non-moderator cannot move image to another product"
	);

	# Non-moderator trying to delete image uploaded by someone else -> error
	my $err2 = process_image_move("user_a", "12345678", "2", "trash", "off");
	is(
		$err2,
		"You can only remove images uploaded by yourself.",
		"non-moderator cannot delete image uploaded by someone else"
	);

	# Non-moderator with empty user_id -> error
	my $err3 = process_image_move("", "12345678", "1", "trash", "off");
	is($err3, "You can only remove images uploaded by yourself.", "unauthenticated user cannot delete image");

	# Non-moderator trying to delete image uploaded >24h ago -> error
	my $err4 = process_image_move("user_a", "12345678", "3", "trash", "off");
	is(
		$err4,
		"Images uploaded more than 24 hours ago can only be removed by a moderator.",
		"cannot delete image older than 24h"
	);

	# Non-moderator trying to delete image uploaded <24h ago -> should succeed (no error)
	my $err5 = process_image_move("user_a", "12345678", "4", "trash", "off");
	is($err5, undef, "non-moderator can delete their own image uploaded less than 24h ago");

	# Moderator can delete any image regardless of time
	$User{moderator} = 1;
	my $err6 = process_image_move("user_a", "12345678", "3", "trash", "off");
	is($err6, undef, "moderator can delete image older than 24h");

	# Admin can delete any image regardless of time
	$User{moderator} = 0;
	$User{admin} = 1;
	my $err7 = process_image_move("user_a", "12345678", "3", "trash", "off");
	is($err7, undef, "admin can delete image older than 24h");
}

done_testing();
