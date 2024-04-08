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
				"product_name_en": "Test product",
				"brands_tags": ["Test brand"],
				"categories_tags": ["en:beverages", "en:teas"],
				"lang": "en",
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Test setup - Update the product
	{
		setup => 1,
		test_case => 'setup-update-product',
		method => 'PATCH',
		path => '/api/v3/product/1234567890100',
		body => '{
			"product": { 
				"product_name_en": "Test product updated",
				"brands_tags": ["Test brand updated"],
				"categories_tags": ["en:coffees"],
				"countries_tags": ["en:france"]
			}
		}',
	},
	# Revert the product - code not supplied
	{
		test_case => 'revert-product-no-code',
		method => 'POST',
		path => '/api/v3/product_revert',
		body => '{
			"rev": 1,
			"fields": "code,rev,product_name_en,brands_tags,categories_tags"
		}',
		ua => $moderator_ua,
		expected_status_code => 400,
	},
	# Revert the product - rev not supplied
	{
		test_case => 'revert-product-no-rev',
		method => 'POST',
		path => '/api/v3/product_revert',
		body => '{
			"code": "1234567890100",
			"fields": "code,rev,product_name_en,brands_tags,categories_tags"
		}',
		ua => $moderator_ua,
		expected_status_code => 400,
	},
	# Revert the product - code does not exist
	{
		test_case => 'revert-product-code-does-not-exist',
		method => 'POST',
		path => '/api/v3/product_revert',
		body => '{
			"code": "5234567890100",
			"rev": 1,
			"fields": "code,rev,product_name_en,brands_tags,categories_tags"
		}',
		ua => $moderator_ua,
		expected_status_code => 404,
	},
	# Revert the product - rev does not exist
	{
		test_case => 'revert-product-rev-does-not-exist',
		method => 'POST',
		path => '/api/v3/product_revert',
		body => '{
			"code": "1234567890100",
			"rev": 5,
			"fields": "code,rev,product_name_en,brands_tags,categories_tags"
		}',
		ua => $moderator_ua,
		expected_status_code => 404,
	},
	# Revert the product - user is not a moderator
	{
		test_case => 'revert-product-user-not-moderator',
		method => 'POST',
		path => '/api/v3/product_revert',
		body => '{
			"code": "1234567890100",
			"rev": 1,
			"fields": "code,rev,product_name_en,brands_tags,categories_tags"
		}',
		expected_status_code => 403,
	},
	# Revert the product - good (existing code and rev + moderator user)
	{
		test_case => 'revert-product-good',
		method => 'POST',
		path => '/api/v3/product_revert',
		body => '{
			"code": "1234567890100",
			"rev": 1,
			"fields": "code,rev,product_name_en,brands_tags,categories_tags"
		}',
		ua => $moderator_ua,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
