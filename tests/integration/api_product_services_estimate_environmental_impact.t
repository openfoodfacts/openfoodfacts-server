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
                "is_in_taxonomy" : 1,
                "id" : "en:sugar",
                "vegetarian" : "yes",
                "percent_estimate" : 50,
                "ecobalyse_code" : "9b476f8e-08c2-4406-9198-1fb2e007f000",
                "vegan" : "yes",
                "ciqual_proxy_food_code" : "31016",
                "text" : "Sucre"
            },
            {
                "vegetarian" : "yes",
                "from_palm_oil" : "yes",
                "percent_estimate" : 25,
                "ciqual_food_code" : "16129",
                "is_in_taxonomy" : 1,
                "id" : "en:palm-oil",
                "text" : "huile de palme",
                "ecobalyse_code" : "45658c32-66d9-4305-a34b-21d6a4cef89c",
                "vegan" : "yes"
            },
            {
                "is_in_taxonomy" : 1,
                "id" : "en:hazelnut",
                "vegetarian" : "yes",
                "percent_estimate" : 13,
                "ciqual_food_code" : "15004",
                "ecobalyse_code" : "60184de2-cc9e-4618-924a-b8fecf080c8b",
                "vegan" : "yes",
                "percent" : 13,
                "text" : "NOISETTES"
            },
            {
                "id" : "en:skimmed-milk-powder",
                "is_in_taxonomy" : 1,
                "percent_estimate" : 8.7,
                "ciqual_food_code" : "19054",
                "vegetarian" : "yes",
                "vegan" : "no",
                "ecobalyse_code" : "33d2f3c2-ffa2-4b96-811e-50c1c8670e26",
                "text" : "LAIT écrémé en poudre",
                "percent" : 8.7
            },
            {
                "ciqual_proxy_food_code" : "18100",
                "vegan" : "yes",
                "text" : "cacao maigre",
                "percent" : 7.4,
                "id" : "en:fat-reduced-cocoa",
                "is_in_taxonomy" : 1,
                "percent_estimate" : 3.3,
                "vegetarian" : "yes",
				"ecobalyse_code" : "3d7f808b-77c5-4207-968d-feea6dfd9496"
            }
        ]
    }
';

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	# compute the environmental impact of the product
	# return the whole product object
	{
		test_case => 'estimate_environmental_impact',
		method => 'POST',
		path => '/api/v3/product_services',
		body => '{
			"services":["estimate_environmental_impact"],
			"fields": ["all"],'
			. $product_hazelnut_spread_json . '}',
	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
