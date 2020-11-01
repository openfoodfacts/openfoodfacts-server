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
use ProductOpener::Packaging qw/:all/;

my $testdir = "packaging";

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
		'packaging_text_en_glass_bottle',
		{
			lc => "en",
			packaging_text => "glass bottle"
		}
	],
	[
		'packaging_text_en_plastic_bottle',
		{
			lc => "en",
			packaging_text => "6 25cl transparent plastic bottle to recycle"
		}
	],
	[
		'packaging_text_fr_bouteille_en_plastique',
		{
			lc => "fr",
			packaging_text => "bouteille en plastique à jeter"
		}
	],
	[
		'packaging_text_fr_multiple',
		{
			lc => "fr",
			packaging_text => "barquette en plastique à jeter, film plastique à jeter, boîte en carton à recycler"
		}
	],
	[
		'packaging_text_fr_boite_cartonee_accents',
		{
			lc => "fr",
			packaging_text => "boîte cartonnée"
		}
	],
	[
		'packaging_text_fr_bouteille_pet',
		{
			lc => "fr",
			packaging_text => "bouteille PET"
		}
	],
	# check that we use the most specific material (e.g. PET instead of plastic)
	[
		'packaging_text_fr_bouteille_plastique_pet',
		{
			lc => "fr",
			packaging_text => "bouteille plastique PET"
		}
	],
	
	# Merge packaging text data with existing packagings structure
	
	[
		'merge_en_add_packaging',
		{
			lc => "en",
			packaging_text => "aluminium can",
			packagings => [
				{
					'shape' => 'en:box',
					'material' => 'en:cardboard',
				},
			]
		}
	],
	[
		'merge_en_merge_packaging_add_property',
		{
			lc => "en",
			packaging_text => "plastic box",
			packagings => [
				{
					'shape' => 'en:box',
					'units' => 2
				},
			]
		}
	],
	[
		'merge_en_merge_packaging_more_specific_property',
		{
			lc => "en",
			packaging_text => "rPET plastic box",
			packagings => [
				{
					'shape' => 'en:box',
					'material' => 'en:plastic',
				},
			]
		}
	],
	[
		'merge_en_merge_packaging_less_specific_property',
		{
			lc => "en",
			packaging_text => "plastic box",
			packagings => [
				{
					'shape' => 'en:box',
					'material' => 'en:recycled-plastic',
				},
			]
		}
	],
	[
		'merge_en_merge_packaging_tag_and_packaging_text',
		{
			lc => "en",
			packaging => "plastic, box, paper bag",
			packaging_text => "plastic box",
		}
	],
	[
		'merge_en_merge_packaging_tag_and_packaging_text_2',
		{
			lc => "en",
			packaging => "PET, box, paper bag",
			packaging_text => "plastic box, kraft paper",
		}
	],		
);

init_packaging_taxonomies_regexps();

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];
	
	# Run the test
	
	analyze_and_combine_packaging_data($product_ref);
	
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
