#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user edit_product execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;

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
			code => '4260392550101',
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
		path => '/api/v3/product/12345678',
		expected_status_code => 404,
	},
	{
		test_case => 'get-existing-product',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-gs1-caret',
		method => 'GET',
		path => '/api/v3/product/%5E0104260392550101',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-gs1-fnc1',
		method => 'GET',
		path => '/api/v3/product/%1D0104260392550101',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-gs1-gs',
		method => 'GET',
		path => '/api/v3/product/%E2%90%9D0104260392550101',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-gs1-ai-data-str',
		method => 'GET',
		path => '/api/v3/product/(01)04260392550101',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-gs1-data-uri',
		method => 'GET',
		path => '/api/v3/product/https%3A%2F%2Fid.gs1.org%2F01%2F04260392550101%2F10%2FABC%2F21%2F123456%3F17%3D211200',
		expected_status_code => 200,
	},
	{
		test_case => 'get-specific-fields',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=product_name,categories_tags,categories_tags_en',
		expected_status_code => 200,
	},
	{
		test_case => 'get-images-to-update',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=images_to_update_en',
		expected_status_code => 200,
	},
	{
		test_case => 'get-attribute-groups',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=attribute_groups',
		expected_status_code => 200,
	},
	{
		test_case => 'get-attribute-groups-fr',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=attribute_groups&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'get-knowledge-panels',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=knowledge_panels',
		expected_status_code => 200,
	},
	{
		test_case => 'get-knowledge-panels-fr',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=knowledge_panels&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'get-packagings',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=packagings',
		expected_status_code => 200,
	},
	{
		test_case => 'get-packagings-fr',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=packagings&tags_lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-raw',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=raw',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-all',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=all',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-all-knowledge-panels',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=all,knowledge_panels',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-attribute-groups-all-knowledge-panels',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=attribute_groups,all,knowledge_panels',
		expected_status_code => 200,
	},
	# Test authentication
	# (currently not needed for READ requests, but it could in the future, for instance to get personalized results)
	{
		test_case => 'get-auth-good-password',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=code,product_name&user_id=tests&password=testtest',
		expected_status_code => 200,
	},
	{
		test_case => 'get-auth-bad-user-password',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=code,product_name&user_id=tests&password=bad_password',
		expected_status_code => 403,
	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
