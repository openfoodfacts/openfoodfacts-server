#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/create_user execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Auth qw/get_token_using_password_credentials/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

remove_all_users();

remove_all_products();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $token = get_token_using_password_credentials('tests', 'testtest')->{access_token};
$log->debug('test token', {token => $token}) if $log->is_debug();

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	# Test anonymous contribution, this should fail
	{
		# it will fail with code 200
		# but failure message is in the expected result json
		test_case => 'post-product-anonymous',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			cc => "be",
			lc => "fr",
			code => "1234567890001",
			product_name => "Product name",
			categories => "Cookies",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '50.2',
			nutriment_salt_unit => 'mg',
			nutriment_sugars => '12.5',
		},
	},
	{
		test_case => 'get-product-anonymous',
		method => 'GET',
		path => '/api/v2/product/1234567890001',
		expected_status_code => 404,
	},
	# Test authentication
	{
		test_case => 'post-product-auth-good-password',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => "testtest",
			cc => "be",
			lc => "fr",
			code => "1234567890002",
			product_name => "Product name",
			categories => "Cookies",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '50.2',
			nutriment_salt_unit => 'mg',
			nutriment_sugars => '12.5',
		}
	},
	# Test authentication - OAuth token
	{
		test_case => 'post-product-oauth-token',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			cc => "be",
			lc => "fr",
			code => "1234567890005",
			product_name => "Product name",
			categories => "Cookies",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '50.2',
			nutriment_salt_unit => 'mg',
			nutriment_sugars => '12.5',
		},
		headers_in => {
			'Authorization' => 'Bearer ' . $token,
		},
	},
	{
		test_case => 'get-product-auth-good-password',
		method => 'GET',
		path => '/api/v2/product/1234567890002',
	},
	{
		test_case => 'post-product-auth-bad-user-password',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => "bad password",
			cc => "be",
			lc => "fr",
			code => "1234567890003",
			product_name => "Product name",
			categories => "Cookies",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '50.2',
			nutriment_salt_unit => 'mg',
			nutriment_sugars => '12.5',
		},
		expected_type => "html",
		expected_status_code => 403,
	},
	{
		test_case => 'get-product-auth-bad-user-password',
		method => 'GET',
		path => '/api/v2/product/1234567890003',
		expected_status_code => 404,
	},
	# Test that we use the language of the interface (lc) for language fields without a language suffix
	{
		test_case => 'post-product-ingredients-text-without-language',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			cc => "uk",
			lc => "en",    # lc is the language of the interface
			lang => "fr",    # lang is the main language of the product
			code => "1234567890004",
			product_name => "Some sausages"
			, # product_name does not have a language suffix, so it is assumed to be in the language of the interface (lc = "en")
			categories => "Sausages",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text => "Pork meat, salt",
			traces => "Moutarde, milk, abcd",
		}
	},
	{
		test_case => 'get-product-ingredients-text-without-language',
		method => 'GET',
		path => '/api/v2/product/1234567890004',
	},
	{
		test_case => 'post-product-auth-bad-oauth-token',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			cc => "be",
			lc => "fr",
			code => "1234567890006",
			product_name => "Product name",
			categories => "Cookies",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '50.2',
			nutriment_salt_unit => 'mg',
			nutriment_sugars => '12.5',
		},
		headers_in => {
			'Authorization' => 'Bearer 4711',
		},
		expected_type => "html",
		expected_status_code => 403,
	},
	# Nutrition facts: test that we provide backward compatibility for the old field names
	# that were used before we restructured the nutrition data in 2025.

# From the documentation (ref-cheatsheet.md)
# 
# ### Indicate the absence of nutrition facts

# ```text
# no_nutrition_data=on (indicates if the nutrition facts are not indicated on the food label)
# ```

# ### Add nutrition facts values, units and base

# ```text
# nutrition_data_per=100g

# OR

# nutrition_data_per=serving
# serving_size=38g
# ```

# ```text
# nutriment_energy=450
# nutriment_energy_unit=kJ
# ```

# ### Adding values to a field that is already filled

# > You just have to prefix `add_` before the name of the field

# ```text
# add_categories
# add_labels
# add_brands
# ```

# ### Adding nutrition facts for the prepared product
# You can send prepared nutritional values
# * nutriment_energy-kj (regular)
# * nutriment_energy-kj_prepared (prepared)


	{
		test_case => 'post-product-nutrition-no_nutrition_data-on',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "1234567890007",
			product_name_en => "Test no_nutrition_data on",
			no_nutrition_data => 'on',
		}
	},
	{
		test_case => 'get-product-nutrition-no_nutrition_data-on',
		method => 'GET',
		path => '/api/v2/product/1234567890007',
	},
	{
		test_case => 'post-product-nutrition-no_nutrition_data-empty',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "1234567890007",
			product_name_en => "Test no_nutrition_data empty",
			no_nutrition_data => '',
		}
	},
	{
		test_case => 'get-product-nutrition-no_nutrition_data-empty',
		method => 'GET',
		path => '/api/v2/product/1234567890007',
	},
	# Old fields for nutrition facts
	{
		test_case => 'post-product-nutrition-old-fields-nutrition_data_per-100g',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "1234567890008",
			product_name_en => "Test old nutrition fields",
			nutrition_data_per => '100g',
			nutriment_energy => '450',
			nutriment_energy_unit => 'kJ',
			nutriment_fat => '12.5',
			nutriment_fat_unit => 'g',
			"nutriment_saturated-fat" => '3.1',
			"nutriment_saturated-fat_unit" => 'g',
			nutriment_carbohydrates => '67.4',
			nutriment_carbohydrates_unit => 'g',
			nutriment_fiber => '4.5',
			nutriment_fiber_unit => 'g',
			nutriment_proteins => '8.2',
			nutriment_proteins_unit => 'g',
			nutriment_salt => '1.2',
			nutriment_salt_unit => 'g',
			nutriment_sodium => '0.472',
			nutriment_sodium_unit => 'g',
			nutriment_alcohol => '0.0',
			nutriment_alcohol_unit => 'g',
			nutriment_water => '10.0',
			nutriment_water_unit => 'g',
		}
	},
	{
		test_case => 'get-product-nutrition-nutrition_data_per-100g',
		method => 'GET',
		path => '/api/v2/product/1234567890008',
	},

];

execute_api_tests(__FILE__, $tests_ref, undef, 0);

done_testing();
