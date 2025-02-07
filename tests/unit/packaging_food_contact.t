#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::Packaging qw/init_packaging_taxonomies_regexps analyze_and_combine_packaging_data/;
use ProductOpener::PackagingFoodContact qw/determine_food_contact_of_packaging_components/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;
use ProductOpener::API qw/get_initialized_response/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

init_packaging_taxonomies_regexps();

# Tests for determine_food_contact_of_packaging_components()

my @tests = (

	[
		'empty-packagings',
		{
			lc => "en",
			packaging_text => "",
		}
	],
	[
		'hazelnut-paste-glass-jar',
		{
			lc => "en",
			packaging_text => "glass jar, plastic lid, paper label, paper seal, cardboard box",
		}
	],
	[
		'canned-tomatoes',
		{
			lc => "en",
			packaging_text => "can, paper label",
		}
	],
	[
		'coffee-capsule',
		{
			lc => "en",
			packaging_text => "carboard box, plastic capsule, plastic film",
		}
	],
	[
		'meat-tray',
		{
			lc => "en",
			packaging_text => "plastic tray, plastic film, paper label",
		}
	],
	[
		'wine-bottle',
		{
			lc => "en",
			packaging_text => "glass bottle, cork, paper label",
		}
	],
	[
		'plastic-bottle',
		{
			lc => "en",
			packaging_text => "plastic bottle, plastic cap, plastic label",
		}
	],
	[
		'chocolate-bar',
		{
			lc => "en",
			packaging_text => "cardboard sleeve, aluminium foil, paper label",
		}
	],
	[
		'fr-tablette-de-chocolat',
		{
			lc => "fr",
			packaging_text => "étui en carton, feuille d'aluminium, étiquette papier",
		}
	]

);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test

	# Response structure to keep track of warnings and errors
	# Note: currently some warnings and errors are added,
	# but we do not yet do anything with them
	my $response_ref = get_initialized_response();

	analyze_and_combine_packaging_data($product_ref, $response_ref);
	determine_food_contact_of_packaging_components($product_ref->{packagings});

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
