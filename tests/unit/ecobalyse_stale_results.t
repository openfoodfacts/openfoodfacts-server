#!/usr/bin/perl -w

# Tests for reusing previous Ecobalyse results when the request did not change,
# and for keeping previous results as stale when we cannot get new results.

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::EnvironmentalImpact qw/estimate_environmental_impact_service/;

# Mocked Ecobalyse API: each test sets the response returned by call_ecobalyse()
my $mock_calls = 0;
my @mock_response = ();
my $ecobalyse_mock = mock 'ProductOpener::EnvironmentalImpact' => (
	override => [
		'call_ecobalyse' => sub {
			++$mock_calls;
			return @mock_response;
		}
	]
);

sub success_response ($ecs) {
	return (encode_json({results => {total => {ecs => $ecs}}}), 1, 200);
}

sub new_product ($sugar_percent = 100) {
	return {
		categories_tags => [],
		ingredients => [{id => "en:sugar", percent_estimate => $sugar_percent, ecobalyse_id => "sugar-id"}],
	};
}

sub has_misc_tag ($product_ref, $tag) {
	return scalar grep {$_ eq $tag} @{$product_ref->{misc_tags} // []};
}

# Compute initial results
my $product_ref = new_product();
@mock_response = success_response(100);
estimate_environmental_impact_service($product_ref, {}, []);
is($mock_calls, 1, "initial call: API called");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 100, "initial call: results");
ok($product_ref->{environmental_impact}{ecobalyse_results_t}, "initial call: time of results");
my $results_t = $product_ref->{environmental_impact}{ecobalyse_results_t};

# Same request: previous results are reused, the API is not called
@mock_response = success_response(200);
estimate_environmental_impact_service($product_ref, {}, []);
is($mock_calls, 1, "same request: API not called");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 100, "same request: previous results reused");
is($product_ref->{environmental_impact}{ecobalyse_results_t}, $results_t, "same request: time of results kept");
ok(has_misc_tag($product_ref, "en:ecobalyse-api-not-called-same-request"), "same request: misc tag");

# Same request, with numbers stored as strings (e.g. after the product is stored and loaded)
$product_ref->{environmental_impact}{ecobalyse_request}{data}{ingredients}[0]{mass} = "100";
estimate_environmental_impact_service($product_ref, {}, []);
is($mock_calls, 1, "same request with numbers as strings: API not called");

# Same request, but forced call
my $errors_ref = [];
estimate_environmental_impact_service($product_ref, {}, $errors_ref, 0, 1);
is($mock_calls, 2, "forced call: API called");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 200, "forced call: new results");

# Changed product, API call skipped: previous results are kept and marked as stale
my $previous_input_ref = $product_ref->{environmental_impact}{ecobalyse_input};
$product_ref->{ingredients}[0]{percent_estimate} = 90;
estimate_environmental_impact_service($product_ref, {}, [], 1);
is($mock_calls, 2, "skipped call: API not called");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 200, "skipped call: previous results kept");
is($product_ref->{environmental_impact}{ecobalyse_input}, $previous_input_ref, "skipped call: previous input kept");
ok($product_ref->{environmental_impact}{ecobalyse_stale}, "skipped call: results are stale");
ok(has_misc_tag($product_ref, "en:ecobalyse-results-stale"), "skipped call: stale misc tag");
is($product_ref->{environmental_impact}{ecobalyse_pending_request}{data}{ingredients}[0]{mass},
	90, "skipped call: pending request");
my $stale_t = $product_ref->{environmental_impact}{ecobalyse_stale_t};
ok($stale_t, "skipped call: time when results became stale");

# Timeout: previous results are still kept as stale, error is returned
@mock_response = ("500 read timeout", 0, 500);
$errors_ref = [];
estimate_environmental_impact_service($product_ref, {}, $errors_ref);
is($mock_calls, 3, "timeout: API called");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 200, "timeout: previous results kept");
ok($product_ref->{environmental_impact}{ecobalyse_stale}, "timeout: results are stale");
is($product_ref->{environmental_impact}{ecobalyse_stale_t}, $stale_t, "timeout: stale time not changed");
is($product_ref->{environmental_impact}{ecobalyse_error_response}, "500 read timeout", "timeout: error response");
ok(has_misc_tag($product_ref, "en:ecobalyse-results-stale"), "timeout: stale misc tag");
ok(has_misc_tag($product_ref, "en:ecobalyse-api-temporary-error"), "timeout: temporary error misc tag");
is(scalar @$errors_ref, 1, "timeout: error returned");

# Authentication error (e.g. expired API token) with a JSON error: previous results are still kept as stale
@mock_response = (encode_json({error => "invalid token"}), 0, 401);
$errors_ref = [];
estimate_environmental_impact_service($product_ref, {}, $errors_ref);
is($mock_calls, 4, "authentication error: API called");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 200, "authentication error: previous results kept");
ok($product_ref->{environmental_impact}{ecobalyse_stale}, "authentication error: results are stale");
ok(has_misc_tag($product_ref, "en:ecobalyse-api-temporary-error"), "authentication error: temporary error misc tag");
is(scalar @$errors_ref, 1, "authentication error: error returned");

# Successful call: results are not stale anymore
@mock_response = success_response(300);
estimate_environmental_impact_service($product_ref, {}, []);
is($mock_calls, 5, "success after stale: API called");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 300, "success after stale: new results");
ok(!$product_ref->{environmental_impact}{ecobalyse_stale}, "success after stale: results not stale");
ok(!has_misc_tag($product_ref, "en:ecobalyse-results-stale"), "success after stale: no stale misc tag");
ok(!exists $product_ref->{environmental_impact}{ecobalyse_pending_request}, "success after stale: no pending request");

# Request rejected by Ecobalyse (4xx with a JSON error): previous results are removed
$product_ref->{ingredients}[0]{percent_estimate} = 80;
@mock_response = (encode_json({error => "unknown ingredient"}), 0, 400);
estimate_environmental_impact_service($product_ref, {}, []);
is($mock_calls, 6, "rejected request: API called");
ok(!exists $product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, "rejected request: previous results removed");
ok(!has_misc_tag($product_ref, "en:ecobalyse-results-stale"), "rejected request: no stale misc tag");
ok(has_misc_tag($product_ref, "en:ecobalyse-api-error"), "rejected request: error misc tag");
ok(!has_misc_tag($product_ref, "en:ecobalyse-api-temporary-error"), "rejected request: no temporary error misc tag");

# Ingredients with a quantity of 0 are not sent to Ecobalyse (it rejects the whole request)
$product_ref = new_product();
push @{$product_ref->{ingredients}}, {id => "en:salt", percent_estimate => 0, ecobalyse_id => "salt-id"};
@mock_response = success_response(100);
estimate_environmental_impact_service($product_ref, {}, []);
is([map {$_->{id}} @{$product_ref->{environmental_impact}{ecobalyse_request}{data}{ingredients}}],
	["sugar-id"], "ingredient with a quantity of 0 not sent");

# Timeout without previous results: error, no results
$product_ref = new_product();
@mock_response = ("500 Can't connect", 0, 500);
estimate_environmental_impact_service($product_ref, {}, []);
ok(!exists $product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, "timeout without previous results: no results");
ok(!has_misc_tag($product_ref, "en:ecobalyse-results-stale"), "timeout without previous results: no stale misc tag");
ok(has_misc_tag($product_ref, "en:ecobalyse-api-error"), "timeout without previous results: error misc tag");
ok(
	has_misc_tag($product_ref, "en:ecobalyse-api-temporary-error"),
	"timeout without previous results: temporary error misc tag"
);

done_testing();
