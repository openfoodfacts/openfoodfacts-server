#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user edit_product execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;

use File::Basename "dirname";

use Storable qw(dclone);

use ProductOpener::Cache qw/$memd/;
# We need to flush memcached so that cached queries from other tests (e.g. web_html.t) don't interfere with this test
$memd->flush_all;

wait_application_ready();

remove_all_users();

remove_all_products();

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
		path => '/facets/countries/france',
		expected_status_code => 200,
		expected_type => 'html',
	},
	{
		test_case => 'country-cambodia-exists-but-empty',
		method => 'GET',
		path => '/facets/countries/cambodia',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'cambodia',
	},
	{
		test_case => 'country-doesnotexist',
		method => 'GET',
		path => '/facets/countries/doesnotexist',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'doesnotexist',
	},
	{
		test_case => 'ingredient-apple-exists',
		method => 'GET',
		path => '/facets/ingredients/apple',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'apple',
	},
	{
		test_case => 'ingredient-someunknowningredient-does-not-exist-but-not-empty',
		method => 'GET',
		path => '/facets/ingredients/someunknowningredient',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'someunknowningredient',
	},
	{
		test_case => 'ingredient-someunknownandemptyingredient-does-not-exist-and-empty',
		method => 'GET',
		path => '/facets/ingredients/someunknownandemptyingredient',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'someunknownandemptyingredient',
	},
	{
		test_case => 'country-doesnotexist-ingredients-apple',
		method => 'GET',
		path => '/facets/countries/doesnotexist/ingredients/apple',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'doesnotexist',
	},
	{
		test_case => 'country-doesnotexist-ingredients',
		method => 'GET',
		path => '/facets/countries/doesnotexist/ingredients',
		expected_status_code => 404,
		expected_type => 'html',
		response_content_must_not_match => 'doesnotexist',
	},
	{
		test_case => 'ingredient-someunknowningredient-does-not-exist-but-not-empty-labels',
		method => 'GET',
		# we need &no_cache=1 in order to get results (otherwise we use the query service)
		path => '/facets/ingredients/someunknowningredient/labels&no_cache=1',
		expected_status_code => 200,
		expected_type => 'html',
		response_content_must_match => 'someunknowningredient',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
