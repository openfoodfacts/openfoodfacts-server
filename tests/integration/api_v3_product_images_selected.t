#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";
use Storable qw(dclone);
use MIME::Base64 qw(encode_base64);

remove_all_users();

remove_all_products();

wait_application_ready();

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

my $tests_ref = [
	{
		test_case => 'post-product-image',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => '{"image_data_base64":"' . get_base64_image_data_from_file("$sample_products_images_path/1.jpg") . '"}',
		expected_status_code => 200,
	},
	# Select / crop images

	{
		test_case => 'patch-images-selected',
		method => 'PATCH',
		path => '/api/v3/product/234567890012',
		body => '{
			"fields" : "updated",
			"product": { 
				"images": {
                    "selected": {
                        "front": {
                            "fr": {
                                "imgid": "1"
                            }
                        },
                        "ingredients": {
							"es": {
                                "imgid": "1",
                                "geometry": {
                                    "angle": 90,
                                    "x1": 10,
                                    "y1": 20,
                                    "x2": 100,
                                    "y2": 200
                                }
                            }
                        }
                    }
                }
			}
		}',
	},
	# {
	# 	test_case => 'post-product-image-select-without-crop',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_crop.pl',
	# 	form => {
	# 		code => "1234567890012",    # Product had an image uploaded in a previous test
	# 		id => "ingredients_es",
	# 		imgid => "1",
	# 	},
	# 	expected_status_code => 200,
	# },
	# {
	# 	test_case => 'post-product-image-crop-imgid-does-not-exist',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_crop.pl',
	# 	form => {
	# 		code => "1234567890012",    # Product had an image uploaded in a previous test
	# 		id => "nutrition_fr",
	# 		imgid => "25",
	# 		angle => 0,
	# 		x1 => 10,
	# 		y1 => 20,
	# 		x2 => 100,
	# 		y2 => 200,
	# 		coordinates_image_size => "full",
	# 	},
	# 	expected_status_code => 200,
	# },
	# {
	# 	test_case => 'post-product-image-crop-missing-image-type',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_crop.pl',
	# 	form => {
	# 		code => "1234567890012",    # Product had an image uploaded in a previous test
	# 		imgid => "1",
	# 	},
	# 	expected_status_code => 200,
	# },
	# {
	# 	test_case => 'post-product-image-crop-invalid-image-type',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_crop.pl',
	# 	form => {
	# 		code => "1234567890012",    # Product had an image uploaded in a previous test
	# 		id => "invalid_image_type_fr",
	# 		imgid => "1",
	# 	},
	# 	expected_status_code => 200,
	# },
	# check we got the images selected
	{
		test_case => 'get-product-image-crop',
		method => 'GET',
		path => '/api/v3.2/product/1234567890012',
		expected_status_code => 200,
	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
