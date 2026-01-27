#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Log::Any qw($log);

use ProductOpener::APITest qw/create_user_in_keycloak execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Auth qw/get_token_using_password_credentials/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user_in_keycloak(\%create_user_args);

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
	# should get nutrition.no_nutrition_data_on_packaging = true
	{
		test_case => 'get-product-nutrition-no_nutrition_data-on-api-v3-6',
		method => 'GET',
		path => '/api/v3.6/product/1234567890007',
	},
	# should get no_nutrition_data = on (schema downgrade)
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
	# API v2 will get the nutrition data in the old nutriments structure
	{
		test_case => 'get-product-nutrition-nutrition_data_per-100g',
		method => 'GET',
		path => '/api/v2/product/1234567890008',
	},
	# Get the new nutrition schema
	{
		test_case => 'get-product-nutrition-nutrition_data_per-100g-v3',
		method => 'GET',
		path => '/api/v3.5/product/1234567890008',
	},
	# Removing a value
	{
		test_case => 'post-product-nutrition-old-fields-nutrition_data_per-100g-remove-value',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "1234567890008",
			product_name_en => "Test old nutrition fields - remove value",
			nutrition_data_per => '100g',
			# will not work as the client should pass energy-kj or energy-kcal
			nutriment_energy => '',
			nutriment_fat => '',
			nutriment_salt => '',
		}
	},
	{
		test_case => 'get-product-nutrition-nutrition_data_per-100g-remove-value-v3',
		method => 'GET',
		path => '/api/v3.5/product/1234567890008',
	},
	# Set some values per serving
	{
		test_case => 'post-product-nutrition-old-fields-nutrition_data_per-serving',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "1234567890008",
			product_name_en => "Test old nutrition fields - per serving",
			nutrition_data_per => 'serving',
			serving_size => '10g',
			nutriment_energy => '5',
			nutriment_energy_unit => 'kcal',
			# We pass the fat that has been removed for the per 100g
			# it should be used in the aggregated set
			nutriment_fat => '2',
			nutriment_fat_unit => 'g',
		}
	},
	{
		test_case => 'get-product-nutrition-nutrition_data_per-serving-v3',
		method => 'GET',
		path => '/api/v3.5/product/1234567890008',
	},
	# Test modifiers
	{
		test_case => 'post-product-nutrition-old-fields-nutrition_data_per-100g-modifiers',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "1234567890009",
			product_name_en => "Test old nutrition fields - modifiers",
			nutrition_data_per => '100g',
			nutriment_energy => '<450',
			nutriment_energy_unit => 'kJ',
			nutriment_fat => '~12.5',
			nutriment_fat_unit => 'g',
			"nutriment_saturated-fat" => '> 3.1',
			"nutriment_saturated-fat_unit" => 'g',
			nutriment_carbohydrates => '67.4',
			nutriment_carbohydrates_unit => 'g',
			# - is accepted as a value to indicate that the value is not specified
			nutriment_fiber => '-',
			# empty value: used to remove an existing value, no effect if it's not there
			nutriment_proteins => '',
			nutriment_proteins_unit => 'g',
			nutriment_salt => '<=1.2',
			nutriment_salt_unit => 'g',
			nutriment_sodium => '≤0.472',
			nutriment_sodium_unit => 'g',
			nutriment_alcohol => '0.0',
			nutriment_alcohol_unit => 'g',
			nutriment_water => '10.0',
			nutriment_water_unit => 'g',
		}
	},
	{
		test_case => 'get-product-nutrition-nutrition_data_per-100g-modifiers-v3',
		method => 'GET',
		path => '/api/v3.5/product/1234567890009',
	},
	# Test values with different formatting
	{
		test_case => 'post-product-nutrition-old-fields-nutrition_data_per-100g-formatting',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "1234567890010",
			product_name_en => "Test old nutrition fields - formatting",
			nutrition_data_per => '100g',
			nutriment_energy => ' 450 ',    # extra spaces
			nutriment_energy_unit => ' kJ ',
			nutriment_fat => '12,5',    # comma as decimal separator
			nutriment_fat_unit => ' g ',    # extra spaces
			"nutriment_saturated-fat" => ' 3.1 ',
			"nutriment_saturated-fat_unit" => 'G',    # uppercase unit
			nutriment_carbohydrates => '0,008',
			nutriment_carbohydrates_unit => 'KG',
			nutriment_fiber => '~0',
			nutriment_fiber_unit => 'g',
			nutriment_proteins => '8.2000',
			nutriment_proteins_unit => 'g',
			nutriment_salt => ' 1.2 ',
			nutriment_salt_unit => ' g ',
			nutriment_sodium => ' 0.472 ',
			nutriment_sodium_unit => ' g ',
			nutriment_alcohol => ' 0.0 ',
			nutriment_alcohol_unit => ' g ',
			nutriment_water => ' 10.0 ',
			nutriment_water_unit => ' g ',
		}
	},
	{
		test_case => 'get-product-nutrition-nutrition_data_per-100g-formatting-v3',
		method => 'GET',
		path => '/api/v3.5/product/1234567890010',
	},

	# Nutrition facts - new fields for new nutrition schema (October 2025)
	#
	# nutrient values and units are passed for the different input sets (for each preparation type and for each per quantity)
	# with parameters like:
	#
	# nutrition_input_sets_prepared_100ml_nutrients_saturated-fat_value_string
	# nutrition_input_sets_prepared_100ml_nutrients_saturated-fat_unit

	{
		test_case => 'post-product-nutrition-new-fields-nutrition_data_per-100g',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => 'testtest',
			code => "2234567890001",
			product_name_en => "Test new nutrition fields",
			# As sold per 100g
			nutrition_input_sets_regular_100g_nutrients_energy_value_string => '450',
			nutrition_input_sets_regular_100g_nutrients_energy_unit => 'kJ',
			nutrition_input_sets_regular_100g_nutrients_fat_value_string => '12.5',
			nutrition_input_sets_regular_100g_nutrients_fat_unit => 'g',
			"nutrition_input_sets_regular_100g_nutrients_saturated-fat_value_string" => '3.1',
			"nutrition_input_sets_regular_100g_nutrients_saturated-fat_unit" => 'g',
			nutrition_input_sets_regular_100g_nutrients_carbohydrates_value_string => '67.4',
			nutrition_input_sets_regular_100g_nutrients_carbohydrates_unit => 'g',
			# Test a string value with a 0 after the decimal point
			nutrition_input_sets_regular_100g_nutrients_fiber_value_string => '4.0',
			nutrition_input_sets_regular_100g_nutrients_fiber_unit => 'g',
			nutrition_input_sets_regular_100g_nutrients_proteins_value_string => '8.2',
			nutrition_input_sets_regular_100g_nutrients_proteins_unit => 'g',
			nutrition_input_sets_regular_100g_nutrients_salt_value_string => '1.2',
			nutrition_input_sets_regular_100g_nutrients_salt_unit => 'g',
			nutrition_input_sets_regular_100g_nutrients_sodium_value_string => '0.472',
			nutrition_input_sets_regular_100g_nutrients_sodium_unit => 'g',
			nutrition_input_sets_regular_100g_nutrients_alcohol_value_string => '0.0',
			nutrition_input_sets_regular_100g_nutrients_alcohol_unit => 'g',
			nutrition_input_sets_regular_100g_nutrients_water_value_string => '10.0',
			nutrition_input_sets_regular_100g_nutrients_water_unit => 'g',
			# Prepared per 100g
			nutrition_input_sets_prepared_100g_nutrients_energy_value_string => '400',
			nutrition_input_sets_prepared_100g_nutrients_energy_unit => 'kJ',
			nutrition_input_sets_prepared_100g_nutrients_fat_value_string => '10.5',
			nutrition_input_sets_prepared_100g_nutrients_fat_unit => 'g',
		}
	},
	# Get the new nutrition schema
	{
		test_case => 'get-product-nutrition-new-fields-nutrition_data_per-100g-v3',
		method => 'GET',
		path => '/api/v3.5/product/2234567890001',
	},
];

execute_api_tests(__FILE__, $tests_ref, undef, 0);

done_testing();
