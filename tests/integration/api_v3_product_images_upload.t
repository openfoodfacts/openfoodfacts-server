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
	{
		test_case => 'get-product-image',
		method => 'GET',
		path => '/api/v3.3/product/1234567890012',
		expected_status_code => 200,
	},
	# {
	# 	test_case => 'post-image-too-small',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_upload.pl',
	# 	form => {
	# 		code => "1234567890013",
	# 		imagefield => "front_en",
	# 		imgupload_front_en => ["$sample_products_images_path/small-img.jpg", 'small-img.jpg'],
	# 	},
	# 	expected_status_code => 200,
	# },
	# {
	# 	test_case => 'get-image-too-small',
	# 	method => 'GET',
	# 	path => '/api/v2/product/1234567890013',
	# 	expected_status_code => 200,

	# },
	# {
	# 	test_case => 'post-same-image-twice',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_upload.pl',
	# 	form => {
	# 		code => "1234567890014",
	# 		imagefield => "front_en",
	# 		imgupload_front_en => ["$sample_products_images_path/front_en.3.full.jpg", 'front_en.3.full.jpg'],
	# 	},
	# 	expected_status_code => 200,
	# },
	# {
	# 	test_case => 'post-same-image-twice-duplicate',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_upload.pl',
	# 	form => {
	# 		code => "1234567890014",
	# 		imagefield => "front_en",
	# 		imgupload_front_en => ["$sample_products_images_path/front_en.3.full.jpg", 'front_en.3.full.jpg'],
	# 	},
	# 	expected_status_code => 200,

	# },
	# {
	# 	test_case => 'get-same-image-twice',
	# 	method => 'GET',
	# 	path => '/api/v2/product/1234567890014',
	# 	expected_status_code => 200,

	# },
	# {
	# 	test_case => 'post-missing-imagefield',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_upload.pl',
	# 	form => {
	# 		code => "1234567890015",
	# 		imgupload_front_en => ["$sample_products_images_path/1.jpg", '1.jpg'],
	# 	},
	# 	expected_status_code => 200,
	# },
	# {
	# 	test_case => 'get-missing-imagefield',
	# 	method => 'GET',
	# 	path => '/api/v2/product/1234567890015',
	# 	expected_status_code => 404,
	# },
	# {
	# 	test_case => 'post-missing-imgupload_[imagefield]',
	# 	method => 'POST',
	# 	path => '/cgi/product_image_upload.pl',
	# 	form => {
	# 		code => "1234567890016",
	# 		imagefield => "front_en",
	# 	},
	# 	expected_status_code => 200,
	# },
	# {
	# 	test_case => 'get-missing-imgupload_[imagefield]',
	# 	method => 'GET',
	# 	path => '/api/v2/product/1234567890016',
	# 	expected_status_code => 200,

	# },

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
