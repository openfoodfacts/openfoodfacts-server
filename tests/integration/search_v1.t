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
			code => '200000000037',
			product_name => "vegan & palm oil free",
			generic_name => "Tester",
			ingredients_text => "fruit, rice",
			packaging_text => "no"
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000038',
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
			code => '200000000039',
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
			code => '200000000045',
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
			code => '200000000046',
			product_name => "More vegan breakfast cereals without palm oil",
			ingredients_text => "apple, water",
			origin => "UK",
			countries => "United Kingdom, Ireland",
			categories => "breakfast cereals"
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
		path => '/api/v2/search?code=200000000039,200000000038,200000000034&fields=code,product_name',
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
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
