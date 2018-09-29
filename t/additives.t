#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;

use Log::Any::Adapter ('Stderr');

# dummy product for testing

my $product_ref = {
	lc => "es",
	ingredients_text => "Agua, vitaminas (B1, C y E), Vitamina B2"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

# vitamine C is not used as an additive (no fuction)

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

is_deeply($product_ref->{vitamins_tags}, [
        "en:thiamin",
        "en:vitamin-c",
        "en:vitamin-e",
        "en:riboflavin",
                              ],
);



my $product_ref = {
	lc => "fr",
	ingredients_text => "Acide citrique, colorant : e120, vitamine C, E-500"
};

extract_ingredients_classes_from_text($product_ref);

is($product_ref->{additives}, 
' [ acide-citrique -> en:e330  -> exists  -- ok  ]  [ colorant -> fr:colorant  ]  [ e120 -> en:e120  -> exists  -- ok  ]  [ vitamine-c -> en:e300  -> exists  -- mandatory_additive_class: en:acidity-regulator,en:antioxidant,en:flour-treatment-agent,en:sequestrant,en:acid (current: en:colour)  -> exists as a vitamin en:vitamin-c  ]  [ e500 -> en:e500  -> exists  -- mandatory_additive_class: en:acidity-regulator, en:raising-agent (current: en:vitamins)  -- e-number  ] '
);

# vitamine C is not used as an additive (no fuction)

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e330',
                                'en:e120',
                                'en:e500',
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

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
				'en:e502',
				'en:e251',
				'en:e541',
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text => "poudres à lever : carbonates de sodium et d'ammonium",
};

extract_ingredients_classes_from_text($product_ref);

#use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_original_tags});

is_deeply($product_ref->{additives_original_tags}, [
                                'en:e500',
                                'en:e503',
				]
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
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
          'en:calcium-chloride',
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
          'en:e510',
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
          'en:calcium-chloride',
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
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:ferrous-sulphate",
	"en:zinc-sulphate",
	"en:cupric-sulphate",
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
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:calcium-carbonate",
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

$product_ref = {
        lc => "fr",
        ingredients_text =>
"chlorure de choline, taurine, inositol, L-cystéine, sels de sodium de l’AMP, citrate de choline, carnitine"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

is_deeply($product_ref->{amino_acids_tags}, [
	"en:l-cysteine",
                              ],
);

is_deeply($product_ref->{nucleotides_tags}, [
	"en:sodium-salts-of-amp",
                              ],
);

is_deeply($product_ref->{other_nutritional_substances_tags}, [
	"en:choline-chloride",
	"en:taurine",
	"en:inositol",
	"en:carnitine",

                              ],
);




$product_ref = {
        lc => "fr",
        ingredients_text =>
"émulsifiant: chlorure de choline, agent de traitement de la farine:l cystéine"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
        "en:e1001",
        "en:e920",
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text =>
"
Lait partiellement écrémé, eau, lactose, maltodextrines, huiles végétales (colza, tournesol), vitamines : A, B1, B2, B5, B6, B8, B9, B12, C, D3, E, K1 et PP, substances d'apport minéral : citrate de calcium, sulfates de fer, de magnésium, de zinc, de cuivre et de manganèse, citrate de sodium, iodure et hydroxyde de potassium, sélénite de sodium, émulsifiant : lécithine de colza, éthylvanilline."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
        "en:e322i",
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
        "en:calcium-citrate",
        "en:ferrous-sulphate",
        "en:magnesium-sulphate",
        "en:zinc-sulphate",
        "en:cupric-sulphate",
        "en:manganese-sulphate",
        "en:sodium-citrate",
        "en:potassium-iodide",
        "en:potassium-hydroxide",
        "en:sodium-selenite",

                              ],
);



$product_ref = {
        lc => "fr",
        ingredients_text =>
"INFORMATIONS NUTRITIONNELLES PRÉPARATION POUR NOURRISSONS EN potlDRE - Ingrédients du produit reconstitué : Lactose (lait), huiles végétales (palme, colza, tournesol), maltodextrines, proteines de lait hydrolysées, minéraux (phosphate tricalcique, chlorure de potassium, citrate trisodique, phosphate dipotassique, phosphate de magnésium, sulfate ferreux, sulfate de zinc, hydroxyde de potassium, sélénite de sodium, iodure de potassium, sulfate de cuivre, sulfate de manganèse), émulsifiant (esters citriques de mono et diglycérides d'acides gras), vitamines (C,pp, B9,H,B12), L-phénylalanine, chlorure de choline, L-tryptophane, L-tyrosine, taurine, inositol, antioxydants (palmitate d'ascorbyle, tocophérols) (soja), L-carnitine, ferments lactiques (Lactobacillus fermentum CECT5716)"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
        "en:e472c",
        "en:e304i",
        "en:e307c",
                              ],
);

is_deeply($product_ref->{nucleotides_tags}, [
                              ],
);

is_deeply($product_ref->{amino_acids_tags}, [
	"en:l-phenylalanine",
	"en:l-tryptophan",
	"en:l-tyrosine",
                              ],
);

is_deeply($product_ref->{other_nutritional_substances_tags}, [
	"en:choline-chloride",
	"en:taurine",
	"en:inositol",
	"en:l-carnitine",
                              ],
);





is_deeply($product_ref->{minerals_tags}, [
	"en:calcium-phosphate",
	"en:potassium-chloride",
	"en:sodium-citrate",
	"en:potassium-phosphate",
	"en:magnesium-phosphate",
	"en:ferrous-sulphate",
	"en:zinc-sulphate",
	"en:potassium-hydroxide",
	"en:sodium-selenite",
	"en:potassium-iodide",
        "en:cupric-sulphate",
        "en:manganese-sulphate",
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text =>
"huile de colza, orthophosphates de calcium, carbonate de calcium, citrates de potassium"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

is_deeply($product_ref->{minerals_tags}, [
	"en:calcium-phosphate",
	"en:calcium-carbonate",
	"en:potassium-citrate",
                              ],
);

$product_ref = {
        lc => "fr",
        ingredients_text =>
"Café instantané 100 % pur arabica"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);

# 100 % --> no E100 curcumine
$product_ref = {
        lc => "en",
        ingredients_text =>
"Instant coffee 100 %."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
                              ],
);


# products in Hong Kong sometimes have no E before E numbers
# https://hk.openfoodfacts.org/product/4891028164456/vlt-vita
# "water, sugar, tea, lemon juice, flavouring, acidity regulator (330, 331), vitamin C, antioxidant (304)"

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



$product_ref = {
        lc => "fr",
        ingredients_text =>
"Sucre (France), OEUF entier (reconstitué à partir de poudre d OEUF), huile de colza, farine de riz, amidon de pomme de terre, stabilisants : glycérol et gomme xanthane, amidon de maïs, poudres à lever : diphosphates et carbonates de sodium, arôme naturel de citron, émulsifiant : mono- et diglycérides d'acides gras, conservateur : sorbate de potassium, sel, colorant : riboflavine. Traces éventuelles de soja."
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e422",
	"en:e415",
	"en:e450i",
	"en:e500",
	"en:e471",
	"en:e202",
	"en:e101i",
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text =>
"farine de seigle, sel, poudre à lever : carbonates de sodium,carbonates dlammonium,diphosphates,tartrates d potassium, amidon de blé, poudre de lait écrémé, extrait de malt dlorge, noix de coco 0,1 % arômes, jaune d'œuf en poudre, fécule de pomme de terre, farine dorge, amidon de maïs colorants : caramel ordinaire et curcumine, lactose et protéine de lait en poudre. Colorant: Sels de sodium et de potassium de complexes cupriques de chlorophyllines, Complexe cuivrique des chlorophyllines avec sels de sodium et de potassium, oxyde et hydroxyde de fer rouge, oxyde et hydroxyde de fer jaune et rouge, Tartrate double de sodium et de potassium, Éthylènediaminetétraacétate de calcium et de disodium, Phosphate d'aluminium et de sodium, Diphosphate de potassium et de sodium, Tripoliphosphates de sodium et de potassium, Sels de sodium de potassium et de calcium d'acides gras, Mono- et diglycérides d'acides gras, Esters acétiques des mono- et diglycérides, Esters glycéroliques de l'acide acétique et d'acides gras, Esters glycéroliques de l'acide citrique et d'acides gras, Esters monoacétyltartriques et diacétyltartriques, Esters mixtes acétiques et tartriques des mono- et diglycérides d'acides gras, Esters lactyles d'acides gras du glycérol et du propane-1, Silicate double d'aluminium et de calcium, Silicate d'aluminium et calcium, Silicate d'aluminium et de calcium, Silicate double de calcium et d'aluminium,  Glycine et son sel de sodium, Cire d'abeille blanche et jaune, Acide cyclamique et ses sels, Saccharine et ses sels, Acide glycyrrhizique et sels, Sels et esters de choline, Octénylesuccinate d'amidon et d'aluminium, "
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e500',
          'en:e503',
          'en:e450',
          'en:e336',
          'en:e150a',
          'en:e100',
          'en:e141ii',
          'en:e172ii',
          'en:e172iii',
          'en:e337',
          'en:e385',
          'en:e541',
	  'en:e450i',
	  'en:e451',
	  'en:e340',
          'en:e470a',
          'en:e471',
          'en:e472a',
          'en:e472c',
          'en:e472f',
          'en:e478',
          'en:e556',
          'en:e640',
          'en:e901',
          'en:e952',
          'en:e954',
          'en:e958',
          'en:e1452'
],
);

#print STDERR Dumper($product_ref->{additives_original_tags});


$product_ref = {
        lc => "fr",
        ingredients_text =>
"Liste des ingrédients : viande de porc, sel, lactose, épices, sucre, dextrose, ail, conservateurs : nitrate de potassium et nitrite de sodium, ferments, boyau naturel de porc. Poudre de fleurage : talc et carbonate de calcium. 164 g de viande de porc utilisée poudre 100 g de produit fini. 
"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e252",
	"en:e250",
	"en:e553b",
	"en:e170",
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text =>
"Fruits* 43,8% (bigarreaux confits 19,3% (bigarreaux, sirop de glucose- fructose, colorant anthocyanes, correcteur d'acidité: acide citrique, conservateur: anhydride sulfureux), raisins secs 11%, raisins secs macérés dans l'extrait aromatique rhum orange 10% (raisins secs, rhum, infusion d'écorces d'oranges douces), écorces d'orange confites 3,5% (écorces d'orange. sirop de glucose-fructose, saccharose, correcteur d'acidité: acide citrique, conservateur: anhydride sulfureux)), farine de blé, eufs entiers, sucre, beurre 14%, sirop de glucose, stabilisant:glycérol, arôme naturel de vanille (contient alcool) et autre arôme, sel, poudres à lever : diphosphates et carbonates de sodium (dont céréales contenant du gluten), émulsifiant mono-et diglycérides d'acides gras, épaississant gommexanthane. *fruits confits, fruits secs et fruits secs macérés.
"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
	"en:e163",
	"en:e330",
	"en:e220",
	"en:e422",
	"en:e450i",
	"en:e500",
	"en:e471",
	"en:e415",
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text =>
"Farine de BLE, sucre, chocolat au lait 13% (sucre, beurre de cacao, pâte de cacao, LAIT écrémé en poudre, LACTOSE, matière grasse LAITIERE anhydre, LACTOSERUM en poudre, émulsifiant : lécithines de tournesol), chocolat blanc 8% (sucre, beurre de cacao, LAIT entier en poudre, émulsifiant : lécithines de tournesol), BEURRE pâtissier, chocolat noir 6% (pâte de cacao, sucre, beurre de cacao, matière grasse LAITIERE, émulsifiant : lécithines de tournesol), blancs d'OEUFS, fourrage à la purée de framboise 3.5% (sirop de glucose- fructose, stabilisant : glycérol, purée et brisures de framboise, purée de framboise concentrée, purée de pomme, BEURRE, arômes, acidifiant : acide citrique, gélifiant : pectines de fruits, correcteur d'acidité : citrates de sodium, jus concentré de sureau), huile de tournesol, OEUFS entiers, AMANDES 1.3%, poudre de NOIX DE CAJOU 1.2%, sucre de canne roux, NOISETTES, poudre de florentin 0.6% (sucre, sirop de glucose, BEURRE, émulsifiant : lécithines de SOJA, poudre de LAIT écrémé), sirop de sucre inverti et partiellement inverti, grains de riz soufflés 0.5% (farine de riz, gluten de BLE, malt de BLE, saccharose, sel, dextrose), nougatine 0.4% (sucre, AMANDES et NOISETTES torréfiées), éclat de caramel 0.4% (sucre, sirop de glucose, CREME et BEURRE caramélisés), farine de SEIGLE, sel, poudres à lever : carbonates de sodium - carbonates d'ammonium- diphosphates- tartrates de potassium, amidon de BLE, poudre de LAIT écrémé, extrait de malt d'ORGE, noix de coco 0.1%, arômes, jaune d'OEUF en poudre, fécule de pomme de terre, farine d'ORGE, amidon de maïs, colorants : caramel ordinaire et curcumine, LACTOSERUM en poudre et protéines de LAIT, cannelle en poudre, émulsifiant : lécithines de tournesol, antioxydant : acide ascorbique. Traces éventuelles de graines de sésame et autres fruits à coques.
"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e322',
          'en:e422',
          'en:e330',
          'en:e440',
          'en:e331',
          'en:e500',
          'en:e503',
          'en:e450',
          'en:e336',
          'en:e150a',
          'en:e100',
          'en:e300'

                              ],
);

#print STDERR Dumper($product_ref->{additives_original_tags});



$product_ref = {
        lc => "fr",
        ingredients_text =>
"Ac1de citrique; or; ar; amidon modfié, carbonate dlammonium, carmims, glycoside de steviol, sel ntrite, vltamine c
"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e330',
          'en:e175',
          'en:e14xx',
          'en:e503i',
          'en:e120',
          'en:e960',
          'en:e250',
	
                              ],
);

#print STDERR Dumper($product_ref->{additives_original_tags});




$product_ref = {
        lc => "fr",
        ingredients_text =>
"Eau, E501
"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e501',
	
                              ],
);

#print STDERR Dumper($product_ref->{additives_original_tags});


$product_ref = {
        lc => "fr",
        ingredients_text =>
"Olives d'import 80 % (vertes, tournantes, noires), poivron et piment, sel, oignon, huile de tournesol, ail, acidifiants (E330, vinaigre), conservateur : sulfites.
"
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e330',
	
                              ],
);

#print STDERR Dumper($product_ref->{additives_original_tags});




$product_ref = {
        lc => "fr",
        ingredients_text =>
"Biscuit 65 % :farine de riz blanche*, amidon de pomme de terre*, huile de palme non hydrogénée, sucre de canne blond, amidon de riz*, œufs*, sirop de glucose de r|z*, farine de pois chiche*, épaississants (gomme d’acacia*, gomme de guar), agents levants (tartrates potassium, carbonates de sodium), sel. Fourrage 35% : sirop de glucose de riz*, purée de pomme*, purée d’abricot* 08%), purée de pêche (7%), gélifiant: pectine, régulateur d’acidité : acide citrique, arôme naturel*. *issus de agriculture biologique. **Ingrédient biologique issu du Commerce Équitable.
",
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e414',
          'en:e412',
          'en:e336',
          'en:e500',
          'en:e440i',
          'en:e330',
	
                              ],
);

#print STDERR Dumper($product_ref->{additives_original_tags});


$product_ref = {
        lc => "fr",
        ingredients_text =>
"dioxyde titane, le glutamate de sodium, 
",
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [
          'en:e171',
          'en:e621',
	
                              ],
);

#print STDERR Dumper($product_ref->{additives_original_tags});



$product_ref = {
        lc => "fr",
        ingredients_text =>
"boyau, coloré, chlorela, chlorelle, chlorele bio
",
};

extract_ingredients_classes_from_text($product_ref);

print STDERR $product_ref->{additives} . "\n";

is_deeply($product_ref->{additives_original_tags}, [

                              ],
);





done_testing();
