#!/usr/bin/perl -w

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::Test qw/init_expected_results/;
use ProductOpener::EnvironmentalImpact qw/estimate_environmental_impact_service/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Sample product

my $product_hazelnut_spread_json = '{
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
}';

my $json = JSON->new->allow_nonref->canonical;
my $product_ref = $json->decode($product_hazelnut_spread_json);
my $mock_response_file = "$expected_result_dir/ecobalyse_mocked_response.json";
my $test_result_file = "$expected_result_dir/environmental_impact.json";
my $mock_calls = 0;
my $ecobalyse_mock;

if (!$update_expected_results) {
	if (open(my $mock_response, "<:encoding(UTF-8)", $mock_response_file)) {
		local $/;    #Enable 'slurp' mode
		my $response_data = <$mock_response>;
		$ecobalyse_mock = mock 'ProductOpener::EnvironmentalImpact' => (
			override => [
				'call_ecobalyse' => sub {
					++$mock_calls;
					return ($response_data, 1);
				}
			]
		);
	}
	else {
		fail("could not load $mock_response_file");
	}
}

# Run the test
my $updated_product_fields_ref = {};
my $errors_ref = {};

estimate_environmental_impact_service($product_ref, $updated_product_fields_ref, $errors_ref);

# Save the result
if ($update_expected_results) {
	open(my $response, ">:encoding(UTF-8)", $mock_response_file)
		or die("Could not create $mock_response_file: $!\n");
	print $response $json->pretty->encode($product_ref->{ecobalyse_response});
	close($response);

	open(my $result, ">:encoding(UTF-8)", $test_result_file)
		or die("Could not create $test_result_file: $!\n");
	print $result $json->pretty->encode($product_ref);
	close($result);
}
else {
	is($mock_calls, 1, "Ecobalyse mock called");
}

# Compare the result with the expected result
if (open(my $expected_result, "<:encoding(UTF-8)", $test_result_file)) {
	local $/;    #Enable 'slurp' mode
	my $expected_product_ref = $json->decode(<$expected_result>);
	is($product_ref, $expected_product_ref, 'Matches expected results') or diag Dumper $product_ref;
}
else {
	fail("could not load $test_result_file");
	diag Dumper $product_ref;
}

done_testing();
