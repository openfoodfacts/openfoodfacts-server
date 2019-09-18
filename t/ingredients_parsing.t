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

use Log::Any::Adapter 'TAP', filter => "none";

is (normalize_a_of_b("en", "oil", "olive"), "olive oil");
is (normalize_a_of_b("es", "aceta", "oliva"), "aceta de oliva");
is (normalize_a_of_b("fr", "huile végétale", "olive"), "huile végétale d'olive");

is (normalize_enumeration("en", "phosphates", "calcium and sodium"), "calcium phosphates, sodium phosphates");
is (normalize_enumeration("en", "vegetal oil", "sunflower, palm"), "sunflower vegetal oil, palm vegetal oil");
is (normalize_enumeration("fr", "huile", "colza, tournesol et olive"), "huile de colza, huile de tournesol, huile d'olive");

is (separate_additive_class("fr", "colorant", " ", "", "naturel"), "colorant ");
is (separate_additive_class("fr", "colorant", " ", "", "carmins"), "colorant : ");
is (separate_additive_class("fr", "colorant", " ", "", "E120, sel"), "colorant : ");
is (separate_additive_class("fr", "colorant", " ", "", "E120 et E150b"), "colorant : ");
is (separate_additive_class("fr", "colorant", " ", "", "caramel au sulfite d'ammonium"), "colorant : ");
is (separate_additive_class("fr", "colorant", " ", "", "caramel au sulfite d'ammonium et rocou"), "colorant : ");


my @lists =(

	["fr","Sel marin, blé, lécithine de soja", "Sel marin, blé, lécithine de soja"],
	["fr","Vitamine A", "Vitamine A"],
	["fr","Vitamines A, B et C", "Vitamines, Vitamine A, Vitamine B, Vitamine C"],
	["fr","Vitamines (B1, B2, B6, PP)", "Vitamines, Vitamine B1, Vitamine B2, Vitamine B6, Vitamine PP"],
	["fr","Huile de palme", "Huile de palme"],
	["fr","Huile (palme)", "Huile de palme"],
	["fr","Huile (palme, colza)", "Huile de palme, Huile de colza"],
	["fr","Huile (palme et colza)", "Huile de palme, Huile de colza"],
	["fr","Huiles végétales de palme et de colza", "Huiles végétales de palme, Huiles végétales de colza"],
	["fr","Huiles végétales de palme et d'olive", "Huiles végétales de palme, Huiles végétales d'olive"],
	["fr","Huiles végétales de palme, de colza et de tournesol", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales de tournesol"],
	["fr","Huiles végétales de palme, de colza, de tournesol", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales de tournesol"],
	["fr","Huiles végétales de palme, de colza et d'olive en proportion variable", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales d'olive"],
	["fr","Huiles végétales de palme, de colza et d'olive", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales d'olive"],
	["fr","phosphate et sulfate de calcium", "phosphate de calcium, sulfate de calcium"],
	["fr","sulfates de calcium et potassium", "sulfates de calcium, sulfates de potassium"],
	["fr","chlorures (sodium et potassium)", "chlorures de sodium, chlorures de potassium"],
	["fr","chlorures (sodium, potassium)", "chlorures de sodium, chlorures de potassium"],
	["fr","fraises 30%", "fraises 30%"],
	["fr","Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales (illipe, mangue, sal, karité et palme en proportions variables), arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja).", "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales d'illipe, graisses végétales de mangue, graisses végétales de sal, graisses végétales de karité, graisses végétales de palme, arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja)."],
	["fr","graisses végétales (illipe, mangue, sal, karité et palme en proportions variables)", "graisses végétales d'illipe, graisses végétales de mangue, graisses végétales de sal, graisses végétales de karité, graisses végétales de palme"],
	["fr","graisses végétales (illipe, mangue, palme)", "graisses végétales d'illipe, graisses végétales de mangue, graisses végétales de palme"],
	["fr","graisses végétales (illipe)", "graisses végétales d'illipe"],
	["fr","graisses végétales (illipe et sal)", "graisses végétales d'illipe, graisses végétales de sal"],
	["fr","gélifiant pectine", "gélifiant : pectine"],
	["fr","gélifiant (pectine)", "gélifiant (pectine)"],
	["fr","agent de traitement de la farine (acide ascorbique)", "agent de traitement de la farine (acide ascorbique)"],
	["fr","lait demi-écrémé", "lait demi-écrémé"],
	["fr","Saveur vanille : lait demi-écrémé 77%, sucre", "Saveur vanille : lait demi-écrémé 77%, sucre"],
	["fr","colorants alimentaires E (124,122,133,104,110)", "colorants : alimentaires E124, E122, E133, E104, E110"],
	["fr","INS 240,241,242b","E240, E241, E242b"],
	["fr","colorants E (124, 125, 120 et 122", "colorants : E124, E125, E120, E122"],
	["fr","E250-E251", "E250 - E251"],
	["fr","E250-E251-E260", "E250 - E251 - E260"],
	["fr","E 250b-E251-e.260(ii)", "E250b - E251 - E260(ii)"],
	["fr","émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475","émulsifiants : e463, e432, e472 - correcteurs d'acidité : e322/e333, e474 - e475"],
	["fr","E100 E122", "E100, E122"],
	["fr","E103 et E140", "E103, E140"],
	["fr","E103 ET E140", "E103, E140"],
	["fr","curcumine et E140", "curcumine, E140"],
	["fr","E140 et tartrazine", "E140, tartrazine"],
	["fr","Acide citrique, colorant : e120, vitamine C, E-500", "Acide citrique, colorant : e120, vitamine C, E500"],
	["fr","poudres à lever (carbonates acides d’ammonium et de sodium, acide citrique)", "poudres à lever (carbonates acides d'ammonium, carbonates acides de sodium, acide citrique)"],

	["en","REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), INS 334, INS345", "REAL SUGARCANE, SALT, ANTIOXIDANT (e300), e334, e345"],

	["es","colores E (120, 124 y 125)", "colores E120, E124, E125"],
	["es","Leche desnatada de vaca, enzima lactasa y vitaminas A, D, E y ácido fólico.","Leche desnatada de vaca, enzima lactasa y vitaminas, vitamina A, vitamina D, vitamina E, ácido fólico."],
	["es","Leche desnatada, leche desnatada en polvo, zumo de lima, almidón de maíz, extracto de ginseng 0,19%, aromas, fermentos lácticos con Lcasei, colorante: caramelo natural, edulcorantes: sucralosa y acesulfamo K, estabilizante: goma xantana, vitaminas: D, B6, ácido fólico y B12 Origen de la feche. España. Preparación: Agitar antes de abrir.",
	"Leche desnatada, leche desnatada en polvo, zumo de lima, almidón de maíz, extracto de ginseng 0,19%, aromas, fermentos lácticos con Lcasei, colorante: caramelo natural, edulcorantes: sucralosa y acesulfamo K, estabilizante: goma xantana, vitaminas, vitamina D, vitamina B6, ácido fólico, vitamina B12 Origen de la feche. España. Preparación: Agitar antes de abrir."],
	["es","edulcorantes (acesulfamo K y sucralosa) y vitaminas (riboflavina (vitamina B2) y cianocobalamina vitamina B12))",
	"edulcorantes (acesulfamo K y sucralosa), vitaminas (riboflavina (vitamina B2), cianocobalamina vitamina B12))"],
	["es","aceites vegetales [aceite de girasol (70%) y aceite de oliva virgen (30%)] y sal",
	"aceites vegetales [aceite de girasol (70%), aceite de oliva virgen (30%)], sal"],
	["es","Trazas de cacahuete, huevo y frutos de cáscara.","Trazas : cacahuete, Trazas : huevo, Trazas : frutos de cáscara."],
	["es","sal y acidulante (ácido cítrico). Puede contener trazas de cacahuete, huevo y frutos de cáscara.","sal y acidulante (ácido cítrico). Trazas : cacahuete, Trazas : huevo, Trazas : frutos de cáscara."],

	["fr","arôme naturel de citron-citron vert et d'autres agrumes", "arôme naturel de citron, arôme naturel de citron vert, arôme naturel d'agrumes"],
	["fr","arômes naturels de citron et de limette","arômes naturels de citron, arômes naturels de limette"],
	["fr","arôme naturel de pomme avec d'autres arômes naturels","arôme naturel de pomme, arômes naturels"],
	["fr","jus de pomme, eau, sucre. Traces de lait.","jus de pomme, eau, sucre. traces éventuelles : lait."],
	["fr","jus de pomme, eau, sucre. Traces possibles de céleri, moutarde et gluten.","jus de pomme, eau, sucre. Traces éventuelles : céleri, Traces éventuelles : moutarde, Traces éventuelles : gluten."],
	["fr","jus de pomme, eau, sucre. Traces possibles de céleri, de moutarde et gluten.","jus de pomme, eau, sucre. Traces éventuelles : céleri, Traces éventuelles : moutarde, Traces éventuelles : gluten."],
	["fr","Traces de moutarde","traces éventuelles : moutarde."],
	["fr","Sucre de canne Traces éventuelles d'oeufs","Sucre de canne, Traces éventuelles : oeufs."],
	["fr","huile végétale de tournesol et/ou colza","huile végétale de tournesol, huile végétale de colza"],

	["de","Zucker. Kann Spuren von Sellerie.","zucker. spuren : sellerie."],
	["de","Zucker. Kann Spuren von Senf und Sellerie.","zucker. spuren : senf, spuren : sellerie."],
	["de","Zucker. Kann Spuren von Senf und Sellerie enthalten","zucker. spuren : senf, spuren : sellerie."],

	["it","Puo contenere tracce di frutta a guscio, sesamo, soia e uova","tracce : frutta a guscio, tracce : sesamo, tracce : soia, tracce : uova."],
	["it","Il prodotto può contenere tracce di GRANO, LATTE, UOVA, FRUTTA A GUSCIO e SOIA.","tracce : grano, tracce : latte, tracce : uova, tracce : frutta a guscio, tracce : soia."],

	["fr","Jus de pomme*** 68%, jus de poire***32% *** Ingrédients issus de l'agriculture biologique","jus de pomme bio 68%, jus de poire bio 32%"],
	["fr","Pâte de cacao°* du Pérou 65 %, sucre de canne°*, beurre de cacao°*, sel *, lait °. °Issus de l'agriculture biologique (100 %). *Issus du commerce équitable (100 % du poids total avec 93 % SPP).","Pâte de cacao Bio Commerce équitable du Pérou 65 %, sucre de canne Bio Commerce équitable, beurre de cacao Bio Commerce équitable, sel Commerce équitable, lait Bio."],

	["fr","p\x{e2}te de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce \x{e9}quitable et de l'agriculture biologique (100% du poids total).","pâte de cacao Commerce équitable Bio de Madagascar 75%, sucre de canne Commerce équitable Bio, beurre de cacao Commerce équitable Bio."],

	["fr","Céleri - rave 21% - Eau, légumes 33,6% (carottes, céleri - rave, poivrons rouges 5,8% - haricots - petits pois bio - haricots verts - courge - radis, pommes de terre - patates - fenouil - cerfeuil tubéreux - persil plat)","Céleri-rave 21% - Eau, légumes 33,6% (carottes, céleri-rave, poivrons rouges 5,8% - haricots - petits pois bio - haricots verts - courge - radis, pommes de terre - patates - fenouil - cerfeuil tubéreux - persil plat)"],
	["fr","poudres à lever : carbonates d'ammonium - carbonates de sodium - phosphates de calcium, farine, sel","poudres à lever : carbonates d'ammonium - carbonates de sodium - phosphates de calcium, farine, sel"],
	["en","FD&C Red #40 Lake and silicon dioxide","FD&C Red #40 Lake and silicon dioxide"],
	["fr","Lait pasteurisé à 1,1% de Mat. Gr.","Lait pasteurisé à 1,1% de Matières Grasses"],
	["fr","matière grasse végétale (palme) raffinée","matière grasse végétale de palme raffinée"],
	["fr","huile d'olive vierge, origan", "huile d'olive vierge, origan"],
	["fr","huile de tournesol, cacao maigre en poudre 5.2%", "huile de tournesol, cacao maigre en poudre 5.2%"],

	["pl","regulatory kwasowości: kwas cytrynowy i cytryniany sodu.","regulatory kwasowości: kwas cytrynowy i cytryniany sodu."],

	["de","Wasser, Kohlensäure, Farbstoff Zuckerkulör E 150d, Süßungsmittel Aspartam* und Acesulfam-K, Säuerungsmittel Phosphorsäure und Citronensäure, Säureregulator Natriumcitrat, Aroma Koffein, Aroma. enthält eine Phenylalaninquelle", "Wasser, Kohlensäure, Farbstoff : Zuckerkulör e150d, Süßungsmittel : Aspartam* und Acesulfam-K, Säuerungsmittel : Phosphorsäure und Citronensäure, Säureregulator : Natriumcitrat, Aroma Koffein, Aroma. enthält eine Phenylalaninquelle"],
	["de","Farbstoffe Betenrot, Paprikaextrakt, Kurkumin","farbstoffe : betenrot, paprikaextrakt, kurkumin"],

	["fr","graisse végétale bio (colza)","graisse végétale bio de colza"],
	["fr","huiles végétales* (huile de tournesol*, huile de colza*). *Ingrédients issus de l'agriculture biologique","huiles végétales bio (huile de tournesol bio, huile de colza bio )."],

);

foreach my $test_ref (@lists) {
	my $l = $test_ref->[0]; # Language
	my $ingredients = $test_ref->[1];
	my $preparsed = preparse_ingredients_text($l, $ingredients);
	print STDERR "Ingredients ($l): $ingredients\n";
	print STDERR "Preparsed: $preparsed\n";
	my $expected = $test_ref->[2];
	is (lc($preparsed), lc($expected)) or print STDERR "Original ingredients: $ingredients ($l)\n";
}


done_testing();
