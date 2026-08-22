#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready construct_test_url/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::APIProductServices qw/add_product_data_from_external_service/;
use ProductOpener::API qw/init_api_response/;

use File::Basename "dirname";

use Storable qw(dclone);
use JSON qw(decode_json);

wait_application_ready(__FILE__);

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Sample product

my $product_ref = {
	product_name => "My hazelnut spread",
	product_name_fr => "Ma pâte aux noisettes",
	ingredients => [
		{
			id => "en:sugar",
			text => "Sucre",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			ciqual_food_code => "16129",
			from_palm_oil => "yes",
			id => "en:palm-oil",
			text => "huile de palme",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			ciqual_food_code => "17210",
			from_palm_oil => "no",
			id => "en:hazelnut-oil",
			percent => 13,
			text => "huile de NOISETTES",
			vegan => "yes",
			vegetarian => "yes"
		}
	]
};

# Make a call to an external product service
# We use a Product Opener product service, but we call it as if it was an external service through HTTP

my $services_url = construct_test_url("/api/v3/product_services");
my $services_ref = ["estimate_ingredients_percent"];
my $request_ref = {};
init_api_response($request_ref);

# Following lines are for testing recipe-estimator connection, they should be commented out

# $services_url = "https://recipe-estimator.openfoodfacts.net/api/v3/estimate_recipe_scipy";
# following does not seem to work, maybe because recipe-estimator listens only to http://127.0.0.1:8000
# $services_url = "http://host.docker.internal:8000/api/v3/estimate_recipe";
# $services_ref = undef;

add_product_data_from_external_service($request_ref, $product_ref, $services_url, $services_ref, undef);
my $response_ref = $request_ref->{api_response};

$test_id = "estimate_ingredients_percent";

compare_to_expected_results($response_ref, "$expected_result_dir/$test_id.response.json", $update_expected_results);
compare_to_expected_results($product_ref, "$expected_result_dir/$test_id.product.json", $update_expected_results);

done_testing();
