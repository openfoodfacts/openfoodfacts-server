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

# Create some products

my @products = (

	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000034',
			product_name => "test",
			ingredients_text => "apple, someunknowningredient",
			countries => "france",
			labels => "organic",
		)
	},

);

foreach my $product_ref (@products) {
	edit_product($ua, $product_ref);
}

# Verify that we get back a 404 error for inexisting tags with 0 products

my $tests_ref = [
	{
		test_case => 'unknown-product',
		method => 'GET',
		path => '/product/321342143242343243423',
		expected_status_code => 404,
		expected_type => 'html',
	},
	{
		test_case => 'country-france-exists',
		method => 'GET',
		path => '/country/france',
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'country-cambodia-exists-but-empty',
		method => 'GET',
		path => '/country/cambodia',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'cambodia',
	},
	{
		test_case => 'country-doesnotexist',
		method => 'GET',
		path => '/country/doesnotexist',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'doesnotexist',
	},
	{
		test_case => 'ingredient-apple-exists',
		method => 'GET',
		path => '/ingredient/apple',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'apple',
	},
	{
		test_case => 'ingredient-someunknowningredient-does-not-exist-but-not-empty',
		method => 'GET',
		path => '/ingredient/someunknowningredient',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'someunknowningredient',
	},
	{
		test_case => 'ingredient-someunknownandemptyingredient-does-not-exist-and-empty',
		method => 'GET',
		path => '/ingredient/someunknownandemptyingredient',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'someunknownandemptyingredient',
	},
	{
		test_case => 'country-doesnotexist-ingredients-apple',
		method => 'GET',
		path => '/country/doesnotexist/ingredient/apple',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'doesnotexist',
	},
	{
		test_case => 'country-doesnotexist-ingredients',
		method => 'GET',
		path => '/country/doesnotexist/ingredients',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'doesnotexist',
	},
	{
		test_case => 'ingredient-someunknowningredient-does-not-exist-but-not-empty-labels',
		method => 'GET',
		# we need &no_cache=1 in order to get results (otherwise we use the query service)
		path => '/ingredient/someunknowningredient/labels&no_cache=1',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'someunknowningredient',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
