#!/usr/bin/perl -w

# Tests for the experimental feature to compute parent ingredients stats for a set of products
# (implemented in Recipes.pm, activated by adding the parents_ingredients parameter to a search query)

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

remove_all_users();

remove_all_products();

wait_application_ready();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Create some products with different percentages and some commont parent ingredients

my @products = (

	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000001',
			product_name => "Pizza 1",
			ingredients_text => "wheat flour, tomato, cheese 10%, olive oil 5%",
			categories => "pizzas",
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000002',
			product_name => "Pizza 2",
			ingredients_text => "flour, tomato sauce, cheese 10%, olive oil 2%, capers",
			categories => "pizzas",
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000003',
			product_name => "Pizza 3",
			ingredients_text => "wholemeal flour, tomato, mozzarella 20%, olive oil 8%, salt",
			categories => "pizzas",
		)
	},	
);

foreach my $product_ref (@products) {
	edit_product($ua, $product_ref);
}

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'parent-ingredients-stats',
		method => 'GET',
		path => '/search?parent_ingredients=cheese,flour,tomato,olive oil',
		expected_status_code => 200,
		expected_type => 'html',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
