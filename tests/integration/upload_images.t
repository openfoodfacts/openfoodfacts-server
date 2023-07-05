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
	# TODO: add tests for:
	# - missing imagefield
	# - missing corresponding imgupload_[imagefield]
	# - too small image
	# - image already uploaded
	# -> use a different barcode for each test
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
