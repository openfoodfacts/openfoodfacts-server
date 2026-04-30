#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user edit_product execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

# Create some products

my @products = (
	{
		# this product has less than 95% ingredients with nutrition data, so nutrients won't be estimated
		%{dclone(\%default_product_form)},
		(
			code => '4260392550101',
			origin => "france",
			packaging_text_en =>
				"1 wooden box to recycle, 6 25cl glass bottles to reuse, 3 steel lids to recycle, 1 plastic film to discard",
			nutriment_salt => '50.2',
			nutriment_salt_unit => 'mg',
			nutriment_sugars => '12.5',
			"nutriment_saturated-fat" => '5.6',
			nutriment_fiber => 2,
			"nutriment_energy-kj" => 400,
			nutriment_proteins => 4.5,
			nutriment_carbohydrates => 10.5,
			nutriment_fat => 8.5,
		)
	},
	# product with 100% of ingredients with nutrition data, so nutrients will be estimated
	{
		%{dclone(\%default_product_form)},
		(
			lc => "en",
			lang => "en",
			code => '200000000035',
			product_name => "Some product 2 with all ingredients having nutrition data",
			generic_name => "Tester 2",
			ingredients_text => "milk, eggs, sugar",
			categories => "cookies",
			nutriment_salt => '50.2',
			nutriment_salt_unit => 'mg',
			nutriment_sugars => '12.5',
			"nutriment_saturated-fat" => '5.6',
			nutriment_fiber => 2,
			"nutriment_energy-kj" => 400,
			nutriment_proteins => 4.5,
			nutriment_carbohydrates => 10.5,
			nutriment_fat => 8.5,
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
		test_case => 'get-existing-product-api-v3-1',
		method => 'GET',
		path => '/api/v3.1/product/4260392550101',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-with-leading-zero',
		method => 'GET',
		path => '/api/v3/product/04260392550101',
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
	# in API 3.1 ecoscore fields are renamed to environmental_score
	{
		test_case => 'get-specific-fields-ecoscore-api-v3',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=ecoscore_score,ecoscore_grade,ecoscore_data',
		expected_status_code => 200,
	},
	{
		test_case => 'get-specific-fields-ecoscore-api-v3-1',
		method => 'GET',
		path => '/api/v3.1/product/4260392550101',
		query_string => '?fields=ecoscore_score,ecoscore_grade,ecoscore_data',
		expected_status_code => 200,
	},
	{
		test_case => 'get-specific-fields-environmental-score-api-v3',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=environmental_score_score,environmental_score_grade,environmental_score_data',
		expected_status_code => 200,
	},
	{
		test_case => 'get-specific-fields-environmental-score-api-v3-1',
		method => 'GET',
		path => '/api/v3.1/product/4260392550101',
		query_string => '?fields=environmental_score_score,environmental_score_grade,environmental_score_data',
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
		test_case => 'get-attribute-groups-api-v3-1',
		method => 'GET',
		path => '/api/v3.1/product/4260392550101',
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
	{
		test_case => 'get-fields-knowledge-panels-knowledge-panels_included-health_card-environment_card',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=knowledge_panels&knowledge_panels_included=health_card,environment_card',
		expected_status_code => 200,
	},
	{
		test_case => 'get-fields-knowledge-panels-knowledge-panels_excluded-environment_card',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=knowledge_panels&knowledge_panels_excluded=environment_card',
		expected_status_code => 200,
	},
	{
		test_case =>
			'get-fields-knowledge-panels-knowledge-panels_included-health_card-environment_card-knowledge_panels_excluded-health_card',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string =>
			'?fields=knowledge_panels&knowledge_panels_included=health_card,environment_card&knowledge_panels_excluded=health_card',
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
	{
		test_case => 'get-specific-fields-environmental-score-api-v3-1',
		method => 'GET',
		path => '/api/v3.1/product/4260392550101',
		query_string => '?fields=environmental_score_score,environmental_score_grade,environmental_score_data',
		expected_status_code => 200,
	},

	# Get attributes with unwanted_ingredients using a cookie
	{
		test_case => 'get-attributes-unwanted-ingredients-milk',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=attribute_groups',
		cookies => [{name => "attribute_unwanted_ingredients_tags", value => "en:milk,en:chocolate"}],
		expected_status_code => 200,
	},
	# Get attributes with unwanted_ingredients using a query parameter
	{
		test_case => 'get-attributes-unwanted-ingredients-milk-query-param',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=attribute_groups&attribute_unwanted_ingredients_tags=en:milk,en:chocolate',
		expected_status_code => 200,
	},

	# Get simplified knowledge panels
	{
		test_case => 'get-knowledge-panels-simplified',
		method => 'GET',
		path => '/api/v3/product/4260392550101',
		query_string => '?fields=knowledge_panels&activate_knowledge_panels_simplified=true',
		expected_status_code => 200,
	},
	# v3.5 new nutrition schema
	{
		test_case => 'get-existing-product-api-v3-5',
		method => 'GET',
		path => '/api/v3.5/product/4260392550101',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-with-estimated-nutrients',
		method => 'GET',
		path => '/api/v3/product/200000000035',
		expected_status_code => 200,
	},
	{
		test_case => 'get-existing-product-with-estimated-nutrients-api-v3-5',
		method => 'GET',
		path => '/api/v3.5/product/200000000035',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
