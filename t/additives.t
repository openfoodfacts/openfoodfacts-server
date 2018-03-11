#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my $product_ref = {
	lc => "fr",
	ingredients_text => "Acide citrique, colorant : e120, vitamine C, E-500"
};

extract_ingredients_classes_from_text($product_ref);

is($product_ref->{additives}, 
' [ acide-citrique -> en:e330  -> exists  -- ok  ]  [ colorant -> fr:colorant  ]  [ e120 -> en:e120  -> exists  -- ok  ]  [ vitamine-c -> en:e300  -> exists  -- mandatory_additive_class: en:acidity-regulator,en:antioxidant,en:flour-treatment-agent,en:sequestrant (current: en:colour)  -> exists as a vitamin en:vitamin-c  ]  [ e500 -> en:e500  -> exists  -- ok  ] '
);

# vitamine C is not used as an additive (no fuction)

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e330',
                                'en:e120',
                                'en:e500'
                              ],
);

# E316 detection - https://github.com/openfoodfacts/openfoodfacts-server/issues/269

$product_ref = {
        lc => "fr",
        ingredients_text => "Poitrine de porc, sel, conservateurs : lactate de potassium, nitrite de sodium, arôme naturel, sirop de glucose, antioxydant : érythorbate de sodium"
};

extract_ingredients_classes_from_text($product_ref);

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e326',
                                'en:e250',
				'en:e316',
                              ],
);


#use Data::Dumper;
#print STDERR Dumper($product_ref);

is(canonicalize_taxonomy_tag("fr", "additives", "erythorbate de sodium"), "en:e316");
is(canonicalize_taxonomy_tag("fr", "additives", "acide citrique"), "en:e330");

#is_deeply($product_ref, $expected_product_ref);

# issue/801-wrong-E471

$product_ref = {
        lc => "fr",
        ingredients_text => "Farine de blé 46 %, sucre de canne roux non raffiné, farine complète de blé 15 %, graines de sésame 13 %, huile de tournesol oléique 13 %, sel marin non raffiné, poudres à lever : carbonates d'ammonium et de sodium, acide citrique ; extrait de vanille, antioxydant : extraits de romarin.",
};

extract_ingredients_classes_from_text($product_ref);

#use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e503',
                                'en:e500',
                                'en:e330',
                                'en:e392',
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text => "carbonates de sodium et d'ammonium, nitrate de sodium et de potassium, Phosphate d'aluminium et de sodium.",
};

extract_ingredients_classes_from_text($product_ref);

#use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e500',
                                'en:e503',
                                'en:e251',
                                'en:e252',
				'en:e541',
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text => "calcium, sodium, potassium, aluminium, magnésium, fer, or, argent, sels",
};

extract_ingredients_classes_from_text($product_ref);

use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e173',
                                'en:e175',
                                'en:e174',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text => "sirop de maltitol, Chlorophylle, Sels de sodium et de potassium de complexes cupriques de chlorophyllines, Carotènes végétaux, Carotènes d'algues",
};

extract_ingredients_classes_from_text($product_ref);

use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e965ii',
                                'en:e140i',
				'en:e141ii',
                                'en:e160aii',
                                'en:e160aiv',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text => "colorants : carotène et extraits de paprika et de curcuma",
};

extract_ingredients_classes_from_text($product_ref);

use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

0 and is_deeply($product_ref->{additives_original_tags}, [
                                'en:e160a',
                                'en:e160c',
                                'en:e100',
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text => "colorants : E100 et E120, acidifiant : acide citrique et E331, colorants : lutéine et tartrazine",
};

extract_ingredients_classes_from_text($product_ref);

use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

0 and is_deeply($product_ref->{additives_original_tags}, [
                                'en:e100',
                                'en:e120',
                                'en:e330',
                                'en:e331',
                                'en:e100',
                                'en:e102',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text => "colorant: caroténoides mélangés",
};

extract_ingredients_classes_from_text($product_ref);

use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e160a',
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text => "Eau, huile végétale, amidon, vinaigre, moutarde (eau, vinaigre, graines de moutarde, sel, épices), oignons, jaune d'œuf, sel, amidon modifié, cerfeuil, vinaigre de malt (contient de l'orge), mélasse, sauce soja (contient du blé), sucre, jus de citron, sirop de glucose-fructose, anchois, extrait d'épices, tamarin, extrait d'herbes, épices, herbes. Stabilisateurs : gomme guar, farine de graines de caroube, gomme xanthane. Conservateurs : acide tartrique, acide citrique, acide malique, sorbate de potassium, benzoate de sodium. Colorants : bêta-carotène, carmoisine, caramel. Antioxydant : calcium-dinatrium-EDTA.
",
};

extract_ingredients_classes_from_text($product_ref);

use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
          'en:e14xx',
          'en:e412',
          'en:e410',
          'en:e415',
          'en:e334',
          'en:e330',
          'en:e296',
          'en:e202',
          'en:e211',
          'en:e160ai',
          'en:e122',
          'en:e150',
          'en:e385',
		      ],
);



# chewing-gum mentos

$product_ref = {
        lc => "fr",
        ingredients_text => "Edulcorants (xylitol (32%), erythritol, mannitol, maltitol, sorbitol, sirop de maltitol, aspartame, acésulfame K, sucralose), gomme base, arômes, agent épaissisant (gomme arabique), gélatine, colorant (dioxyde de titane), stabilisant (glycérol), émulsifiant (lécithine de soja), extrait naturel de thé vert, agent d'enrobage (cire de carnauba), antioxydant (E320).
",
};

extract_ingredients_classes_from_text($product_ref);

use Data::Dumper;
print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
          'en:e967',
          'en:e968',
          'en:e421',
          'en:e965i',
          'en:e420i',
          'en:e965ii',
          'en:e951',
          'en:e950',
          'en:e955',
          'en:e414',
          'en:e428',
          'en:e171',
          'en:e422',
          'en:e322i',
          'en:e903',
          'en:e320'
                              ],
);


# additives that are only additives when preceeded by their function

$product_ref = {
        lc => "fr",
        ingredients_text => "Eau, sucre, vitamine C"
};

extract_ingredients_classes_from_text($product_ref);

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text => "Eau, sucre, antioxydant: vitamine C"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e300',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text => "Eau, sucre, anti-oxydants: vitamine C"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e300',
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text => "Eau, sucre, antioxydants: vitamine C, acide citrique"
};

extract_ingredients_classes_from_text($product_ref);

#print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e300',
          'en:e330',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text =>
"vitamines (A,C)"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{vitamins_tags}, [
        "en:vitamin-a",
        "en:vitamin-c",
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text =>
"vitamines E, B6"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{vitamins_tags}, [
        "en:vitamin-e",
        "en:vitamin-b6",
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text =>
"vitamines B9 et B12"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{vitamins_tags}, [
        "en:folic-acid",
        "en:vitamin-b12",
                              ],
);



$product_ref = {
        lc => "fr",
        ingredients_text =>
"vitamines: D, K et PP"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{vitamins_tags}, [
        "en:vitamin-d",
        "en:vitamin-k",
        "en:niacin",
                              ],
);




$product_ref = {
        lc => "fr",
        ingredients_text =>
"vitamines : C, PP, acide folique et E"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{vitamins_tags}, [
        "en:vitamin-c",
        "en:niacin",
        "en:folic-acid",
        "en:vitamin-e",
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text =>
"Chlorures d'ammonium et de calcium"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";


is_deeply($product_ref->{additives_original_tags}, [
          'en:e510',
          'en:e509',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text =>
"Chlorures de calcium et ammonium"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";


is_deeply($product_ref->{additives_original_tags}, [
          'en:e509',
          'en:e510',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text =>
"Sulfates de fer, de zinc et de cuivre"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e519',
                              ],
);



$product_ref = {
        lc => "fr",
        ingredients_text =>
"Minéraux (carbonate de calcium)"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:calcium-carbonate",
                              ],
);



$product_ref = {
        lc => "fr",
        ingredients_text =>
"carbonate de calcium"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e170",
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
                              ],
);



$product_ref = {
        lc => "fr",
        ingredients_text =>
"Mineraux (carbonate de calcium, chlorures de calcium, potassium et magnésium, citrates de potassium et de sodium, phosphate de calcium, sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium)."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";


is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:calcium-carbonate",
	"en:calcium-chloride",
	"en:potassium-chloride",
	"en:magnesium-chloride",
	"en:potassium-citrate",
	"en:sodium-citrate",
	"en:calcium-phosphate",
	"en:ferrous-sulphate",
	"en:zinc-sulphate",
	"en:cupric-sulphate",
	"en:manganese-sulphate",
	"en:potassium-iodide",
	"en:sodium-selenite",
                              ],
);




$product_ref = {
        lc => "fr",
        ingredients_text =>
"(carbonate de calcium, chlorures de calcium, potassium et magnésium, citrates de potassium et de sodium, phosphate de calcium, sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium)."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";


is_deeply($product_ref->{additives_original_tags}, [
	"en:e170",
	"en:e509",
	"en:e508",
	"en:e511",
	"en:e332",
	"en:e331",
	"en:e519",
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:calcium-phosphate",
	"en:ferrous-sulphate",
	"en:zinc-sulphate",
	"en:manganese-sulphate",
	"en:potassium-iodide",
	"en:sodium-selenite",
                              ],
);





$product_ref = {
        lc => "fr",
        ingredients_text => 
"Lactosérum déminéralisé (lait) - Huiles végétales (Palme, Colza, Coprah, Tournesol, Mortierella alpina) - Lactose (lait) - Lait écrémé - Galacto- oligosaccharides (GOS) (lait) - Protéines de lactosérum concentrées (lait) - Fructo- oligosaccharides (FOS) - Huile de poisson - Chlorure de choline - Emulsifiant: lécithine de soja - Taurine - Nucléotides - Inositol - L-tryptophane - L-carnitine - Vitamines (C, PP, B5, B9, A, E, B8, B12, BI, D3, B6, K1, B2) - Minéraux (carbonate de calcium, chlorures de potassium et de magnésium, citrates de potassium et de sodium, phosphate de calcium, sulfates de fer, de zinc, de cuivre et de manganèse, iodure de potassium, sélénite de sodium)."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR Dumper($product_ref->{additives_original_tags});

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e322i',
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text => 
"Purée de pomme 40 %, sirop de glucose-fructose, farine de blé, protéines de lait, sucre, protéines de soja, purée de framboise 5 %, lactosérum, protéines de blé hydrolysées, sirop de glucose, graisse de palme non hydrogénée, humectant : glycérol végétal, huile de tournesol, minéraux (potassium, calcium, magnésium, fer, zinc, cuivre, sélénium, iode), jus concentré de raisin, arômes naturels, jus concentré de citron, levure désactivée, correcteur d'acidité : citrates de sodium, sel marin, acidifiant : acide citrique, vitamines A, B1, B2, B5, B6, B9, B12, C, D, H, PP et E (lactose, protéines de lait), cannelle, poudres à lever (carbonates de sodium, carbonates d'ammonium)."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR Dumper($product_ref->{additives_original_tags});

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e422',
          'en:e331',
          'en:e330',
          'en:e500',
          'en:e503',
                              ],
);

is_deeply($product_ref->{vitamins_tags}, [
          'en:vitamin-a',
          'en:thiamin',
          'en:riboflavin',
          'en:pantothenic-acid',
          'en:vitamin-b6',
          'en:folic-acid',
          'en:vitamin-b12',
          'en:vitamin-c',
          'en:vitamin-d',
          'en:biotin',
          'en:niacin',
          'en:vitamin-e',
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
          'en:potassium',
          'en:calcium',
          'en:magnesium',
          'en:iron',
          'en:zinc',
          'en:copper',
          'en:selenium',
          'en:iodine',
                              ],
);



$product_ref = {
        lc => "en",
        ingredients_text =>
"Calcium phosphate"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
        "en:calcium-phosphate",
                              ],
);

$product_ref = {
        lc => "en",
        ingredients_text =>
"acidity regulators: Calcium phosphate"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e341"
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text =>
"Dextrines maltées de mais, lait écrémé, huiles végétales non hydrogénées : colza, noix de coco, tournesol, lactose, Bifidus longum maternis. Minéraux : phosphate de calcium naturel de lait, oxyde de magnésium naturel, pyrophosphate de fer, gluconate de zinc, gluconate de cuivre, iodate de potassium, sélénite de sodium Vitamine d'Origine Végétale : L-ascorbate de sodium (vitamine C, cobalamine (vitamine B12), vitamines nature identique : niacine (vitamine PP), acide pantothénique (vitamine B5), riboflavine (vitamine B2), thiamine (vitamine B1), pyridoxine (vitamine B6), rétinol (vitamine A), acide folique (vitamine B9), phytoménadione (vitamine K1), biotine (vitamine B8), ergocalciférol (vitamine D2), vitamine Naturelle : tocophérols naturels extrait de tournesol (vitamine E)"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
        "en:e1400",
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:calcium-phosphate",
	"en:magnesium-oxide",
	"en:ferric-diphosphate",
	"en:zinc-gluconate",
	"en:cupric-gluconate",
	"en:potassium-iodate",
	"en:sodium-selenite",
                             ],
);

is_deeply($product_ref->{vitamins_tags}, [
	"en:sodium-l-ascorbate",
	"en:vitamin-c",
	"en:vitamin-b12",
	"en:niacin",
	"en:pantothenic-acid",
	"en:riboflavin",
	"en:thiamin",
	"en:vitamin-b6",
	"en:retinol",
	"en:vitamin-a",
	"en:folic-acid",
	"en:phylloquinone",
	"en:biotin",
	"en:ergocalciferol",
	"en:vitamin-e",
                              ],
);



$product_ref = {
        lc => "fr",
        ingredients_text =>
"Oxyde de magnésium, Acide gluconique, Gluconate de calcium"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e574",
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:magnesium-oxide",
	"en:calcium-gluconate",
                              ],
);

is_deeply($product_ref->{vitamins_tags}, [
                              ],
);



$product_ref = {
        lc => "fr",
        ingredients_text =>
"Céréales 90,5 % (farine de blé et gluten de blé 57,8 %, farine complète de blé 31 %, farine de blé malté), sucre, graines de lin, levure, huile de palme, fibres d'avoine, sel, minéraux [calcium (orthophosphate), fer (fumarate), magnésium (oxyde)], agent de traitement de la farine (acide ascorbique), vitamines [E, thiamine (B1), riboflavine (B2), B6, acide folique)]."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e300",
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:calcium",
	"en:iron",
	"en:magnesium",
                              ],
);

is_deeply($product_ref->{vitamins_tags}, [
	"en:vitamin-e",
	"en:thiamin",
	"en:riboflavin",
	"en:vitamin-b6",
	"en:folic-acid",
                              ],
);


$product_ref = {
        lc => "en",
        ingredients_text =>
"REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), ACIDITY REGULATOR (INS 334), STABILIZER (INS 440, INS 337), WATER (FOR MAINTAINING DESIRED BRIX), CONTAINS PERMITTED NATURAL FLAVOUR & NATURAL IDENTICAL COLOURING SUBSTANCES (INS 141[i])"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e300",
	"en:e334",
	"en:e440",
	"en:e337",
	"en:e141",
                              ],
);


# bug 1133
$product_ref = {
        lc => "en",
        ingredients_text =>
"water, sugar, tea, lemon juice, flavouring, acidity regulator (330, 331), vitamin C, antioxidant (304)"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e330",
	"en:e331",
	"en:e304",
                              ],
);

done_testing();
