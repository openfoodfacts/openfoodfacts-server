#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

remove_all_users();

remove_all_products();

my $sample_products_images_path = dirname(__FILE__) . "/inputs/upload_images";

my $tests_ref = [
	{
		test_case => 'post-product-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890012",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/1.jpg", '1.jpg'],
		},
		expected_status_code => 200,
	},
	{
		test_case => 'get-product-image',
		method => 'GET',
		path => '/api/v2/product/1234567890012',
		expected_status_code => 200,
	},
	{
		test_case => 'post-image-too-small',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890013",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/small-img.jpg", 'small-img.jpg'],
		},
		expected_status_code => 200,
	},
	{
		test_case => 'get-image-too-small',
		method => 'GET',
		path => '/api/v2/product/1234567890013',
		expected_status_code => 200,

	},
	{
		test_case => 'post-same-image-twice',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890014",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/front_en.3.full.jpg", 'front_en.3.full.jpg'],
		},
		expected_status_code => 200,
	},
	{
		test_case => 'post-same-image-twice-duplicate',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890014",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/front_en.3.full.jpg", 'front_en.3.full.jpg'],
		},
		expected_status_code => 200,

	},
	{
		test_case => 'get-same-image-twice',
		method => 'GET',
		path => '/api/v2/product/1234567890014',
		expected_status_code => 200,

	},
	{
		test_case => 'post-missing-imagefield',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890015",
			imgupload_front_en => ["$sample_products_images_path/1.jpg", '1.jpg'],
		},
		expected_status_code => 200,
	},
	{
		test_case => 'get-missing-imagefield',
		method => 'GET',
		path => '/api/v2/product/1234567890015',
		expected_status_code => 404,
	},
	{
		test_case => 'post-missing-imgupload_[imagefield]',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890016",
			imagefield => "front_en",
		},
		expected_status_code => 200,
	},
	{
		test_case => 'get-missing-imgupload_[imagefield]',
		method => 'GET',
		path => '/api/v2/product/1234567890016',
		expected_status_code => 200,

	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
