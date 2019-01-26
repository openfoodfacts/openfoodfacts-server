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

# dummy product for testing

my $product_ref = {
	lc => "fr",
	ingredients_text_fr => "lait 98 % ,sel,ferments lactiques,coagulant Valeurs nutritionnelles Pour 100 g 1225 kj 295 kcal pour 22g 270 kJ 65 kcal Matières grasses dont acides gras saturés pour 100g 23g/ 15,5g pour 22g 5,1g/ 3,4g Glucides dont sucres traces Protéines pour 100g 22 g pour 22g 4,8 g Sel pour 100g 1,8 g pour 22g 0,40g Calcium pour 100g 680 mg(85 % ) pour 22g 150 mg(19 % ) Afin d'éviter les risques d'étouffement pour les enfants de moins de 4 ans, coupez en petites bouchées. AQR: Apports Quotidiens de Référence А conserver au froid après achat."
};

compute_languages($product_ref);
clean_ingredients_text($product_ref);

diag explain $product_ref;

is($product_ref->{ingredients_text_fr}, "lait 98 % ,sel,ferments lactiques,coagulant");



# empty product for easy copy and paste

$product_ref = {
        lc => "fr",
        ingredients_text_fr => ""
};

compute_languages($product_ref);
clean_ingredients_text($product_ref);

diag explain $product_ref;

is($product_ref->{ingredients_text_fr}, "");

##

$product_ref = {
        lc => "fr",
        ingredients_text_fr => "viande de porc (Origine UE), pistaches (fruits à coque) 5%, lactose (lait), sel, dextroses poivre, sucre, ail, ferments, conservateur : nitrate de potassium ; antioxydant : érythorbate de sodium. 134 g de viande utilisés pour 100 g de produit fini. Conditionné sous atmosphère protectrice. VALEURS NUTRITIONNELLES"
};

compute_languages($product_ref);
clean_ingredients_text($product_ref);

diag explain $product_ref;

is($product_ref->{ingredients_text_fr}, "viande de porc (Origine UE), pistaches (fruits à coque) 5%, lactose (lait), sel, dextroses poivre, sucre, ail, ferments, conservateur : nitrate de potassium ; antioxydant : érythorbate de sodium. 134 g de viande utilisés pour 100 g de produit fini.");


$product_ref = {
        lc => "fr",
        ingredients_text_fr => "ln rédients : Sauce soja 38.3% fèves de soja dégraissées'&i se blé, fèves de sop 1.6%, alcoo ), sucre eau, (eall, riz, alcool, ma t de riz, sel, correcteur d'acidité : acide sel, aldbôt;qolorant : caramel ordinaire ; amidon modifié de diamidon acétylé, phosphate de diamidon hydroxypro)/é' Valeurs nutritionnelles moyennes pour 100 ml', Og) -Glucides : 53g (dont sucres : 46g) - Protéines : 7,6g 92) BOUTEILLE VERRE ET SON BOUCHON PENSEZ À RECYCLER AU TRI ! CONSIGNE POUVANT VARIER LOCALEMENT > WWW.CONSIGNESDETRI.FR CONTENANCE : Pour toutes vos questions, 200 ml contactez notre Service Consommateurs : Bjorg et Compagnie Service Consommateurs 69561 Saint-Genis-Laval Cede»e France Avant ouverture, à conserver dans un endroit sec, frais et à l'abri de la lumière. Après ouverture, à conserver au réfrigérateur et à consommer rapidement. Fabriqué au Japon. Tanoshi.fr A consommer de préférence avant le / NO de lot : 16.0102019"
};

compute_languages($product_ref);
clean_ingredients_text($product_ref);

diag explain $product_ref;

is($product_ref->{ingredients_text_fr}, "ln rédients : Sauce soja 38.3% fèves de soja dégraissées'&i se blé, fèves de sop 1.6%, alcoo ), sucre eau, (eall, riz, alcool, ma t de riz, sel, correcteur d'acidité : acide sel, aldbôt;qolorant : caramel ordinaire ; amidon modifié de diamidon acétylé, phosphate de diamidon hydroxypro)/é'");


$product_ref = {
        lc => "fr",
	ingredients_text_fr => "Ingrédients: viande de porc 72 %. gras de porc, eau, farine (BLE), conservateur E325, épices et arornales, sel cle Guérarandes 1.1%. lactose (LAIT), acidifiant :E 262, conservateurs:E250 E316, arormes, arome naturel. A consommer cuit à coeur. Conditionné sous atmosphère protectrice ALLERGENES: GLUTEN,LAIT. Valeurs nutritionnelles pour 100 g: Energie: 1306 kJ ou 316 kcal Matières grasses 27.8 g donl acides gras saturés : 11.1 g Glucides: 3.1 g dont sucres 2.1 g Protéines 13.3 g Sel 1.4 g LOT 2530187431",
};

compute_languages($product_ref);
clean_ingredients_text($product_ref);

diag explain $product_ref;

is($product_ref->{ingredients_text_fr}, "viande de porc 72 %. gras de porc, eau, farine (BLE), conservateur E325, épices et arornales, sel cle Guérarandes 1.1%. lactose (LAIT), acidifiant :E 262, conservateurs:E250 E316, arormes, arome naturel.");


my $ingredients = "CERVITA NATURE VOUS APPORTE Valeurs nutritionnelles moyennes pour 100 g en % des RNJ* par pot INGRÉDIENTS: fromage blanc à 3,6% de matière grasse (75,3%), crème fouettée stérilisée (24,6%), gélatine, ferments lactiques. Valeur énergétique Proteines 561 k] 135 kcal 6,9g 3,8 g 3,7 9 10,3g 14 Glucides dont Sucres Lipides 15 35 dont Acides gras satures Fibres 6,9 g 0 9 0,03g allimentaires Sodium Repères Nutritionnels Journaliers pour un adulte avec un apport moyen de 2000 kcal. Ces valeurs et les portions peuvent varier vius ";

$ingredients = clean_ingredients_text_for_lang($ingredients, 'fr');

is($ingredients, "fromage blanc à 3,6% de matière grasse (75,3%), crème fouettée stérilisée (24,6%), gélatine, ferments lactiques.");

$ingredients = "INGREDIENTS lait entier (55,4%), crème (lait), sucre (9,7%), myrtille (8%), lait écrémé concentré, épaississants : amidon transformé, farine de graines de caroube, protéines de lait, extrait de carotte pourpre et d'hibiscus, correcteurs d'acidité : citrates de sodium, acide citrique, arôme naturel, ferments lactiques (lait). ";

$ingredients = clean_ingredients_text_for_lang($ingredients, 'fr');

is($ingredients, "lait entier (55,4%), crème (lait), sucre (9,7%), myrtille (8%), lait écrémé concentré, épaississants : amidon transformé, farine de graines de caroube, protéines de lait, extrait de carotte pourpre et d'hibiscus, correcteurs d'acidité : citrates de sodium, acide citrique, arôme naturel, ferments lactiques (lait).");

$ingredients = "Pomme*, fraise*. *: ingrédients issus de l'agriculture biologique";

$ingredients = clean_ingredients_text_for_lang($ingredients, 'fr');

is($ingredients, "Pomme*, fraise*. *: ingrédients issus de l'agriculture biologique");


$ingredients = "Ingrédients :
Pulpe de tomate 41% (tomate pelée 24.6%, jus de tomate 16.4%, acidifiant : acide citrique), purée de tomate 25%, eau, oignon,
crème fraîche
5%, lait de coco déshydraté 2,5% (contient des protéines de lait), curry 2%, sucre, amidon modifié de maïs, poivron vert, poivron rouge, sel, noix de coco râpée 1%, arôme naturel de curry 0,25%, acidifiant : acide lactique. Peut contenir des traces de céleri et de moutarde.
";

$ingredients = clean_ingredients_text_for_lang($ingredients, 'fr');

is($ingredients, "Pulpe de tomate 41% (tomate pelée 24.6%, jus de tomate 16.4%, acidifiant : acide citrique), purée de tomate 25%, eau, oignon,
crème fraîche
5%, lait de coco déshydraté 2,5% (contient des protéines de lait), curry 2%, sucre, amidon modifié de maïs, poivron vert, poivron rouge, sel, noix de coco râpée 1%, arôme naturel de curry 0,25%, acidifiant : acide lactique. Peut contenir des traces de céleri et de moutarde.");


done_testing();
