#!/usr/bin/perl -w

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
	# Send code=obf to move product to Open Beauty Facts
	{
		test_case => 'change-product-code-to-obf',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890102",
			new_code => "obf",
		},
		ua => $moderator_ua,
	},
	# Get the product
	{
		test_case => 'get-product-obf',
		method => 'GET',
		path => '/api/v3/product/1234567890102',
		expected_status_code => 200,
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
	# Change the product_type field to opf
	{
		test_case => 'change-product-type-to-opf',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			code => "1234567890200",
			new_code => "opf",
		},
		ua => $moderator_ua,
	},
	# Get the product
	{
		test_case => 'get-product-opf',
		method => 'GET',
		path => '/api/v3/product/1234567890200',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
