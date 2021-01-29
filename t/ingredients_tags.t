#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';
#use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

init_emb_codes();

# dummy product for testing

my @tests = (
	[ { lc => "en", ingredients_text => "sugar and water"}, [ "en:sugar", "en:water"], ],
	[ { lc => "en", ingredients_text => "something and something else"}, [ "en:something and something else", ], ],
	[ { lc => "en", ingredients_text => "apple juice, water and sugar. May contain celery, mustard and gluten."}, [ "en:apple-juice", "en:water", "en:sugar" ], ],

	[ { lc => "fr", ingredients_text => "lait demi-écrémé 67%" }, ["en:semi-skimmed-milk"] ],
	[ { lc => "fr", ingredients_text => "Saveur vanille : lait demi-écrémé 77%, sucre" }, [ "fr:Saveur vanille", "en:sugar", "en:semi-skimmed-milk" ], ],
	[ { lc => "fr", ingredients_text => "lécithine de soja"}, [ "en:soya-lecithin", ], ],
	[ { lc => "fr", ingredients_text => "sel et épices"}, [ "en:salt", "en:spice" ], ],
	[ { lc => "fr", ingredients_text => "cire d'abeille blanche et jaune"}, [ "en:e901", ], ],
	[ { lc => "fr", ingredients_text => "viande de porc 50% du poids total"}, [ "en:pork-meat" ], ],
	[ { lc => "fr", ingredients_text => "arôme naturel"}, [ "en:natural-flavouring" ], ],
	[ { lc => "fr", ingredients_text => "arôme naturel de pomme avec d'autres arômes naturels"}, [ "en:natural-apple-flavouring", "en:natural-flavouring" ], ],
	[ { lc => "fr", ingredients_text => "Eau minérale naturelle Volvic (96%), sucre (3,7%), acidifiant : acide citrique, arôme naturel​, extraits de thé (0,02%)"}, [ "en:volvic-natural-mineral-water", "en:sugar", "en:acid", "en:natural-flavouring", "en:tea-extract", "en:e330" ], ],
	[ { lc => "fr", ingredients_text => "jus de pomme, eau, sucre. Traces possibles de céleri, moutarde et gluten."}, [ "en:apple-juice", "en:water", "en:sugar" ], ],
	[ { lc => "fr", ingredients_text => "100 % semoule de BLE dur de qualité supérieure, Traces de moutarde"}, [ "en:superior-quality-durum-wheat-semolina" ], ],
	[ { lc => "fr", ingredients_text => "100 % semoule de BLE dur de qualité supérieure Traces éventuelles d'oeufs"}, [ "en:superior-quality-durum-wheat-semolina",  ], ],
	[ { lc => "fr", ingredients_text => "Eau. Traces possibles d'oeuf et de moutarde"}, [ "en:water" ], ],
	[ { lc => "fr", ingredients_text => "jus de pomme, eau, sucre, Traces possibles d'oeuf, de moutarde et gluten."}, [ "en:apple-juice", "en:water", "en:sugar" ], ],
	[ { lc => "fr", ingredients_text => "Traces de moutarde"}, [  ], ],

	[ { lc => "es", ingredients_text => "Quinoa"}, [ "en:quinoa", ], ],
	[ { lc => "es", ingredients_text => "aromas y antioxidante: ácido cítrico"}, [ "en:flavouring", "en:antioxidant", "en:e330", ], ],
	[ { lc => "es", ingredients_text => "aromas y antioxidante"}, [ "en:flavouring", "en:antioxidant", ], ],
	[ { lc => "es", ingredients_text => "manzanas 10% y naranjas 5%"}, [ "en:apple", "en:orange", ], ],
	[ { lc => "es", ingredients_text => "sal y acidulante (ácido cítrico). Puede contener trazas de cacahuete, huevo y frutos de cáscara."}, [ "en:salt", "en:acid", "en:e330" ], ],

	[ { lc => "fi", ingredients_text => "valkosipulijauhe ja suola"}, [ "en:garlic-powder", "en:salt", ], ],
	[ { lc => "fi", ingredients_text => "Sokeri, Mausteet, Hapettumisenestoaine (Askorbiinihappo), Säilöntäaine (Natriumnitriitti). Saattaa sisältää pieniä määriä sinappi ja selleri"}, [ "en:sugar", "en:spice", "en:antioxidant", "en:preservative", "en:e300", "en:e250" ], ],
	[ { lc => "fi", ingredients_text => "Aspartaami ja Asesulfaami K"}, [ "en:e951", "en:e950" ], ],
	[ { lc => "fi", ingredients_text => "Värit (Punajuuriväri, Paprikauute, Kurkumiini)"}, [ "en:colour", "en:e162", "en:e160c", "en:e100" ], ],
	[ { lc => "fi", ingredients_text => "Vitamiinit (A, B2, B12, C, D2)"}, [ "en:vitamins", "en:vitamin-a", "en:e101", "en:vitamin-b12", "en:e300",  "en:ergocalciferol"], ],

	[ { lc => "it", ingredients_text => "sale e spezie"}, [ "en:salt", "en:spice" ], ],
	[ { lc => "it", ingredients_text => "Puo contenere tracce di frutta a guscio, sesamo, soia e uova"}, [  ], ],

	[ { lc => "de", ingredients_text => "Zucker, Gewürze, Antioxidations-mittel: Ascorbinsäure, Konservierungsstoff: Natriumnitrit. Kann Spuren von Senf und Sellerie enthalten."}, [ "en:sugar", "en:spice", "en:antioxidant", "en:preservative", "en:e300", "en:e250" ], ],

	[ { lc => "fr", ingredients_text => "Lait de vache pasteurisé (origine: France), crème pasteurisée (origine France), sel (origine UE), ferments."}, [ 'en:pasteurised-cow-s-milk', 'en:pasteurized-cream', 'en:salt', 'en:ferment'  ], ],
	[ { lc => "en", ingredients_text => "Organically grown green tea"}, [ "en:green-tea" ], ],
	[ { lc => "fr", ingredients_text => "Céleri - rave, choux - fleurs, béta - carotène"}, [ "en:celeriac", "en:cauliflower", "en:e160ai" ], ],
	[ { lc => "fr", ingredients_text => "Pâte de cacao de Madagascar, café"},["en:cocoa-paste", "en:coffee"]],
	[ { lc => "es", ingredients_text => "Vinagre, chile rojo y sal."},["en:vinegar", "en:red-chili-pepper", "en:salt"]],
	[ { lc => "fr", ingredients_text => "Farine de blé 56 g* ; beurre concentré 25 g* (soit 30 g* en beurre reconstitué); sucre 22 g* ; œufs frais 2 g"}, [ "en:wheat-flour", "en:butterfat", "en:sugar", "en:fresh-egg" ], ],
	[ { lc => "fr", ingredients_text => "Farine de blé 60%. Les pourcentages sont exprimés sur le produit avant cuisson. Sucre 40% (% exprimé sur la pâte)"}, [ "en:wheat-flour", "en:sugar" ], ],
	[ { lc => "fr", ingredients_text => "Artichaut coupé"}, [ "en:artichoke" ], ],
	[ { lc => "fr", ingredients_text => "Artichaut coupe"}, [ "en:artichoke" ], ],
	[ { lc => "fr", ingredients_text => "Banane cuite"}, [ "en:banana" ], ],
	[ { lc => "fr", ingredients_text => "Banane coupée cuite"}, [ "en:banana" ], ],
	[ { lc => "fr", ingredients_text => "Fromage étrange à pâte cuite"}, [ "fr:Fromage étrange à pâte cuite" ], ],
	[ { lc => "fr", ingredients_text => "Banane coupée et cuite au naturel"}, [ "en:banana" ], ],
	[ { lc => "fr", ingredients_text => "Lamelles de bananes déshydratées"}, [ "en:banana" ], ],
	[ { lc => "fr", ingredients_text => "émincé de filet de poulet traité en salaison cuit rôti, Pourcentages exprimés sur les pâtes alimentaires aux oeufs "}, ["fr:filet-de-poulet-traite-en-salaison-cuit" ], ],
	[ { lc => "fr", ingredients_text => "sucre 22g**"}, [ "en:sugar" ], ],

	# [ { lc => "de", ingredients_text => "Wasser, Kohlensäure, Farbstoff Zuckerkulör E 150d, Süßungsmittel Aspartam* und Acesulfam-K, Säuerungsmittel Phosphorsäure und Citronensäure, Säureregulator Natriumcitrat, Aroma Koffein, Aroma. enthält eine Phenylalaninquelle"}, [ "en:sugar" ], ],
	[ { lc => "de", ingredients_text => "Wasser, Kohlensäure, Süßungsmittel Aspartam* und Acesulfam-K. *enthält eine Phenylalaninquelle"}, [ "en:water", "en:e290", "en:sweetener", "en:e951", "en:e950" ], ],
	[ { lc => "de", ingredients_text => "Aspartam und Acesulfam-K"}, [ "en:e951", "en:e950" ], ],
	[ { lc => "de", ingredients_text => "Farbstoffe (Betenrot, Paprikaextrakt, Kurkumin)"}, [ "en:colour", "en:e162", "en:e160c", "en:e100" ], ],

	[ { lc => "fr", ingredients_text => "graisse végétale bio (colza)"}, ["en:colza-oil"]],

	[ { lc => "fr", ingredients_text => "lait cru de lapin"}, ["fr:lait cru de lapin"]],
	[ { lc => "fr", ingredients_text => "aubergine crue, dés de jambon cru coupés, jambon de montagne cru"}, ["en:aubergine", "en:raw-ham", "fr:jambon de montagne cru"]],
	[ { lc => "en", ingredients_text => "raw cane sugar, raw bananas, raw sliced tomatoes, cooked raw sugar"}, ["en:unrefined-cane-sugar", "en:banana", "en:tomato", "en:unrefined-sugar"]],

	[ { lc => "en", ingredients_text => "vegetable oil (coconut & rapeseed)" }, ["en:vegetable-oil", "en:coconut", "en:rapeseed"]],

	[ { lc => "fr", ingredients_text => "amidon de blé. traces de _céleri_."}, ["en:wheat-starch"]],

	[ { lc => "fr", ingredients_text => "Fraises. Contient du lait et des noix. Peut contenir : crustacés, céleri et moutarde."}, ["en:strawberry"]],
	[ { lc => "en", ingredients_text => "Apples. Contains: milk, nuts and mustard. May contains traces of celery."}, ["en:apple"]],

	# Currently "Kann [allergens] enthalten" is not supported
	# [ { lc => "de", ingredients_text => "Paprikaextrakt. Kann Haselnüsse, Mandeln enthalten."}, ["en:e160c"]],

	# issue with "Organic 100% juice" being turned into the en:pure-juice label
	# and all sub-ingredients being discarded
	[ { lc => "en", ingredients_text => "Organic 100% juice (organic pear, organic apple), natural flavor."}, ['en:juice','en:natural-flavouring','en:pear','en:apple']],
	[ { lc => "en", ingredients_text => "au jus (beef stock, water)"}, [ 'en:au jus', 'en:beef-broth', 'en:water' ]],
	# pure juice is a label, and currently not an ingredient
	# it makes the sub ingredients being discarded
	# recognize unknown ingredients that are labels as labels only if they
	# don't have sub-ingredients
	[ { lc => "en", ingredients_text => "pure juice (orange juice)"}, [ 'en:pure juice', 'en:orange-juice' ]],
	# using vegan in case we add "pure juice" as an ingredient at some point
	[ { lc => "en", ingredients_text => "vegan (orange juice)"}, [ 'en:vegan', 'en:orange-juice' ]],

	# Spanish and is "e" before "i" or "hi"
	[ { lc => "es", ingredients_text => "agua de coco e hielo"} , ['en:coconut-water', 'en:ice']],

	# Additive number + name
	[ { lc => "fr", ingredients_text => "acide citrique E330"} , ["en:e330"]],
	[ { lc => "fr", ingredients_text => "E330 acide citrique"} , ["en:e330"]],
	[ { lc => "en", ingredients_text => "E-330 citric acid"} , ["en:e330"]],
	# citric acid E-330 does not work, as "acid" is an additive class
	# and it currently gets turned into citric acid: E-330
	# (which is not that bad)
	#[ { lc => "en", ingredients_text => "citric acid E-330"} , ["en:e330"]],
	[ { lc => "en", ingredients_text => "tartrazine E-102"} , ["en:e102"]],
	# caramel: e150, match e150c
	[ { lc => "es", ingredients_text => "caramelo E-150c"} , ["en:e150c"]],
	# mismatch between name and number
	[ { lc => "fr", ingredients_text => "acide citrique E120"} , ["fr:acide citrique e120"]],
	
	# removal of "allergy advice..." in %ignore_regexps
	[ { lc => "en", ingredients_text => "salt, spice. allergy advice! for allergens, see ingredients in bold, water."}, ['en:salt','en:spice','en:water']],
	[ { lc => "en", ingredients_text => "salt, spice. allergy advice: for allergens, see ingredients in bold. May contain traces of nuts."}, ['en:salt','en:spice']],
	[ { lc => "en", ingredients_text => "salt, spice. allergen advice: for allergens including cereals containing gluten, see ingredients in bold. May contain traces of nuts."}, ['en:salt','en:spice']],
	[ { lc => "fr", ingredients_text => "sucre, lécithine de soja, sel. Allergènes : voir les ingrédients en gras. Traces éventuelles de gluten et de fruits à coque."}, ['en:sugar', 'en:soya-lecithin', 'en:salt']],

	[ { lc => "nl", ingredients_text => "romano"}, ['nl:romano']],
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	print STDERR "ingredients_text: " . $product_ref->{ingredients_text} . "\n";

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
