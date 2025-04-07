#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';
use JSON;

use ProductOpener::Products qw/compute_languages/;
use ProductOpener::Tags qw/canonicalize_taxonomy_tag/;
use ProductOpener::Ingredients qw/clean_ingredients_text extract_additives_from_text/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	# Spanish vitamins test
	[
		'es-vitamins',
		{
			lc => "es",
			ingredients_text => "Agua, vitaminas (B1, C y E), Vitamina B2"
		}
	],

	# Make sure acides gras don't get detected as E-570
	[
		'fr-acides-gras-false-positive',
		{
			lc => "fr",
			ingredients_text =>
				"Acide citrique, Gorge, foie et gras de fermier, œuf, graines de tournesol (4%), vin blanc, graines de sésame (2%), sel, poivre. Peut contenir des traces de gluten, soja, lait, fruits à coque. À conserver à l'abri de laichateur et de Ihumidité* À consommer de préférence avant la date figurant sur le bocal. Après -ouverture, à conserver au Téfrigérateuretàconsommerrapidernent? Servir frais. Sans colorant ni conservateur ajouté. Mateurs nutritionnelles moyennes pour 100 g : énergie (1584 kJ / 383 kcal), matières grasses (36 g) dont : acides gras saturés (14 g), glucides (2 g) dont : sucres (0,9 g), protéines (14,3 g), sel (1 ,6 g).",
			ingredients_text_fr =>
				"Acide citrique, Gorge, foie et gras de fermier, œuf, graines de tournesol (4%), vin blanc, graines de sésame (2%), sel, poivre. Peut contenir des traces de gluten, soja, lait, fruits à coque. À conserver à l'abri de laichateur et de Ihumidité* À consommer de préférence avant la date figurant sur le bocal. Après -ouverture, à conserver au Téfrigérateuretàconsommerrapidernent? Servir frais. Sans colorant ni conservateur ajouté. Mateurs nutritionnelles moyennes pour 100 g : énergie (1584 kJ / 383 kcal), matières grasses (36 g) dont : acides gras saturés (14 g), glucides (2 g) dont : sucres (0,9 g), protéines (14,3 g), sel (1 ,6 g)."
		}
	],

	# Make sure 100% is not recognized as E-100
	[
		'fr-100-percent-not-e100',
		{
			lc => "fr",
			ingredients_text =>
				"pâte de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce équitable et de l'agriculture biologique (100% du poids total)."
		}
	],

	# Colorant and vitamins
	[
		'fr-colorant-e120',
		{
			lc => "fr",
			ingredients_text => "Acide citrique, colorant : e120, vitamine C, E-500",
			categories_tags => ["en:debug"]
		}
	],

	# E316 detection - https://github.com/openfoodfacts/openfoodfacts-server/issues/269
	[
		'fr-e316-detection',
		{
			lc => "fr",
			ingredients_text =>
				"Poitrine de porc, sel, conservateurs : lactate de potassium, nitrite de sodium, arôme naturel, sirop de glucose, antioxydant : érythorbate de sodium"
		}
	],

	# issue/801-wrong-E471
	[
		'fr-issue-801-wrong-E471',
		{
			lc => "fr",
			ingredients_text =>
				"Farine de blé 46 %, sucre de canne roux non raffiné, farine complète de blé 15 %, graines de sésame 13 %, huile de tournesol oléique 13 %, sel marin non raffiné, poudres à lever : carbonates d'ammonium et de sodium, acide citrique ; extrait de vanille, antioxydant : extraits de romarin."
		}
	],

	# Multiple additives
	[
		'fr-carbonates-sodium-ammonium',
		{
			lc => "fr",
			ingredients_text =>
				"carbonates de sodium et d'ammonium, nitrate de sodium et de potassium, Phosphate d'aluminium et de sodium."
		}
	],

	# poudres à lever
	[
		'fr-poudres-a-lever',
		{
			lc => "fr",
			ingredients_text => "poudres à lever : carbonates de sodium et d'ammonium"
		}
	],

	# metals
	[
		'fr-metals',
		{
			lc => "fr",
			ingredients_text => "calcium, sodium, potassium, aluminium, magnésium, fer, or, argent, sels"
		}
	],

	# chlorophylles
	[
		'fr-chlorophylles',
		{
			lc => "fr",
			ingredients_text =>
				"sirop de maltitol, Chlorophylle, Sels de sodium et de potassium de complexes cupriques de chlorophyllines, Carotènes végétaux, Carotènes d'algues"
		}
	],

	# caroténoides
	[
		'fr-colorants-carotene-with-paprika',
		{
			lc => "fr",
			ingredients_text => "colorants : carotène et extraits de paprika et de curcuma"
		}
	],
	[
		'fr-colorants-with-codes',
		{
			lc => "fr",
			ingredients_text =>
				"colorants : E100 et E120, acidifiant : acide citrique et E331, colorants : lutéine et tartrazine"
		}
	],
	[
		'fr-colorants-carotenoides-melanges',
		{
			lc => "fr",
			ingredients_text => "colorants : caroténoides mélangés"
		}
	],

	# gums and acids
	[
		'fr-gums-acids',
		{
			lc => "fr",
			ingredients_text =>
				"Eau, huile végétale, amidon, vinaigre, moutarde (eau, vinaigre, graines de moutarde, sel, épices), oignons, jaune d'œuf, sel, amidon modifié, cerfeuil, vinaigre de malt (contient de l'orge), mélasse, sauce soja (contient du blé), sucre, jus de citron, sirop de glucose-fructose, anchois, extrait d'épices, tamarin, extrait d'herbes, épices, herbes. Stabilisateurs : gomme guar, farine de graines de caroube, gomme xanthane. Conservateurs : acide tartrique, acide citrique, acide malique, sorbate de potassium, benzoate de sodium. Colorants : bêta-carotène, carmoisine, caramel. Antioxydant : calcium-dinatrium-EDTA."
		}
	],

	# chewing-gum mentos
	[
		'fr-mentos-chewing-gum',
		{
			lc => "fr",
			ingredients_text =>
				"Edulcorants (xylitol (32%), erythritol, mannitol, maltitol, sorbitol, sirop de maltitol, aspartame, acésulfame K, sucralose), gomme base, arômes, agent épaissisant (gomme arabique), gélatine, colorant (dioxyde de titane), stabilisant (glycérol), émulsifiant (lécithine de soja), extrait naturel de thé vert, agent d'enrobage (cire de carnauba), antioxydant (E320)."
		}
	],

	# additives that are only additives when preceeded by their function
	[
		'fr-vitamine-c-not-additive',
		{
			lc => "fr",
			ingredients_text => "Eau, sucre, vitamine C"
		}
	],

	[
		'fr-vitamine-c-with-function',
		{
			lc => "fr",
			ingredients_text => "Eau, sucre, antioxydant: vitamine C"
		}
	],

	[
		'fr-anti-oxydants',
		{
			lc => "fr",
			ingredients_text => "Eau, sucre, anti-oxydants: vitamine C"
		}
	],

	[
		'fr-antioxydants-multiple',
		{
			lc => "fr",
			ingredients_text => "Eau, sucre, antioxydants: vitamine C, acide citrique"
		}
	],

	# Vitamins
	[
		'fr-vitamines-a-c',
		{
			lc => "fr",
			ingredients_text => "vitamines (A,C)"
		}
	],

	[
		'fr-vitamines-e-b6',
		{
			lc => "fr",
			ingredients_text => "vitamines E, B6"
		}
	],

	[
		'fr-vitamines-b9-et-b12',
		{
			lc => "fr",
			ingredients_text => "vitamines B9 et B12"
		}
	],

	[
		'fr-vitamines-d-k-pp',
		{
			lc => "fr",
			ingredients_text => "vitamines: D, K et PP"
		}
	],

	[
		'fr-vitamines-c-pp-acide-folique-e',
		{
			lc => "fr",
			ingredients_text => "vitamines : C, PP, acide folique et E"
		}
	],

	# Minerals
	[
		'fr-chlorures-ammonium-calcium',
		{
			lc => "fr",
			ingredients_text => "Chlorures d'ammonium et de calcium"
		}
	],

	[
		'fr-chlorures-calcium-ammonium',
		{
			lc => "fr",
			ingredients_text => "Chlorures de calcium et ammonium"
		}
	],

	[
		'fr-sulfates-fer-zinc-cuivre',
		{
			lc => "fr",
			ingredients_text => "Sulfates de fer, de zinc et de cuivre"
		}
	],

	[
		'fr-mineraux-carbonate-calcium',
		{
			lc => "fr",
			ingredients_text => "Minéraux (carbonate de calcium)"
		}
	],

	[
		'fr-carbonate-calcium-simple',
		{
			lc => "fr",
			ingredients_text => "carbonate de calcium"
		}
	],
	[
		'fr-mineraux-calcium-et-autres',
		{
			lc => "fr",
			ingredients_text =>
				"Mineraux (carbonate de calcium, chlorures de calcium, potassium et magnésium, citrates de potassium et de sodium, phosphate de calcium, sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium)."
		}
	],
	[
		'fr-mineraux-sans-mention',
		{
			lc => "fr",
			ingredients_text =>
				"(carbonate de calcium, chlorures de calcium, potassium et magnésium, citrates de potassium et de sodium, phosphate de calcium, sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium)."

		}
	],
	[
		'fr-lactoserum-with-minerals',
		{
			lc => "fr",
			ingredients_text =>
				"Lactosérum déminéralisé (lait) - Huiles végétales (Palme, Colza, Coprah, Tournesol, Mortierella alpina) - Lactose (lait) - Lait écrémé - Galacto- oligosaccharides (GOS) (lait) - Protéines de lactosérum concentrées (lait) - Fructo- oligosaccharides (FOS) - Huile de poisson - Chlorure de choline - Emulsifiant: lécithine de soja - Taurine - Nucléotides - Inositol - L-tryptophane - L-carnitine - Vitamines (C, PP, B5, B9, A, E, B8, B12, BI, D3, B6, K1, B2) - Minéraux (carbonate de calcium, chlorures de potassium et de magnésium, citrates de potassium et de sodium, phosphate de calcium, sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium)."
		}
	],
	[
		'fr-puree-pomme-with-minerals',
		{
			lc => "fr",
			ingredients_text =>
				"Purée de pomme 40 %, sirop de glucose-fructose, farine de blé, protéines de lait, sucre, protéines de soja, purée de framboise 5 %, lactosérum, protéines de blé hydrolysées, sirop de glucose, graisse de palme non hydrogénée, humectant : glycérol végétal, huile de tournesol, minéraux (potassium, calcium, magnésium, fer, zinc, cuivre, sélénium, iode), jus concentré de raisin, arômes naturels, jus concentré de citron, levure désactivée, correcteur d'acidité : citrates de sodium, sel marin, acidifiant : acide citrique, vitamines A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E (lactose, protéines de lait), cannelle, poudres à lever (carbonates de sodium, carbonates d'ammonium)."
		}
	],
	[
		'en-calcium-phosphate',
		{
			lc => "en",
			ingredients_text => "Calcium phosphate"
		}
	],
	[
		'en-calcium-phosphate-with-function',
		{
			lc => "en",
			ingredients_text => "acidity regulators: Calcium phosphate"
		}
	],
	# Additives and Vitamins/Minerals
	[
		'fr-dextrines-maltees',
		{
			lc => "fr",
			ingredients_text =>
				"Dextrines maltées de mais, lait écrémé, huiles végétales non hydrogénées : colza, noix de coco, tournesol, lactose, Bifidus longum maternis. Minéraux : phosphate de calcium naturel de lait, oxyde de magnésium naturel, pyrophosphate de fer, gluconate de zinc, gluconate de cuivre, iodate de potassium, sélénite de sodium Vitamine d'Origine Végétale : L-ascorbate de sodium (vitamine C, cobalamine (vitamine B12), vitamines nature identique : niacine (vitamine PP), acide pantothénique (vitamine B5), riboflavine (vitamine B2), thiamine (vitamine B1), pyridoxine (vitamine B6), rétinol (vitamine A), acide folique (vitamine B9), phytoménadione (vitamine K1), biotine (vitamine B8), ergocalciférol (vitamine D2), vitamine Naturelle : tocophérols naturels extrait de tournesol (vitamine E)"
		}
	],

	# Oxyde de magnésium
	[
		'fr-oxyde-magnesium',
		{
			lc => "fr",
			ingredients_text => "Oxyde de magnésium, Acide gluconique, Gluconate de calcium"
		}
	],

	# Céréales with minerals and vitamins
	[
		'fr-cereales-mineraux-vitamines',
		{
			lc => "fr",
			ingredients_text =>
				"Céréales 90,5 % (farine de blé et gluten de blé 57,8 %, farine complète de blé 31 %, farine de blé malté), sucre, graines de lin, levure, huile de palme, fibres d'avoine, sel, minéraux [calcium (orthophosphate), fer (fumarate), magnésium (oxyde)], agent de traitement de la farine (acide ascorbique), vitamines [E, thiamine (B1), riboflavine (B2), B6, acide folique)]."
		}
	],

	# English test with INS codes
	[
		'en-ins-codes',
		{
			lc => "en",
			ingredients_text =>
				"REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), ACIDITY REGULATOR (INS 334), STABILIZER (INS 440, INS 337), WATER (FOR MAINTAINING DESIRED BRIX), CONTAINS PERMITTED NATURAL FLAVOUR & NATURAL IDENTICAL COLOURING SUBSTANCES (INS 141[i])"
		}
	],

	# English test with numbers no E
	[
		'en-numbers-no-e',
		{
			lc => "en",
			ingredients_text =>
				"water, sugar, tea, lemon juice, flavouring, acidity regulator (330, 331), vitamin C, antioxidant (304)"
		}
	],

	# Nutritional substances test
	[
		'fr-nutritional-substances',
		{
			lc => "fr",
			ingredients_text =>
				"chlorure de choline, taurine, inositol, L-cystéine, sels de sodium de l'AMP, citrate de choline, carnitine"
		}
	],

	# Emulsifiant test
	[
		'fr-emulsifiant-chlorure',
		{
			lc => "fr",
			ingredients_text => "émulsifiant: chlorure de choline, agent de traitement de la farine:l cystéine"
		}
	],

	# Test lait
	[
		'fr-lait-vitamines',
		{
			lc => "fr",
			ingredients_text =>
				"Lait partiellement écrémé, eau, lactose, maltodextrines, huiles végétales (colza, tournesol), vitamines : A, B1, B2, B5, B6, B8, B9, B12, C, D3, E, K1 et PP, substances d'apport minéral : citrate de calcium, sulfates de fer, de magnésium, de zinc, de cuivre et de manganèse, citrate de sodium, iodure et hydroxyde de potassium, sélénite de sodium, émulsifiant : lécithine de colza, éthylvanilline."
		}
	],

	# Test préparation pour nourrissons
	[
		'fr-preparation-nourrissons',
		{
			lc => "fr",
			ingredients_text =>
				"INFORMATIONS NUTRITIONNELLES PRÉPARATION POUR NOURRISSONS EN potlDRE - Ingrédients du produit reconstitué : Lactose (lait), huiles végétales (palme, colza, tournesol), maltodextrines, proteines de lait hydrolysées, minéraux (phosphate tricalcique, chlorure de potassium, citrate trisodique, phosphate dipotassique, phosphate de magnésium, sulfate ferreux, sulfate de zinc, hydroxyde de potassium, sélénite de sodium, iodure de potassium, sulfate de cuivre, sulfate de manganèse), émulsifiant (esters citriques de mono et diglycérides d'acides gras), vitamines (C,pp, B9,H,B12), L-phénylalanine, chlorure de choline, L-tryptophane, L-tyrosine, taurine, inositol, antioxydants (palmitate d'ascorbyle, tocophérols) (soja), L-carnitine, ferments lactiques (Lactobacillus fermentum CECT5716)"
		}
	],

	# Test huile de colza
	[
		'fr-huile-colza',
		{
			lc => "fr",
			ingredients_text =>
				"huile de colza, orthophosphates de calcium, carbonate de calcium, citrates de potassium"
		}
	],

	# Test copper carbonate
	[
		'en-copper-carbonate',
		{
			lc => "en",
			ingredients_text => "copper carbonate"
		}
	],

	# Test café 100%
	[
		'fr-cafe-100-percent',
		{
			lc => "fr",
			ingredients_text => "Café instantané 100 % pur arabica"
		}
	],

	# Test instant coffee 100%
	[
		'en-instant-coffee-100-percent',
		{
			lc => "en",
			ingredients_text => "Instant coffee 100 %."
		}
	],

	# Products in Hong Kong sometimes have no E before E numbers
	[
		'en-hong-kong-no-e',
		{
			lc => "en",
			ingredients_text =>
				"water, sugar, tea, lemon juice, flavouring, acidity regulator (330, 331), vitamin C, antioxidant (304)"
		}
	],

	# Test sugars, glycerol, xanthane
	[
		'fr-sugars-glycerol-xanthane',
		{
			lc => "fr",
			ingredients_text =>
				"Sucre (France), OEUF entier (reconstitué à partir de poudre d OEUF), huile de colza, farine de riz, amidon de pomme de terre, stabilisants : glycérol et gomme xanthane, amidon de maïs, poudres à lever : diphosphates et carbonates de sodium, arôme naturel de citron, émulsifiant : mono- et diglycérides d'acides gras, conservateur : sorbate de potassium, sel, colorant : riboflavine. Traces éventuelles de soja."
		}
	],

	# Test colorants
	[
		'fr-farine-seigle-colorants',
		{
			lc => "fr",
			ingredients_text =>
				"farine de seigle, sel, poudre à lever : carbonates de sodium,carbonates dlammonium,diphosphates,tartrates d potassium, amidon de blé, poudre de lait écrémé, extrait de malt dlorge, noix de coco 0,1 % arômes, jaune d'œuf en poudre, fécule de pomme de terre, farine dorge, amidon de maïs colorants : caramel ordinaire et curcumine, lactose et protéine de lait en poudre. Colorant: Sels de sodium et de potassium de complexes cupriques de chlorophyllines, Complexe cuivrique des chlorophyllines avec sels de sodium et de potassium, oxyde et hydroxyde de fer rouge, oxyde et hydroxyde de fer jaune et rouge, Tartrate double de sodium et de potassium, Éthylènediaminetétraacétate de calcium et de disodium, Phosphate d'aluminium et de sodium, Diphosphate de potassium et de sodium, Tripoliphosphates de sodium et de potassium, Sels de sodium de potassium et de calcium d'acides gras, Mono- et diglycérides d'acides gras, Esters acétiques des mono- et diglycérides, Esters glycéroliques de l'acide acétique et d'acides gras, Esters glycéroliques de l'acide citrique et d'acides gras, Esters monoacétyltartriques et diacétyltartriques, Esters mixtes acétiques et tartriques des mono- et diglycérides d'acides gras, Esters lactyles d'acides gras du glycérol et du propane-1, Silicate double d'aluminium et de calcium, Silicate d'aluminium et calcium, Silicate d'aluminium et de calcium, Silicate double de calcium et d'aluminium,  Glycine et son sel de sodium, Cire d'abeille blanche et jaune, Acide cyclamique et ses sels, Saccharine et ses sels, Acide glycyrrhizique et sels, Sels et esters de choline, Octénylesuccinate d'amidon et d'aluminium"
		}
	],

	# Test acide citrique
	[
		'fr-acide-citrique',
		{
			lc => "fr",
			ingredients_text =>
				"Ac1de citrique; or; ar; amidon modfié, carbonate dlammonium, carmims, glycoside de steviol, sel ntrite, vltamine c",
			categories_tags => ["en:debug"]
		}
	],

	# Test E501
	[
		'fr-e501',
		{
			lc => "fr",
			ingredients_text => "Eau, E501"
		}
	],

	# Test olives
	[
		'fr-olives',
		{
			lc => "fr",
			ingredients_text =>
				"Olives d'import 80 % (vertes, tournantes, noires), poivron et piment, sel, oignon, huile de tournesol, ail, acidifiants (E330, vinaigre), conservateur : sulfites."
		}
	],

	# Test biscuit with épaississants and more
	[
		'fr-biscuit-epaississants',
		{
			lc => "fr",
			ingredients_text =>
				"Biscuit 65 % :farine de riz blanche*, amidon de pomme de terre*, huile de palme non hydrogénée, sucre de canne blond, amidon de riz*, œufs*, sirop de glucose de r|z*, farine de pois chiche*, épaississants (gomme d'acacia*, gomme de guar), agents levants (tartrates potassium, carbonates de sodium), sel. Fourrage 35% : sirop de glucose de riz*, purée de pomme*, purée d'abricot* 08%), purée de pêche (7%), gélifiant: pectine, régulateur d'acidité : acide citrique, arôme naturel*. *issus de agriculture biologique. **Ingrédient biologique issu du Commerce Équitable."
		}
	],

	# Test dioxyde titane
	[
		'fr-dioxyde-titane',
		{
			lc => "fr",
			ingredients_text => "dioxyde titane, le glutamate de sodium"
		}
	],

	# Test boyau coloré
	[
		'fr-boyau-colore',
		{
			lc => "fr",
			ingredients_text => "boyau, coloré, chlorela, chlorelle, chlorele bio"
		}
	],

	# Test émulsifiants
	[
		'fr-emulsifiants',
		{
			lc => "fr",
			ingredients_text => "émulsifiants : E463, E432 et E472, correcteurs d'acidité : E322/E333 E474-E475"
		}
	],

	# Spanish vitamines
	[
		'es-leche-desnatada',
		{
			lc => "es",
			ingredients_text => "Leche desnatada de vaca, enzima lactasa y vitaminas A, D, E y ácido fólico."
		}
	],

	# Finnish sian rinta
	[
		'fi-sian-rinta-with-preservatives',
		{
			lc => "fi",
			ingredients_text =>
				"Sian rinta, suola, säilöntäaineet (kaliumlaktaatti), natriumnitriitti, luontainen aromi, glukoosisiirapppi, hapettumisenestoaine (natriumerytorbaatti)"
		}
	],
	[
		'fi-sian-rinta-with-citric-acid',
		{
			lc => "fi",
			ingredients_text => "Sitruunahappo, väri (e120), C-vitamiini, E-500",
			categories_tags => ["en:debug"]
		}
	],

	# Finnish sakeuttamisaine
	[
		'fi-sakeuttamisaine',
		{
			lc => "fi",
			ingredients_text =>
				"sakeuttamisaine arabikumi, makeutusaineet (sorbitoli, maltitolisiirappi, asesulfaami K), happamuudensäätöaine sitruunahappo, pintakäsittelyaine mehiläisvaha"
		}
	],

	# chocolate cookies with additives
	[
		'fr-chocolate-cookies-additives',
		{
			lc => "fr",
			ingredients_text =>
				"Farine de BLE, sucre, chocolat au lait 13% (sucre, beurre de cacao, pâte de cacao, LAIT écrémé en poudre, LACTOSE, matière grasse LAITIERE anhydre, LACTOSERUM en poudre, émulsifiant : lécithines de tournesol), chocolat blanc 8% (sucre, beurre de cacao, LAIT entier en poudre, émulsifiant : lécithines de tournesol), BEURRE pâtissier, chocolat noir 6% (pâte de cacao, sucre, beurre de cacao, matière grasse LAITIERE, émulsifiant : lécithines de tournesol), blancs d'OEUFS, fourrage à la purée de framboise 3.5% (sirop de glucose- fructose, stabilisant : glycérol, purée et brisures de framboise, purée de framboise concentrée, purée de pomme, BEURRE, arômes, acidifiant : acide citrique, gélifiant : pectines de fruits, correcteur d'acidité : citrates de sodium, jus concentré de sureau), huile de tournesol, OEUFS entiers, AMANDES 1.3%, poudre de NOIX DE CAJOU 1.2%, sucre de canne roux, NOISETTES, poudre de florentin 0.6% (sucre, sirop de glucose, BEURRE, émulsifiant : lécithines de SOJA, poudre de LAIT écrémé), sirop de sucre inverti et partiellement inverti, grains de riz soufflés 0.5% (farine de riz, gluten de BLE, malt de BLE, saccharose, sel, dextrose), nougatine 0.4% (sucre, AMANDES et NOISETTES torréfiées), éclat de caramel 0.4% (sucre, sirop de glucose, CREME et BEURRE caramélisés), farine de SEIGLE, sel, poudres à lever : carbonates de sodium - carbonates d'ammonium- diphosphates- tartrates de potassium, amidon de BLE, poudre de LAIT écrémé, extrait de malt d'ORGE, noix de coco 0.1%, arômes, jaune d'OEUF en poudre, fécule de pomme de terre, farine d'ORGE, amidon de maïs, colorants : caramel ordinaire et curcumine, LACTOSERUM en poudre et protéines de LAIT, cannelle en poudre, émulsifiant : lécithines de tournesol, antioxydant : acide ascorbique. Traces éventuelles de graines de sésame et autres fruits à coques."
		}
	]
);

foreach my $test_ref (@tests) {
	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test
	extract_additives_from_text($product_ref);

	# If there's a language test, perform it
	if (exists $product_ref->{ingredients_text_fr}) {
		compute_languages($product_ref);
		clean_ingredients_text($product_ref);
		extract_additives_from_text($product_ref);
	}

	# Remove any temporary OCR fields that might cause test failures
	# Those fields can be added by clean_ingredients_text()
	foreach my $key (keys %{$product_ref}) {
		if ($key =~ /^ingredients_text_.*ocr_\d+/) {
			delete $product_ref->{$key};
		}
		if ($key =~ /^ingredients_text_.*ocr_\d+_result/) {
			delete $product_ref->{$key};
		}
	}

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

# Additional tests for canonicalize_taxonomy_tag
is(canonicalize_taxonomy_tag("fr", "additives", "erythorbate de sodium"),
	"en:e316", "Testing canonicalize_taxonomy_tag for erythorbate de sodium");
is(canonicalize_taxonomy_tag("fr", "additives", "acide citrique"),
	"en:e330", "Testing canonicalize_taxonomy_tag for acide citrique");
is(canonicalize_taxonomy_tag("fi", "additives", "natriumerytorbaatti"),
	"en:e316", "Testing canonicalize_taxonomy_tag for natriumerytorbaatti");
is(canonicalize_taxonomy_tag("fi", "additives", "sitruunahappo"),
	"en:e330", "Testing canonicalize_taxonomy_tag for sitruunahappo");

done_testing();
