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

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $token = get_token_using_password_credentials('tests', 'testtest')->{access_token};
$log->debug('test token', {token => $token}) if $log->is_debug();

my $tests_ref = [
	# Product not created yet, creating an empty product for the code
	{
		test_case => 'post-product-search-or-add',
		method => 'POST',
		path => '/cgi/product_multilingual.pl',
		form => {
			user_id => "tests",
			password => "testtest",
			action => "process",
			type => "search_or_add",
			code => "1234567890012",
			lang => "en",
		},
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'get-product-search-or-add',
		method => 'GET',
		path => '/api/v3.6/product/1234567890012',
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-no-nutrition-data-on',
		method => 'POST',
		path => '/cgi/product_multilingual.pl',
		form => {
			user_id => "tests",
			password => "testtest",
			action => "process",
			type => "edit",
			code => "1234567890012",
			lang => "en",
			product_name_en => "English product name",
			product_name_fr => "Nom du produit en français",
			categories => "Breakfast cereals",
			labels => "Organic, Gluten-Free",
			no_nutrition_data => "on",
		},
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'get-product-no-nutrition-data-on',
		method => 'GET',
		path => '/api/v3.6/product/1234567890012',
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-no-nutrition-data-off',
		method => 'POST',
		path => '/cgi/product_multilingual.pl',
		form => {
			user_id => "tests",
			password => "testtest",
			action => "process",
			type => "edit",
			code => "1234567890012",
			lang => "en",
			product_name_en => "English product name updated",
			product_name_fr => "Nom du produit en français mis à jour",
			# Not sending categories, changing labels
			labels => "Fair Trade",
			# no_nutrition_data not sent, so it is off
			no_nutrition_data_displayed => 1,    # to indicate the checkbox was displayed
		},
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'get-product-no-nutrition-data-off',
		method => 'GET',
		path => '/api/v3.6/product/1234567890012',
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-add-nutrition',
		method => 'POST',
		path => '/cgi/product_multilingual.pl',
		form => {
			user_id => "tests",
			password => "testtest",
			action => "process",
			type => "edit",
			code => "1234567890012",
			lang => "en",
			serving_size => "30 g",
			"nutrition_input_sets_as_sold_100g_nutrients_saturated-fat_value_string" => "5.0",
			"nutrition_input_sets_as_sold_100g_nutrients_saturated-fat_unit" => "g",
			"nutrition_input_sets_prepared_serving_nutrients_salt_value_string" => "50",
			"nutrition_input_sets_prepared_serving_nutrients_salt_unit" => "mg",
		},
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'get-product-add-nutrition',
		method => 'GET',
		path => '/api/v3.6/product/1234567890012',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
