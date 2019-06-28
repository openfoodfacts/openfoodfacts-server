#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my @tests = (
[
	{
	lc => "fr",
	ingredients_text => "lait demi-écrémé 67%"
},
[ "en:semi-skimmed-milk"]
],

[
	{ lc => "fr",
	ingredients_text => "Saveur vanille : lait demi-écrémé 77%, sucre"},
[
	"fr:Saveur vanille",
	"en:semi-skimmed-milk",
	"en:sugar",
],
],


[ { lc => "fr", ingredients_text => "lécithine de soja"}, [ "en:soya-lecithin", ], ],

[ { lc => "fr", ingredients_text => "sel et épices"}, [ "en:salt", "en:spice" ], ],
[ { lc => "fr", ingredients_text => "cire d'abeille blanche et jaune"}, [ "en:e901", ], ],
[ { lc => "en", ingredients_text => "sugar and water"}, [ "en:sugar", "en:water"], ],
[ { lc => "en", ingredients_text => "something and something else"}, [ "en:something and something else", ], ],

[ { lc => "es", ingredients_text => "Quinoa"}, [ "en:quinoa", ], ],
[ { lc => "es", ingredients_text => "aromas y antioxidante: ácido cítrico"}, [ "en:flavouring", "en:antioxidant", "en:e330", ], ],
[ { lc => "es", ingredients_text => "aromas y antioxidante"}, [ "en:flavouring", "en:antioxidant", ], ],
[ { lc => "es", ingredients_text => "manzanas 10% y naranjas 5%"}, [ "en:apple", "en:orange", ], ],

[ { lc => "fr", ingredients_text => "viande de porc 50% du poids total"}, [ "en:pork-meat" ], ],
[ { lc => "fr", ingredients_text => "arôme naturel"}, [ "en:natural-flavouring" ], ],
[ { lc => "fr", ingredients_text => "arôme naturel de pomme avec d'autres arômes naturels"}, [ "en:natural-apple-flavouring", "en:natural-flavouring" ], ],
[ { lc => "fr", ingredients_text => "Eau minérale naturelle Volvic (96%), sucre (3,7%), acidifiant : acide citrique, arôme naturel​, extraits de thé (0,02%)"}, [ "en:volvic-natural-mineral-water", "en:sugar", "en:acid", "en:e330", "en:natural-flavouring", "en:tea-extract" ]],

[ { lc => "fr", ingredients_text => "jus de pomme, eau, sucre. Traces possibles de céleri, moutarde et gluten."}, [ "en:apple-juice", "en:water", "en:sugar" ], ],
[ { lc => "en", ingredients_text => "apple juice, water and sugar. May contain celery, mustard and gluten."}, [ "en:apple-juice", "en:water", "en:sugar" ], ],
[ { lc => "es", ingredients_text => "sal y acidulante (ácido cítrico). Puede contener trazas de cacahuete, huevo y frutos de cáscara."}, [ "en:salt", "en:acid", "en:e330" ], ],
[ { lc => "fr", ingredients_text => "100 % semoule de BLE dur de qualité supérieure, Traces de moutarde"}, [ "en:superior-quality-durum-wheat-semolina" ], ],
[ { lc => "fr", ingredients_text => "100 % semoule de BLE dur de qualité supérieure Traces éventuelles d'oeufs"}, [ "en:superior-quality-durum-wheat-semolina",  ], ],
[ { lc => "fr", ingredients_text => "Eau. Traces possibles d'oeuf et de moutarde"}, [ "en:water" ], ],
[ { lc => "fr", ingredients_text => "jus de pomme, eau, sucre, Traces possibles d'oeuf, de moutarde et gluten."}, [ "en:apple-juice", "en:water", "en:sugar" ], ],
[ { lc => "fr", ingredients_text => "Traces de moutarde"}, [  ], ],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is_deeply ($product_ref->{ingredients_original_tags}, 
		$expected_tags) or diag explain $product_ref;
}

my $before = "";
my $after = "";
my $s = "aromas y antioxidante";
if ($s =~ / y /) {
my $ingredient1 = $`;
my $ingredient2 = $';
my $product_ref = { lc => "es" };

 my $canon_ingredient = canonicalize_taxonomy_tag($product_ref->{lc}, "ingredients", $s);

 if (not exists_taxonomy_tag("ingredients", $canon_ingredient)) {

 my $canon_ingredient1 = canonicalize_taxonomy_tag($product_ref->{lc}, "ingredients", $ingredient1);
 my $canon_ingredient2 = canonicalize_taxonomy_tag($product_ref->{lc}, "ingredients", $ingredient2);

 if ( (exists_taxonomy_tag("ingredients", $canon_ingredient1))
 and (exists_taxonomy_tag("ingredients", $canon_ingredient2)) ) {
 $before = $ingredient1;
 $after = $ingredient2;
 }
}
}

print "before: $before - after: $after\n";

done_testing();
