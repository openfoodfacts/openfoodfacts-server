#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# dummy product for testing

my $product_ref = {
	lc => "fr",
	ingredients_text => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"
};

extract_ingredients_from_text($product_ref);

use Data::Dumper;
print STDERR Dumper($product_ref);


is($product_ref->{ingredients_n}, 17);

my $expected_product_ref = {

          'ingredients_n_tags' => [
                                    '17',
                                    '11-20'
                                  ],
          'ingredients_original_tags' => [
                                           'en:flour',
                                           'en:chocolate',
                                           'en:sugar',
                                           'en:milk-proteins',
                                           'en:egg',
                                           'en:emulsifier',
                                           'fr:E463',
                                           'fr:E432 et E472',
                                           'en:acidity-regulator',
                                           'fr:e475',
                                           'en:acid',
                                           'en:salt',
                                           'en:cocoa-butter',
                                           'fr:e322',
                                           'fr:E333 E474',
                                           'en:citric-acid',
                                           'en:phosphoric-acid'
                                         ],
          'ingredients_hierarchy' => [
                                       'en:flour',
                                       'en:chocolate',
                                       'en:sugar',
                                       'en:milk-proteins',
                                       'en:animal-protein',
                                       'en:protein',
                                       'en:egg',
                                       'en:emulsifier',
                                       'fr:E463',
                                       'fr:E432 et E472',
                                       'en:acidity-regulator',
                                       'fr:e475',
                                       'en:acid',
                                       'en:salt',
                                       'en:cocoa-butter',
                                       'en:cocoa',
                                       'fr:e322',
                                       'fr:E333 E474',
                                       'en:citric-acid',
                                       'en:phosphoric-acid'
                                     ],
          'ingredients_tags' => [
                                  'en:flour',
                                  'en:chocolate',
                                  'en:sugar',
                                  'en:milk-proteins',
                                  'en:animal-protein',
                                  'en:protein',
                                  'en:egg',
                                  'en:emulsifier',
                                  'fr:e463',
                                  'fr:e432-et-e472',
                                  'en:acidity-regulator',
                                  'fr:e475',
                                  'en:acid',
                                  'en:salt',
                                  'en:cocoa-butter',
                                  'en:cocoa',
                                  'fr:e322',
                                  'fr:e333-e474',
                                  'en:citric-acid',
                                  'en:phosphoric-acid'
                                ],
          'ingredients_text' => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], prot\x{e9}ines de lait, oeuf 1%) - \x{e9}mulsifiants : E463, E432 et E472 - correcteurs d'acidit\x{e9} : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel",
          'lc' => 'fr',
          'ingredients' => [
                             {
                               'percent' => '12',
                               'text' => 'farine',
                               'id' => 'en:flour',
                               'rank' => 1
                             },
                             {
                               'text' => 'chocolat',
                               'id' => 'en:chocolate',
                               'rank' => 2
                             },
                             {
                               'percent' => '10',
                               'text' => 'sucre',
                               'id' => 'en:sugar',
                               'rank' => 3
                             },
                             {
                               'text' => "prot\x{e9}ines de lait",
                               'id' => 'en:milk-proteins',
                               'rank' => 4
                             },
                             {
                               'text' => 'oeuf',
                               'id' => 'en:egg',
                               'rank' => 5
                             },
                             {
                               'text' => "\x{e9}mulsifiants",
                               'id' => 'en:emulsifier',
                               'rank' => 6
                             },
                             {
                               'text' => 'E463',
                               'id' => 'fr:E463',
                               'rank' => 7
                             },
                             {
                               'text' => 'E432 et E472',
                               'id' => 'fr:E432 et E472',
                               'rank' => 8
                             },
                             {
                               'text' => "correcteurs d'acidit\x{e9}",
                               'id' => 'en:acidity-regulator',
                               'rank' => 9
                             },
                             {
                               'text' => 'E475',
                               'id' => 'fr:e475',
                               'rank' => 10
                             },
                             {
                               'text' => 'acidifiant',
                               'id' => 'en:acid',
                               'rank' => 11
                             },
                             {
                               'text' => 'sel',
                               'id' => 'en:salt',
                               'rank' => 12
                             },
                             {
                               'percent' => '15',
                               'text' => 'beurre de cacao',
                               'id' => 'en:cocoa-butter'
                             },
                             {
                               'text' => 'E322',
                               'id' => 'fr:e322'
                             },
                             {
                               'text' => 'E333 E474',
                               'id' => 'fr:E333 E474'
                             },
                             {
                               'text' => 'acide citrique',
                               'id' => 'en:citric-acid'
                             },
                             {
                               'text' => 'acide phosphorique',
                               'id' => 'en:phosphoric-acid'
                             }
                           ],
          'unknown_ingredients_n' => 3,
          'ingredients_n' => 17

        };


is_deeply($product_ref, $expected_product_ref);




$product_ref = {
        lc => "fr",
        ingredients_text => "graisse de palmiste"
};

extract_ingredients_from_text($product_ref);
extract_ingredients_classes_from_text($product_ref);


#ingredients_from_palm_oil_tags: [
#"huile-de-palme"
#],

use Data::Dumper;
print STDERR Dumper($product_ref);


my $expected_product_ref = 
{
          'ingredients_hierarchy' => [
                                       'en:palm-kernel-fat',
                                       'en:palm-kernel-oil',
                                     ],
          'ingredients_from_or_that_may_be_from_palm_oil_n' => 1,
          'additives_original_tags' => [],
          'amino_acids_tags' => [],
          'ingredients_original_tags' => [
                                           'en:palm-kernel-fat'
                                         ],
          'ingredients_that_may_be_from_palm_oil_tags' => [],
          'nucleotides_tags' => [],
          'additives_tags' => [],
          'ingredients_n_tags' => [
                                    '1',
                                    '1-10'
                                  ],
          'ingredients_tags' => [
                                  'en:palm-kernel-fat',
                                  'en:palm-kernel-oil',
                                ],
          'additives_n' => 0,
          'ingredients_n' => 1,
          'vitamins_tags' => [],
          'ingredients_from_palm_oil_tags' => [
                                                'huile-de-palme'
                                              ],
          'additives_old_tags' => [],
          'ingredients_text_debug' => 'graisse de palmiste',
          'ingredients_that_may_be_from_palm_oil_n' => 0,
          'ingredients_text' => 'graisse de palmiste',
          'ingredients_from_palm_oil_n' => 1,
          'minerals_tags' => [],
          'ingredients_debug' => [
                                   'graisse de palmiste'
                                 ],
          'lc' => 'fr',
          'ingredients' => [
                             {
                               'text' => 'graisse de palmiste',
                               'id' => 'en:palm-kernel-fat',
                               'rank' => 1
                             }
                           ],
          'unknown_ingredients_n' => 0,
          'additives' => ' [ graisse-de-palmiste -> fr:graisse-de-palmiste  ]  [ graisse-de -> fr:graisse-de  ]  [ graisse -> fr:graisse  ] ',
          'additives_old_n' => 0,
          'additives_debug_tags' => [],
          'ingredients_ids_debug' => [
                                       'graisse-de-palmiste'
                                     ]
        };{
          'ingredients_hierarchy' => [
                                       'en:palm-kernel-fat',
                                       'en:palm-kernel-oil',
                                     ],
          'ingredients_from_or_that_may_be_from_palm_oil_n' => 1,
          'additives_original_tags' => [],
          'amino_acids_tags' => [],
          'ingredients_original_tags' => [
                                           'en:palm-kernel-fat'
                                         ],
          'ingredients_that_may_be_from_palm_oil_tags' => [],
          'nucleotides_tags' => [],
          'additives_tags' => [],
          'ingredients_n_tags' => [
                                    '1',
                                    '1-10'
                                  ],
          'ingredients_tags' => [
                                  'en:palm-kernel-fat',
                                  'en:palm-kernel-oil',
                                ],
          'additives_n' => 0,
          'ingredients_n' => 1,
          'vitamins_tags' => [],
          'ingredients_from_palm_oil_tags' => [
                                                'huile-de-palme'
                                              ],
          'additives_old_tags' => [],
          'ingredients_text_debug' => 'graisse de palmiste',
          'ingredients_that_may_be_from_palm_oil_n' => 0,
          'ingredients_text' => 'graisse de palmiste',
          'ingredients_from_palm_oil_n' => 1,
          'minerals_tags' => [],
          'ingredients_debug' => [
                                   'graisse de palmiste'
                                 ],
          'lc' => 'fr',
          'ingredients' => [
                             {
                               'text' => 'graisse de palmiste',
                               'id' => 'en:palm-kernel-fat',
                               'rank' => 1
                             }
                           ],
          'unknown_ingredients_n' => 0,
          'additives' => ' [ graisse-de-palmiste -> fr:graisse-de-palmiste  ]  [ graisse-de -> fr:graisse-de  ]  [ graisse -> fr:graisse  ] ',
          'additives_old_n' => 0,
          'additives_debug_tags' => [],
          'ingredients_ids_debug' => [
                                       'graisse-de-palmiste'
                                     ]
        };


delete $product_ref->{additives_prev_original_tags};
delete $product_ref->{additives_prev_tags};
delete $product_ref->{additives_prev};
delete $product_ref->{additives_prev_n};
delete $product_ref->{minerals_prev_original_tags};
delete $product_ref->{vitamins_prev_tags};
delete $product_ref->{nucleotides_prev_tags};
delete $product_ref->{amino_acids_prev_tags};
delete $product_ref->{minerals_prev_tags};
delete $product_ref->{minerals_prev};

is_deeply($product_ref, $expected_product_ref);




my $product_ref = {
        lc => "fr",
        ingredients_text => "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales (illipe, mangue, sal, karité et palme en proportions variables), arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja)."
};

extract_ingredients_from_text($product_ref);

delete $product_ref->{additives_prev_original_tags};
delete $product_ref->{additives_prev_tags};
delete $product_ref->{additives_prev};
delete $product_ref->{additives_prev_n};
delete $product_ref->{minerals_prev_original_tags};
delete $product_ref->{vitamins_prev_tags};
delete $product_ref->{nucleotides_prev_tags};
delete $product_ref->{amino_acids_prev_tags};
delete $product_ref->{minerals_prev_tags};
delete $product_ref->{minerals_prev};


use Data::Dumper;

$expected_product_ref = {
          'ingredients_n_tags' => [
                                    '43',
                                    '41-50'
                                  ],
          'ingredients_original_tags' => [
                                           'fr:Marmelade d\'oranges',
                                           "fr:pulpe d'orange concentr\x{e9}e",
                                           "fr:\x{e9}quivalent pulpe d'orange",
                                           'en:gelling-agent',
                                           'en:pectin',
                                           'en:acid',
                                           'en:citric-acid',
                                           'en:acidity-regulator',
                                           'en:natural-orange-flavouring',
                                           'en:thickener',
                                           'en:xanthan-gum',
                                           'en:chocolate',
                                           'en:flavouring',
                                           'en:emulsifier',
                                           'en:soya-lecithin',
                                           'fr:lactose-et-proteine-de-lait',
                                           'en:wheat-flour',
                                           'en:sugar',
                                           'en:egg',
                                           'en:glucose-fructose-syrup',
                                           'en:colza-oil',
                                           'en:yeast-powder',
                                           'en:salt',
                                           'en:emulsifier',
                                           'en:soya-lecithin',
                                           'en:glucose-fructose-syrup',
                                           'en:sugar',
                                           'de:orangenfruchtfleish',
                                           'en:concentrated-orange-juice',
                                           "fr:\x{e9}quivalent jus d'orange",
                                           'fr:citrate-de-calcium',
                                           'fr:citrate-de-sodium',
                                           'en:sugar',
                                           'en:cocoa-paste',
                                           'en:cocoa-butter',
                                           'en:vegetable-fat',
                                           'en:illipe',
                                           'en:mango',
                                           'fr:sal',
                                           "fr:karit\x{e9} et palme en proportions variables",
                                           'fr:carbonate-acide-d-ammonium',
                                           'fr:diphosphate-disodique',
                                           'fr:carbonate-acide-de-sodium'
                                         ],
          'ingredients_hierarchy' => [
                                       'fr:Marmelade d\'oranges',
                                       "fr:pulpe d'orange concentr\x{e9}e",
                                       "fr:\x{e9}quivalent pulpe d'orange",
                                       'en:gelling-agent',
                                       'en:pectin',
                                       'en:acid',
                                       'en:citric-acid',
                                       'en:acidity-regulator',
                                       'en:natural-orange-flavouring',
                                       'en:natural-flavouring',
                                       'en:flavouring',
                                       'en:thickener',
                                       'en:xanthan-gum',
                                       'en:stabiliser',
                                       'en:thickener',
                                       'en:chocolate',
                                       'en:flavouring',
                                       'en:emulsifier',
                                       'en:soya-lecithin',
                                       'en:lecithins',
                                       'fr:lactose-et-proteine-de-lait',
                                       'en:wheat-flour',
                                       'en:cereal-flour',
                                       'en:wheat',
                                       'en:cereal',
                                       'en:sugar',
                                       'en:egg',
                                       'en:glucose-fructose-syrup',
                                       'en:fructose',
                                       'en:syrup',
                                       'en:glucose',
                                       'en:colza-oil',
                                       'en:vegetable-oil',
                                       'en:oil-and-vegetable-fat',
                                       'en:oil',
                                       'en:yeast-powder',
                                       'en:yeast',
                                       'en:raising-agent',
                                       'en:salt',
                                       'en:emulsifier',
                                       'en:soya-lecithin',
                                       'en:lecithins',
                                       'en:glucose-fructose-syrup',
                                       'en:fructose',
                                       'en:syrup',
                                       'en:glucose',
                                       'en:sugar',
                                       'de:orangenfruchtfleish',
                                       'en:orange',
                                       'en:citrus-fruit',
                                       'en:fruit',
                                       'en:concentrated-orange-juice',
                                       'en:orange-juice',
                                       'en:orange',
                                       'en:fruit-juice',
                                       'en:citrus-fruit',
                                       'en:fruit',
                                       "fr:\x{e9}quivalent jus d'orange",
                                       'fr:citrate-de-calcium',
                                       'fr:citrate-de-sodium',
                                       'en:sugar',
                                       'en:cocoa-paste',
                                       'en:cocoa-butter',
                                       'en:cocoa',
                                       'en:vegetable-fat',
                                       'en:oil-and-vegetable-fat',
                                       'en:oil',
                                       'en:illipe',
                                       'en:vegetable-fat',
                                       'en:oil-and-vegetable-fat',
                                       'en:oil',
                                       'en:mango',
                                       'en:fruit',
                                       'fr:sal',
                                       "fr:karit\x{e9} et palme en proportions variables",
                                       'fr:carbonate-acide-d-ammonium',
                                       'fr:diphosphate-disodique',
                                       'fr:carbonate-acide-de-sodium'
                                     ],
          'ingredients_tags' => [
                                  'fr:marmelade-d-oranges',
                                  'fr:pulpe-d-orange-concentree',
                                  'fr:equivalent-pulpe-d-orange',
                                  'en:gelling-agent',
                                  'en:pectin',
                                  'en:acid',
                                  'en:citric-acid',
                                  'en:acidity-regulator',
                                  'en:natural-orange-flavouring',
                                  'en:natural-flavouring',
                                  'en:flavouring',
                                  'en:thickener',
                                  'en:xanthan-gum',
                                  'en:stabiliser',
                                  'en:thickener',
                                  'en:chocolate',
                                  'en:flavouring',
                                  'en:emulsifier',
                                  'en:soya-lecithin',
                                  'en:lecithins',
                                  'fr:lactose-et-proteine-de-lait',
                                  'en:wheat-flour',
                                  'en:cereal-flour',
                                  'en:wheat',
                                  'en:cereal',
                                  'en:sugar',
                                  'en:egg',
                                  'en:glucose-fructose-syrup',
                                  'en:fructose',
                                  'en:syrup',
                                  'en:glucose',
                                  'en:colza-oil',
                                  'en:vegetable-oil',
                                  'en:oil-and-vegetable-fat',
                                  'en:oil',
                                  'en:yeast-powder',
                                  'en:yeast',
                                  'en:raising-agent',
                                  'en:salt',
                                  'en:emulsifier',
                                  'en:soya-lecithin',
                                  'en:lecithins',
                                  'en:glucose-fructose-syrup',
                                  'en:fructose',
                                  'en:syrup',
                                  'en:glucose',
                                  'en:sugar',
                                  'de:orangenfruchtfleish',
                                  'en:orange',
                                  'en:citrus-fruit',
                                  'en:fruit',
                                  'en:concentrated-orange-juice',
                                  'en:orange-juice',
                                  'en:orange',
                                  'en:fruit-juice',
                                  'en:citrus-fruit',
                                  'en:fruit',
                                  'fr:equivalent-jus-d-orange',
                                  'fr:citrate-de-calcium',
                                  'fr:citrate-de-sodium',
                                  'en:sugar',
                                  'en:cocoa-paste',
                                  'en:cocoa-butter',
                                  'en:cocoa',
                                  'en:vegetable-fat',
                                  'en:oil-and-vegetable-fat',
                                  'en:oil',
                                  'en:illipe',
                                  'en:vegetable-fat',
                                  'en:oil-and-vegetable-fat',
                                  'en:oil',
                                  'en:mango',
                                  'en:fruit',
                                  'fr:sal',
                                  'fr:karite-et-palme-en-proportions-variables',
                                  'fr:carbonate-acide-d-ammonium',
                                  'fr:diphosphate-disodique',
                                  'fr:carbonate-acide-de-sodium'
                                ],
          'ingredients_text' => "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentr\x{e9} 1.4% (\x{e9}quivalent jus d'orange 7.8%), pulpe d'orange concentr\x{e9}e 0.6% (\x{e9}quivalent pulpe d'orange 2.6%), g\x{e9}lifiant (pectines), acidifiant (acide citrique), correcteurs d'acidit\x{e9} (citrate de calcium, citrate de sodium), ar\x{f4}me naturel d'orange, \x{e9}paississant (gomme xanthane)), chocolat 24.9% (sucre, p\x{e2}te de cacao, beurre de cacao, graisses v\x{e9}g\x{e9}tales (illipe, mangue, sal, karit\x{e9} et palme en proportions variables), ar\x{f4}me, \x{e9}mulsifiant (l\x{e9}cithine de soja), lactose et prot\x{e9}ines de lait), farine de bl\x{e9}, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre \x{e0} lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, \x{e9}mulsifiant (l\x{e9}cithine de soja).",
          'lc' => 'fr',
          'ingredients' => [
                             {
                               'percent' => '41',
                               'text' => 'Marmelade d\'oranges',
                               'id' => 'fr:Marmelade d\'oranges',
                               'rank' => 1
                             },
                             {
                               'percent' => '0.6',
                               'text' => "pulpe d'orange concentr\x{e9}e",
                               'id' => "fr:pulpe d'orange concentr\x{e9}e",
                               'rank' => 2
                             },
                             {
                               'percent' => '2.6',
                               'text' => "\x{e9}quivalent pulpe d'orange",
                               'id' => "fr:\x{e9}quivalent pulpe d'orange",
                               'rank' => 3
                             },
                             {
                               'text' => "g\x{e9}lifiant",
                               'id' => 'en:gelling-agent',
                               'rank' => 4
                             },
                             {
                               'text' => 'pectines',
                               'id' => 'en:pectin',
                               'rank' => 5
                             },
                             {
                               'text' => 'acidifiant',
                               'id' => 'en:acid',
                               'rank' => 6
                             },
                             {
                               'text' => 'acide citrique',
                               'id' => 'en:citric-acid',
                               'rank' => 7
                             },
                             {
                               'text' => "correcteurs d'acidit\x{e9}",
                               'id' => 'en:acidity-regulator',
                               'rank' => 8
                             },
                             {
                               'text' => "ar\x{f4}me naturel d'orange",
                               'id' => 'en:natural-orange-flavouring',
                               'rank' => 9
                             },
                             {
                               'text' => "\x{e9}paississant",
                               'id' => 'en:thickener',
                               'rank' => 10
                             },
                             {
                               'text' => 'gomme xanthane',
                               'id' => 'en:xanthan-gum',
                               'rank' => 11
                             },
                             {
                               'percent' => '24.9',
                               'text' => 'chocolat',
                               'id' => 'en:chocolate',
                               'rank' => 12
                             },
                             {
                               'text' => "ar\x{f4}me",
                               'id' => 'en:flavouring',
                               'rank' => 13
                             },
                             {
                               'text' => "\x{e9}mulsifiant",
                               'id' => 'en:emulsifier',
                               'rank' => 14
                             },
                             {
                               'text' => "l\x{e9}cithine de soja",
                               'id' => 'en:soya-lecithin',
                               'rank' => 15
                             },
                             {
                               'text' => "lactose et prot\x{e9}ines de lait",
                               'id' => 'fr:lactose-et-proteine-de-lait',
                               'rank' => 16
                             },
                             {
                               'text' => "farine de bl\x{e9}",
                               'id' => 'en:wheat-flour',
                               'rank' => 17
                             },
                             {
                               'text' => 'sucre',
                               'id' => 'en:sugar',
                               'rank' => 18
                             },
                             {
                               'text' => 'oeufs',
                               'id' => 'en:egg',
                               'rank' => 19
                             },
                             {
                               'text' => 'sirop de glucose-fructose',
                               'id' => 'en:glucose-fructose-syrup',
                               'rank' => 20
                             },
                             {
                               'text' => 'huile de colza',
                               'id' => 'en:colza-oil',
                               'rank' => 21
                             },
                             {
                               'text' => "poudre \x{e0} lever",
                               'id' => 'en:yeast-powder',
                               'rank' => 22
                             },
                             {
                               'text' => 'sel',
                               'id' => 'en:salt',
                               'rank' => 23
                             },
                             {
                               'text' => "\x{e9}mulsifiant",
                               'id' => 'en:emulsifier',
                               'rank' => 24
                             },
                             {
                               'text' => "l\x{e9}cithine de soja",
                               'id' => 'en:soya-lecithin',
                               'rank' => 25
                             },
                             {
                               'text' => 'sirop de glucose-fructose',
                               'id' => 'en:glucose-fructose-syrup'
                             },
                             {
                               'text' => 'sucre',
                               'id' => 'en:sugar'
                             },
                             {
                               'percent' => '4.5',
                               'text' => 'pulpe d\'orange',
                               'id' => 'de:orangenfruchtfleish'
                             },
                             {
                               'percent' => '1.4',
                               'text' => "jus d'orange concentr\x{e9}",
                               'id' => 'en:concentrated-orange-juice'
                             },
                             {
                               'percent' => '7.8',
                               'text' => "\x{e9}quivalent jus d'orange",
                               'id' => "fr:\x{e9}quivalent jus d'orange"
                             },
                             {
                               'text' => 'citrate de calcium',
                               'id' => 'fr:citrate-de-calcium'
                             },
                             {
                               'text' => 'citrate de sodium',
                               'id' => 'fr:citrate-de-sodium'
                             },
                             {
                               'text' => 'sucre',
                               'id' => 'en:sugar'
                             },
                             {
                               'text' => "p\x{e2}te de cacao",
                               'id' => 'en:cocoa-paste'
                             },
                             {
                               'text' => 'beurre de cacao',
                               'id' => 'en:cocoa-butter'
                             },
                             {
                               'text' => "graisses v\x{e9}g\x{e9}tales",
                               'id' => 'en:vegetable-fat'
                             },
                             {
                               'text' => 'illipe',
                               'id' => 'en:illipe'
                             },
                             {
                               'text' => 'mangue',
                               'id' => 'en:mango'
                             },
                             {
                               'text' => 'sal',
                               'id' => 'fr:sal'
                             },
                             {
                               'text' => "karit\x{e9} et palme en proportions variables",
                               'id' => "fr:karit\x{e9} et palme en proportions variables"
                             },
                             {
                               'text' => 'carbonate acide d\'ammonium',
                               'id' => 'fr:carbonate-acide-d-ammonium'
                             },
                             {
                               'text' => 'diphosphate disodique',
                               'id' => 'fr:diphosphate-disodique'
                             },
                             {
                               'text' => 'carbonate acide de sodium',
                               'id' => 'fr:carbonate-acide-de-sodium'
                             }
                           ],
          'unknown_ingredients_n' => 6,
          'ingredients_n' => 43
        };


is_deeply($product_ref, $expected_product_ref);


# test synonyms for flavouring/flavour/flavor/flavoring
my $product_ref = {
        lc => "en",
        ingredients_text => "Natural orange flavor, Lemon flavouring"
};

extract_ingredients_from_text($product_ref);

delete $product_ref->{additives_prev_original_tags};
delete $product_ref->{additives_prev_tags};
delete $product_ref->{additives_prev};
delete $product_ref->{additives_prev_n};
delete $product_ref->{minerals_prev_original_tags};
delete $product_ref->{vitamins_prev_tags};
delete $product_ref->{nucleotides_prev_tags};
delete $product_ref->{amino_acids_prev_tags};
delete $product_ref->{minerals_prev_tags};
delete $product_ref->{minerals_prev};


use Data::Dumper;
print STDERR Dumper($product_ref);

$expected_product_ref = {
'ingredients_n_tags' => [
                                    '2',
                                    '1-10'
                                  ],
          'ingredients_original_tags' => [
                                           'en:natural-orange-flavouring',
                                           'en:lemon-flavouring'
                                         ],
          'ingredients_hierarchy' => [
                                       'en:natural-orange-flavouring',
                                       'en:natural-flavouring',
                                       'en:flavouring',
                                       'en:lemon-flavouring',
                                       'en:flavouring'
                                     ],
          'ingredients_tags' => [
                                  'en:natural-orange-flavouring',
                                  'en:natural-flavouring',
                                  'en:flavouring',
                                  'en:lemon-flavouring',
                                  'en:flavouring'
                                ],
          'ingredients_text' => 'Natural orange flavor, Lemon flavouring',
          'lc' => 'en',
          'ingredients' => [
                             {
                               'text' => 'Natural orange flavor',
                               'id' => 'en:natural-orange-flavouring',
                               'rank' => 1
                             },
                             {
                               'text' => 'Lemon flavouring',
                               'id' => 'en:lemon-flavouring',
                               'rank' => 2
                             }
                           ],
          'unknown_ingredients_n' => 0,
          'ingredients_n' => 2

        };


is_deeply($product_ref, $expected_product_ref);



done_testing();
