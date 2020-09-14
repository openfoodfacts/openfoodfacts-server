#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP', filter => "none";
#use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::ImportConvert qw/:all/;
use ProductOpener::Config qw/:all/;

ProductOpener::Ingredients::validate_regular_expressions();

my @tests = (

	["fr", "lait 98 % ,sel,ferments lactiques,coagulant Valeurs nutritionnelles Pour 100 g 1225 kj 295 kcal pour 22g 270 kJ 65 kcal Matières grasses dont acides gras saturés pour 100g 23g/ 15,5g pour 22g 5,1g/ 3,4g Glucides dont sucres traces Protéines pour 100g 22 g pour 22g 4,8 g Sel pour 100g 1,8 g pour 22g 0,40g Calcium pour 100g 680 mg(85 % ) pour 22g 150 mg(19 % ) Afin d'éviter les risques d'étouffement pour les enfants de moins de 4 ans, coupez en petites bouchées. AQR: Apports Quotidiens de Référence А conserver au froid après achat.",
	"lait 98 % ,sel,ferments lactiques,coagulant"],

	["fr",
	"viande de porc (Origine UE), pistaches (fruits à coque) 5%, lactose (lait), sel, dextroses poivre, sucre, ail, ferments, conservateur : nitrate de potassium ; antioxydant : érythorbate de sodium. 134 g de viande utilisés pour 100 g de produit fini. Conditionné sous atmosphère protectrice. VALEURS NUTRITIONNELLES",
	"viande de porc (Origine UE), pistaches (fruits à coque) 5%, lactose (lait), sel, dextroses poivre, sucre, ail, ferments, conservateur : nitrate de potassium ; antioxydant : érythorbate de sodium. 134 g de viande utilisés pour 100 g de produit fini."],

	["fr",
	"ln rédients : Sauce soja 38.3% fèves de soja dégraissées'&i se blé, fèves de sop 1.6%, alcoo ), sucre eau, (eall, riz, alcool, ma t de riz, sel, correcteur d'acidité : acide sel, aldbôt;qolorant : caramel ordinaire ; amidon modifié de diamidon acétylé, phosphate de diamidon hydroxypro)/é' Valeurs nutritionnelles moyennes pour 100 ml', Og) -Glucides : 53g (dont sucres : 46g) - Protéines : 7,6g 92) BOUTEILLE VERRE ET SON BOUCHON PENSEZ À RECYCLER AU TRI ! CONSIGNE POUVANT VARIER LOCALEMENT > WWW.CONSIGNESDETRI.FR CONTENANCE : Pour toutes vos questions, 200 ml contactez notre Service Consommateurs : Bjorg et Compagnie Service Consommateurs 69561 Saint-Genis-Laval Cede»e France Avant ouverture, à conserver dans un endroit sec, frais et à l'abri de la lumière. Après ouverture, à conserver au réfrigérateur et à consommer rapidement. Fabriqué au Japon. Tanoshi.fr A consommer de préférence avant le / NO de lot : 16.0102019",
	"ln rédients : Sauce soja 38.3% fèves de soja dégraissées'&i se blé, fèves de sop 1.6%, alcoo ), sucre eau, (eall, riz, alcool, ma t de riz, sel, correcteur d'acidité : acide sel, aldbôt;qolorant : caramel ordinaire ; amidon modifié de diamidon acétylé, phosphate de diamidon hydroxypro)/é'"],

	["fr",
	"Ingrédients: viande de porc 72 %. gras de porc, eau, farine (BLE), conservateur E325, épices et arornales, sel cle Guérarandes 1.1%. lactose (LAIT), acidifiant :E 262, conservateurs:E250 E316, arormes, arome naturel. A consommer cuit à coeur. Conditionné sous atmosphère protectrice ALLERGENES: GLUTEN,LAIT. Valeurs nutritionnelles pour 100 g: Energie: 1306 kJ ou 316 kcal Matières grasses 27.8 g donl acides gras saturés : 11.1 g Glucides: 3.1 g dont sucres 2.1 g Protéines 13.3 g Sel 1.4 g LOT 2530187431",
	"Viande de porc 72 %. gras de porc, eau, farine (BLE), conservateur E325, épices et arornales, sel cle Guérarandes 1.1%. lactose (LAIT), acidifiant :E 262, conservateurs:E250 E316, arormes, arome naturel."],

	["fr",
	"CERVITA NATURE VOUS APPORTE Valeurs nutritionnelles moyennes pour 100 g en % des RNJ* par pot INGRÉDIENTS: fromage blanc à 3,6% de matière grasse (75,3%), crème fouettée stérilisée (24,6%), gélatine, ferments lactiques. Valeur énergétique Proteines 561 k] 135 kcal 6,9g 3,8 g 3,7 9 10,3g 14 Glucides dont Sucres Lipides 15 35 dont Acides gras satures Fibres 6,9 g 0 9 0,03g allimentaires Sodium Repères Nutritionnels Journaliers pour un adulte avec un apport moyen de 2000 kcal. Ces valeurs et les portions peuvent varier vius ",
	"Fromage blanc à 3,6% de matière grasse (75,3%), crème fouettée stérilisée (24,6%), gélatine, ferments lactiques."],

	["fr",
	"INGREDIENTS lait entier (55,4%), crème (lait), sucre (9,7%), myrtille (8%), lait écrémé concentré, épaississants : amidon transformé, farine de graines de caroube, protéines de lait, extrait de carotte pourpre et d'hibiscus, correcteurs d'acidité : citrates de sodium, acide citrique, arôme naturel, ferments lactiques (lait). ",
	"Lait entier (55,4%), crème (lait), sucre (9,7%), myrtille (8%), lait écrémé concentré, épaississants : amidon transformé, farine de graines de caroube, protéines de lait, extrait de carotte pourpre et d'hibiscus, correcteurs d'acidité : citrates de sodium, acide citrique, arôme naturel, ferments lactiques (lait)."],

	["fr", "Pomme*, fraise*. *: ingrédients issus de l'agriculture biologique",
	"Pomme*, fraise*. *: ingrédients issus de l'agriculture biologique"],

	["fr", "Ingrédients :
Pulpe de tomate 41% (tomate pelée 24.6%, jus de tomate 16.4%, acidifiant : acide citrique), purée de tomate 25%, eau, oignon,
crème fraîche
5%, lait de coco déshydraté 2,5% (contient des protéines de lait), curry 2%, sucre, amidon modifié de maïs, poivron vert, poivron rouge, sel, noix de coco râpée 1%, arôme naturel de curry 0,25%, acidifiant : acide lactique. Peut contenir des traces de céleri et de moutarde.
",
	"Pulpe de tomate 41% (tomate pelée 24.6%, jus de tomate 16.4%, acidifiant : acide citrique), purée de tomate 25%, eau, oignon,
crème fraîche
5%, lait de coco déshydraté 2,5% (contient des protéines de lait), curry 2%, sucre, amidon modifié de maïs, poivron vert, poivron rouge, sel, noix de coco râpée 1%, arôme naturel de curry 0,25%, acidifiant : acide lactique. Peut contenir des traces de céleri et de moutarde."],

	["fr", "Lait demi - écrémé, fromage Saint - Moret 3% - pommes - bananes",
	"Lait demi-écrémé, fromage Saint-Moret 3% - pommes - bananes"],

	############################
	# # SCANDINAVIAN LANGUAGES #
	############################
	["da",
	 "ingredienser: 56 % kogte kikærter (kikærter, vand), solsikkeolie, vand, 9 % sesampuré, citronsaft, sukker, salt.",
	 "56 % kogte kikærter (kikærter, vand), solsikkeolie, vand, 9 % sesampuré, citronsaft, sukker, salt."
	],
	["da",
	 "56 % kogte kikærter (kikærter, vand), solsikkeolie, vand, 9 % sesampuré, citronsaft, sukker, salt.",
	 "56 % kogte kikærter (kikærter, vand), solsikkeolie, vand, 9 % sesampuré, citronsaft, sukker, salt."
	],
	["da",
	 "INGREDIENSER : 56 % kogte kikærter (kikærter, vand), solsikkeolie, vand, 9 % sesampuré, citronsaft, sukker, salt. NÆRINGSINDHOLD pr. 100 g; Energi 1204 kJ /291 kcal Fedt 24g heraf mættede fedtsyrer 2,89g Kulhydrat 7,3g heraf sukkerarter 0,9g",
	 "56 % kogte kikærter (kikærter, vand), solsikkeolie, vand, 9 % sesampuré, citronsaft, sukker, salt."
	],
	["is",
	 "Hveiti, mjólk, egg, jurtafita, maltextrín (Úr hveiti), sykur, E450a, E500, bragðefni. Næringargildi í 100g af þurrefni: Orka 527kJ Fita 3,6g Þar af mettuð 2,7g Kolvetni 19,1g þar af sykurtegundii 3,1g",
	 "Hveiti, mjólk, egg, jurtafita, maltextrín (Úr hveiti), sykur, E450a, E500, bragðefni."
	],
	["is",
	 "Innihald: Sykur, glúkósi, fondant, bragðefni, mjólkurduft, kakósmjör, kakómassi, sojalesitín (£322), litarefni (E160a). Gæti innihaldið snefil af heslihnetum, möndlum og kókosmjóli.",
	 "Sykur, glúkósi, fondant, bragðefni, mjólkurduft, kakósmjör, kakómassi, sojalesitín (£322), litarefni (E160a). Gæti innihaldið snefil af heslihnetum, möndlum og kókosmjóli."
	],
	["is",
	 "INNIHALDSEFNI : Vatn, möndlu (5%), agave-síróp*, sjávarsalt. *Lifrænt. Eftir opnum skal geyma drykkinn í kæli og neyta innan 3-4 daga.",
	 "Vatn, möndlu (5%), agave-síróp*, sjávarsalt. *Lifrænt."
	],
	["nb",
	 "pasteurisert melk, syrekultur, salt, mikrøobiell løpe og surhetsregularnde middel (kalsiumklorid).",
	 "pasteurisert melk, syrekultur, salt, mikrøobiell løpe og surhetsregularnde middel (kalsiumklorid)."
	],
	["nb",
	 "Ingredienser: pasteurisert melk, syrekultur, salt, mikrøobiell løpe og surhetsregularnde middel (kalsiumklorid).",
	 "Pasteurisert melk, syrekultur, salt, mikrøobiell løpe og surhetsregularnde middel (kalsiumklorid)."
	],
	["nb",
	 "INGREDIENSER : pasteurisert melk, syrekultur, salt, mikrøobiell løpe og surhetsregularnde middel (kalsiumklorid). NÆRINGSINNHOLD: 100 g vare gir ca.: energi 1458 kJ (351 kcal), fett 27 g, -hvorav mettede fettsyrer 17 g, karbohydrat 0 g, -hvorav sukkerarter 0 g, protein 27 g, salt 1,2g.",
	 "Pasteurisert melk, syrekultur, salt, mikrøobiell løpe og surhetsregularnde middel (kalsiumklorid)."
	],
	["sv",
	 "Pastöriserad mjölk, salt, syrningskultur, ystenzym.",
	 "Pastöriserad mjölk, salt, syrningskultur, ystenzym."
	],
	["sv",
	 "INGREDIENSER : Pastöriserad mjölk, salt, syrningskultur, ystenzym. Näringsvärde per 100 g ost Energi 1763 kJ/426 kcal Fett 38g varav mättat fett 24g Kolhydrater 0g varav sockerarter 0g Protein 20g Salt 1,8g",
	 "Pastöriserad mjölk, salt, syrningskultur, ystenzym."
	],
	["sv",
	 "Ingredienser: Pastöriserad mjölk, salt, syrningskultur, ystenzym.",
	 "Pastöriserad mjölk, salt, syrningskultur, ystenzym."
	],

	############################
	# Finnish

	["fi",
	"vesi, kaura 10%, jodioitu suola Ravintoarvo per 100 ml: Energi/Energia 245 kJ/59 kcal Fett/Fedt/Rasva 3,0g varav/hvorav/heraf/josta mättat fett/mettede fettsyrer tyydyttynyttä 0,3g Kolhydrat / Karbohydrat Kulhydrat/Hiilihydraatti 6,6g varav/hvorav/heraf/josta sockerarter/sukkerarter sokereita 4,0g Fiber/Kostfiber Ravintokuitu 0,8g Protein/Proteiini 1,0g Salt/Suola 0,10g Vitamin D/D-vitamiini 1,5 ug (30%**) Riboflavin/Riboflaviini 0,21 mg (15%**) Kalcium/Kalsium 120mg (15%*)",
	"vesi, kaura 10%, jodioitu suola"],

	["fi",
	"Vesi, manteli 2%, kivennäisaine (kalsiumkarbonaatti), suola, emulgointiaine (E 322) SÄILYTYS: Huoneenlämmössä. Avattuna: 4 päivää jääkaapissa.",
	"Vesi, manteli 2%, kivennäisaine (kalsiumkarbonaatti), suola, emulgointiaine (E 322)"],

	["fi",
	"Pastöroitu maito, maitoproteiini, suola, paakkuuntumisenestoaine (E460), hapate. Pakattu suojakaasuun. SÄILÖNTÄAINEETON. LAKTOOSITON. Juusto sisältää runsaasti kalsiumia ja proteiinja",
	"Pastöroitu maito, maitoproteiini, suola, paakkuuntumisenestoaine (E460), hapate."],

	["fi",
	"Ainesosat: sitruunajauhe, maustamisvalmiste (vesi, suola, glukoosisiirappi, valkopippuri), rapsiöljy. Valmistus pannulla: Paista jäisiä leikkeitä kuumalla pannulla runsaassa öljyssä kummaltakin puolelta n. 3 minuuttia. Sulanutta tuotetta ei saa jäädyttää uudelleen. Kuumennettava läpikotaisin ennen tarjoilua.",
	"Sitruunajauhe, maustamisvalmiste (vesi, suola, glukoosisiirappi, valkopippuri), rapsiöljy."],

	["fi",
	"Cornflakes - Maissihiutaleet INGREDIENSER: Majs 92% (EU), socker, kornmaltextrakt, salt. Kan innehälla spär av vete, räg, havre, mjölk och soja. FÖRVARING: Torrt och inte för varmt. AINESOSAT: Maissi 92% (EU), sokeri, ohramallasuute, suola. PARASTA ENNEN: Katso pakkauksen yläosa.",
	"Maissi 92% (EU), sokeri, ohramallasuute, suola."],

	["fi",
	"VALMISTUSAINEET Vesi, riisi 11%, auringonkukkaöljy, kivennäinen (kalsiumkarbonaatti), merisuola, vitamiinit (riboflaviini, D-vitamiini)",
	"Vesi, riisi 11%, auringonkukkaöljy, kivennäinen (kalsiumkarbonaatti), merisuola, vitamiinit (riboflaviini, D-vitamiini)"],

	["fi",
	"AINEKSET / INGREDIENSER :
Naudanliha (75 %), vesi, mausteet (mm.sipuli),
vehnäjauho
5%, suola, perunakuitu.
Saattaa sisältää pieniä määrlä soijaa ja seesaminslemeniä",
	"Naudanliha (75 %), vesi, mausteet (mm.sipuli),
vehnäjauho
5%, suola, perunakuitu.
Saattaa sisältää pieniä määrlä soijaa ja seesaminslemeniä"],

	# Spanish

	["es", "blabla. INGREDIENTES - AZUCAR - ALMENDRAS",
	"AZUCAR - ALMENDRAS"],

	["es", "Pasta de cacao*; azúcar de caña*; aceite de almendra en polvo*: 20% (almendras*: 55%, jarabe de arroz deshidratado* fibras de acacia*. aroma natural de vanilla*); manteca de cacao*. * Ingredientes de comercio justo.",
	"Pasta de cacao*; azúcar de caña*; aceite de almendra en polvo*: 20% (almendras*: 55%, jarabe de arroz deshidratado* fibras de acacia*. aroma natural de vanilla*); manteca de cacao*. * Ingredientes de comercio justo."],

	# English

	["en",
	"Caories per gram: at 9 Carbekydrate 4 . Protein 4 INGREDIENTS: MECHANICALLY SEPARATED CHIGKEN, PORK, CORN SYRUP, WATER, 2% OR LESS OF: MODIFIED FOOD STARCH NATURAL FLAVORINGS, SALT, POTASSIUM LACTATE, BEEF, SODIUM PHOSPHATES, SODIUM DIACETATE, PAPRIKA, SODIUMERYTHORBATE, SODIUM NITRITE, EXTRACTIVES OF PAPRIKA. DIST& SOLD EXCLUSIVELY BY: ALD ALDI Tuice as Nice GLUTEN FREE BATAVIA, IL 610 GUARANTEE NET WT 48 0Z (3 LB) 1. 0. TRANS FATNG Item eplaced money refunded PLASTIC WRAP
Edit ingredients (en)",
	"MECHANICALLY SEPARATED CHIGKEN, PORK, CORN SYRUP, WATER, 2% OR LESS OF: MODIFIED FOOD STARCH NATURAL FLAVORINGS, SALT, POTASSIUM LACTATE, BEEF, SODIUM PHOSPHATES, SODIUM DIACETATE, PAPRIKA, SODIUMERYTHORBATE, SODIUM NITRITE, EXTRACTIVES OF PAPRIKA."],
	
	["en",
	"INGREDIENTS Almonds (76%), rice malt, dried blueberries (6%), sesame seeds, unrefined cane sugar natural flavours, sea salt. NUTRITIONAL INFORMATION Serving: 1, Serving size: 20g",
	"Almonds (76%), rice malt, dried blueberries (6%), sesame seeds, unrefined cane sugar natural flavours, sea salt."],
	
	["en",
	"Savoury crackers with sesame seeds. Ingredients: Wheat flour, palm oil, sesame seeds 4.9 %, glucose-fructose syrup, sugar, poppy seeds 2.3 %, raising agents (ammonium carbonates, calcium phosphates, sodium carbonates), salt, malted barley flour, dried yeast, wheat gluten, flavouring (contains celery). May contain egg, milk, nuts. Nutrition Information 1 Portion %*/1 Portion (25 g) 100 g (25 g) 2023 kJ",
	"Wheat flour, palm oil, sesame seeds 4.9 %, glucose-fructose syrup, sugar, poppy seeds 2.3 %, raising agents (ammonium carbonates, calcium phosphates, sodium carbonates), salt, malted barley flour, dried yeast, wheat gluten, flavouring (contains celery). May contain egg, milk, nuts."],

	# Polish
	["pl",
	"jogurt*, cukier, owoce 7%, (maliny 2,3%, ananasy 1,8%, sok ananasowy z koncentratu 1,6%, sok malinowy z koncentratu 1,3%), musli 2,5% (otręby pszenne, płatki owsiane, pszenica, siemię lniane, ziarno słonecznika,orzechy laskowe), koncentrat soku z buraków czerwonych - aromat. *zawiera składniki pochodzące z mleka oraz żywe kultury bakterii.",
	"jogurt*, cukier, owoce 7%, (maliny 2,3%, ananasy 1,8%, sok ananasowy z koncentratu 1,6%, sok malinowy z koncentratu 1,3%), musli 2,5% (otręby pszenne, płatki owsiane, pszenica, siemię lniane, ziarno słonecznika,orzechy laskowe), koncentrat soku z buraków czerwonych - aromat. *zawiera składniki pochodzące z mleka oraz żywe kultury bakterii."],
	
	["fr","INGREDIENTS : badiane* (Illicium verum) 30%, anis vert* (Pimpinella anisum) 30%, fenouil* (Foeniculum vulgare) 30%, racine de réglisse* (Glycyrrhiza glabra). *Produits issus de l'agriculture biologique. INGREDIENTS: star anise* 30%, green anise* 30%, fennel* 30%, liquorice*. *Organically grown products. INGREDIËNTEN: steranijs* 30%, groene anijs* 30%, venkel* 30%, zoethout*. *Biologisch geteelde producten.",
"Badiane* (Illicium verum) 30%, anis vert* (Pimpinella anisum) 30%, fenouil* (Foeniculum vulgare) 30%, racine de réglisse* (Glycyrrhiza glabra). *Produits issus de l'agriculture biologique. INGREDIENTS: star anise* 30%, green anise* 30%, fennel* 30%, liquorice*. *Organically grown products. INGREDIËNTEN: steranijs* 30%, groene anijs* 30%, venkel* 30%, zoethout*. *Biologisch geteelde producten."],

	["de", "ZUTATEN: 67% Pizzateig: Weizenmehl, Trinkwasser. ZUTATEN: 33% zubereitete Tomatensosse: 92,7 % Tomatenpüree mit kleinen Tomatenstückchen.", "67% Pizzateig: Weizenmehl, Trinkwasser. ZUTATEN: 33% zubereitete Tomatensosse: 92,7 % Tomatenpüree mit kleinen Tomatenstückchen."],

);

foreach my $test_ref (@tests) {

	is(cut_ingredients_text_for_lang($test_ref->[1], $test_ref->[0]), $test_ref->[2]);

}

# clean_field() tests

@tests = (

	["fr","<STRONG><i>thon</i></STRONG>, eau, sel",
	"_thon_, eau, sel"],

	["fr", "<b>blé</b>, <i>froment</i>, <strong><u>soja</u></strong>, test",
	"_blé_, _froment_, _soja_, test"],

	["fr", "Traces de <b> fruits à coque </b>, <b></b><b>lait)</b> - extrait de malt d'<u>orge - </u>sel, persil- poivre blanc -ail",
	"Traces de _fruits \x{e0} coque_ , _lait_) - extrait de malt d'_orge_ - sel, persil - poivre blanc - ail"],

	["fr", "Farine de<STRONG> <i>blé</i> </STRONG> - sucre",
	"Farine de _blé_ - sucre"],

	["en", "INGREDIENTS - SALT, SUGAR, SPICES 12%", "Salt, sugar, spices 12%"],
	["en", "Natural pasteurized cow milk - Natural milk fat", "Natural pasteurized cow milk - Natural milk fat"],
	["en", "NA.", ""],


	# HTML entities
	["fr", "P&acirc;tes alimentaires cuites aromatis&eacute;es au curcuma", "Pâtes alimentaires cuites aromatisées au curcuma"],

	# The clean_fields function should remove "Ingrédients:" only when at the very beginning
	["fr","eau, sel, sucre - Garniture - Ingrédients: Chocolat, sucre",
		"Eau, sel, sucre - Garniture - Ingrédients: Chocolat, sucre"],
	["fr","Ingrédients: eau, sel, sucre - Garniture - Ingrédients: Chocolat, sucre",
		"Eau, sel, sucre - Garniture - Ingrédients: Chocolat, sucre"],

);

# Results of some tests are different on the producers platform (on purpose)

$server_options{producers_platform} = 0;

foreach my $test_ref (@tests) {

	my $ingredients_lc = "ingredients_text_" . $test_ref->[0];

	my $product_ref = { 
		lc => $test_ref->[0],
		$ingredients_lc => $test_ref->[1],
	};

	clean_fields($product_ref);
	is($product_ref->{$ingredients_lc}, $test_ref->[2]);
}

$server_options{producers_platform} = 1;


# split_generic_name_from_ingredients() tests

@tests = (

	["fr", "test", undef, "Test"],

	["fr","Pâtes de fruits aromatisées à la fraise et à la canneberge, contenant de la maltodextrine et de l'acérola. Source de vitamines B1, B6, B12 et C.  Ingrédients : Pulpe de fruits 50% (poire William 25%, fraise 15%, canneberge 10%), sucre, sirop de glucose de blé, maltodextrine 5%, stabilisant : glycérol, gélifiant : pectine, acidifiant : acide citrique, arôme naturel de fraise, arôme naturel de canneberge, poudre d'acérola (acérola, maltodextrine) 0,4%, vitamines : B1, B6 et B12. Fabriqué dans un atelier utilisant: GLUTEN*, FRUITS A COQUE*. * Allergènes",
	"Pâtes de fruits aromatisées à la fraise et à la canneberge, contenant de la maltodextrine et de l'acérola. Source de vitamines B1, B6, B12 et C.",
	"Pulpe de fruits 50% (poire William 25%, fraise 15%, canneberge 10%), sucre, sirop de glucose de blé, maltodextrine 5%, stabilisant : glycérol, gélifiant : pectine, acidifiant : acide citrique, arôme naturel de fraise, arôme naturel de canneberge, poudre d'acérola (acérola, maltodextrine) 0,4%, vitamines : B1, B6 et B12. Fabriqué dans un atelier utilisant: GLUTEN*, FRUITS A COQUE*. * Allergènes"],


);

foreach my $test_ref (@tests) {

	my $ingredients_lc = "ingredients_text_" . $test_ref->[0];

	my $product_ref = { lc => $test_ref->[0],
		$ingredients_lc => $test_ref->[1] };

	clean_fields($product_ref);

	is($product_ref->{"generic_name_" . $test_ref->[0]}, $test_ref->[2]);
	is($product_ref->{$ingredients_lc}, $test_ref->[3]) or diag explain $product_ref;

}

done_testing();
