#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use JSON;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ecoscore qw/:all/;

load_agribalyse_data();

# Taxonomy tags used by EcoScore.pm that should not be renamed
# (or that should be renamed in the code and tests as well).

my %tags = (
labels => [

	# Production system
	"fr:nature-et-progres",
	"fr:bio-coherence",
	"en:demeter",
	
	"fr:ab-agriculture-biologique",
	"en:eu-organic",
	
	"fr:haute-valeur-environnementale",
	"en:utz-certified",
	"en:rainforest-alliance",
	"en:fairtrade-international",
	"fr:bleu-blanc-coeur",
	"fr:label-rouge",
	"en:sustainable-seafood-msc",
	"en:responsible-aquaculture-asc",
	
	# Threatened species
	"en:roundtable-on-sustainable-palm-oil",
	
	],
categories => [
	"en:beef",
	"en:lamb-meat",
	"en:veal-meat",
],
);

foreach my $tagtype (keys %tags) {

	foreach my $tagid (@{$tags{$tagtype}}) {
		is(canonicalize_taxonomy_tag("en", $tagtype, $tagid), $tagid);
	}
}

my $testdir = "ecoscore";

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
		'unknown-category',
		{
			lc => "en",
			categories_tags=>["en:some-unknown-category"],
		}
	],
	[
		'known-category-butters',
		{
			lc => "en",
			categories_tags=>["en:butters"],
		}
	],	
	[
		'label-organic',
		{
			lc => "en",
			categories_tags=>["en:butters"],
			labels_tags=>["fr:ab-agriculture-biologique"],
		}
	],
	[
		'known-category-margarines',
		{
			lc => "en",
			categories_tags=>["en:margarines"],
		}
	],
	[
		'ingredient-palm-oil',
		{
			lc => "en",
			categories_tags=>["en:margarines"],
			ingredients_analysis_tags=>["en:palm-oil"],
		}
	],
	[
		'ingredient-palm-oil-rspo',
		{
			lc => "en",
			categories_tags=>["en:margarines"],
			ingredients_analysis_tags=>["en:palm-oil"],
			labels_tags=>["en:roundtable-on-sustainable-palm-oil"],
		}
	],		
);


my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];
	
	# Run the test
	
	compute_ecoscore($product_ref);
	
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
	}
}

# 

done_testing();
