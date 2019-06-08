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
