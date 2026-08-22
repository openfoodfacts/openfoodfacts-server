#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user edit_product execute_api_tests new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_product_form %default_user_form/;
use ProductOpener::Cache qw/$memd/;
# We need to flush memcached so that cached queries from other tests (e.g. web_html.t) don't interfere with this test
$memd->flush_all;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Create some products

my @products = (

	{
		%{dclone(\%default_product_form)},
		(
			code => '2000000000343',
			product_name => "test_1",
			generic_name => "Tester",
			ingredients_text => "apple, milk, eggs, palm oil",
			origin => "france",
			packaging_text_en => "1 25cl glass bottle, 1 steel lid, 1 plastic wrap"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '2000000000374',
			product_name => "vegan & palm oil free",
			generic_name => "Tester",
			ingredients_text => "fruit, rice",
			packaging_text => "no"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '2000000000381',
			product_name => "palm oil free & non vegan",
			generic_name => "Tester",
			quantity => "100 ml",
			ingredients_text => "apple, milk, eggs",
			origin => "france"
		)
	},
	# Note: the following 2 products will have ingredients set in English (language of the interface)
	# and not in Spanish (main language of the product)
	{
		%{dclone(\%default_product_form)},
		(
			code => '2000000000398',
			lang => "es",
			product_name => "Vegan Test Snack with palm oil",
			generic_name => "Tester",
			ingredients_text => "apple, water, palm oil",
			origin => "spain",
			categories => "snacks"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '2000000000459',
			lang => "es",
			product_name => "Vegan breakfast cereals without palm oil",
			generic_name => "Tester",
			ingredients_text => "apple, water",
			origin => "China",
			packaging_text => "no",
			categories => "breakfast cereals"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '2000000000466',
			product_name => "More vegan breakfast cereals without palm oil",
			ingredients_text => "apple, water, sugar 20%",
			origin => "UK",
			countries => "United Kingdom, Ireland",
			categories => "breakfast cereals",
		)
	}
	#
);

foreach my $product_ref (@products) {
	edit_product($ua, $product_ref);
}

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'search-no-filter',
		method => 'GET',
		path => '/cgi/search.pl?action=process&json=1',
		expected_status_code => 200,
	},
	{
		test_case => 'search-without-ingredients-from-palm-oil',
		method => 'GET',
		path => '/cgi/search.pl?action=process&json=1&ingredients_from_palm_oil=without',
		expected_status_code => 200,
	},
	{
		test_case => 'search-specific-barcodes',
		method => 'GET',
		path => '/api/v2/search?code=2000000000398,2000000000381,2000000000343&fields=code,product_name',
		expected_status_code => 200,
	},
	# Additional GS1 formats that should be recognized and reduced to the GTIN
	{
		test_case => 'search-specific-barcodes-gs1-bracketed-ai',
		method => 'GET',
		path => '/api/v2/search?code=%2801%2902000000000398%2822%292A&fields=code,product_name',
		expected_status_code => 200,
	},
	{
		test_case => 'search-specific-barcodes-gs1-fnc1-unbracketed',
		method => 'GET',
		path => '/api/v2/search?code=%1D0102000000000398&fields=code,product_name',
		expected_status_code => 200,
	},
	{
		test_case => 'search-specific-barcodes-gs1-raw-ai',
		method => 'GET',
		path => '/api/v2/search?code=01020000000003980217231231&fields=code,product_name',
		expected_status_code => 200,
	},
	{
		test_case => 'search-specific-barcodes-gs1-digital-link-alt',
		method => 'GET',
		path =>
			'/api/v2/search?code=https%3A%2F%2Fexample.com%2F01%2F02000000000398%3F17%3D271200&fields=code,product_name',
		expected_status_code => 200,
	},
	{
		test_case => 'search-tags-categories-without-ingredients-from-palm-oil',
		method => 'GET',
		path =>
			'/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&ingredients_from_palm_oil=without&json=1',
		expected_status_code => 200,
	},
	{
		test_case => 'search-fields-packagings',
		method => 'GET',
		path => '/cgi/search.pl?action=process&json=1&fields=code,packaging_text_en,packagings',
		expected_status_code => 200,
	},
	# Get the packagings field with the new API v3 format that differs from the old format
	{
		test_case => 'search-fields-packagings-in-api-v3-format',
		method => 'GET',
		path => '/cgi/search.pl?action=process&json=1&fields=code,packaging_text_en,packagings&api_version=3',
		expected_status_code => 200,
	},
	# Attribute groups with unwanted ingredients
	{
		test_case => 'search-attribute-unwanted-ingredients-water',
		method => 'GET',
		path =>
			'/cgi/search.pl?action=process&json=1&attribute_unwanted_ingredients_tags=en:water&fields=attribute_groups',
		expected_status_code => 200,
	},
	# Attributes groups with unwanted ingredients using a cookie to set the language to Spanish
	{
		test_case => 'search-attribute-unwanted-ingredients-water-cookie',
		method => 'GET',
		path => '/cgi/search.pl?action=process&json=1&fields=attribute_groups',
		cookies => [{name => "attribute_unwanted_ingredients_tags", value => "en:water"}],
		expected_status_code => 200,
	},
	# Search on nutrients
	# Note: the test products have no nutrition facts set, but they get estimated nutrition facts from ingredients
	{
		test_case => 'search-nutrient-sugar-greater-than-15g',
		method => 'GET',
		path => '/cgi/search.pl?action=process&json=1&sugars_100g=>15',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
