#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Products qw/:all/;

# dummy product for testing

my @tests = (
[ { lc => "en", ingredients_text => "water, sugar, tea, lemon juice, flavouring, acidity regulator (330, 331), vitamin C, antioxidant (304)" }, [ "en:e330", "en:e331", "en:e304" ] ], 
[ { lc => "en", ingredients_text => "REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), ACIDITY REGULATOR (INS 334), STABILIZER (INS 440, INS 337), WATER (FOR MAINTAINING DESIRED BRIX), CONTAINS PERMITTED NATURAL FLAVOUR & NATURAL IDENTICAL COLOURING SUBSTANCES (INS 141[i])" }, [ "en:e300", "en:e334", "en:e440", "en:e337", "en:e141" ] ], 
[ { lc => "fr", ingredients_text => "Stabilisants: (SIN450i, SIN450iii), antioxydant (SIN316), Agent de conservation: (SIN250)." }, [ "en:e450i", "en:e450iii", "en:e316", "en:e250" ] ], 
[ { lc => "fr", ingredients_text => "Laitue, Carmine" }, [ ] ], 
[ { lc => "fr", ingredients_text => "poudres à lever (carbonates acides d’ammonium et de sodium, acide citrique)" }, ["en:e503ii", "en:e500ii", "en:e330" ] ], 
[ { lc => "fr", ingredients_text => "Saumon Atlantique* 97% (salmo salar), sel. poissons. Saumon élevé en/au : voir sur la face avant. INFORMATIONS : A consommerjusqu'au / NO de lot : voir sur la face avant. A conserver entre OOC et +40C avant et" }, [ ] ], 
[ { lc => "fr", ingredients_text => "Liste des ingrédients : viande de porc, sel, lactose, épices, sucre, dextrose, ail, conservateurs : nitrate de potassium et nitrite de sodium, ferments, boyau naturel de porc. Poudre de fleurage : talc et carbonate de calcium. 164 g de viande de porc utilisée poudre 100 g de produit fini. Substances ou produits provoquant des allergies ou intolérances : Lait" }, [ "en:e252", "en:e250", "en:e553b", "en:e170" ] ], 
[ { lc => "fr", ingredients_text => "conservateurs: nitrate de potassium et nitrite de sodium" }, [ "en:e252", "en:e250" ] ], 

# currently does not pass
#[ { lc => "en", ingredients_text => "INGREDIENTS: Parboiled rice, (enriched with iron (Ferric Orthophosphate), Niacin, Thiamine (Thiamine Mononitrate), Folic Acid, Chicken Base (Containing Modified Food Starch, Salt, Hydrolyzed Soy Protein. Sugar, Onion, Garlic, Herbs and Spices And Natural Chicken Skin), Dehydrated Bell Peppers and Onion, Spices (Including Paprika, Turmeric And Spice Extracts), Olive Oil, FD&C Yellow#5 and #6, FD&C Red #40 Lake And Silicon Dioxide For Anti Caking." }, [ ""] ], 

[ { lc => "en", ingredients_text => "FD&C Red #40 and silicon dioxide" }, [ "en:e129" ] ], 
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	$product_ref->{categories_tags} = ["en:debug"];
	$product_ref->{"ingredients_text_" . $product_ref->{lc}} = $product_ref->{ingredients_text};

	extract_ingredients_classes_from_text($product_ref);

	is_deeply ($product_ref->{additives_original_tags}, 
		$expected_tags) or diag explain $product_ref;
}

done_testing();
