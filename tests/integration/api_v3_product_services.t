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

# Note: expected results are stored in json files, see execute_api_tests
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

	# parse_ingredients_text missing ingredients
	{
		test_case => 'parse-ingredients-text-service-missing-ingredients',
		method => 'POST',
		path => '/api/v3/product_services',
		body => <<JSON
{
	"services":["parse_ingredients_text"],
	"product": {
		"lc": "en"
	}
}
JSON
	},

	# parse_ingredients_text
	{
		test_case => 'parse-ingredients-text-service-lc-fr',
		method => 'POST',
		path => '/api/v3/product_services',
		body => <<JSON
{
	"services":["parse_ingredients_text"],
	"product": {
		"ingredients_text": "Sucre, huile de palme, huile de NOISETTES, quelque chose d'inconnu",
		"lc": "fr"
	}
}
JSON
	},

	# no lc, should default to en
	{
		test_case => 'parse-ingredients-text-service-no-lc',
		method => 'POST',
		path => '/api/v3/product_services',
		body => <<JSON
{
	"services":["parse_ingredients_text"],
	"product": {
		"ingredients_text_es": "azúcar, aceite de palma, agua, algo desconocido",
		"ingredients_text_en": "sugar, palm oil, water, something unknown"
	}
}
JSON
	},

	# ingredients_text_fr defined, should use it
	{
		test_case => 'parse-ingredients-text-service-ingredients-text-fr',
		method => 'POST',
		path => '/api/v3/product_services',
		body => <<JSON
{
	"services":["parse_ingredients_text"],
	"product": {
		"ingredients_text_fr": "sucre, huile de palme, eau, quelque chose d'inconnu"
	}
}
JSON
	},

	# determine_food_contact_of_packaging_components
	{
		test_case => 'determine-food-contact-of-packaging-components-service',
		method => 'POST',
		path => '/api/v3/product_services',
		body => <<JSON
{
	"services":["determine_food_contact_of_packaging_components"],
	"product": {
		"lc": "en",
		"packagings": [
			{
				"material": "en:plastic",
				"shape": "en:tray"
			},
			{
				"material": "en:plastic",
				"shape": "en:film"
			},
			{
				"material": "en:paper",
				"shape": "en:label"
			}
		]
	}
}
JSON
	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
