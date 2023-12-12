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
			code => '200000000001',
			product_name => "Product with no data quality tags",
			packagings => {
				material => "en:clear-glass",
				number_of_units => 1,
				quantity_per_unit => "100g",
				recycling => "en:recycle-in-glass-bin",
				shape => "en:jar",
				weight_measured => 25.2
			},
			categories => "en:carots",
			ingredients_en => "carots origin France (100%)",
		),
	},
	{
		# every type of tags
		%{dclone(\%default_product_form)},
		(
			code => '200000000002',
			product_name => "Product with data quality tags",
			# errors on nutriments
			nutriment_salt => 120,
			'nutriment_energy-kcal' => 1302,
			'nutriment_energy-kj' => 1302,
			# info: no packaging data
		)
	},
);

foreach my $product_ref (@products) {
	edit_product($ua, $product_ref);
}

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'no-data-quality',
		desc => "Display data quality knowledge panels for product with no data quality issues",
		method => 'GET',
		path => '/api/v2/product/200000000001?fields=knowledge_panels&knowledge_panels_client=web',
		expected_status_code => 200,
	},
	{
		test_case => 'data-quality',
		desc => "Display data quality knowledge panels for product with data quality issues",
		method => 'GET',
		path => '/api/v2/product/200000000002?fields=knowledge_panels&knowledge_panels_client=web',
		expected_status_code => 200,
	},
];

# note: we need to execute the tests with bob, because we need authentication
# to see data quality panels
execute_api_tests(__FILE__, $tests_ref, $ua);

done_testing();
