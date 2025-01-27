#!/usr/bin/perl
use ProductOpener::PerlStandards;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

# Définition du produit exemple
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

# Définition des tests
my $tests_ref = [
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

	# estimate_environmental_impact_service service
	# no fields parameter, should get back only updated fields
	{
		test_case => 'estimate-environmental-impact-service-hazelnut-spread',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["estimate_environmental_impact_service"],'
			. $product_hazelnut_spread_json . '}',
	},
	# Get back only specific fields
	{
		test_case => 'estimate-environmental-impact-service-hazelnut-spread-specific-fields',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["estimate_environmental_impact_service"],
            "fields": ["ingredients_percent_analysis"],'
			. $product_hazelnut_spread_json . '}',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
