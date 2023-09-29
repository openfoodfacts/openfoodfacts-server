#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

# Sample product

my $product_hazelnut_spread_json = '
    "product": {
        "ingredients": [
            {
                "id": "en:sugar",
                "text": "Sucre",
                "vegan": "yes",
                "vegetarian": "yes"
            },
            {
                "ciqual_food_code": "16129",
                "from_palm_oil": "yes",
                "id": "en:palm-oil",
                "text": "huile de palme",
                "vegan": "yes",
                "vegetarian": "yes"
            },
            {
                "ciqual_food_code": "17210",
                "from_palm_oil": "no",
                "id": "en:hazelnut-oil",
                "percent": 13,
                "text": "huile de NOISETTES",
                "vegan": "yes",
                "vegetarian": "yes"
            }
        ]
    }
';

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'unknown-service',
		method => 'POST',
		path => '/api/v3/product_services/unknown',
		body => '{"product":{}}',
	},
	# echo service
	{
		test_case => 'echo-service-no-body',
		method => 'POST',
		path => '/api/v3/product_services/echo',
	},
	{
		test_case => 'echo-service-hazelnut-spread',
		method => 'POST',
		path => '/api/v3/product_services/echo',
		body => '{' . $product_hazelnut_spread_json . '}',
	},
	# estimate-ingredients-percent service
	{
		test_case => 'estimate-ingredients-percent-service-hazelnut-spread',
		method => 'POST',
		path => '/api/v3/product_services/estimate_ingredients_percent',
		body => '{' . $product_hazelnut_spread_json . '}',
	},
	# Get back only specific fields
	{
		test_case => 'estimate-ingredients-percent-service-hazelnut-spread-specific-fields',
		method => 'POST',
		path => '/api/v3/product_services/estimate_ingredients_percent',
		body => '{
                "fields": "ingredients_percent_analysis",'
			. $product_hazelnut_spread_json . '}',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
