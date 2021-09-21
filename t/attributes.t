#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use Getopt::Long;


use JSON::PP;

my $json = JSON::PP->new->allow_nonref->canonical;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Attributes qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;

load_agribalyse_data();
load_ecoscore_data();

init_packaging_taxonomies_regexps();

load_forest_footprint_data();

my $testdir = "attributes";

my $usage = <<TXT

The expected results of the tests are saved in $data_root/t/expected_test_results/$testdir

To verify differences and update the expected test results, actual test results
can be saved to a directory by passing --results [path of results directory]

The directory will be created if it does not already exist.

TXT
;

my $resultsdir;

GetOptions ("results=s"   => \$resultsdir)
  or die("Error in command line arguments.\n\n" . $usage);
  
if ((defined $resultsdir) and (! -e $resultsdir)) {
	mkdir($resultsdir, 0755) or die("Could not create $resultsdir directory: $!\n");
}

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
			ingredients_text => "wheat flour (origin: UK), sugar (Paraguay), eggs, strawberries, high fructose corn syrup, rapeseed oil, macadamia nuts, milk proteins, salt, E102, E120",
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
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];
	my $options_ref = $test_ref->[2];
	
	# Run the test
	
	compute_languages($product_ref); # need languages for allergens detection and cleaning ingredients
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);
	detect_allergens_from_text($product_ref);
	special_process_product($product_ref);
	fix_salt_equivalent($product_ref);
	compute_nutrition_score($product_ref);
	compute_nova_group($product_ref);
	compute_nutrient_levels($product_ref);
	compute_unknown_nutrients($product_ref);
	analyze_and_combine_packaging_data($product_ref);
	compute_ecoscore($product_ref);
	compute_forest_footprint($product_ref);
			
	compute_attributes($product_ref, $product_ref->{lc}, "world", $options_ref);

	# Travis has a different $server_domain, so we need to change the resulting URLs
	#          $got->{attribute_groups_fr}[0]{attributes}[0]{icon_url} = 'https://static.off.travis-ci.org/images/attributes/nutriscore-unknown.svg'
	#     $expected->{attribute_groups_fr}[0]{attributes}[0]{icon_url} = 'https://static.openfoodfacts.dev/images/attributes/nutriscore-unknown.svg'
	
	# code below from https://www.perlmonks.org/?node_id=1031287
	
	use Scalar::Util qw/reftype/;

	sub walk {
	  my ($entry,$code) =@_;
	  my $type = reftype($entry);
	  $type //= "SCALAR";

	  if    ($type eq "HASH") {
		walk($_,$code) for values %$entry;
	  }
	  elsif ($type eq "ARRAY") {
		walk($_,$code) for @$entry;
	  }
	  elsif ($type eq "SCALAR" ) {
		$code->($_[0]);        # alias of entry
	  }
	  else {
		warn "unknown type $type";
	  }
	}
	
	walk $product_ref, sub { $_[0] =~ s/https:\/\/([^\/]+)\//https:\/\/server_domain\//; };	
	
	# Save the result
	
	if (defined $resultsdir) {
		open (my $result, ">:encoding(UTF-8)", "$resultsdir/$testid.json") or die("Could not create $resultsdir/$testid.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close ($result);
	}
	
	# Compare the result with the expected result
	
	if (open (my $expected_result, "<:encoding(UTF-8)", "$data_root/t/expected_test_results/$testdir/$testid.json")) {

		local $/; #Enable 'slurp' mode
		my $expected_product_ref = $json->decode(<$expected_result>);
		is_deeply ($product_ref, $expected_product_ref) or diag explain $product_ref;
	}
	else {
		diag explain $product_ref;
		fail("could not load expected_test_results/$testdir/$testid.json");
	}
}


done_testing();
