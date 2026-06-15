#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Test qw/init_expected_results/;
use ProductOpener::Ingredients qw/extract_ingredients_from_text/;
use ProductOpener::ForestFootprint2026 qw/compute_forest_footprint_2026 load_forest_footprint_2026_data/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

load_forest_footprint_2026_data();

my @tests = (

	[
		'empty-product',
		{
			lc => "en",
		}
	],
	[
		'fr-ingredients-cacao',
		{
			lc => "fr",
			ingredients_text => "cacao",
		}
	],
	[
		'fr-ingredients-cacao-50-percent',
		{
			lc => "fr",
			ingredients => [
				{
					id => "en:cocoa",
					percent => 50,
					text => "cacao",
				}
			],
		}
	],
	[
		'fr-ingredients-cacao-with-origin',
		{
			lc => "fr",
			ingredients => [
				{
					id => "en:cocoa",
					percent => 50,
					text => "cacao",
				}
			],
			origins_tags => ["en:brazil"],
		}
	],
	[
		'fr-ingredients-cacao-with-origin-and-label',
		{
			lc => "fr",
			ingredients => [
				{
					id => "en:cocoa",
					percent => 50,
					text => "cacao",
				}
			],
			origins_tags => ["en:brazil"],
			labels_tags => ["en:organic"],
		}
	],
	[
		'fr-ingredients-cacao-100-percent',
		{
			lc => "fr",
			ingredients => [
				{
					id => "en:cocoa",
					percent => 100,
					text => "cacao",
				}
			],
			origins_tags => ["en:brazil"],
			labels_tags => ["en:organic"],
		}
	],
	[
		'fr-ingredients-pate-de-cacao',
		{
			lc => "fr",
			ingredients => [
				{
					id => "en:cocoa-paste",
					percent => 100,
					text => "pâte de cacao",
				}
			],
			origins_tags => ["en:brazil"],
		}
	],
	[
		'fr-ingredients-beurre-de-cacao',
		{
			lc => "fr",
			ingredients => [
				{
					id => "en:cocoa-butter",
					percent => 100,
					text => "beurre de cacao",
				}
			],
			origins_tags => ["en:brazil"],
		}
	],
	[
		'fr-ingredients-chocolate-with-utz-label',
		{
			lc => "fr",
			ingredients => [
				{
					id => "en:cocoa",
					percent => 50,
					text => "cacao",
				}
			],
			origins_tags => ["en:brazil"],
			labels_tags => ["en:utz"],
		}
	],

);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test
	if (defined $product_ref->{ingredients_text}) {
		extract_ingredients_from_text($product_ref);
	}

	compute_forest_footprint_2026($product_ref);

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
		is($product_ref, $expected_product_ref) or diag Dumper $product_ref;
	}
	else {
		fail("could not load $expected_result_dir/$testid.json");
		diag Dumper $product_ref;
	}
}

done_testing();
