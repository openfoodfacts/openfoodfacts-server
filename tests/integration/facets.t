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

# Create some products to test facets

my @products = (
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000001',
			product_name => "Carrots - Organic - France",
			categories => "en:carrots",
			labels => "en:organic",
			origins => "en:france",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000002',
			product_name => "Carrots - Fair trade, Organic - France",
			categories => "en:carrots",
			labels => "en:organic, en:fair-trade",
			origins => "en:france",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000003',
			product_name => "Carrots - No label - Belgium",
			categories => "en:carrots",
			origins => "en:belgium",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000004',
			product_name => "Carrots - Fair trade - Italy",
			categories => "en:carrots",
			labels => "en:fair-trade",
			origins => "en:italy",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000005',
			product_name => "Bananas - Organic - France",
			categories => "en:bananas",
			labels => "en:organic",
			origins => "en:france",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000006',
			product_name => "Bananas - Organic - Martinique",
			categories => "en:bananas",
			labels => "en:organic",
			origins => "en:martinique",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000007',
			product_name => "Oranges - Organic - Spain",
			categories => "en:oranges",
			labels => "en:organic",
			origins => "en:spain",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000008',
			product_name => "Oranges - Fair trade - Italy",
			categories => "en:oranges",
			labels => "en:fair-trade",
			origins => "en:italy",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000009',
			product_name => "Apples - Organic - France",
			categories => "en:apples",
			labels => "en:organic",
			origins => "en:france",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000010',
			product_name => "Apples - Organic, Fair trade - France",
			categories => "en:apples",
			labels => "en:organic,en:fair-trade",
			origins => "en:france",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000011',
			product_name => "Apples - Organic - France, Belgium, Canada",
			categories => "en:apples",
			labels => "en:organic",
			origins => "en:france,en:belgium,en:canada",
		),
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '200000000012',
			product_name => "Chocolate - Organic, Fair trade - Martinique",
			categories => "en:chocolate",
			labels => "en:organic,en:fair-trade",
			origins => "en:martinique",
		),
	},
);

foreach my $product_ref (@products) {
	edit_product($ua, $product_ref);
}

# Note: expected results are stored in json files, see execute_api_tests
# We use the API with .json to test facets, in order to easily get the products that are returned
my $tests_ref = [
	{
		test_case => 'category_apples',
		method => 'GET',
		path => '/category/apples.json?fields=product_name',
		expected_status_code => 200,
		sort_products_by => 'product_name',
	},
	{
		test_case => 'category_-apples',
		method => 'GET',
		path => '/category/-apples.json?fields=product_name',
		expected_status_code => 200,
		sort_products_by => 'product_name',
	},
	{
		test_case => 'category_apples_label_organic',
		method => 'GET',
		path => '/category/apples/label/organic.json?fields=product_name',
		expected_status_code => 200,
		sort_products_by => 'product_name',
	},
	{
		test_case => 'category_-apples_label_organic',
		method => 'GET',
		path => '/category/-apples/label/organic.json?fields=product_name',
		expected_status_code => 200,
		sort_products_by => 'product_name',
	},
	{
		test_case => 'category_-apples_label_-organic',
		method => 'GET',
		path => '/category/-apples/label/-organic.json?fields=product_name',
		expected_status_code => 200,
		sort_products_by => 'product_name',
	},
	{
		test_case => 'label_fair-trade_label_-organic',
		method => 'GET',
		path => '/label/fair-trade/label/-organic.json?fields=product_name',
		expected_status_code => 200,
		sort_products_by => 'product_name',
	},
];

# note: we need to execute the tests with bob, because we need authentication
# to see data quality panels
execute_api_tests(__FILE__, $tests_ref, $ua);

done_testing();
