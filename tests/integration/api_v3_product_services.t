#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

# Sample product

my $product_hazelnut_spread_json = '
    "product": {
		"product_name_en": "My hazelnut spread",
		"product_name_fr": "Ma pâte aux noisettes",
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


my $product_with_errors_json = '
    "product": {
        "product_name_en": "Erroneous Nut Spread",
        "product_name_fr": "Pâte de Noisettes Erronée",
        "nutrition": {
            "energy": "99999", # Excessive unrealistic energy value
            "sugars": "-5" # Negative sugar value which is illogical
        },
        "ingredients": [
            {
                "id": "en:sugar",
                "text": "Sugar",
                "vegan": "yes",
                "vegetarian": "yes"
            },
            {
                "id": "en:palm-oil",
                "text": "Palm oil",
                "vegan": "yes",
                "vegetarian": "yes",
                "from_palm_oil": "yes"
            }
        ]
    }
';

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	 {
        test_case => 'check-quality-service-with-errors',
        method => 'POST',
        path => '/api/v3/product_services',
        body => '{
            "services":["check_quality"],
            "product":' . $product_with_errors_json . '
        }',
        expected_status_code => 200, # Expecting a successful operation
        expected_response => 'response/check-quality-service-with-errors.json' # Pointing to the expected JSON response
    },
	
	{
		test_case => 'unknown-service',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["unknown"],
			"product":{}
		}',
		expected_status_code => 400,
	},
	# echo service
	{
		test_case => 'service-no-body',
		method => 'POST',
		path => '/api/v3/product_services',
		expected_status_code => 400,
	},
	{
		test_case => 'echo-service-hazelnut-spread',
		method => 'POST',
		path => '/api/v3/product_services/echo',
		body => '{
			"services":["echo"],
			"fields":["all"],'
			. $product_hazelnut_spread_json . '}',
	},
	{
		test_case => 'echo-service-hazelnut-spread-fields',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["echo"],
			"fields": ["product_name_en","product_name_fr"],'
			. $product_hazelnut_spread_json . '}',
	},
	# estimate_ingredients_percent service
	# no fields parameter, should get back only updated fields
	{
		test_case => 'estimate-ingredients-percent-service-hazelnut-spread',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["estimate_ingredients_percent"],'
			. $product_hazelnut_spread_json . '}',
	},
	# Get back only specific fields
	{
		test_case => 'estimate-ingredients-percent-service-hazelnut-spread-specific-fields',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["estimate_ingredients_percent"],
            "fields": ["ingredients_percent_analysis"],'
			. $product_hazelnut_spread_json . '}',
	},
	# estimate_ingredients_percent + analyze_ingredients
	{
		test_case => 'estimate-ingredients-percent-analyze-ingredients-services-hazelnut-spread',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["estimate_ingredients_percent", "analyze_ingredients"],'
			. $product_hazelnut_spread_json . '}',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
