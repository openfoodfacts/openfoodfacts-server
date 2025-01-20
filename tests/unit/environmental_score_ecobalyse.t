#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;

# Définition du produit exemple
my $product_hazelnut_spread_json = '
    "product": {
        "product_name_en": "My hazelnut spread",
        "product_name_fr": "Ma pâte aux noisettes",
        "ingredients": [
            {
                "is_in_taxonomy": 1,
                "id": "en:sugar",
                "vegetarian": "yes",
                "percent_estimate": 50,
                "ecobalyse_code": "sugar",
                "vegan": "yes",
                "ciqual_proxy_food_code": "31016",
                "text": "Sucre"
            },
            {
                "vegetarian": "yes",
                "from_palm_oil": "yes",
                "percent_estimate": 25,
                "ciqual_food_code": "16129",
                "is_in_taxonomy": 1,
                "id": "en:palm-oil",
                "text": "huile de palme",
                "ecobalyse_code": "refined-palm-oil",
                "vegan": "yes"
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
	{
		test_case => 'echo-service-hazelnut-spread',
		method => 'POST',
		path => '/api/v3/product_services/echo',
		body => '{
            "services":["echo"],
            "fields":["all"],' . $product_hazelnut_spread_json . '}',
	},
];

execute_api_tests(__FILE__, $tests_ref);

# Tests supplémentaires (exemple)
my @tests = (
	[
		'empty-product',
		{
			lc => "en",
		}
	],
	[
		'unknown-category',
		{
			lc => "en",
			categories_tags => ["en:some-unknown-category"],
		}
	],
);

# Validation des tests supplémentaires
foreach my $test (@tests) {
	my ($description, $params) = @$test;
	diag("Testing: $description");
	# Ajouter ici la logique de test avec les $params
}

done_testing();
