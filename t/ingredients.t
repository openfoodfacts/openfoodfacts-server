#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my $product_ref = {
	lc => "fr",
	ingredients_text => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"
};

extract_ingredients_from_text($product_ref);

diag explain $product_ref;


is($product_ref->{ingredients_n}, 17);

my $expected_product_ref = {

	ingredients_text => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel",
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
                                           'en:polyglycerol-esters-of-fatty-acids',
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
                                       'en:protein',
                                       'en:animal-protein',
                                       'en:egg',
                                       'en:emulsifier',
                                       'fr:E463',
                                       'fr:E432 et E472',
                                       'en:acidity-regulator',
                                       'en:polyglycerol-esters-of-fatty-acids',
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
                                  'en:protein',
                                  'en:animal-protein',
                                  'en:egg',
                                  'en:emulsifier',
                                  'fr:e463',
                                  'fr:e432-et-e472',
                                  'en:acidity-regulator',
                                  'en:polyglycerol-esters-of-fatty-acids',
                                  'en:acid',
                                  'en:salt',
                                  'en:cocoa-butter',
                                  'en:cocoa',
                                  'fr:e322',
                                  'fr:e333-e474',
                                  'en:citric-acid',
                                  'en:phosphoric-acid'
                                ],
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
                               'id' => 'en:polyglycerol-esters-of-fatty-acids',
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

#diag explain $product_ref;


my $expected_product_ref =
 {
  'additives_n' => 0,
  'additives_old_n' => 0,
  'additives_old_tags' => [],
  'additives_original_tags' => [],
  'additives_tags' => [],
  'amino_acids_tags' => [],
  'ingredients' => [
    {
      'id' => 'en:palm-kernel-fat',
      'rank' => 1,
      'text' => 'graisse de palmiste'
    }
  ],
  'ingredients_from_or_that_may_be_from_palm_oil_n' => 1,
  'ingredients_from_palm_oil_n' => 1,
  'ingredients_from_palm_oil_tags' => [
    'huile-de-palme'
  ],
  'ingredients_hierarchy' => [
    'en:palm-kernel-fat',
    'en:palm-kernel-oil'
  ],
  'ingredients_n' => 1,
  'ingredients_n_tags' => [
    '1',
    '1-10'
  ],
  'ingredients_original_tags' => [
    'en:palm-kernel-fat'
  ],
  'ingredients_tags' => [
    'en:palm-kernel-fat',
    'en:palm-kernel-oil'
  ],
  'ingredients_text' => 'graisse de palmiste',
  'ingredients_that_may_be_from_palm_oil_n' => 0,
  'ingredients_that_may_be_from_palm_oil_tags' => [],
  'lc' => 'fr',
  'minerals_tags' => [],
  'nucleotides_tags' => [],
  'other_nutritional_substances_tags' => [],
  'unknown_ingredients_n' => 0,
  'vitamins_tags' => []
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

is_deeply($product_ref, $expected_product_ref) || diag explain $product_ref;



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

$expected_product_ref = 
{
  'ingredients' => [
    {
      'id' => 'fr:Marmelade d\'oranges',
      'percent' => '41',
      'rank' => 1,
      'text' => 'Marmelade d\'oranges'
    },
    {
      'id' => "fr:pulpe d'orange concentr\x{e9}e",
      'percent' => '0.6',
      'rank' => 2,
      'text' => "pulpe d'orange concentr\x{e9}e"
    },
    {
      'id' => "fr:\x{e9}quivalent pulpe d'orange",
      'percent' => '2.6',
      'rank' => 3,
      'text' => "\x{e9}quivalent pulpe d'orange"
    },
    {
      'id' => 'en:gelling-agent',
      'rank' => 4,
      'text' => "g\x{e9}lifiant"
    },
    {
      'id' => 'en:pectin',
      'rank' => 5,
      'text' => 'pectines'
    },
    {
      'id' => 'en:acid',
      'rank' => 6,
      'text' => 'acidifiant'
    },
    {
      'id' => 'en:citric-acid',
      'rank' => 7,
      'text' => 'acide citrique'
    },
    {
      'id' => 'en:acidity-regulator',
      'rank' => 8,
      'text' => "correcteurs d'acidit\x{e9}"
    },
    {
      'id' => 'en:natural-orange-flavouring',
      'rank' => 9,
      'text' => "ar\x{f4}me naturel d'orange"
    },
    {
      'id' => 'en:thickener',
      'rank' => 10,
      'text' => "\x{e9}paississant"
    },
    {
      'id' => 'en:xanthan-gum',
      'rank' => 11,
      'text' => 'gomme xanthane'
    },
    {
      'id' => 'en:chocolate',
      'percent' => '24.9',
      'rank' => 12,
      'text' => 'chocolat'
    },
    {
      'id' => 'en:flavouring',
      'rank' => 13,
      'text' => "ar\x{f4}me"
    },
    {
      'id' => 'en:emulsifier',
      'rank' => 14,
      'text' => "\x{e9}mulsifiant"
    },
    {
      'id' => 'en:soya-lecithin',
      'rank' => 15,
      'text' => "l\x{e9}cithine de soja"
    },
    {
      'id' => 'en:lactose-and-milk-proteins',
      'rank' => 16,
      'text' => "lactose et prot\x{e9}ines de lait"
    },
    {
      'id' => 'en:wheat-flour',
      'rank' => 17,
      'text' => "farine de bl\x{e9}"
    },
    {
      'id' => 'en:sugar',
      'rank' => 18,
      'text' => 'sucre'
    },
    {
      'id' => 'en:egg',
      'rank' => 19,
      'text' => 'oeufs'
    },
    {
      'id' => 'en:glucose-fructose-syrup',
      'rank' => 20,
      'text' => 'sirop de glucose-fructose'
    },
    {
      'id' => 'en:colza-oil',
      'rank' => 21,
      'text' => 'huile de colza'
    },
    {
      'id' => 'en:yeast-powder',
      'rank' => 22,
      'text' => "poudre \x{e0} lever"
    },
    {
      'id' => 'en:salt',
      'rank' => 23,
      'text' => 'sel'
    },
    {
      'id' => 'en:emulsifier',
      'rank' => 24,
      'text' => "\x{e9}mulsifiant"
    },
    {
      'id' => 'en:soya-lecithin',
      'rank' => 25,
      'text' => "l\x{e9}cithine de soja"
    },
    {
      'id' => 'en:glucose-fructose-syrup',
      'text' => 'sirop de glucose-fructose'
    },
    {
      'id' => 'en:sugar',
      'text' => 'sucre'
    },
    {
      'id' => 'de:orangenfruchtfleisch',
      'percent' => '4.5',
      'text' => 'pulpe d\'orange'
    },
    {
      'id' => 'en:concentrated-orange-juice',
      'percent' => '1.4',
      'text' => "jus d'orange concentr\x{e9}"
    },
    {
      'id' => "fr:\x{e9}quivalent jus d'orange",
      'percent' => '7.8',
      'text' => "\x{e9}quivalent jus d'orange"
    },
    {
      'id' => 'fr:citrate-de-calcium',
      'text' => 'citrate de calcium'
    },
    {
      'id' => 'en:trisodium-citrate',
      'text' => 'citrate de sodium'
    },
    {
      'id' => 'en:sugar',
      'text' => 'sucre'
    },
    {
      'id' => 'en:cocoa-paste',
      'text' => "p\x{e2}te de cacao"
    },
    {
      'id' => 'en:cocoa-butter',
      'text' => 'beurre de cacao'
    },
    {
      'id' => 'en:vegetable-fat',
      'text' => "graisses v\x{e9}g\x{e9}tales"
    },
    {
      'id' => 'en:illipe',
      'text' => 'illipe'
    },
    {
      'id' => 'en:mango',
      'text' => 'mangue'
    },
    {
      'id' => 'fr:sal',
      'text' => 'sal'
    },
    {
      'id' => "fr:karit\x{e9} et palme en proportions variables",
      'text' => "karit\x{e9} et palme en proportions variables"
    },
    {
      'id' => 'en:ammonium-hydrogen-carbonate',
      'text' => 'carbonate acide d\'ammonium'
    },
    {
      'id' => 'en:disodium-diphosphate',
      'text' => 'diphosphate disodique'
    },
    {
      'id' => 'en:sodium-hydrogen-carbonate',
      'text' => 'carbonate acide de sodium'
    }
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
    'en:flavouring',
    'en:natural-flavouring',
    'en:thickener',
    'en:xanthan-gum',
    'en:chocolate',
    'en:emulsifier',
    'en:soya-lecithin',
    'en:lecithins',
    'en:lactose-and-milk-proteins',
    'en:protein',
    'en:animal-protein',
    'en:lactose',
    'en:milk-proteins',
    'en:wheat-flour',
    'en:cereal',
    'en:cereal-flour',
    'en:wheat',
    'en:sugar',
    'en:egg',
    'en:glucose-fructose-syrup',
    'en:glucose',
    'en:fructose',
    'en:colza-oil',
    'en:oil',
    'en:oil-and-vegetable-fat',
    'en:vegetable-oil',
    'en:yeast-powder',
    'en:yeast',
    'en:salt',
    'de:orangenfruchtfleisch',
    'en:fruit',
    'en:citrus-fruit',
    'en:orange',
    'en:concentrated-orange-juice',
    'en:fruit-juice',
    'en:orange-juice',
    "fr:\x{e9}quivalent jus d'orange",
    'fr:citrate-de-calcium',
    'en:trisodium-citrate',
    'en:sodium-citrates',
    'en:cocoa-paste',
    'en:cocoa-butter',
    'en:cocoa',
    'en:vegetable-fat',
    'en:illipe',
    'en:mango',
    'fr:sal',
    "fr:karit\x{e9} et palme en proportions variables",
    'en:ammonium-hydrogen-carbonate',
    'en:ammonium-carbonates',
    'en:disodium-diphosphate',
    'en:diphosphates',
    'en:sodium-hydrogen-carbonate',
    'en:sodium-carbonates'
  ],
  'ingredients_n' => 43,
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
    'en:lactose-and-milk-proteins',
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
    'de:orangenfruchtfleisch',
    'en:concentrated-orange-juice',
    "fr:\x{e9}quivalent jus d'orange",
    'fr:citrate-de-calcium',
    'en:trisodium-citrate',
    'en:sugar',
    'en:cocoa-paste',
    'en:cocoa-butter',
    'en:vegetable-fat',
    'en:illipe',
    'en:mango',
    'fr:sal',
    "fr:karit\x{e9} et palme en proportions variables",
    'en:ammonium-hydrogen-carbonate',
    'en:disodium-diphosphate',
    'en:sodium-hydrogen-carbonate'
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
    'en:flavouring',
    'en:natural-flavouring',
    'en:thickener',
    'en:xanthan-gum',
    'en:chocolate',
    'en:emulsifier',
    'en:soya-lecithin',
    'en:lecithins',
    'en:lactose-and-milk-proteins',
    'en:protein',
    'en:animal-protein',
    'en:lactose',
    'en:milk-proteins',
    'en:wheat-flour',
    'en:cereal',
    'en:cereal-flour',
    'en:wheat',
    'en:sugar',
    'en:egg',
    'en:glucose-fructose-syrup',
    'en:glucose',
    'en:fructose',
    'en:colza-oil',
    'en:oil',
    'en:oil-and-vegetable-fat',
    'en:vegetable-oil',
    'en:yeast-powder',
    'en:yeast',
    'en:salt',
    'de:orangenfruchtfleisch',
    'en:fruit',
    'en:citrus-fruit',
    'en:orange',
    'en:concentrated-orange-juice',
    'en:fruit-juice',
    'en:orange-juice',
    'fr:equivalent-jus-d-orange',
    'fr:citrate-de-calcium',
    'en:trisodium-citrate',
    'en:sodium-citrates',
    'en:cocoa-paste',
    'en:cocoa-butter',
    'en:cocoa',
    'en:vegetable-fat',
    'en:illipe',
    'en:mango',
    'fr:sal',
    'fr:karite-et-palme-en-proportions-variables',
    'en:ammonium-hydrogen-carbonate',
    'en:ammonium-carbonates',
    'en:disodium-diphosphate',
    'en:diphosphates',
    'en:sodium-hydrogen-carbonate',
    'en:sodium-carbonates'
  ],
  'ingredients_text' => "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentr\x{e9} 1.4% (\x{e9}quivalent jus d'orange 7.8%), pulpe d'orange concentr\x{e9}e 0.6% (\x{e9}quivalent pulpe d'orange 2.6%), g\x{e9}lifiant (pectines), acidifiant (acide citrique), correcteurs d'acidit\x{e9} (citrate de calcium, citrate de sodium), ar\x{f4}me naturel d'orange, \x{e9}paississant (gomme xanthane)), chocolat 24.9% (sucre, p\x{e2}te de cacao, beurre de cacao, graisses v\x{e9}g\x{e9}tales (illipe, mangue, sal, karit\x{e9} et palme en proportions variables), ar\x{f4}me, \x{e9}mulsifiant (l\x{e9}cithine de soja), lactose et prot\x{e9}ines de lait), farine de bl\x{e9}, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre \x{e0} lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, \x{e9}mulsifiant (l\x{e9}cithine de soja).",
  'lc' => 'fr',
  'unknown_ingredients_n' => 6
};


is_deeply($product_ref, $expected_product_ref) || diag explain $product_ref;


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


# diag explain $product_ref;

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
                                       'en:flavouring',
                                       'en:natural-flavouring',
                                       'en:lemon-flavouring',
                                     ],
          'ingredients_tags' => [
                                  'en:natural-orange-flavouring',
                                  'en:flavouring',
                                  'en:natural-flavouring',
                                  'en:lemon-flavouring',
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


my $product_ref = {
        lc => "fr",
        ingredients_text => "pâte de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce équitable et de l'agriculture biologique (100% du poids total)."
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


diag explain $product_ref;

$expected_product_ref = {

          'ingredients_n_tags' => [
                                    '5',
                                    '1-10'
                                  ],
          'ingredients_original_tags' => [
                                           "fr:p\x{e2}te de cacao* de Madagascar",
                                           'en:cane-sugar',
                                           'en:cocoa-butter',
                                           "fr:issus du commerce \x{e9}quitable et de l'agriculture",
                                           'fr:du poids total'
                                         ],
          'ingredients_hierarchy' => [
                                       "fr:p\x{e2}te de cacao* de Madagascar",
                                       'en:cane-sugar',
                                       'en:sugar',
                                       'en:cocoa-butter',
                                       'en:cocoa',
                                       "fr:issus du commerce \x{e9}quitable et de l'agriculture",
                                       'fr:du poids total'
                                     ],
          'ingredients_tags' => [
                                  'fr:pate-de-cacao-de-madagascar',
                                  'en:cane-sugar',
                                  'en:sugar',
                                  'en:cocoa-butter',
                                  'en:cocoa',
                                  'fr:issus-du-commerce-equitable-et-de-l-agriculture',
                                  'fr:du-poids-total'
                                ],
          'ingredients_text' => "p\x{e2}te de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce \x{e9}quitable et de l'agriculture biologique (100% du poids total).",
          'lc' => 'fr',
          'ingredients' => [
                             {
                               'percent' => '75',
                               'text' => "p\x{e2}te de cacao* de Madagascar",
                               'id' => "fr:p\x{e2}te de cacao* de Madagascar",
                               'rank' => 1
                             },
                             {
                               'text' => 'sucre de canne',
                               'id' => 'en:cane-sugar',
                               'rank' => 2
                             },
                             {
                               'text' => 'beurre de cacao',
                               'id' => 'en:cocoa-butter',
                               'rank' => 3
                             },
                             {
                               'text' => "issus du commerce \x{e9}quitable et de l'agriculture",
                               'id' => "fr:issus du commerce \x{e9}quitable et de l'agriculture",
			       'label' => "en:organic",
                               'rank' => 4
                             },
                             {
                               'percent' => '100',
                               'text' => 'du poids total',
                               'id' => 'fr:du poids total',
                               'rank' => 5
                             }
                           ],
          'unknown_ingredients_n' => 3,
          'ingredients_n' => 5

        };


is_deeply($product_ref, $expected_product_ref);


done_testing();
