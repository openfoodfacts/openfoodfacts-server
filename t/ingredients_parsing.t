#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

#use Log::Any::Adapter 'TAP', filter => "none";
#
is (normalize_a_of_b("en", "oil", "olive"), "olive oil");
is (normalize_a_of_b("es", "aceta", "oliva"), "aceta de oliva");
is (normalize_a_of_b("fr", "huile végétale", "olive"), "huile végétale d'olive");

is (normalize_enumeration("en", "phosphates", "calcium and sodium"), "calcium phosphates, sodium phosphates");
is (normalize_enumeration("en", "vegetal oil", "sunflower, palm"), "sunflower vegetal oil, palm vegetal oil");
is (normalize_enumeration("fr", "huile", "colza, tournesol et olive"), "huile de colza, huile de tournesol, huile d'olive");

my @lists =( 
['fr' ,
[
["Sel marin, blé, lécithine de soja", "Sel marin, blé, lécithine de soja"],
["Vitamine A", "Vitamine A"],
["Vitamines A, B et C", "Vitamines, Vitamine A, Vitamine B, Vitamine C"],
["Vitamines (B1, B2, B6, PP)", "Vitamines, Vitamine B1, Vitamine B2, Vitamine B6, Vitamine PP"],
["Huile de palme", "Huile de palme"],
["Huile (palme)", "Huile de palme"],
["Huile (palme, colza)", "Huile de palme, Huile de colza"],
["Huile (palme et colza)", "Huile de palme, Huile de colza"],
["Huiles végétales de palme et de colza", "Huiles végétales de palme, Huiles végétales de colza"],
["Huiles végétales de palme et d'olive", "Huiles végétales de palme, Huiles végétales d'olive"],
["Huiles végétales de palme, de colza et de tournesol", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales de tournesol"],
["Huiles végétales de palme, de colza, de tournesol", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales de tournesol"],
["Huiles végétales de palme, de colza et d'olive en proportion variable", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales d'olive"],
["Huiles végétales de palme, de colza et d'olive", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales d'olive"],
["phosphate et sulfate de calcium", "phosphate de calcium, sulfate de calcium"],
["sulfates de calcium et potassium", "sulfates de calcium, sulfates de potassium"],
["chlorures (sodium et potassium)", "chlorures de sodium, chlorures de potassium"],
["chlorures (sodium, potassium)", "chlorures de sodium, chlorures de potassium"],
["fraises 30%", "fraises 30%"],
["Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales (illipe, mangue, sal, karité et palme en proportions variables), arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja).",

 "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales d'illipe, graisses végétales de mangue, graisses végétales de sal, graisses végétales de karité, graisses végétales de palme, arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja)."],


["graisses végétales (illipe, mangue, sal, karité et palme en proportions variables)", "graisses végétales d'illipe, graisses végétales de mangue, graisses végétales de sal, graisses végétales de karité, graisses végétales de palme"],
["graisses végétales (illipe, mangue, palme)", "graisses végétales d'illipe, graisses végétales de mangue, graisses végétales de palme"],
["graisses végétales (illipe)", "graisses végétales d'illipe"],
["graisses végétales (illipe et sal)", "graisses végétales d'illipe, graisses végétales de sal"],

["gélifiant pectine", "gélifiant : pectine"],
["gélifiant (pectine)", "gélifiant (pectine)"],

["agent de traitement de la farine (acide ascorbique)", "agent de traitement de la farine (acide ascorbique)"],
["lait demi-écrémé", "lait demi-écrémé"],
["Saveur vanille : lait demi-écrémé 77%, sucre", "Saveur vanille : lait demi-écrémé 77%, sucre"],

["colorants alimentaires E (124,122,133,104,110)", "colorants : alimentaires E124, E122, E133, E104, E110"],
["INS 240,241,242b","E240, E241, E242b"],
["colorants E (124, 125, 120 et 122", "colorants : E124, E125, E120, E122"],
["E250-E251", "E250 - E251"],
["E250-E251-E260", "E250 - E251 - E260"],
["E 250b-E251-e.260(ii)", "E250b - E251 - E260(ii)"],
["émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475","émulsifiants : e463, e432, e472 - correcteurs d'acidité : e322/e333, e474 - e475"],
["E100 E122", "E100, E122"],
["E103 et E140", "E103, E140"],
["E103 ET E140", "E103, E140"],
["curcumine et E140", "curcumine, E140"],
["E140 et tartrazine", "E140, tartrazine"],
["Acide citrique, colorant : e120, vitamine C, E-500", "Acide citrique, colorant : e120, vitamine C, E500"],

],
],

['en',
[
["REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), INS 334, INS345", "REAL SUGARCANE, SALT, ANTIOXIDANT (e300), e334, e345"],
],
],

['es',
[
["colores E (120, 124 y 125)", "colores E120, E124, E125"],
["Leche desnatada de vaca, enzima lactasa y vitaminas A, D, E y ácido fólico.","Leche desnatada de vaca, enzima lactasa y vitaminas, vitamina A, vitamina D, vitamina E, ácido fólico."],
],
],

['it',
[
["Vitamine C, D, acido folico, E", "vitamine, vitamin C, vitamin D, acido folico, vitamin E"],
],
],

);

foreach my $list_ref (@lists) {
	my $l = $list_ref->[0];
	foreach my $test_ref (@{$list_ref->[1]}) {
		my $ingredients = $test_ref->[0];
		my $preparsed = preparse_ingredients_text($l, $ingredients);
		print STDERR "ingredients: $ingredients\n";
		print STDERR "preparsed: $preparsed\n";
		my $expected = $test_ref->[1];
		is (lc($preparsed), lc($expected)) or print STDERR "original ingredients: $ingredients ($l)\n";
	}	
}

done_testing();
