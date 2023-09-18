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

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'post-product',
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
		}
	},
	{
		test_case => 'get-product',
		method => 'GET',
		path => '/api/v2/product/1234567890001',
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
		}
	},
	{
		test_case => 'get-product-ingredients-text-without-language',
		method => 'GET',
		path => '/api/v2/product/1234567890004',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
