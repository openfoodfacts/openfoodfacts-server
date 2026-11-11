#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/construct_test_url create_user execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/get_base64_image_data_from_file remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Auth qw/get_token_using_password_credentials/;
use ProductOpener::Products qw/product_path_from_id/;
use ProductOpener::Store qw/retrieve_object/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use JSON::MaybeXS qw/encode_json/;
use Encode qw/encode/;

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

subtest 'upload with non-ASCII comment (CGI)' => sub {
	my $code = '1234567890019';
	my $comment = 'slovenščina photo upload';
	my $response = $ua->post(
		construct_test_url('/cgi/product_image_upload.pl'),
		Content_Type => 'form-data',
		Content => [
			code => $code,
			imagefield => 'other_en',
			comment => encode('UTF-8', $comment),
			imgupload_other_en => ["$sample_products_images_path/pulses-cereals.jpg", 'pulses-cereals.jpg'],
		],
	);
	is($response->code, 200, 'CGI image upload with non-ASCII comment succeeds');

	my $path = product_path_from_id($code);
	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes") // [];
	ok(@{$changes_ref} > 0, 'product has changes recorded');
	my ($upload_change) = grep {$_->{comment} =~ /^new image 1 /} @{$changes_ref};
	ok($upload_change, 'found upload change entry');
	like($upload_change->{comment}, qr/slovenščina photo upload/,
		'upload change comment contains decoded UTF-8 string');
};

subtest 'upload with non-ASCII comment (API v3)' => sub {
	my $code = '1234567890020';
	my $comment = 'slovenščina API upload';
	my $response = $ua->post(
		construct_test_url("/api/v3/product/$code/images"),
		'Content-Type' => 'application/json',
		Content => encode_json(
			{
				image_data_base64 => get_base64_image_data_from_file("$sample_products_images_path/pulses-cereals.jpg"),
				comment => $comment,
			}
		),
	);
	is($response->code, 200, 'API v3 image upload with non-ASCII comment succeeds');

	my $path = product_path_from_id($code);
	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes") // [];
	ok(@{$changes_ref} > 0, 'product has changes recorded');
	my ($api_upload_change) = grep {$_->{comment} =~ /^new image 1 /} @{$changes_ref};
	ok($api_upload_change, 'found upload change entry');
	like(
		$api_upload_change->{comment},
		qr/slovenščina API upload/,
		'upload change comment contains decoded UTF-8 comment'
	);
};

done_testing();
