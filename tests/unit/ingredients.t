#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::ProductsTags qw/compute_field_tags/;
use ProductOpener::Ingredients qw/extract_ingredients_from_text/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

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

	[
		"en-origin-and",
		{
			lc => "en",
			ingredients_text => "Tomatoes (France and Italy)",
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
		"fr-origin-and",
		{
			lc => "fr",
			ingredients_text => "Pomme de Terre (France et Italie)",
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
	# origins
	[
		"ja-origins",
		{
			lc => "ja",
			ingredients_text => "塩(国産),
クレームフレーシュ(国内製造),
肉(オーストラリア),
オリーブ油(ブラジル産、エチオピア産),
白ワインビネガー(オーストラリア又はフィンランド又はその他),
麦芽(国内製造又は韓国製造),
糖類(外国製造又は国内製造),
ココア(輸入又は国産 (5%未満)),
えだまめ(北海道産).
パンの実(三陸産),
クレメンタイン(九州産)"
		}
	],

	[
		"ja-origin-and",
		{
			lc => "ja",
			ingredients_text => "トマト(ときがわ町])",
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
	# synonyms between demi-complet -> semi-complet
	[
		"fr-semi",
		{
			lc => "fr",
			ingredients_text => "farine demi-complète de riz, farine de blé demi complet",
		}
	],
	# illegal division by zero
	[
		"fr-illegal-division-by-zero",
		{
			lc => "fr",
			ingredients_text => "Analyse moyenne pour 1 00 g: 1472 kJ,",
		}
	],
	[
		"en-illegal-division-by-zero",
		{
			lc => "en",
			ingredients_text => "each capsule contains: paracetamol 500 m 5 060198 790 0 mg.",
		}
	],
	# mechanicaly separated meat
	[
		"en-mechanicaly-separated-meat",
		{
			lc => "en",
			ingredients_text => "mechanicaly separated poultry meat",
		}
	],
	[
		"fr-mechanicaly-separated-meat",
		{
			lc => "fr",
			ingredients_text =>
				"viande de dinde séparée mécaniquement, viande séparée mécaniquement de porc, viande séparée mecaniquement de poulet halal",
		}
	],
	# halal
	[
		"fr-halal",
		{
			lc => "fr",
			ingredients_text => "viande halal, gélatine de boeuf halal, collagène halal, foie gras de canard halal",
		}
	],
	# kosher
	[
		"en-kosher",
		{
			lc => "en",
			ingredients_text => "kosher sea salt, kosher american cheese, kosher bovine gelatine",
		}
	],
	# nova 4 for fruit juice concentrates
	[
		"en-nova-4-fruit-juice-concentrates",
		{
			lc => "en",
			ingredients_text => "apple juice concentrates",
		}
	],
	# Japanese additives
	[
		"ja-additives",
		{
			lc => "ja",
			ingredients_text => "増粘剤(加工デンプン、キサンタン)、酢酸Na、トレハロース、加工デンプン、グリシン、調味料(アミノ酸等)、酸化防止剤(V.C,V.E)、着色料(野菜色素)",
		},
	],
	# 148g per 100g
	[
		"en-quantity-per-100g",
		{
			lc => "en",
			ingredients_text => "tomatoes (148 g per 100g), pork (200 g per 100 g of finished product)",
		},
	],
	[
		"fr-quantity-per-100g",
		{
			lc => "fr",
			ingredients_text => "tomates (148 g par 100g), porc (200 gr par 100 g de produit fini)",
		}
	],
	[
		"en-content-of-ingredient",
		{
			lc => "en",
			ingredients_text => "total content of milk 80%, content of fruits 120g per 100g"
		}
	],
	[
		"en-ingredient-content",
		{
			lc => "en",
			ingredients_text =>
				"strawberry content: 5%, min cocoa content: 40,3g, total milk content minimum 30%, fruit content: 10%; apples content 50.20g per 100g of product"
		}
	],
	[
		"en-prepared-with",
		{
			lc => "en",
			ingredients_text => "70g of onions per 100g, prepared with 100g of cucumber per 100g of product,
				made with 150 g of tomatoes per 100ml, prepared with: 50% of potatoes"
		}
	],
	[
		"fr-content-of-ingredient",
		{
			lc => "fr",
			ingredients_text =>
				"Taux minimum de légumes : 30%, teneur minimale en lait de 14% - teneur totale de fruits 15%"
		}
	],
	[
		"fr-prepared-with",
		{
			lc => "fr",
			ingredients_text =>
				"Elaboré avec 50g d'abricots, produit avec 30% d'asperges, fabriquée avec 500g de viande pour 100g, préparé à partir de 140 g de tomates pour 100g de produit"
		}
	],
	# fruits 50% and pear 30% is not a specific ingredient
	[
		"en-fruits-sub-ingredients",
		{lc => "en", ingredients_text => "fruits 50% (apple 40%, pear 30%, cranberry, lemon), sugar"},
	],
	# 50g of ingredient
	[
		"en-quantity-of-ingredient",
		{lc => "en", ingredients_text => "50g of tomatoes, 35% garlic, 20cl of water, 10ml of rapeseed oil"}
	],
	[
		"fr-quantity-of-ingredient",
		{lc => "fr", ingredients_text => "50g de tomates, 35% d'ail, 20cl d'eau, 10ml d'huile de colza"}
	],
	# 'and' + processing
	[
		"en-ing1-and-ing2-processing",
		{
			lc => "en",
			ingredients_text => "apple,
non-hydrogenated banana,
cherry and date,
hardened elderberry and fig,
grape and treated huckleberry,
desalted jackfruit and grilled kiwifruit,
lemon and unknown_fruit,
toasted mango and unknown_fruit2,
nectarine and fried unknown_fruit3,
puffed orange and caramelized unknown_fruit4.",
		}
	],
	[
		"en-ing1-and-ing2-processing-parenthesis",
		{
			lc => "en",
			ingredients_text =>
				"fruits (apple, banana and dried cherry), vegetables (pitted avocado, peeled black radish).",
		}
	],
	# category / types enumeration
	[
		"en-category-types",
		{
			lc => "de",
			ingredients_text => "pflanzliche Öle und Fette (Raps, Palm, Shea, Sonnenblumen)",
		}
	],
	[
		"fr-viande-de-boeuf-issue-d-animaux-nourris-sans-ogm",
		{
			lc => "fr",
			ingredients_text => "Viande de boeuf issue d'animaux nourris sans OGM",
		}
	],
	# French ingredient
	[
		"fr-oignon-francais-tomate-francaise",
		{
			lc => "fr",
			ingredients_text => "Oignon français, tomate française",
		}
	],
	[
		'fr-legumes-issus-de-l-agriculture-durable',
		{
			lc => "fr",
			ingredients_text => "Légumes issus de l'agriculture durable",
		}
	],
	[
		"fr-farines-labels-and-processes",
		{
			lc => "fr",
			ingredients_text =>
				"Farine de blé CRC, farine de maïs fermentée, farine sans gluten, farine de petit épeautre fortifiée",
		}
	],
	# Label in a list of ingredients: the product should have labels organic and gluten-free.
	[
		"en-wheat-flour-organic-gluten-free",
		{
			lc => "en",
			ingredients_text => "wheat flour. MSC (fish). organic. gluten-free",
		}
	],
	# Removing a label with stopwords without removing the stopwords in origins
	[
		"fr-cacao-issu-de-l-agriculture-biologique-de-madagascar",
		{
			lc => "fr",
			ingredients_text => "cacao issu de l'agriculture biologique de Madagascar",
		}
	],
	# Allergens in parenthesis
	[
		"en-allergens-in-parenthesis",
		{
			lc => "en",
			ingredients_text =>
				"butter (milk), surimi (fish), wheat flour (gluten), dough (flour, gluten, salt, water)",
		}
	],
	# Japanese allergens in parenthesis
	[
		"ja-allergens-in-parenthesis",
		{
			lc => "ja",
			ingredients_text => "香料 (ラッカセイ, 種実類, 魚).",
		}
	],
	# Ingredients in parenthesis that are in the allergens taxonomy
	# Those ingredients should not be removed from the ingredients list
	# e.g. if we have "butter (milk)", we may want to consider that milk is not a sub ingredient, but an indication of an allergen
	# but if we have "cheese (parmigiano reggiano)", we definitely want to keep "parmigiano reggiano" as a sub ingredient
	[
		"en-ingredients-in-parenthesis-that-are-in-the-allergens-taxonomy",
		{
			lc => "en",
			ingredients_text => "butter (milk), cheese (parmigiano reggiano)",
		}
	],
	[
		"fr-ingredients-in-parenthesis-that-are-in-the-allergens-taxonomy",
		{
			lc => "fr",
			ingredients_text => "beurre (lait), fromage (parmesan)",
		}
	],
	# Infinite loop https://github.com/openfoodfacts/openfoodfacts-server/issues/9755
	[
		"fr-infinite-loop-allergens",
		{
			lc => "fr",
			ingredients_text =>
				"Sucre, LAIT* entier en poudre 25%, graisse végétale (palme, palmiste), beurre de cacao1, pâte de cacao1, LAIT* écrémé en poudre 3%, huile de tournesol, émulsifiant: lécithines, arômes de vanille. Traces éventuelles de fruits à coque et de céréales contenant du gluten. Cacao: 30% minimum dans le chocolat au lait. *Lait: origine UE et/ou non UE (Royaume-Uni)",
		}
	],
	# , and salt
	[
		"en-comma-and-pepper",
		{
			lc => "en",
			ingredients_text => "sugar, salt, and pepper",
		}
	],
	# some unknown ingredient and a known one
	[
		"en-some-unknown-ingredient-and-salt",
		{
			lc => "en",
			ingredients_text => "some unknown ingredient and salt",
		}
	],

	# Do not consider A at the end of the string to be a stopword
	# https://github.com/openfoodfacts/openfoodfacts-server/pull/11095
	[
		"en-ingredient-ending-with-a",
		{
			lc => "en",
			ingredients_text => "E124, Ponceau 4R, Cochineal Red A, Cochineal Red, a pear",
		}
	],

	# Vegetable oils with one unrecognized oil
	[
		"en-vegetable-oils-with-one-unrecognized-oil",
		{
			lc => "en",
			ingredients_text => "vegetable oils (sunflower, soy, something strange)",
		}
	],

	# Multi-word oils inside a generic name: "palm kernel" and "palm stearin"
	# must be expanded as a single ingredient each, not left as a dangling word
	# after "palm" was matched (e.g. "palm, palm, stearin, palm kernel").
	[
		"en-vegetable-oils-palm-stearin-palm-kernel",
		{
			lc => "en",
			ingredients_text => "vegetable oils (palm stearin, palm, palm kernel)",
		}
	],

	[
		"en-vegetable-oils-palm-stearin-palm-kernel-with-other-oils",
		{
			lc => "en",
			ingredients_text => "vegetable oils (coconut, palm stearin, palm, palm kernel)",
		}
	],

	# Oils that resolve to their taxonomy id via an "X vegetable oil(s)" synonym
	# (ingredients.txt). Guards the synonym entries added for these oils.
	[
		"en-vegetable-oils-five-resolved-oils",
		{
			lc => "en",
			ingredients_text => "vegetable oils (avocado, olive, colza, cottonseed, safflower)",
		}
	],

	# émulsifiant : lécithines (tournesol)
	[
		"fr-emulsifiant-lecithines-tournesol",
		{
			lc => "fr",
			ingredients_text => "émulsifiant : lécithines (tournesol)",
		}
	],

	# émulsifiant e471
	[
		"fr-emulsifiant-e471-emulsifiant-lecithine-de-soja",
		{
			lc => "fr",
			ingredients_text => "émulsifiant e471, émulsifiant lécithine de soja",
		}
	],

	# SV koncentrat från (morot, svarta vinbär)
	[
		"sv-koncentrat-fran-morot-svarta-vinbar",
		{
			lc => "sv",
			ingredients_text => "koncentrat från (morot, svarta vinbär)",
		}
	],

	# SV vegetabilisk olja (solros, raps i varierande proportion)
	# https://github.com/openfoodfacts/openfoodfacts-server/issues/11991
	[
		"sv-vegetabilisk-olja-solros-raps-i-varierande-proportion",
		{
			lc => "sv",
			ingredients_text => "vegetabilisk olja (solros, raps i varierande proportion)",
		},
	],

	# FR - demi-secs processing + "garden peas medium" (official name in French for some peas)
	[
		"fr-haricots-blancs-demi-secs-garden-peas-medium",
		{
			lc => "fr",
			ingredients_text => "haricots blancs demi-secs, garden peas medium, carottes parisiennes",
		}
	],
	# JA check usage of “●” as separator
	# https://github.com/openfoodfacts/openfoodfacts-server/pull/13691
	[
		'ja-black-circle-separator',
		{
			lc => 'ja',
			ingredients_text => '小麦粉●砂糖●植物油脂●食塩●香料●乳化剤',
		},
	],
	# origins adjectives
	[
		'fr-origins-adjectives',
		{
			lc => 'fr',
			ingredients_text =>
				'Tomates italiennes, fraises bretonnes, pommes normandes, huile d’olive italienne, huile d’olive grecque, fromage anglais',
		}
	],
	[
		'fr-origins-adjectives-false-positives',
		{
			lc => 'fr',
			ingredients_text =>
				'Crème anglaise, sauce anglaise, pain suédois (farine, sel), maquereaux espagnols, maquereau espagnol',
		}
	],
	[
		'sv-origins-adjectives',
		{
			lc => 'sv',
			ingredients_text => 'svensk jordgubbe, svenska jordgubbar',
		}

	],
	# Recipes with ingredients by weight and volume
	[
		'en-ingredients-with-a-specific-density',
		{
			lc => 'en',
			ingredients_text => 'cooking oil 25 fl oz, milk 1dl, 5cl granulated sugar, water 1l, apple juice 20ml',
		}
	],
	[
		'fr-recipes-with-ingredients-by-weight-and-volume',
		{
			lc => 'fr',
			ingredients_text =>
				"3 kilos d'huile de palme, un kilo de farine, 5 tasses de farine, 30 g de sucre, une tasse de lait, 10 ml d’huile, 2 pincées de poivre, une pincée de sel",
		}
	],
	# percent_or_quantity_regexp
	[
		'en-percent-or-quantity-regexp',
		{
			lc => 'en',
			ingredients_text => "cod 40g, salmon 30%, 20% tuna, mackerel (7%), 3g sardine",
		}
	],

	# Concentrations as mg/kg must not split on '/' (issue #6132)
	# Simplified Spanish reproducer (avoids "Ac." abbreviation which hits period+space separators)
	[
		"es-mg-per-kg",
		{
			lc => "es",
			ingredients_text =>
				"Hierro 30 mg/kg, ácido fólico 2,2 mg/kg, tiamina 6,3 mg/kg, riboflavina 1,3 mg/kg, niacina 13 mg/kg",
		}
	],
	[
		"en-compound-unit-minimum-qualifier",
		{
			lc => "en",
			ingredients_text => "Vitamin A 100 mg/kg minimum",
		}
	],
	[
		"en-label-promoted-compound-unit-slash",
		{
			lc => "en",
			ingredients_text => "organic (mg/kg 1b306)",
		}
	],
	# French petfood dosages (Open Pet Food Facts / related to #6132)
	[
		"fr-petfood-mg-per-kg",
		{
			lc => "fr",
			ingredients_text =>
				"extrait de yucca 180 mg/kg, fructooligosaccharides 480 mg/kg, glucosamine 180 mg/kg, méthylsulfométhane 180 mg/kg, sulfate de chondroïtine 125 mg/kg, mannanoligosaccharides 120 mg/kg",
		}
	],
	# Activity / count units (vitamins IU/UI/I.E, probiotics UFC) — no quantity_g
	[
		"fr-vitamin-ui-and-ufc",
		{
			lc => "fr",
			ingredients_text =>
				"Vitamine A 14000 U.I., Vitamine D 500 I.E, Vitamine E 10 IU, Enterococcus faecium 1000000000 UFC",
		}
	],
	# Slash between additives must still separate / stay as additive enumeration
	[
		"fr-additive-slash-still-works",
		{
			lc => "fr",
			ingredients_text => "correcteurs d'acidité : E322/E333, sel",
		}
	],
	# Compound-unit quantity glued between two ingredients (no comma): it must
	# be isolated so both ingredients are still extracted (#6132 follow-up)
	[
		"fr-petfood-mid-segment-mg-per-kg",
		{
			lc => "fr",
			ingredients_text => "L-carnitine 450 mg/kg sulfate de glucosamine 450 mg/kg, chondroïtine 450 mg/kg",
		}
	],
	# An additive class followed only by unit junk / unknown codes keeps its
	# node instead of being flattened into unknown children
	[
		"fr-additive-class-kept-over-unit-junk",
		{
			lc => "fr",
			ingredients_text => "Antioxygènes : Avec antioxydant naturel : mg/kg 1b306(i), sel",
		}
	],
	# Same, with the class itself ("antioxydant naturel") directly followed by
	# the unit junk (regression: read-only split chunk crash)
	[
		"fr-additive-class-natural-antioxidant-unit-junk",
		{
			lc => "fr",
			ingredients_text => "Avec antioxydant naturel : mg/kg 1b306(i)",
		}
	],
	# a lone roman numeral in parenthesis is an oxidation state, not a sub-ingredient
	[
		"fr-oxidation-states-not-sub-ingredients",
		{
			lc => "fr",
			ingredients_text => "Minéraux : sulfate de fer (II), sulfate de cuivre (ii), fer (iii), oxyde de zinc",
		}
	],
	# an unknown word after the numeral must not hide the known parent
	[
		"fr-oxidation-state-before-unknown-word",
		{
			lc => "fr",
			ingredients_text => "Sulfate de cuivre (II) pentahydraté, sulfate de fer (II) monohydraté",
		}
	],
	# taxonomies can store the numeral between spaces: "ijzer (II) citraat", "iron(III) oxide"
	[
		"nl-oxidation-state-spaced-in-taxonomy",
		{
			lc => "nl",
			ingredients_text => "ijzer (II) citraat, zout",
		}
	],
	[
		"en-oxidation-state-spaced-in-taxonomy",
		{
			lc => "en",
			ingredients_text => "colour: iron (III) oxide, salt",
		}
	],
	# the name stops before "and" or a quantity
	[
		"pl-oxidation-state-before-and",
		{
			lc => "pl",
			ingredients_text => "konserwant: Azotan(III) potasu i sól",
		}
	],
	[
		"pl-oxidation-state-before-percent",
		{
			lc => "pl",
			ingredients_text => "konserwant: Azotan(III) potasu 0,1%, sól",
		}
	],
	# processing words after the name
	[
		"en-oxidation-state-with-processing",
		{
			lc => "en",
			ingredients_text => "copper (II) sulfate powder, salt",
		}
	],
	[
		"fr-oxidation-state-with-processing",
		{
			lc => "fr",
			ingredients_text => "sulfate de cuivre (II) en poudre, sel",
		}
	],
	# the name continues after the numeral: "Azotan(III) potasu" is E249, "Azotan potasu" is E252
	[
		"pl-oxidation-state-inside-name",
		{
			lc => "pl",
			ingredients_text => "konserwant: Azotan(III) potasu, sól",
		}
	],
	# EU feed additive codes (Regulation 1831/2003 register) are synonyms of the additive
	[
		"fr-feed-additive-codes",
		{
			lc => "fr",
			ingredients_text =>
				"Additifs nutritionnels : Fer (3b103), Cuivre (3b405), vitamine A (3a672a), vitamine E (3a700), taurine (3a370). Antioxydant : 1b306(i)",
		}
	],
	# EU feed additive code before or after the name: kept if the name is the same entry as the code,
	# or one of its parents ("vitamine A" for 3a672a, retinyl acetate)
	[
		"fr-feed-additive-code-with-name",
		{
			lc => "fr",
			ingredients_text =>
				"Additifs nutritionnels : 3a672a vitamine A, vitamine E 3a700, 3b103 fer, taurine 3a370, 3a700 taurine",
		}
	],
	# handling of */ and **/ in the tail of the ingredients list
	[
		# https://se.openfoodfacts.org/product/7350056848709/%C3%B6rtsalt-original-spicemaster
		'sv-asterisk-slash',
		{
			lc => 'sv',
			ingredients_text =>
				'Havssalt (93%)**, basilika*, timjan*, rosmarin*, lök*, salvia, oregano* och vitlök* */ ekologiskt odlat **/oraffinerat havssalt med låg natriumhalt',
		},
	],
	[
		'en-asterisk-slash',
		{
			lc => 'en',
			ingredients_text =>
				'Sea salt (93%)**, basil*, thyme*, rosemary*, onion*, sage, oregano* and garlic* */ organically grown **/fair trade',
		},
	],
	# Ingredients list with new lines
	[
		'fr-ingredients-with-new-lines-simple-recipe',
		{
			lc => 'fr',
			ingredients_text =>
				"1 kg de sucre\r\n1 kg de farine\n\n1 litre d'eau\n1 pincée de sel\n1 sachet de levure chimique\npoivre, épices\n",
		},
	],
	[
		'en-ingredients-with-new-lines',
		{
			lc => 'en',
			ingredients_text =>
				"Water\nSugar\nGlucose Syrup\nModified Starch\nCitric Acid\nNatural Flavouring\nFruit and Vegetable Concentrates (Carrot, Blackcurrant, Apple, Lemon, Safflower, Spirulina)\nColours (Anthocyanins, Curcumin)\nAcidity Regulator (Sodium Citrates)\nPreservative (Potassium Sorbate)",
		},
	],
	# Ingredients with commas and new lines in middle of ingredient names that should not be split into multiple ingredients
	[
		'fr-ingredients-with-new-lines-and-commas-simple',
		{
			lc => 'fr',
			ingredients_text =>
				"Eau, Sucre, Sirop de\nGlucose, Amidon Modifié, Acide\nCitrique, Arôme Naturel,\nConcentrés de Fruits\net Légumes",
		},
	],
	[
		'en-ingredients-with-new-lines-and-commas',
		{
			lc => 'en',
			ingredients_text =>
				"Water, Sugar, Glucose Syrup, Modified\nStarch, Citric Acid, Natural\nFlavouring, Fruit and\n Vegetable Concentrates (Carrot,\nBlackcurrant, Apple, Lemon, Safflower, \nSpirulina), Colours (Anthocyanins, Curcumin), Acidity\nRegulator (Sodium Citrates), Preservative (Potassium Sorbate)",
		},
	],
	# Check that specific ingredients are not added twice when we parse ingredients twice (when they have newlines)
	[
		'en-ingredients-parsing-multiple-times-with-specific-ingredients-converting-newlines-to-commas',
		{
			lc => "en",
			ingredients_text => "Black grapes (Italy)\nsugar\neggs\npaprika.\nOrigin of paprika: Hungary",
			origin_en => "Origin of sugar: Guatemala",
			labels => "French Eggs",
		}
	],
	[
		'en-ingredients-parsing-multiple-times-with-specific-ingredients-not-converting-newlines-to-commas',
		{
			lc => "en",
			ingredients_text => "Black\ngrapes (Italy), sugar, eggs, paprika. Origin of paprika: Hungary",
			origin_en => "Origin of sugar: Guatemala",
			labels => "French Eggs",
		}
	],
	# Ingredient unit quantities
	[
		'en-ingredient-unit-quantities-1-egg-2-carrots',
		{
			lc => "en",
			ingredients_text => "1 egg, 2 carrots",
		}
	],
	[
		'en-ingredient-unit-quantities-1-large-egg-2-small-carrots',
		{
			lc => "en",
			ingredients_text => "1 large egg, 2 small carrots, 1 large apple",
		}
	],
	[
		'fr-ingredient-unit-quantities-1-gros-oeuf-2-petites-carottes',
		{
			lc => "fr",
			ingredients_text => "1 gros œuf, 2 petites carottes",
		}
	],
	# sizes stopwords
	[
		'en-1-small-size-orange-2-medium-size-apples',
		{
			lc => "en",
			ingredients_text => "1 small sized orange, 2 medium size apples",
		}
	],
	[
		'fr-ingredient-unit-quantities-3-concombres-de-petite-taille-2-aubergines-de-taille-moyenne',
		{
			lc => "fr",
			ingredients_text => "3 concombres de petite taille, 2 aubergines de taille moyenne",
		}
	],
	# E150c bug
	[
		"en-e150c",
		{
			lc => "en",
			ingredients_text => "E150c",
		}
	],
	# English ingredients but different main language: should still work
	[
		"en-ingredients-with-different-main-language",
		{
			lc => "fr",
			lang => "fr",
			ingredients_lc =>
				"sr",    # wrong ingredients_lc that was set previously before an ingredients_text language change
			ingredients_text => "sugar, salt, and pepper",
			ingredients_text_en => "sugar, salt, and pepper",
			ingredients_text_fr => "",
		}
	],

);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test

	if (defined $product_ref->{labels}) {

		compute_field_tags($product_ref, $product_ref->{lc}, "labels");
	}

	extract_ingredients_from_text($product_ref);

	# Note: extract_ingredients_from_text will create fields allergens/traces_from_ingredients
	# Those are kept in the unit tests, but in real processing, they are then removed by detect_allergens_from_text

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

# Vitamin E dosages must survive additive normalization, including decimal commas
# that look like an enumeration of E-numbers.
foreach my $test (
	['fr', 'vitamine E 105 mg', '105 mg', 0.105],
	['fr', 'vitamine E 105mg', '105 mg', 0.105],
	['fr', 'vitamine  E 105 mg', '105 mg', 0.105],
	['fr', "vitamine \tE  105 mg", '105 mg', 0.105],
	['fr', "vitamine\x{a0}E 105 mg", '105 mg', 0.105],
	['fr', 'vitamine E 105,5 mg', '105.5 mg', 0.1055],
	['fr', 'vitamine E 105.5 mg', '105.5 mg', 0.1055],
	['fr', 'vitamine E 105,125 mg', '105.125 mg', 0.105125],
	['fr', 'vitamine E 1050 mg', '1050 mg', 1.05],
	['fr', 'vit. E 105 mg', '105 mg', 0.105],
	['fr', 'vitamine E (105 mg)', '105 mg', 0.105],
	['fr', 'vitamine E 105 UI', '105 UI', undef],
	['en', 'vitamin E 105 mg', '105 mg', 0.105],
	['de', 'Vitamin E 105 mg', '105 mg', 0.105],
	['es', 'vitamina E 105 mg', '105 mg', 0.105],
	['pl', 'witamina E 105 mg', '105 mg', 0.105],
	['el', 'βιταμίνη E 105 mg', '105 mg', 0.105],
	['ru', 'витамин E 105 мг', '105 мг', 0.105],
	# The Cyrillic spelling is not yet a vitamin E synonym: preserve the dose
	# without inventing either an additive or a taxonomy match.
	['ru', 'витамин е 105 мг', '105 мг', 0.105, 'ru:витамин е', 0],
	)
{
	my ($lc, $text, $quantity, $quantity_g, $id, $known) = @$test;
	my $product = {lc => $lc, ingredients_text => $text};
	extract_ingredients_from_text($product);
	is(
		[map {[@{$_}{qw(id quantity quantity_g is_in_taxonomy)}]} @{$product->{ingredients}}],
		[[$id // 'en:vitamin-e', $quantity, $quantity_g, $known // 1]],
		"vitamin E dosage: $lc / $text"
	);
}

foreach my $text (
	'vitamines A, C et E 105 mg',
	'vitamines  A, C et E 105 mg',
	'vitamines A, C  et  E 105 mg',
	"vitamines\x{a0}A, C et E 105 mg",
	"vitamines A, C\x{a0}et\x{a0}E 105 mg",
	)
{
	my $product = {lc => 'fr', ingredients_text => $text};
	extract_ingredients_from_text($product);
	is(
		[
			map {[@{$_}{qw(id quantity quantity_g is_in_taxonomy)}]}
			grep {$_->{id} ne 'en:vitamins'} @{$product->{ingredients}}
		],
		[['en:vitamin-a', undef, undef, 1], ['en:vitamin-c', undef, undef, 1], ['en:vitamin-e', '105 mg', 0.105, 1],],
		"only the last vitamin receives the dosage: $text"
	);
}

foreach my $test (
	['3b 103 105 mg', 'en:ferrous-sulfate', '105 mg', 0.105, 1],
	['3B 103 fer 73,2 mg', 'en:ferrous-sulfate', '73.2 mg', 0.0732, 1],
	['sulfate de fer 3b 103 73,2 mg', 'en:ferrous-sulfate', '73.2 mg', 0.0732, 1],
	['3a 672a vitamine A 13400 UI', 'en:retinyl-acetate', '13400 UI', undef, 1],
	['vitamine E 3a 700 105 mg', 'en:dl-alpha-tocopheryl-acetate', '105 mg', 0.105, 1],
	['3B 405 sulfate de cuivre 7,2 mg', 'en:e519', '7.2 mg', 0.0072, 1],
	['E 330 acide citrique 105 mg', 'en:e330', '105 mg', 0.105, 1],
	['1b 306(i) 105 mg', 'en:e306', '105 mg', 0.105, 1],
	['Omega 3b 150mg', 'fr:Omega 3b', '150 mg', 0.15, 0],
	['Omega 3b 103 mg', 'fr:Omega 3b', '103 mg', 0.103, 0],
	['Omega E 150 mg', 'fr:Omega E', '150 mg', 0.15, 0],
	['3b 103,5 mg', 'fr:3b', '103.5 mg', 0.1035, 0],
	['3b 502 manganèse 7,6 mg', 'fr:3b 502 manganèse', '7.6 mg', 0.0076, 0],
	)
{
	my ($text, @expected) = @$test;
	my $product = {lc => 'fr', ingredients_text => $text};
	extract_ingredients_from_text($product);
	is([map {[@{$_}{qw(id quantity quantity_g is_in_taxonomy)}]} @{$product->{ingredients}}],
		[\@expected], "food and feed codes with quantities: $text");
}

my $feed_with_unknown_name = {lc => 'en', ingredients_text => '1b 306(i) unlisted extract 40 mg'};
extract_ingredients_from_text($feed_with_unknown_name);
is($feed_with_unknown_name->{ingredients}[0]{id}, 'en:e306', 'feed variant remains recognized before an unknown name');

my $ins_variants
	= {lc => 'pt', ingredients_text => 'Bicarbonato De Sódio (INS 500ii), Difosfato Tetrassódico (INS 450iii)'};
extract_ingredients_from_text($ins_variants);
is(
	[map {[$_->{id}, $_->{ingredients}[0]{id}]} @{$ins_variants->{ingredients}}],
	[['en:e500ii', 'en:e500ii'], ['en:e450iii', 'en:e450iii']],
	'INS variants retain every roman digit'
);

# OPFF 3770024561043: do not let a partly unknown code list change the
# newline interpretation and lose the taurine dosage at the end of the label.
my $multiline_codes = {lc => 'fr', ingredients_text => <<'LABEL'};
Porc 45 % (Cœur, Lobe de Poumon),
Poulet 28 % (Cœur, Foie), Eau, Huile de Colza, Carottes déshydratées, Courgettes déshydratées, Levure de bière, Minéraux, Thym.
CONSTITUANTS ANALYTIQUES
Protéines brutes : 10 %
Matières grasses brutes : 6 %
Cellulose brute : 0,6 %
Cendres brutes : 1,3 %
ENA (glucides) : 0,1 %
Humidité : 82 %
ADDITIFS NUTRITIONNELS
Manganèse (3b503) : 3 mg
Zinc (3b607 & 3b605) : 38 mg
Iode (3b203) : 0,51 mg
Sélénium (E8 & 3b811) : 19 µg
Vitamine D3 (3a671) : 427 UI
Vitamine E (3a700) : 388 mg
Vitamine B1 (3a821) : 54 mg
Vitamine B2 : 39 mg
Vitamine B3 (3a315) : 388 mg
Acide pantothénique (3a841) : 72 mg
Vitamine B6 (3a831) : 40 mg
Biotine (3a880) : 97 µg
Acide folique (3a316) : 9,7 mg
Vitamine B12 : 233 µg
Choline (3a890) : 58 mg
Taurine (3a370) : 660 mg
LABEL
extract_ingredients_from_text($multiline_codes);
my @identities = qw(en:protein en:manganese en:choline en:taurine);
is(
	[
		map {
			my $id = $_;
			my ($ingredient) = grep {$_->{id} eq $id} @{$multiline_codes->{ingredients}};
			[$ingredient->{id}, $ingredient->{quantity}]
		} @identities
	],
	[['en:protein', undef], ['en:manganese', '3 mg'], ['en:choline', '58 mg'], ['en:taurine', '660 mg']],
	'known ingredients and dosages survive mixed known and unknown codes on separate lines'
);

done_testing();
