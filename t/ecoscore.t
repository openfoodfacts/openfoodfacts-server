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
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Packaging qw/:all/;

load_agribalyse_data();
load_ecoscore_data();

init_packaging_taxonomies_regexps();

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
	
	# Origins of ingredients
	
	[
		'origins-of-ingredients-specified',
		{
			lc => "en",
			categories_tags=>["en:jams"],
			ingredients_text =>"60% apricots (France), 30% cane sugar (Martinique), lemon juice (Italy)",
		}
	],
	[
		'origins-of-ingredients-not-specified',
		{
			lc => "en",
			categories_tags=>["en:jams"],
			ingredients_text =>"60% apricots, 30% cane sugar, lemon juice",
		}
	],
	[
		'origins-of-ingredients-partly-specified',
		{
			lc => "en",
			categories_tags=>["en:jams"],
			ingredients_text =>"60% apricots (France), 30% cane sugar, lemon juice",
		}
	],
	[
		'origins-of-ingredients-specified-multiple',
		{
			lc => "en",
			categories_tags=>["en:jams"],
			ingredients_text =>"60% apricots (France, Spain), 30% cane sugar (Martinique, Guadeloupe, Dominican Republic), lemon juice",
		}
	],
	[
		'origins-of-ingredients-in-origins-field',
		{
			lc => "en",
			categories_tags=>["en:jams"],
			origins_tags=>["en:france"],
			ingredients_text =>"60% apricots, 30% cane sugar (Martinique), lemon juice",
		}
	],
	[
		'origins-of-ingredients-in-origins-field-multiple',
		{
			lc => "en",
			categories_tags=>["en:jams"],
			origins_tags=>["en:france", "en:dordogne", "en:belgium"],
			ingredients_text =>"60% apricots, 30% cane sugar (Martinique), lemon juice",
		}
	],

	[
		'origins-of-ingredients-nested',
		{
			lc => "en",
			categories_tags=>["en:cheeses"],
			ingredients_text=>"Milk, salt, coloring: E160b",
		}
	],
	
	[
		'origins-of-ingredients-nested-2',
		{
			lc => "en",
			categories_tags=>["en:cheeses"],
			ingredients_text=>"Milk, chocolate (cocoa, cocoa butter, sweetener: aspartame), salt",
		}
	],
	
	[
		'origins-of-ingredients-unknown-origin',
		{
			lc => "en",
			categories_tags=>["en:cheeses"],
			ingredients_text=>"Milk (origin: Milky way)",
		}
	],
	
	[
		'origins-of-ingredients-unspecified-origin',
		{
			lc => "en",
			categories_tags=>["en:cheeses"],
			origins_tags=>["en:unspecified"],
			ingredients_text=>"Milk",
		}
	],	
	
	# Packaging adjustment
	
	[
		'packaging-en-pet-bottle',
		{
			lc => "en",
			categories_tags=>["en:beverages", "en:orange-juices"],
			packaging_text=>"PET bottle"
		}
	],
	
	# plastic should be mapped to the en:other-plastics value
	
	[
		'packaging-en-plastic-bottle',
		{
			lc => "en",
			categories_tags=>["en:beverages", "en:orange-juices"],
			packaging_text=>"Plastic bottle"
		}
	],
	
	[
		'packaging-en-multiple',
		{
			lc => "en",
			categories_tags=>["en:beverages", "en:orange-juices"],
			packaging_text=>"1 cardboard box, 1 plastic film wrap, 6 33cl steel beverage cans"
		}
	],

	[
		'packaging-en-multiple-over-maximum-malus',
		{
			lc => "en",
			categories_tags=>["en:biscuits"],
			packaging_text=>"1 plastic box, 1 plastic film wrap, 12 individual plastic bags"
		}
	],	
	
	[
		'packaging-en-unspecified-material-bottle',
		{
			lc => "en",
			categories_tags=>["en:beverages", "en:orange-juices"],
			packaging_text=>"bottle"
		}
	],		

	[
		'packaging-en-unspecified-material-can',
		{
			lc => "en",
			categories_tags=>["en:beverages", "en:orange-juices"],
			packaging_text=>"can"
		}
	],

	[
		'packaging-unspecified',
		{
			lc => "en",
			categories_tags=>["en:milks"],
		}
	],

	[
		'packaging-unspecified-no-a-eco-score',
		{
			lc => "en",
			categories_tags=>["en:speculoos"],
			ingredients_text=>"Wheat (France)",
			labels_tags=>["fr:ab-agriculture-biologique"],
		}
	],		
	
	# Sodas: no Eco-Score
	
	[
		'category-without-ecoscore-sodas',
		{
			lc => "en",
			categories_tags=>["en:sodas"],
			ingredients_text=>"Water, sugar",
		}
	],
	
	# Packaging bulk
	
	[
		'packaging-en-bulk',
		{
			lc => "en",
			categories_tags=>["en:beverages", "en:orange-juices"],
			packaging_text=>"bulk"
		}
	],	
	
	# Sum of bonuses greater than 25
	
	[
		'sum-of-bonuses-greater-than-25',
		{
			lc => "fr",
			categories_tags=>["en:chicken-breasts"],
			packaging_text => "vrac",
			labels_tags => ["en:demeter"],
			ingredients_text => "Poulet (origine France)",
		},
	],
	
	# downgrade from B to A when the product contains non-recyclable and non-biodegradable materials
	
	[
		'carrots',
		{
			lc => "fr",
			categories_tags=>["en:carrots"],
			packaging_text => "vrac",
			labels_tags => ["en:demeter"],
			ingredients_text => "Carottes (origine France)",
		},
	],
	
	[
		'carrots-plastic',
		{
			lc => "fr",
			categories_tags=>["en:carrots"],
			packaging_text => "Barquette en plastique",
			labels_tags => ["en:demeter"],
			ingredients_text => "Carottes (origine France)",
		},
	],
	
	# Label ratio = sheet ratio (0.1) : no downgrade if non recyclable
	
	[
		'grade-a-with-recyclable-label',
		{
			lc => "fr",
			categories_tags=>["en:carrots"],
			packaging_text => "1 Pot verre A recycler, 1 Couvercle acier A recycler,1 Etiquette Polypropylène A jeter",
			labels_tags => ["en:eu-organic"],
			origins_tags => ["en:france"],
			ingredients_text => "Aubergine 60%, Pomme de terre 39%, Huile de colza 1%",
		},
	],
	
	[
		'grade-a-with-non-recyclable-label',
		{
			lc => "fr",
			categories_tags=>["en:carrots"],
			packaging_text => "1 Pot verre A recycler, 1 Couvercle acier A recycler,1 Etiquette plastique A jeter",
			labels_tags => ["en:eu-organic"],
			origins_tags => ["en:france"],
			ingredients_text => "Aubergine 60%, Pomme de terre 39%, Huile de colza 1%",
		},
	],
	
	# Milks should be considered as beverages for the Eco-Score
	
	[
		'milk',
		{
			lc => "fr",
			categories_tags=>["en:milks"],
			packaging_text => "1 bouteille en plastique PET, 1 bouchon PEHD",
			labels_tags => ["en:eu-organic"],
			origins_tags => ["en:france"],
			ingredients_text => "Lait",
		},
	],
	
	# Energy drinks should not have an Eco-Score (like waters and sodas)
	
	[
		'energy-drink',
		{
			lc => "fr",
			categories_tags=>["en:energy-drinks"],
			packaging_text => "1 bouteille en plastique PET, 1 bouchon PEHD",
			ingredients_text => "Water",
		},
	],	

);


my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];
	
	# Run the test
	
	# Parse the ingredients (and extract the origins), and compute the ingredients percent
	extract_ingredients_from_text($product_ref);
	
	analyze_and_combine_packaging_data($product_ref);
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
		diag explain $product_ref;
	}
}

# 

done_testing();
