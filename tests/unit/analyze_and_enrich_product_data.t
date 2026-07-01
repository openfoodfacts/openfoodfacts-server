#!/usr/bin/perl -w

use Modern::Perl '2017';
no warnings qw(experimental::signatures);

use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use JSON::MaybeXS;

my $json = JSON::MaybeXS->new->allow_nonref->canonical;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Test qw/init_expected_results/;
use ProductOpener::Products qw/analyze_and_enrich_product_data/;
use ProductOpener::Food qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::EnvironmentalScore qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Attributes qw/compute_attributes/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::API qw/get_initialized_response/;
use ProductOpener::LoadData qw/load_data/;

load_data();

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (

	# glycemic index and carbon footprint nutrition data should add a label
	[
		'en-carbon-footprint-and-glycemic-index-labels-from-nutrition-data',
		{
			lc => "en",
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"carbon-footprint" => {
								value_string => "5",
								value => 5,
								unit => "g",
							},
							"glycemic-index" => {
								value_string => "55",
								value => 55,
								unit => "",
							},
						}
					}
				]
			},
		}
	],

);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];
	my $options_ref = $test_ref->[2];

	# Run the test

	# Response structure to keep track of warnings and errors
	# Note: currently some warnings and errors are added,
	# but we do not yet do anything with them
	my $response_ref = get_initialized_response();

	analyze_and_enrich_product_data($product_ref, $response_ref);

	# Save the result

	if ($update_expected_results) {
		open(my $result, ">:encoding(UTF-8)", "$expected_result_dir/$testid.json")
			or die("Could not create $expected_result_dir/$testid.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close($result);
	}

	# Compare the result with the expected result

	if (open(my $expected_result, "<:encoding(UTF-8)", "$expected_result_dir/$testid.json")) {

		local $/;    #Enable 'slurp' mode
		my $expected_product_ref = $json->decode(<$expected_result>);
		# print STDERR "testid: $testid\n";
		is($product_ref, $expected_product_ref) or diag Dumper $product_ref;
	}
	else {
		diag Dumper $product_ref;
		fail("could not load $expected_result_dir/$testid.json");
	}
}

done_testing();
