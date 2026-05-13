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

	# FR - palm oil

	[
		'fr-palm-oil-free',
		{
			lc => "fr",
			ingredients_text => "eau, farine, sucre, chocolat",
		}
	],

	[
		'fr-palm-oil',
		{
			lc => "fr",
			ingredients_text => "pommes de terres, huile de palme",
		}
	],

	[
		'fr-palm-kernel-fat',
		{
			lc => "fr",
			ingredients_text => "graisse de palmiste",
		}
	],

	[
		'fr-vegetable-oils',
		{
			lc => "fr",
			ingredients_text => "farine de maïs, huiles végétales, sel",
		}
	],

	# EN

	[
		'en-attributes',
		{
			lc => "en",
			categories => "biscuits",
			categories_tags => ["en:biscuits"],
			ingredients_text =>
				"wheat flour (origin: UK), sugar (Paraguay), eggs, strawberries, high fructose corn syrup, rapeseed oil, macadamia nuts, milk proteins, salt, E102, E120",
			labels_tags => ["en:organic", "en:fair-trade"],
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"energy-kj" => {
								value_string => "800",
								value => 800,
								unit => "kJ",
							},
							fat => {
								value_string => "12",
								value => 12,
								unit => "g",
							},
							"saturated-fat" => {
								value_string => "4",
								value => 4,
								unit => "g",
							},
							sugars => {
								value_string => "25",
								value => 25,
								unit => "g",
							},
							salt => {
								value_string => "0.25",
								value => 0.25,
								unit => "g",
							},
							sodium => {
								value_string => "0.1",
								value => 0.1,
								unit => "g",
							},
							proteins => {
								value_string => "2",
								value => 2,
								unit => "g",
							},
							fiber => {
								value_string => "3",
								value => 3,
								unit => "g",
							},
						}
					}
				]
			},
			countries_tags => ["en:united-kingdom", "en:france"],
			packaging_text => "Cardboard box, film wrap",
		}
	],

	# Nutri-Score attribute, with a match score computed from the nutriscore score
	# https://github.com/openfoodfacts/openfoodfacts-server/issues/5636
	[
		'en-nutriscore',
		{
			lc => "en",
			categories => "biscuits",
			categories_tags => ["en:biscuits"],
			ingredients_text => "100% fruits",
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							energy => {
								value_string => "2591",
								value => 2591,
								unit => "kj",
							},
							fat => {
								value_string => "50",
								value => 50,
								unit => "g",
							},
							"saturated-fat" => {
								value_string => "9.7",
								value => 9.7,
								unit => "g",
							},
							sugars => {
								value_string => "5.1",
								value => 5.1,
								unit => "g",
							},
							salt => {
								value_string => "0",
								value => 0,
								unit => "g",
							},
							sodium => {
								value_string => "0",
								value => 0,
								unit => "g",
							},
							proteins => {
								value_string => "29",
								value => 29,
								unit => "g",
							},
							fiber => {
								value_string => "5.5",
								value => 5.5,
								unit => "g",
							},
						}
					}
				]
			},
		}
	],

	[
		'en-nutriscore-serving-size-error',
		{
			lc => "en",
			categories => "biscuits",
			categories_tags => ["en:biscuits"],
			serving_size => "20",
			ingredients_text => "100% fruits",
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "serving",
						per_quantity => "20",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							energy => {
								value_string => "2591",
								value => 2591,
								unit => "kj",
							},
							fat => {
								value_string => "50",
								value => 50,
								unit => "g",
							},
							"saturated-fat" => {
								value_string => "9.7",
								value => 9.7,
								unit => "g",
							},
							sugars => {
								value_string => "5.1",
								value => 5.1,
								unit => "g",
							},
							salt => {
								value_string => "0",
								value => 0,
								unit => "g",
							},
							sodium => {
								value_string => "0",
								value => 0,
								unit => "g",
							},
							proteins => {
								value_string => "29",
								value => 29,
								unit => "g",
							},
							fiber => {
								value_string => "5.5",
								value => 5.5,
								unit => "g",
							},
						}
					}
				]
			},
		}
	],

	# Maybe vegan: attribute score should be 50
	[
		'en-maybe-vegan',
		{
			lc => "en",
			categories => "Non-dairy cheeses",
			categories_tags => ["en:non-dairy-cheeses"],
			ingredients_text => "tapioca starch, palm oil, enzyme",
		}
	],

	# bug https://github.com/openfoodfacts/openfoodfacts-server/issues/6356
	[
		'en-environmental_score-score-at-20-threshold',
		{
			lc => "en",
			categories => "Cocoa and hazelnuts spreads",
			categories_tags => ["en:cocoa-and-hazelnuts-spreads"],
			ingredients_text => "",
		}
	],

	# NOVA
	[
		'en-nova-groups-markers',
		{
			lc => "en",
			categories => "Cheeses",
			categories_tags => ["en:cheeses"],
			ingredients_text =>
				"Cow milk, salt, microbial culture, garlic flavouring, guar gum, sugar, high fructose corn syrup",
		}
	],

	# Ingredients analysis and allergens when we don't have ingredients, or ingredients are not recognized
	[
		'en-no-ingredients',
		{
			lc => "en",
			categories => "Cheeses",
			categories_tags => ["en:cheeses"],
		}
	],
	[
		'en-unknown-ingredients',
		{
			lc => "en",
			categories => "Cheeses",
			categories_tags => ["en:cheeses"],
			ingredients_text => "some ingredient that we do not recognize",
		}
	],
	# Unwanted ingredients
	[
		'en-unwanted-ingredients',
		{
			lc => "en",
			categories => "Cheeses",
			categories_tags => ["en:cheeses"],
			ingredients_text => "palm oil, soy lecithin, potassium sorbate, sea salt",
		},
		{
			attribute_unwanted_ingredients_tags => "en:salt"
		}
	],
	[
		'en-no-unwanted-ingredients',
		{
			lc => "en",
			categories => "Cheeses",
			categories_tags => ["en:cheeses"],
			ingredients_text => "palm oil, soy lecithin, potassium sorbate",
		},
		{
			attribute_unwanted_ingredients_tags => "en:salt"
		}
	],
	[
		'en-no-unwanted-ingredients-but-many-unknown-ingredients',
		{
			lc => "en",
			categories => "Cheeses",
			categories_tags => ["en:cheeses"],
			ingredients_text => "something, something else",
		},
		{
			attribute_unwanted_ingredients_tags => "en:salt"
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

	compute_attributes($product_ref, $product_ref->{lc}, "world", $options_ref);

	# Travis and docker has a different $server_domain, so we need to change the resulting URLs
	#          $got->{attribute_groups_fr}[0]{attributes}[0]{icon_url} = 'https://static.off.travis-ci.org/images/attributes/nutriscore-unknown.svg'
	#     $expected->{attribute_groups_fr}[0]{attributes}[0]{icon_url} = 'https://static.openfoodfacts.dev/images/attributes/nutriscore-unknown.svg'

	# code below from https://www.perlmonks.org/?node_id=1031287

	use Scalar::Util qw/reftype/;

	sub walk {
		my ($entry, $code) = @_;
		my $type = reftype($entry);
		$type //= "SCALAR";

		if ($type eq "HASH") {
			walk($_, $code) for values %$entry;
		}
		elsif ($type eq "ARRAY") {
			walk($_, $code) for @$entry;
		}
		elsif ($type eq "SCALAR") {
			$code->($_[0]);    # alias of entry
		}
		else {
			warn "unknown type $type";
		}
		return;
	}

	walk $product_ref, sub {return unless defined $_[0]; $_[0] =~ s/https?:\/\/([^\/]+)\//https:\/\/server_domain\//;};

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
