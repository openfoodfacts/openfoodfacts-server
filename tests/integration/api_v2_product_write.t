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

my $token = get_token_using_password_credentials('tests', '!!!TestTest1!!!')->{access_token};
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
	# Test that we use the language of the interface (lc) for language fields without a language suffix
	{
		test_case => 'post-product-ingredients-text-without-language',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
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
			ingredients_text => "Pork meat, salt",
		}
	},
	{
		test_case => 'get-product-ingredients-text-without-language',
		method => 'GET',
		path => '/api/v2/product/1234567890004',
	},
	# Test authentication
	{
		test_case => 'post-product-auth-good-password',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',
		form => {
			user_id => "tests",
			password => '!!!TestTest1!!!',
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
];

execute_api_tests(__FILE__, $tests_ref, undef, 0);

done_testing();
