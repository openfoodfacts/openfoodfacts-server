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
			"tags_lc": "en",
			"product": {
				"product_name_en": "Test product 1",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Change the barcode with API v2, not logged in
	{
		test_case => 'change-product-code-api-v2-not-logged-in',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890100",
			new_code => "1234567890121",
		}
	},
	# Change the product code with API v2, with a normal account,
	{
		test_case => 'change-product-code-api-v2-normal-account',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890100",
			new_code => "1234567890131",
		},
		ua => $ua,
	},
	# Change the product code with a moderator account, invalid code, API v2
	{
		test_case => 'change-product-code-api-v2-moderator-invalid-code',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890100",
			new_code => "some invalid barcode",
		},
		ua => $moderator_ua,
	},
	# Change the product code with a moderator account, API v2
	{
		test_case => 'change-product-code-api-v2-moderator',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890100",
			new_code => "1234567890101",
		},
		ua => $moderator_ua,
	},
	# Get the product with the new code
	{
		test_case => 'get-product-with-new-code',
		method => 'GET',
		path => '/api/v3/product/1234567890101',
		expected_status_code => 200,
	},
	# Change the product code with API v3, not logged in
	{
		test_case => 'change-product-code-api-v3-not-logged-in',
		method => 'PATCH',
		path => '/api/v3/product/1234567890101',
		body => '{
			"tags_lc": "en",
			"product": {
				"code": "1234567890102"
			},
			"fields": "updated"
		}',
		expected_status_code => 403,
	},
	# Change the product code with API v3, with a normal account
	{
		test_case => 'change-product-code-api-v3-normal-account',
		method => 'PATCH',
		path => '/api/v3/product/1234567890101',
		body => '{
			"tags_lc": "en",
			"product": {
				"code": "1234567890104"
			},
			"fields": "updated"
		}',
		ua => $ua,
		expected_status_code => 403,
	},
	# Change the product code with API v3 with a moderator account, to an invalid barcode
	{
		test_case => 'change-product-code-api-v3-moderator-invalid-code',
		method => 'PATCH',
		path => '/api/v3/product/1234567890101',
		body => '{
			"tags_lc": "en",
			"product": {
				"code": "some invalid barcode"
			},
			"fields": "updated"
		}',
		ua => $moderator_ua,
		expected_status_code => 400,
	},
	# Test setup - Create another product
	{
		setup => 1,
		test_case => 'setup-create-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567891234',
		body => '{
			"tags_lc": "en",
			"product": {
				"product_name_en": "Test product 1B",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Change the product code with API v3 with a moderator account, to an existing barcode
	{
		test_case => 'change-product-code-api-v3-moderator-existing-code',
		method => 'PATCH',
		path => '/api/v3/product/1234567890101',
		body => '{
			"tags_lc": "en",
			"product": {
				"code": "1234567891234"
			},
			"fields": "updated"
		}',
		ua => $moderator_ua,
		expected_status_code => 400,
	},
	# Change the product code with API v3, with moderator account, everything good
	{
		test_case => 'change-product-code-api-v3-moderator-valid-code',
		method => 'PATCH',
		path => '/api/v3/product/1234567890101',
		body => '{
			"tags_lc": "en",
			"product": {
				"code": "1234567890102"
			},
			"fields": "updated"
		}',
		ua => $moderator_ua,
	},
	# Send existing product type, normal account
	{
		test_case => 'send-existing-product-type-api-v2-normal-account',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890102",
			product_type => "food",
		},
		ua => $ua,
	},
	# Test setup - Create a product
	{
		setup => 1,
		test_case => 'setup-create-product-b',
		method => 'PATCH',
		path => '/api/v3/product/1234567890202',
		body => '{
			"tags_lc": "en",
			"product": {
				"product_name_en": "Test product 1",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Send product_type=beauty to move product to Open Beauty Facts, normal account
	{
		test_case => 'change-product-type-to-beauty-api-v2-normal-account',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890202",
			product_type => "beauty",
		},
		ua => $ua,
	},
	# Send invalid product type
	{
		test_case => 'change-product-type-to-invalid-api-v2-moderator',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890102",
			product_type => "invalid",
		},
		ua => $moderator_ua,
	},
	# Send null product type
	# 2024/11/21: the OFF app is sending product_type=null for new products
	{
		test_case => 'change-product-type-to-null-api-v2-moderator',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890102",
			product_type => "null",
		},
		ua => $moderator_ua,
	},
	# Send empty string product type
	{
		test_case => 'change-product-type-to-empty-string-api-v2-moderator',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890102",
			product_type => "",
		},
		ua => $moderator_ua,
	},
	# Send product_type=beauty to move product to Open Beauty Facts
	{
		test_case => 'change-product-type-to-beauty-api-v2-moderator',
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
			"tags_lc": "en",
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
	# Get the product with API v2, without product_type parameter
	{
		test_case => 'get-product-opf-without-product-type-api-v2',
		method => 'GET',
		path => '/api/v2/product/1234567890200',
		expected_status_code => 404,
	},
	# Get the product with API v2, with a wrong product type
	{
		test_case => 'get-product-opf-with-wrong-product-type-api-v2',
		method => 'GET',
		path => '/api/v2/product/1234567890200?product_type=food',
		expected_status_code => 404,
	},
	# Get the product with API v2 with the right product type
	{
		test_case => 'get-product-opf-with-right-product-type-api-v2',
		method => 'GET',
		path => '/api/v2/product/1234567890200?product_type=product',
		expected_status_code => 302,
		expected_type => 'html',
	},
	# Get the product with API v2 with the "all" product_type
	{
		test_case => 'get-product-opf-with-all-product-type-api-v2',
		method => 'GET',
		path => '/api/v2/product/1234567890200?product_type=all',
		expected_status_code => 302,
		expected_type => 'html',
	},
	# Get the product with API v3, without product_type parameter
	{
		test_case => 'get-product-opf-without-product-type-api-v3',
		method => 'GET',
		path => '/api/v3/product/1234567890200',
		expected_status_code => 404,
	},
	# Get the product with API v3, with a wrong product type
	{
		test_case => 'get-product-opf-with-wrong-product-type-api-v3',
		method => 'GET',
		path => '/api/v3/product/1234567890200?product_type=food',
		expected_status_code => 404,
	},
	# Get the product with API v3 with the right product type
	{
		test_case => 'get-product-opf-with-right-product-type-api-v3',
		method => 'GET',
		path => '/api/v3/product/1234567890200?product_type=product',
		expected_status_code => 302,
		expected_type => 'html',
	},
	# Get the product with API v3 with the "all" product_type
	{
		test_case => 'get-product-opf-with-all-product-type-api-v3',
		method => 'GET',
		path => '/api/v3/product/1234567890200?product_type=all',
		expected_status_code => 302,
		expected_type => 'html',
	},
	# Create a new product
	{
		setup => 1,
		test_case => 'setup-create-product-3',
		method => 'PATCH',
		path => '/api/v3/product/1234567890300',
		body => '{
			"product": {
				"product_name_en": "Test product 3",
				"lang": "en",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Change the product_name field with API v3
	{
		test_case => 'change-product-name-with-api-v3',
		method => 'PATCH',
		path => '/api/v3/product/1234567890300',
		body => '{
			"product": {
				"product_name_en": "Test product 3 - updated"
			}
		}',
		ua => $moderator_ua,
	},
	# Change the product_type field to invalid product type, with API v3
	{
		test_case => 'change-product-type-to-opff-api-v3-invalid-product-type',
		method => 'PATCH',
		path => '/api/v3/product/1234567890300',
		body => '{
			"tags_lc": "en",
			"product": {
				"product_type": "invalid product type"
			}
		}',
		ua => $moderator_ua,
		expected_status_code => 400,
	},
	# Send existing product type, with API v3, normal account
	{
		test_case => 'send-existing-product-type-api-v3-normal-account',
		method => 'PATCH',
		path => '/api/v3/product/1234567890300',
		body => '{
			"tags_lc": "en",
			"product": {
				"product_type": "food"
			}
		}',
		ua => $ua,
		expected_status_code => 200,
	},
	# Create a new product
	{
		setup => 1,
		test_case => 'setup-create-product-3b',
		method => 'PATCH',
		path => '/api/v3/product/1234567890302',
		body => '{
			"product": {
				"product_name_en": "Test product 3",
				"lang": "en",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Change the product_type field to petfood, with API v3, normal account
	{
		test_case => 'change-product-type-to-opff-api-v3-normal-account',
		method => 'PATCH',
		path => '/api/v3/product/1234567890302',
		body => '{
			"tags_lc": "en",
			"product": {
				"product_type": "petfood"
			}
		}',
		ua => $ua,
	},
	# Change the product_type field to petfood, with API v3, moderator account
	{
		test_case => 'change-product-type-to-opff-api-v3',
		method => 'PATCH',
		path => '/api/v3/product/1234567890300',
		body => '{
			"tags_lc": "en",
			"product": {
				"product_type": "petfood"
			}
		}',
		ua => $moderator_ua,
	},
	# Change the product_name field with API v3 again
	# we have changed the product type, so we should get a redirect request
	{
		test_case => 'change-product-name-of-oppf-product-with-api-v3',
		method => 'PATCH',
		path => '/api/v3/product/1234567890300',
		body => '{
			"tags_lc": "en",
			"product": {
				"product_name_en": "Test product 3 - updated again"
			},
			"fields": "updated"
		}',
		ua => $moderator_ua,
		expected_status_code => 307,
		expected_type => 'html',
	},
	# Get the product with API v3, with product_type eq all
	{
		test_case => 'get-product-opff-with-all-product-type-api-v3',
		method => 'GET',
		path => '/api/v3/product/1234567890300?product_type=all',
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
