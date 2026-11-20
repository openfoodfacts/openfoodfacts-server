#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
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
use ProductOpener::Test qw/compare_to_expected_results init_expected_results normalize_product_for_test_comparison/;
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
	# labels found in the ingredients list should be stored in tags_sources.labels.ingredients,
	# and existing labels from other sources should be kept
	[
		'en-labels-from-ingredients',
		{
			lc => "en",
			schema_version => 1004,
			ingredients_text => "Water, sugar, caffeine free, contains a source of phenylalanine",
			tags_sources => {
				labels => {
					packaging => {
						tags => ["en:fair-trade"],
						last_updated_t => 1700000000,
					},
				},
			},
			labels_tags => ["en:fair-trade"],
		}
	],
	# products saved with the previous code had labels from the ingredients only in the old
	# labels, labels_lc and labels_hierarchy fields, with no tags_sources.labels: they should be removed
	[
		'en-labels-without-tags-sources',
		{
			lc => "en",
			schema_version => 1004,
			ingredients_text => "Water, sugar",
			labels => "Koffeinmentes, en:contains-a-source-of-phenylalanine",
			labels_lc => "hu",
			labels_hierarchy => ["en:no-caffeine", "en:contains-a-source-of-phenylalanine"],
			labels_tags => ["en:no-caffeine", "en:contains-a-source-of-phenylalanine"],
		}
	],
	# Ecobalyse environmental impact estimation should prepare the request payload
	[
		'ecobalyse-environmental-impact-estimation',
		{
			lc => "en",
			ingredients_text => "Olive oil",
			categories_tags => ["en:olive-oils"],
			quantity => "0.75l",
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

	normalize_product_for_test_comparison($product_ref);
	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
