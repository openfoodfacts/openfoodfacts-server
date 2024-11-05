#!/usr/bin/perl -w

# Tests to change the product code or the product type of a product

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%admin_user_form %default_user_form %moderator_user_form/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

# Create an admin
my $admin_ua = new_client();
my $resp = create_user($admin_ua, \%admin_user_form);
ok(!html_displays_error($resp));

# Create a normal user
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
$resp = create_user($ua, \%create_user_args);
ok(!html_displays_error($resp));

# Create a moderator
my $moderator_ua = new_client();
$resp = create_user($moderator_ua, \%moderator_user_form);
ok(!html_displays_error($resp));

# Admin gives moderator status
my %moderator_edit_form = (
	%moderator_user_form,
	user_group_moderator => "1",
	type => "edit",
);
$resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp));

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [

	# Test setup - Create a product
	{
		setup => 1,
		test_case => 'setup-create-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890100',
		body => '{
			"product": {
				"product_name_en": "Test product 1",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Change the barcode
	{
		test_case => 'change-product-code-not-a-moderator',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890100",
			new_code => "1234567890101",
		}
	},
	# Get the product with the initial code
	{
		test_case => 'get-product-with-initial-code',
		method => 'GET',
		path => '/api/v3/product/1234567890100',
		expected_status_code => 200,
	},
	# Change the product with a moderator account
	{
		test_case => 'change-product-code-moderator',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890100",
			new_code => "1234567890102",
		},
		ua => $moderator_ua,
	},
	# Get the product with the new code
	{
		test_case => 'get-product-with-new-code',
		method => 'GET',
		path => '/api/v3/product/1234567890102',
		expected_status_code => 200,
	},
	# Send an invalid product_type
	{
		test_case => 'send-invalid-product-type',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890102",
			product_type => "invalid",
		},
		ua => $moderator_ua,
	},
	# Send product_type=beauty to move product to Open Beauty Facts
	{
		test_case => 'change-product-type-to-beauty',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890102",
			product_type => "beauty",
		},
		ua => $moderator_ua,
	},
	# Get the product with web interface
	{
		test_case => 'get-obf-product-with-web-interface',
		method => 'GET',
		path => '/product/1234567890102',
		expected_status_code => 302,
		expected_type => 'html',
	},
	# Get the product with API v3, no product_type
	{
		test_case => 'get-obf-product-with-api-v3-no-product-type',
		method => 'GET',
		path => '/api/v3/product/1234567890102',
		expected_status_code => 404,
	},
	# Get the product with API v3, with product_type all
	{
		test_case => 'get-obf-product-with-api-v3-no-product-type',
		method => 'GET',
		path => '/api/v3/product/1234567890102?product_type=all',
		expected_status_code => 302,
		expected_type => 'html',
	},	
	# Edit the product with web interface (display the form)
	{
		test_case => 'edit-obf-product-with-web-interface-display-form',
		method => 'GET',
		path => '/cgi/product.pl?type=edit&code=1234567890102',
		expected_status_code => 302,
		expected_type => 'html',
		ua => $ua,
	},
	# Edit the product with web interface (process the form)
	{
		test_case => 'edit-obf-product-with-web-interface-process-form',
		method => 'POST',
		path => '/cgi/product.pl',
		form => {
			type => "edit",
			action => "process",
			code => "1234567890102",
			product_name => "Test product 2 - updated",
		},
		expected_status_code => 302,
		expected_type => 'html',
		ua => $ua,
	},
	# Create a new product
	{
		setup => 1,
		test_case => 'setup-create-product-2',
		method => 'PATCH',
		path => '/api/v3/product/1234567890200',
		body => '{
			"product": {
				"product_name_en": "Test product 2",
				"lang": "en",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Change the product_type field to product
	{
		test_case => 'change-product-type-to-opf',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890200",
			product_type => "product",
		},
		ua => $moderator_ua,
	},
	# Get the product with API v3, without product_type parameter
	{
		test_case => 'get-product-opf-without-product-type',
		method => 'GET',
		path => '/api/v3/product/1234567890200',
		expected_status_code => 404,
	},
	# Get the product with API v3, with a wrong product type
	{
		test_case => 'get-product-opf-with-wrong-product-type',
		method => 'GET',
		path => '/api/v3/product/1234567890200?product_type=off',
		expected_status_code => 404,
	},
	# Get the product with API v3 with the right product type
	{
		test_case => 'get-product-opf-with-right-product-type',
		method => 'GET',
		path => '/api/v3/product/1234567890200?product_type=product',
		expected_status_code => 302,
		expected_type => 'html',
	},
	# Get the product with API v3 with the "all" product_type
	{
		test_case => 'get-product-opf-with-all-product-type',
		method => 'GET',
		path => '/api/v3/product/1234567890200?product_type=all',
		expected_status_code => 302,
		expected_type => 'html',
	},
	# Search all products to check moved products are not on the off MongoDB database anymore
	{
		test_case => 'search-all-products',
		method => 'GET',
		path => '/cgi/search.pl?action=process&json=1&no_cache=1',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
