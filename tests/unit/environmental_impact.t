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

my $calls = 0;
my $ecobalyse_mock = mock 'ProductOpener::EnvironmentalImpact' => (
	override => [
		'call_ecobalyse' => sub {
			++$calls;
			return {
				is_success => 1,
				decoded_content => '{
                "description" : "TODO",
                "query" : {
                "distribution" : "ambient",
                "ingredients" : [
                    {
                        "id" : "9b476f8e-08c2-4406-9198-1fb2e007f000",
                        "mass" : 50
                    },
                    {
                        "id" : "45658c32-66d9-4305-a34b-21d6a4cef89c",
                        "mass" : 25
                    },
                    {
                        "id" : "60184de2-cc9e-4618-924a-b8fecf080c8b",
                        "mass" : 13
                    },
                    {
                        "id" : "33d2f3c2-ffa2-4b96-811e-50c1c8670e26",
                        "mass" : 8.7
                    },
                    {
                        "id" : "3d7f808b-77c5-4207-968d-feea6dfd9496",
                        "mass" : 3.3
                    }
                ],
                "preparation" : [
                    "refrigeration"
                ],
                "transform" : {
                    "id" : "7541cf94-1d4d-4d1c-99e3-a9d5be0e7569",
                    "mass" : 545
                }
                },
                "results" : {
                "distribution" : {
                    "total" : {
                        "acd" : 0,
                        "cch" : 0,
                        "ecs" : 0.312013,
                        "etf" : 0,
                        "etf-c" : 0,
                        "fru" : 0,
                        "fwe" : 0,
                        "htc" : 0,
                        "htc-c" : 0,
                        "htn" : 0,
                        "htn-c" : 0,
                        "ior" : 0,
                        "ldu" : 0,
                        "mru" : 0,
                        "ozd" : 0,
                        "pco" : 0,
                        "pef" : 0.382154,
                        "pma" : 0,
                        "swe" : 0,
                        "tre" : 0,
                        "wtu" : 0
                    },
                    "transports" : {
                        "air" : 0,
                        "impacts" : {
                            "acd" : 0,
                            "cch" : 0,
                            "ecs" : 0.782012,
                            "etf" : 0,
                            "etf-c" : 0,
                            "fru" : 0,
                            "fwe" : 0,
                            "htc" : 0,
                            "htc-c" : 0,
                            "htn" : 0,
                            "htn-c" : 0,
                            "ior" : 0,
                            "ldu" : 0,
                            "mru" : 0,
                            "ozd" : 0,
                            "pco" : 0,
                            "pef" : 0.797585,
                            "pma" : 0,
                            "swe" : 0,
                            "tre" : 0,
                            "wtu" : 0
                        },
                        "road" : 600,
                        "roadCooled" : 0,
                        "sea" : 0,
                        "seaCooled" : 0
                    }
                },
                "packaging" : {
                    "acd" : 0,
                    "cch" : 0,
                    "ecs" : 0,
                    "etf" : 0,
                    "etf-c" : 0,
                    "fru" : 0,
                    "fwe" : 0,
                    "htc" : 0,
                    "htc-c" : 0,
                    "htn" : 0,
                    "htn-c" : 0,
                    "ior" : 0,
                    "ldu" : 0,
                    "mru" : 0,
                    "ozd" : 0,
                    "pco" : 0,
                    "pef" : 0,
                    "pma" : 0,
                    "swe" : 0,
                    "tre" : 0,
                    "wtu" : 0
                },
                "perKg" : {
                    "acd" : 0,
                    "cch" : 0,
                    "ecs" : 1561.48,
                    "etf" : 0,
                    "etf-c" : 0,
                    "fru" : 0,
                    "fwe" : 0,
                    "htc" : 0,
                    "htc-c" : 0,
                    "htn" : 0,
                    "htn-c" : 0,
                    "ior" : 0,
                    "ldu" : 0,
                    "mru" : 0,
                    "ozd" : 0,
                    "pco" : 0,
                    "pef" : 735.061,
                    "pma" : 0,
                    "swe" : 0,
                    "tre" : 0,
                    "wtu" : 0
                },
                "preparation" : {
                    "acd" : 0,
                    "cch" : 0,
                    "ecs" : 0.187588,
                    "etf" : 0,
                    "etf-c" : 0,
                    "fru" : 0,
                    "fwe" : 0,
                    "htc" : 0,
                    "htc-c" : 0,
                    "htn" : 0,
                    "htn-c" : 0,
                    "ior" : 0,
                    "ldu" : 0,
                    "mru" : 0,
                    "ozd" : 0,
                    "pco" : 0,
                    "pef" : 0.229457,
                    "pma" : 0,
                    "swe" : 0,
                    "tre" : 0,
                    "wtu" : 0
                },
                "preparedMass" : 0.0935,
                "recipe" : {
                    "ingredientsTotal" : {
                        "acd" : 0,
                        "cch" : 0,
                        "ecs" : 123.171,
                        "etf" : 0,
                        "etf-c" : 0,
                        "fru" : 0,
                        "fwe" : 0,
                        "htc" : 0,
                        "htc-c" : 0,
                        "htn" : 0,
                        "htn-c" : 0,
                        "ior" : 0,
                        "ldu" : 0,
                        "mru" : 0,
                        "ozd" : 0,
                        "pco" : 0,
                        "pef" : 43.1533,
                        "pma" : 0,
                        "swe" : 0,
                        "tre" : 0,
                        "wtu" : 0
                    },
                    "total" : {
                        "acd" : 0,
                        "cch" : 0,
                        "ecs" : 144.717,
                        "etf" : 0,
                        "etf-c" : 0,
                        "fru" : 0,
                        "fwe" : 0,
                        "htc" : 0,
                        "htc-c" : 0,
                        "htn" : 0,
                        "htn-c" : 0,
                        "ior" : 0,
                        "ldu" : 0,
                        "mru" : 0,
                        "ozd" : 0,
                        "pco" : 0,
                        "pef" : 67.319,
                        "pma" : 0,
                        "swe" : 0,
                        "tre" : 0,
                        "wtu" : 0
                    },
                    "totalBonusImpact" : {
                        "cropDiversity" : 0,
                        "hedges" : -0.184829,
                        "livestockDensity" : 0,
                        "microfibers" : 0,
                        "outOfEuropeEOL" : 0,
                        "permanentPasture" : 0,
                        "plotSize" : -0.718796
                    },
                    "transform" : {
                        "acd" : 0,
                        "cch" : 0,
                        "ecs" : 13.2028,
                        "etf" : 0,
                        "etf-c" : 0,
                        "fru" : 0,
                        "fwe" : 0,
                        "htc" : 0,
                        "htc-c" : 0,
                        "htn" : 0,
                        "htn-c" : 0,
                        "ior" : 0,
                        "ldu" : 0,
                        "mru" : 0,
                        "ozd" : 0,
                        "pco" : 0,
                        "pef" : 15.4848,
                        "pma" : 0,
                        "swe" : 0,
                        "tre" : 0,
                        "wtu" : 0
                    },
                    "transports" : {
                        "air" : 18000,
                        "impacts" : {
                            "acd" : 0,
                            "cch" : 0,
                            "ecs" : 8.3429,
                            "etf" : 0,
                            "etf-c" : 0,
                            "fru" : 0,
                            "fwe" : 0,
                            "htc" : 0,
                            "htc-c" : 0,
                            "htn" : 0,
                            "htn-c" : 0,
                            "ior" : 0,
                            "ldu" : 0,
                            "mru" : 0,
                            "ozd" : 0,
                            "pco" : 0,
                            "pef" : 8.68098,
                            "pma" : 0,
                            "swe" : 0,
                            "tre" : 0,
                            "wtu" : 0
                        },
                        "road" : 9800,
                        "roadCooled" : 0,
                        "sea" : 36000,
                        "seaCooled" : 0
                    }
                },
                "scoring" : {
                    "all" : 1561.48,
                    "biodiversity" : 0,
                    "climate" : 0,
                    "health" : 0,
                    "resources" : 0
                },
                "total" : {
                    "acd" : 0,
                    "cch" : 0,
                    "ecs" : 145.999,
                    "etf" : 0,
                    "etf-c" : 0,
                    "fru" : 0,
                    "fwe" : 0,
                    "htc" : 0,
                    "htc-c" : 0,
                    "htn" : 0,
                    "htn-c" : 0,
                    "ior" : 0,
                    "ldu" : 0,
                    "mru" : 0,
                    "ozd" : 0,
                    "pco" : 0,
                    "pef" : 68.7282,
                    "pma" : 0,
                    "swe" : 0,
                    "tre" : 0,
                    "wtu" : 0
                },
                "totalMass" : 0.0935,
                "transports" : {
                    "air" : 18000,
                    "impacts" : {
                        "acd" : 0,
                        "cch" : 0,
                        "ecs" : 9.12491,
                        "etf" : 0,
                        "etf-c" : 0,
                        "fru" : 0,
                        "fwe" : 0,
                        "htc" : 0,
                        "htc-c" : 0,
                        "htn" : 0,
                        "htn-c" : 0,
                        "ior" : 0,
                        "ldu" : 0,
                        "mru" : 0,
                        "ozd" : 0,
                        "pco" : 0,
                        "pef" : 9.47857,
                        "pma" : 0,
                        "swe" : 0,
                        "tre" : 0,
                        "wtu" : 0
                    },
                    "road" : 10400,
                    "roadCooled" : 0,
                    "sea" : 36000,
                    "seaCooled" : 0
                }
                },
                "webUrl" : "https://ecobalyse.beta.gouv.fr/#/food/ecs/eyJpbmdyZWRpZW50cyI6W3siaWQiOiI5YjQ3NmY4ZS0wOGMyLTQ0MDYtOTE5OC0xZmIyZTAwN2YwMDAiLCJtYXNzIjo1MH0seyJpZCI6IjQ1NjU4YzMyLTY2ZDktNDMwNS1hMzRiLTIxZDZhNGNlZjg5YyIsIm1hc3MiOjI1fSx7ImlkIjoiNjAxODRkZTItY2M5ZS00NjE4LTkyNGEtYjhmZWNmMDgwYzhiIiwibWFzcyI6MTMuMDAwMDAwMDAwMDAwMDAyfSx7ImlkIjoiMzNkMmYzYzItZmZhMi00Yjk2LTgxMWUtNTBjMWM4NjcwZTI2IiwibWFzcyI6OC43fSx7ImlkIjoiM2Q3ZjgwOGItNzdjNS00MjA3LTk2OGQtZmVlYTZkZmQ5NDk2IiwibWFzcyI6My4zfV0sInRyYW5zZm9ybSI6eyJpZCI6Ijc1NDFjZjk0LTFkNGQtNGQxYy05OWUzLWE5ZDViZTBlNzU2OSIsIm1hc3MiOjU0NX0sImRpc3RyaWJ1dGlvbiI6ImFtYmllbnQiLCJwcmVwYXJhdGlvbiI6WyJyZWZyaWdlcmF0aW9uIl19"
            }'
			};
		}
	]
);

execute_api_tests(__FILE__, $tests_ref);

is($calls, 1, "Ecobalyse service called");

done_testing();
