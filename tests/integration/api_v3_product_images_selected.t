#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";
use Storable qw(dclone);
use MIME::Base64 qw(encode_base64);
use JSON::MaybeXS qw(encode_json);

use boolean qw/:all/;

# Make sure we include convert_blessed to cater for blessed objects, like booleans
my $json = JSON::MaybeXS->new->convert_blessed->utf8->canonical;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $sample_products_images_path = dirname(__FILE__) . "/inputs/upload_images";

# For API v3 image upload, we will pass the image data as base64 encoded string

sub get_base64_image_data_from_file($path) {
	my $image_data = '';
	open(my $image, "<", $path);
	binmode($image);
	read $image, my $content, -s $image;
	close $image;
	$image_data = encode_base64($content, '');    # no line breaks
	return $image_data;
}

# these tests depends on each other and must be run sequentially
my $tests_ref = [
	{
		test_case => 'post-product-image',
		method => 'POST',
		path => '/api/v3.3/product/1234567890012/images',
		body => '{"image_data_base64":"' . get_base64_image_data_from_file("$sample_products_images_path/1.jpg") . '"}',
		expected_status_code => 200,
	},
	# Select / crop images
	# Select 2 images, one without cropping, one with cropping and rotation
	{
		test_case => 'patch-images-selected',
		method => 'PATCH',
		path => '/api/v3.3/product/1234567890012',
		body => $json->encode(
			{
				fields => 'updated',
				product => {
					images => {
						selected => {
							front => {
								en => {
									imgid => "1",
								}
							},
							ingredients => {
								fr => {
									imgid => "1",
									generation => {
										angle => 90,
										x1 => 10,
										y1 => 20,
										x2 => 100,
										y2 => 200,
										white_magic => true,
										normalize => false
									}
								},
								es => {
									imgid => "1",
									generation => {
										angle => 90,
										x1 => 10,
										y1 => 20,
										x2 => 100,
										y2 => 200,
										coordinates_image_size => "full",
										white_magic => true,
										normalize => false
									}
								},
								en => {
									imgid => "1",
									generation => {
										angle => 0,
										# some apps send all 0 or -1 to indicate no crop
										x1 => 0,
										y1 => 0,
										x2 => 0,
										y2 => 0,
										# string values instead of boolean
										white_magic => "false",
										normalize => "true"
									}
								}
							},
						}
					}
				}
			}
		),
	},
	{
		test_case => 'path-images-selected-invalid-image-type',
		method => 'PATCH',
		path => '/api/v3.3/product/1234567890012',
		body => $json->encode(
			{
				fields => 'updated',
				product => {
					images => {
						selected => {
							invalid_type => {
								en => {
									imgid => "1",
								}
							},
						}
					}
				}
			}
		),
	},
	{
		test_case => 'path-images-selected-invalid-image-lc',
		method => 'PATCH',
		path => '/api/v3.3/product/1234567890012',
		body => $json->encode(
			{
				fields => 'updated',
				product => {
					images => {
						selected => {
							front => {
								invalid_lc => {
									imgid => "1",
								}
							},
						}
					}
				}
			}
		),
	},
	{
		test_case => 'path-images-selected-inexisting-imgid',
		method => 'PATCH',
		path => '/api/v3.3/product/1234567890012',
		body => $json->encode(
			{
				fields => 'updated',
				product => {
					images => {
						selected => {
							front => {
								de => {
									imgid => "10",
								},
							},
						}
					}
				}
			}
		),
	},
	{
		test_case => 'path-images-unselect',
		method => 'PATCH',
		path => '/api/v3.3/product/1234567890012',
		body => $json->encode(
			{
				fields => 'updated',
				product => {
					images => {
						selected => {
							front => {
								en => undef
							},
						}
					}
				}
			}
		),
	},

	{
		test_case => 'get-product-image-crop',
		method => 'GET',
		path => '/api/v3.3/product/1234567890012',
		expected_status_code => 200,
	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
