#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/create_user execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Auth qw/get_token_using_password_credentials/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $sample_products_images_path = dirname(__FILE__) . "/inputs/upload_images";

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $token = get_token_using_password_credentials('tests', 'testtest')->{access_token};
$log->debug('test token', {token => $token}) if $log->is_debug();

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
	# with new image structure
	{
		test_case => 'get-product-image-new-structure',
		method => 'GET',
		path => '/api/v3.3/product/1234567890012',
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

	# Select / crop images
	{
		test_case => 'post-product-image-crop',
		method => 'POST',
		path => '/cgi/product_image_crop.pl',
		form => {
			code => "1234567890012",    # Product had an image uploaded in a previous test
			id => "ingredients_fr",
			imgid => "1",
			angle => 0,
			x1 => 10,
			y1 => 20,
			x2 => 100,
			y2 => 200,
			coordinates_image_size => "full",
		},
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-select-without-crop',
		method => 'POST',
		path => '/cgi/product_image_crop.pl',
		form => {
			code => "1234567890012",    # Product had an image uploaded in a previous test
			id => "ingredients_es",
			imgid => "1",
		},
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-crop-imgid-does-not-exist',
		method => 'POST',
		path => '/cgi/product_image_crop.pl',
		form => {
			code => "1234567890012",    # Product had an image uploaded in a previous test
			id => "nutrition_fr",
			imgid => "25",
			angle => 0,
			x1 => 10,
			y1 => 20,
			x2 => 100,
			y2 => 200,
			coordinates_image_size => "full",
		},
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-crop-missing-image-type',
		method => 'POST',
		path => '/cgi/product_image_crop.pl',
		form => {
			code => "1234567890012",    # Product had an image uploaded in a previous test
			imgid => "1",
		},
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-crop-invalid-image-type',
		method => 'POST',
		path => '/cgi/product_image_crop.pl',
		form => {
			code => "1234567890012",    # Product had an image uploaded in a previous test
			id => "invalid_image_type_fr",
			imgid => "1",
		},
		expected_status_code => 200,
	},
	# check we got the images selected
	{
		test_case => 'get-product-image-crop',
		method => 'GET',
		path => '/api/v2/product/1234567890012',
		expected_status_code => 200,
	},

	# Keycloak tests
	{
		test_case => 'post-product-image-good-oauth-token',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890017",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/1.jpg", '1.jpg'],
		},
		headers_in => {
			'Authorization' => 'Bearer ' . $token,
		},
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-bad-oauth-token',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890018",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/1.jpg", '1.jpg'],
		},
		headers_in => {
			'Authorization' => 'Bearer 4711',
		},
		expected_status_code => 403,
		expected_type => 'html'
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
