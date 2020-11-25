#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use JSON;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;

load_forest_footprint_data();

my $testdir = "forest_footprint";

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
			ingredients_text =>"Lait",
		}
	],
	[
		'fr-ingredients-poulet',
		{
			lc => "fr",
			ingredients_text =>"Poulet",
		}
	],
	[
		'fr-ingredients-filet-de-poulet-bio',
		{
			lc => "fr",
			ingredients_text =>"Filet de poulet bio",
		}
	],
	[
		'fr-ingredients-poulet-du-gers',
		{
			lc => "fr",
			ingredients_text =>"Poulet du Gers",
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
			ingredients_text =>"Filet de poulet bio, oeuf label rouge, os de poulet IGP",
		}
	],	
	[
		'fr-ingredients-nested-matching-sub-ingredient',
		{
			lc => "fr",
			ingredients_text =>"viande de poulet traitée en salaison [viande de poulet (origine : France), eau, saumure]",
		}
	],
	[
		'fr-ingredients-nested-matching-ingredient',
		{
			lc => "fr",
			ingredients_text =>"viande de poulet traitée en salaison [kangourou, eau, saumure]",
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
		fail("could not load expected_test_results/$testdir/$testid.json");
		diag explain $product_ref;
	}
}

# 

done_testing();
