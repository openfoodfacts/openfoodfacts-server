#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

load_forest_footprint_data();

my @tests = (

	[
		'empty-product',
		{
			lc => "en",
		}
	],
	[
		'fr-ingredients-lait',
		{
			lc => "fr",
			ingredients_text => "Lait",
		}
	],
	[
		'fr-ingredients-poulet',
		{
			lc => "fr",
			ingredients_text => "Poulet",
		}
	],
	[
		'fr-ingredients-filet-de-poulet-bio',
		{
			lc => "fr",
			ingredients_text => "Filet de poulet bio",
		}
	],
	[
		'fr-ingredients-poulet-du-gers',
		{
			lc => "fr",
			ingredients_text => "Poulet du Gers",
		}
	],
	[
		'fr-category-poulets-du-gers',
		{
			lc => "fr",
			categories_tags => ["en:poulets-du-gers"],
		}
	],
	[
		'fr-ingredients-filet-de-poulet-bio-oeuf-label-rouge-os-de-poulet-igp',
		{
			lc => "fr",
			ingredients_text => "Filet de poulet bio, oeuf label rouge, os de poulet IGP",
		}
	],
	[
		'fr-ingredients-nested-matching-sub-ingredient',
		{
			lc => "fr",
			ingredients_text =>
				"viande de poulet traitée en salaison [viande de poulet (origine : France), eau, saumure]",
		}
	],
	[
		'fr-ingredients-nested-matching-ingredient',
		{
			lc => "fr",
			ingredients_text => "viande de poulet traitée en salaison [kangourou, eau, saumure]",
		}
	],

);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test

	extract_ingredients_from_text($product_ref);

	compute_forest_footprint($product_ref);

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
		fail("could not load $expected_result_dir/$testid.json");
		diag explain $product_ref;
	}
}

done_testing();
