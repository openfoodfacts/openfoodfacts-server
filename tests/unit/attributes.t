#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use JSON::PP;

my $json = JSON::PP->new->allow_nonref->canonical;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Attributes qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::API qw/:all/;

load_agribalyse_data();
load_ecoscore_data();

init_packaging_taxonomies_regexps();

load_forest_footprint_data();

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
			nutrition_data_per => "100g",
			nutriments => {
				"energy_100g" => 800,
				"fat_100g" => 12,
				"saturated-fat_100g" => 4,
				"sugars_100g" => 25,
				"salt_100g" => 0.25,
				"sodium_100g" => 0.1,
				"proteins_100g" => 2,
				"fiber_100g" => 3,
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
			nutrition_data_per => "100g",
			ingredients_text => "100% fruits",
			nutriments => {
				"energy_100g" => 2591,
				"fat_100g" => 50,
				"saturated-fat_100g" => 9.7,
				"sugars_100g" => 5.1,
				"salt_100g" => 0,
				"sodium_100g" => 0,
				"proteins_100g" => 29,
				"fiber_100g" => 5.5,
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
		'en-ecoscore-score-at-20-threshold',
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

	walk $product_ref, sub {$_[0] =~ s/https?:\/\/([^\/]+)\//https:\/\/server_domain\//;};

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
		is_deeply($product_ref, $expected_product_ref) or diag explain $product_ref;
	}
	else {
		diag explain $product_ref;
		fail("could not load $expected_result_dir/$testid.json");
	}
}

done_testing();
