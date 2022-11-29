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
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000039',
			lang => "es",
			product_name => "Vegan Test Snack",
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
			product_name => "Vegan Test Snack",
			generic_name => "Tester",
			ingredients_text => "apple, water",
			origin => "China",
			packaging_text => "no",
			categories => "breakfast cereals"
		)
	}
);

my @products2 = (
	{
		%{dclone(\%default_product_form)},
		(
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
		path => '/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=breakfast_cereals&ingredients_from_palm_oil=without&json=1',
		expected_status_code => 200,
	},	

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
