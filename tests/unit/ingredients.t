#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Test qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (

	# FR

	[
		'fr-chocolate-cake',
		{
			lc => "fr",
			ingredients_text =>
				"farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"
		}
	],

	[
		'fr-palm-kernel-fat',
		{
			lc => "fr",
			ingredients_text => "graisse de palmiste"
		}
	],

	[
		'fr-marmelade',
		{
			lc => "fr",
			ingredients_text =>
				"Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales (illipe, mangue, sal, karité et palme en proportions variables), arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja)."
		}
	],

	# test synonyms for flavouring/flavour/flavor/flavoring
	[
		'en-flavour-synonyms',
		{
			lc => "en",
			ingredients_text => "Natural orange flavor, Lemon flavouring"
		}
	],
	# test synonyms for emulsifier/emulsifying - also checking if synonyms are case sensitive
	[
		'en-emulsifier-synonyms',
		{
			lc => "en",
			ingredients_text => "Emulsifying (INS 471, INS 477) & Stabilizing Agents (INS 412, INS 410)"
		}
	],
	# FR * label
	[
		"fr-starred-label",
		{
			lc => "fr",
			ingredients_text =>
				"pâte de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce équitable et de l'agriculture biologique (100% du poids total)."
		}
	],

	# FR additive
	[
		"fr-additive",
		{
			lc => "fr",
			ingredients_text => "gélifiant (pectines)",
		}
	],

	# FR percents
	[
		"fr-percents",
		{
			lc => "fr",
			ingredients_text => "Fraise 12,3% ; Orange 6.5%, Pomme (3,5%)",
		}
	],

	# FR origins labels
	[
		"fr-origins-labels",
		{
			lc => "fr",
			ingredients_text =>
				"Fraise origine France, Cassis (origine Afrique du Sud), Framboise (origine : Belgique), Pamplemousse bio, Orange (bio), Citron (issue de l'agriculture biologique), cacao et beurre de cacao (commerce équitable), cerises issues de l'agriculture biologique",
		}
	],

	# FR percents origins
	[
		"fr-percents-origins",
		{
			lc => "fr",
			ingredients_text =>
				"80% jus de pomme biologique, 20% de coing biologique, sel marin, 98% chlorure de sodium (France, Italie)",
		}
	],

	[
		"fr-percents-origins-2",
		{
			lc => "fr",
			ingredients_text =>
				"émulsifiant : lécithines (tournesol), arôme)(UE), farine de blé 33% (France), sucre, beurre concentré* 6,5% (France)",
		}
	],

	# FR vegetal origin
	[
		"fr-vegetal-origin",
		{
			lc => "fr",
			ingredients_text =>
				"mono - et diglycérides d'acides gras d'origine végétale, huile d'origine végétale, gélatine (origine végétale)",
		}
	],

	# from vegetal origin
	[
		"en-vegetal-ingredients",
		{
			lc => "en",
			ingredients_text =>
				"Gelatin (vegetal), Charcoal (not from animals), ferments (from plants), non-animal rennet, flavours (derived from plants)",
		}
	],

	# FR labels
	[
		"fr-labels",
		{
			lc => "fr",
			ingredients_text => "jus d'orange (sans conservateur), saumon (msc), sans gluten",
		}
	],

	# Processing

	[
		"fr-processing-multi",
		{
			lc => "fr",
			ingredients_text =>
				"tomates pelées cuites, rondelle de citron, dés de courgette, lait cru, aubergines crues, jambon cru en tranches",
		}
	],

	# Bugs #3827, #3706, #3826 - truncated purée

	[
		"fr-truncated-puree",
		{
			lc => "fr",
			ingredients_text => "19% purée de tomate, 90% boeuf, 100% pur jus de fruit, 45% de matière grasses",
		}
	],

	# FI additives, percent

	[
		"fi-additives-percents",
		{
			lc => "fi",
			ingredients_text =>
				"jauho (12%), suklaa (kaakaovoi (15%), sokeri [10%], maitoproteiini, kananmuna 1%) - emulgointiaineet : E463, E432 ja E472 - happamuudensäätöaineet : E322/E333 E474-E475, happo (sitruunahappo, fosforihappo) - suola"
		}
	],

	# FI percents

	[
		"fi-percents",
		{
			lc => "fi",
			ingredients_text => "Mansikka 12,3% ; Appelsiini 6.5%, Omena (3,5%)",
		}
	],

	# FI additives and origins

	[
		"fi-additive",
		{
			lc => "fi",
			ingredients_text => "hyytelöimisaine (pektiinit)",
		}
	],

	[
		"fi-origins",
		{
			lc => "fi",
			ingredients_text =>
				"Mansikka alkuperä Suomi, Mustaherukka (alkuperä Etelä-Afrikka), Vadelma (alkuperä : Ruotsi), Appelsiini (luomu), kaakao ja kaakaovoi (reilu kauppa)",
		}
	],

	[
		"fi-additives-origins",
		{
			lc => "fi",
			ingredients_text => "emulgointiaine : auringonkukkalesitiini, aromi)(EU), vehnäjauho 33% (Ranska), sokeri",
		}
	],

	# FI labels
	[
		"fi-labels",
		{
			lc => "fi",
			ingredients_text => "appelsiinimehu (säilöntäaineeton), lohi (msc), gluteeniton",
		}
	],

	# bug #3432 - mm. should not match Myanmar
	[
		"fi-do-not-match-myanmar",
		{
			lc => "fi",
			ingredients_text => "mausteet (mm. kurkuma, inkivääri, paprika, valkosipuli, korianteri, sinapinsiemen)",
		},
	],

	# FI - organic label as part of the ingredient
	[
		"fi-organic-label-part-of-ingredient",
		{
			lc => "fi",
			ingredients_text => "vihreä luomutee, luomumaito, luomu ohramallas",
		}
	],

	# a label and multiple origins in parenthesis -- does not work yet
	[
		"fr-label-and-multiple-origins",
		{
			lc => "fr",
			ingredients_text => "oeufs (d'élevage au sol, Suisse, France)",
		}
	],

	# Do not mistake single letters for labels, bug #3300
	[
		"xx-single-letters",
		{
			lc => "fr",
			ingredients_text =>
				"a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,0,1,2,3,4,5,6,7,8,9,10,100,1000,vt,leaf,something(bio),somethingelse(u)",
		}
	],

	# Origins with regions
	[
		"en-origins",
		{
			lc => "en",
			ingredients_text =>
				"California almonds, South Carolina peaches, South Carolina black olives, fresh tomatoes (California), Oranges (Florida, USA), orange juice concentrate from Florida",
		},
	],
	# Do not match U to US -> United States (by removing the "plural" S from US)
	[
		"en-origins-u",
		{
			lc => "en",
			ingredients_text => "Something (U)"
		}
	],
	# French origins
	[
		"fr-origins",
		{
			lc => "fr",
			ingredients_text =>
				"Fraises de Bretagne, beurre doux de Normandie, tomates cerises (Bretagne), pommes (origine : Normandie)"
		}
	],
	[
		"fr-origins-agriculture-ue-non-ue",
		{
			lc => "fr",
			ingredients_text => "Fraises (agriculture UE/Non UE)"
		}
	],
	[
		"fr-origins-emmental-allemagne-france-pays-bas-contient-lait",
		{
			lc => "fr",
			ingredients_text => "emmental (Allemagne, France, Pays-Bas, contient lait)",
		}
	],

	# ES percent, too many loops

	[
		"es-percent-loop",
		{
			lc => "es",
			ingredients_text =>
				"Tomate, pimiento (12%), atún (10%), aceite de oliva virgen extra (4%), huevo (3%), cebolla (3%), azúcar, almidón de maíz, sal y acidulante: ácido cítrico.",
		}
	],

	# Ingredient that is also an existing label - https://github.com/openfoodfacts/openfoodfacts-server/issues/4907

	[
		"fr-huile-de-palme-certifiee-durable",
		{
			lc => "fr",
			ingredients_text => "huiles végétales non hydrogénées (huile de palme certifiée durable, huile de colza)",
		},
	],

	# Russian oil parsing
	[
		"ru-russian-oil",
		{
			lc => "ru",
			ingredients_text => "масло растительное (подсолнечное, соевое), Масло (соевое)",
		},
	],

	# Spanish label with "e" meaning "y"
	[
		"es-procedente-e-agricultura-biologica",
		{
			lc => "es",
			ingredients_text =>
				"Leche entera pasteurizada de vaca*, fermentos lácticos de gránulos de kéfir. *Procedente e agricultura ecológica.",
		},
	],

	# Irradiated spices
	[
		"fr-epices-irradiees",
		{
			lc => "fr",
			ingredients_text => "Epices irradiées, sésame (irradié), thym (non-irradié)",
		}
	],

	# E471 (niet dierlijk)
	[
		"nl-e471-niet-dierlijk",
		{
			lc => "nl",
			ingredients_text => "E471 (niet dierlijk)",
		}
	],

	# Specific ingredients mentions
	[
		"fr-specific-ingredients",
		{
			lc => "fr",
			ingredients_text =>
				"Sucre de canne*, abricots*, jus de citrons concentré*, gélifiant : pectines de fruits. *biologique.
Préparée avec 50 grammes de fruits pour 100gr de produit fini.
Préparé avec 32,5 % de légumes -
Préparés avec 25,2g de tomates.
PREPARE AVEC 30% DE TRUC INCONNU.
Teneur totale en sucres : 60 g pour 100 g de produit fini.
Teneur en lait: minimum 40%.
Teneur minimum en jus de fruits 35 grammes pour 100 grammes de produit fini.
Présence exceptionnelle possible de noyaux ou de morceaux de noyaux.
Origine des abricots: Provence.
Teneur en citron de 5,5%",
		}
	],

	[
		"en-specific-ingredients",
		{
			lc => "en",
			ingredients_text => "Milk, cream, sugar. Sugar content: 3 %. Total milk content: 75.2g",
		},
	],

	[
		"en-specific-ingredients-multiple-strings-of-one-ingredient",
		{
			lc => "en",
			ingredients_text => "Milk, cream, sugar. Total milk content: 88%. Origin of milk: UK",
		},
	],

	# Labels that indicate the origin of some ingredients
	[
		"fr-viande-porcine-francaise",
		{
			lc => "fr",
			ingredients_text => "endives 40%, jambon cuit, jaunes d'oeufs, sel",
			labels => "viande porcine française, oeufs de France",
		}
	],

	# Ingredients analysis: keep track of unknown ingredients even if a product is non vegan
	[
		"en-ingredients-analysis-unknown-ingredients",
		{
			lc => "en",
			ingredients_text =>
				"milk, some unknown ingredient, another unknown ingredient, salt, sugar, pepper, spices, water",
		}
	],

	# origins field
	# also test an ingredient with 2 words: bell peppers, which used to break.
	[
		"en-origin-field",
		{
			lc => "en",
			ingredients_text =>
				"Strawberries (Spain), raspberries, blueberries, gooseberries, white peaches, bell peppers. Origin of bell peppers: Guatemala",
			origin_en => "Origin of raspberries: New Caledonia. Blueberries: Canada ; White peaches : Mexico",
		}
	],

	# origins field
	[
		"fr-origin-field",
		{
			lc => "fr",
			ingredients_text =>
				"Coquillettes, comté, jambon supérieur, vin blanc, vin rouge (italie), vin rosé (origine : Espagne), crème UHT, parmesan, ricotta (origine Italie), sel, poivre. Origine du poivre: Népal.",
			origin_fr =>
				"Origine des coquillettes : Italie. Origine du Comté AOP 4 mois : France. Origine du jambon supérieur : France. Vin blanc : Europe. Origine Crème UHT : France. Origine du parmesan : Italie. Fabriqué en France. Tomates d'Italie. Origine du riz : Inde, Thaïlande.",
		}
	],

	# origins with not taxonomized entries
	[
		"en-origin-field-with-not-taxonomized-entries",
		{
			lc => "en",
			ingredients_text => "Peaches. Some unknown ingredient, another unknown ingredient.
Origin of peaches: Spain. Origin of some unknown ingredient: France. origin of Another Unknown Ingredient: Malta",
		}
	],

	# Origins with commas
	[
		"en-origin-field-with-commas",
		{
			lc => "en",
			ingredients_text => "Milk, sugar. Origin of the milk: Belgium, Spain",
		}
	],

	# Origins with commas
	[
		"en-origin-field-with-commas-and",
		{
			lc => "en",
			ingredients_text =>
				"Milk, sugar. Origin of the milk: UK, European Union. Origin of sugar: Paraguay, Uruguay and Costa Rica.",
		}
	],

	# Origins : X from Y
	[
		"en-origin-ingredient-from-origin",
		{
			lc => "en",
			ingredients_text => "Red peppers, yellow peppers",
			origin_en => "Red peppers from Spain, Italy and France, Yellow peppers from South America",
		}
	],

	# Origins : X from Y
	[
		"en-origin-ingredient-origin-and-origin",
		{
			lc => "en",
			ingredients_text => "Red peppers, yellow peppers",
			origin_en => "Red peppers: Spain or South America, Yellow peppers: Mexico, Canada and California",
		}
	],

	# Origins : French - X from Y
	[
		"fr-origin-ingredient-origin-and-origin",
		{
			lc => "fr",
			ingredients_text =>
				"Pomme de Terre 47%, Porc 22%, Lait demi-écrémé (contient Lait) 5.5%, Crème liquide (contient Lait) 5.5%, Eau 5.5%,
			Beurre (contient Lait) 2.7%, Moutarde à l'ancienne (contient Moutarde, Sulfites) 2.7%, Crème (contient Lait) 2.7%, Moutarde de Dijon (contient Moutarde, Sulfites) 2.7%,
			Miel de fleurs 2.7%, Epices (contient Sésame) 0.55%, bouillon (contient Gluten, Lait, Céleri) 0.55%, Sel fin 0.14%",
			origin_fr =>
				"Pomme de Terre de France, Porc de France, Lait demi-écrémé de France, Crème liquide de France, Eau de France, Beurre de France, 
				Moutarde à l'ancienne de France, Crème de France, Moutarde de Dijon de France, Miel de fleurs de France, Epices : Inde, Bouillon de France, Sel fin de France",
		}
	],

	[
		"en-vitamin",
		{
			lc => "en",
			ingredients_text => "vitamin a, salt",
		}
	],

	# test "（" and "）"parenthesis found in some countries (Japan)
	[
		"ja-parenthesis",
		{
			lc => "ja",
			ingredients_text => "しょうゆ（本醸造）、糖類（ぶどう糖果糖液糖、水あめ、砂糖）、みりん、食塩、かつお節、さば節、たん白加水分解物混合物、こんぶ、調味料（アミノ酸等）、アルコール",
		}
	],
	# test "／" slash found in some countries (Japan)
	[
		"ja-slash",
		{
			lc => "ja",
			ingredients_text => "砂糖、小麦粉、全粉乳、カカオマス、ショートニング、植物油脂、ココアバター、小麦全粒粉、小麦ふすま、食塩、小麦胚芽 ／ 加工デンプン、乳化剤（大豆由来）、膨脹剤、香料",
		}
	],
	# U+00B7 "·" (Middle Dot) is a character found in ingredient forsome countries (Catalan)
	[
		"ca-middle-dot",
		{
			lc => "ca",
			ingredients_text =>
				"Formatge mozzarella (llet de vaca pasteuritzada, sal, ferments làctics i quall) i antiaglomerant (cel·lulosa).",
		}
	],
);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test

	if (defined $product_ref->{labels}) {
		compute_field_tags($product_ref, $product_ref->{lc}, "labels");
	}

	extract_ingredients_from_text($product_ref);

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
