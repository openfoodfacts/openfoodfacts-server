#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

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
			lc => "en",
			lang => "en",
			code => '200000000034',
			product_name => "Some product",
			generic_name => "Tester",
			ingredients_text => "apple, milk, eggs, palm oil",
			categories => "cookies",
			labels => "organic",
			origin => "france",
			packaging_text_en =>
				"1 wooden box to recycle, 6 25cl glass bottles to reuse, 3 steel lids to recycle, 1 plastic film to discard",
		)
	},
);

foreach my $product_form_override (@products) {
	edit_product($ua, $product_form_override);
}

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'get-unexisting-product',
		method => 'GET',
		path => '/api/v2/product/12345678',
		expected_status_code => 404,
	},
	{
		test_case => 'get-existing-product',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		expected_status_code => 200,
	},
	{
		test_case => 'get-specific-fields',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=product_name,categories_tags,categories_tags_en',
		expected_status_code => 200,
	},
	{
		test_case => 'get-attribute-groups',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=attribute_groups',
		expected_status_code => 200,
	},
	{
		test_case => 'get-attribute-groups-fr',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=attribute_groups&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'get-knowledge-panels',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=knowledge_panels',
		expected_status_code => 200,
	},
	{
		test_case => 'get-knowledge-panels-fr',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=knowledge_panels&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'get-packagings',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=packagings',
		expected_status_code => 200,
	},
	# test that on v2 tags_lc parameter have no effects
	# packaging part should be exactly the same as get-packagings
	{
		test_case => 'get-packagings-fr',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=packagings&tags_lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-raw',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=raw',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-all',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=all',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-all-knowledge-panels',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=all,knowledge_panels',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-attribute-groups-all-knowledge-panels',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=attribute_groups,all,knowledge_panels',
		expected_status_code => 200,
	},
	# Test authentication
	# (currently not needed for READ requests, but it could in the future, for instance to get personalized results)
	{
		test_case => 'get-auth-good-password',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=code,product_name&user_id=tests&password=' . $test_password,
		expected_status_code => 200,
	},
	# When authentification fails for a v2 request, we return a HTML page
	{
		test_case => 'get-auth-bad-user-password',
		method => 'GET',
		path => '/api/v2/product/200000000034',
		query_string => '?fields=code,product_name&user_id=tests&password=bad_password',
		expected_status_code => 403,
		expected_type => "html",
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
