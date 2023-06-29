#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

my $sample_products_images_path = dirname(__FILE__) . "/inputs/sample-products-images";

my $tests_ref = [
	{
		test_case => 'post-nonexistent-product-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "nonexistent_product_code",
			imgupload_front_en => ["$sample_products_images_path/300/000/000/0001/1.jpg", '1.jpg'],
		}
	},
	{
		test_case => 'get-nonexistent-product-image',
		method => 'GET',
		path => '/api/v2/product/nonexistent_product_code',
	},
	{
		test_case => 'post-existing-product-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890012",
			imgupload_front_en => ["$sample_products_images_path/300/000/000/0001/front_en.3.full.jpg", 'front_en.3.full.jpg'],
		}
	},
	{
		test_case => 'get-existing-product-image',
		method => 'GET',
		path => '/api/v2/product/1234567890012',
	},
	{
		test_case => 'post-image-too-small',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890013",
			imgupload_front_en => ["$sample_products_images_path/small-img.jpg", 'small-img.jpg'],
		}
	},
	{
		test_case => 'get-image-too-small',
		method => 'GET',
		path => '/api/v2/product/1234567890013',
		expected_status_code => 404,
	},
	{
		test_case => 'post-same-image-twice',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890014",
			imgupload_front_en => ["$sample_products_images_path/300/000/000/0001/front_en.3.full.jpg", 'front_en.3.full.jpg'],
		}
	},
	{
		test_case => 'get-same-image-twice',
		method => 'GET',
		path => '/api/v2/product/1234567890014',
		expected_status_code => 404,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
