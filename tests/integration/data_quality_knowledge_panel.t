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
        # no tags
		%{dclone(\%default_product_form)},
		(
			code => '200000000001',
			product_name => "Product with no data quality tags",
        ),
	},
	{
        # every type of tags
		%{dclone(\%default_product_form)},
		(
			code => '200000000002',
			product_name => "Product with data quality tags",
            data_quality_info_tags => ["en:nutrition-data-prepared"],
            data_quality_warnings_tags => [
                "en:all-but-one-ingredient-with-specified-percent",
            ],
            data_quality_errors_tags => [
                "en:energy-value-in-kcal-does-not-match-value-in-kj",
                "en:nutrition-saturated-fat-greater-than-fat",
            ],
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
		path => '/api/v2/product/200000000001?fields=knowledge_panels',
		expected_status_code => 200,
	},
	{
		test_case => 'data-quality',
        desc => "Display data quality knowledge panels for product with data quality issues",
		method => 'GET',
		path => '/api/v2/product/200000000002?fields=knowledge_panels',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
