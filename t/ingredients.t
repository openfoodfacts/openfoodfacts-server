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


is($product_ref->{ingredients_n}, 19);

my $expected_product_ref = 
 {
    'ingredients' => [
      {
        'id' => 'en:flour',
        'percent' => '12',
        'rank' => 1,
        'text' => 'farine',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:chocolate',
	'has_sub_ingredients' => 'yes',
        'rank' => 2,
        'text' => 'chocolat',
	'vegan' => 'maybe',
	'vegetarian' => 'yes',
      },
      {
        'id' => 'en:sugar',
        'percent' => '10',
        'rank' => 3,
        'text' => 'sucre',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:milk-proteins',
        'rank' => 4,
        'text' => "prot\x{e9}ines de lait",
        'vegan' => 'no',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:egg',
	'percent' => 1,
        'rank' => 5,
        'text' => 'oeuf',
        'vegan' => 'no',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:emulsifier',
	'has_sub_ingredients' => 'yes',
        'rank' => 6,
        'text' => "\x{e9}mulsifiants"
      },
      {
        'id' => 'en:e463',
        'rank' => 7,
        'text' => 'e463',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e432',
        'rank' => 8,
        'text' => 'e432',
        'vegan' => 'maybe',
        'vegetarian' => 'maybe',
	'from_palm_oil' => 'maybe',
      },
      {
        'id' => 'en:e472',
        'rank' => 9,
        'text' => 'e472',
        'vegan' => 'maybe',
        'vegetarian' => 'maybe',
	'from_palm_oil' => 'maybe',
      },
      {
        'id' => 'en:acidity-regulator',
	'has_sub_ingredients' => 'yes',
        'rank' => 10,
        'text' => "correcteurs d'acidit\x{e9}"
      },
      {
        'id' => 'en:e474',
        'rank' => 11,
        'text' => 'e474',
        'vegan' => 'maybe',
        'vegetarian' => 'maybe'
      },
      {
        'id' => 'en:e475',
        'rank' => 12,
        'text' => 'e475',
        'vegan' => 'maybe',
        'vegetarian' => 'maybe'
      },
      {
        'id' => 'en:acid',
	'has_sub_ingredients' => 'yes',
        'rank' => 13,
        'text' => 'acidifiant'
      },
      {
        'id' => 'en:salt',
        'rank' => 14,
        'text' => 'sel',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:cocoa-butter',
        'percent' => '15',
        'text' => 'beurre de cacao',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e322',
        'text' => 'e322',
        'vegan' => 'maybe',
        'vegetarian' => 'maybe'
      },
      {
        'id' => 'en:e333',
        'text' => 'e333',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e330',
        'text' => 'acide citrique',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e338',
        'text' => 'acide phosphorique',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      }
    ],
    'ingredients_analysis_tags' => [
      'en:may-contain-palm-oil',
      'en:non-vegan',
      'en:maybe-vegetarian'
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
      'en:e463',
      'en:e432',
      'en:e472',
      'en:acidity-regulator',
      'en:e474',
      'en:e475',
      'en:acid',
      'en:salt',
      'en:cocoa-butter',
      'en:cocoa',
      'en:e322',
      'en:e333',
      'en:e330',
      'en:e338'
    ],
    'ingredients_n' => 19,
    'ingredients_n_tags' => [
      '19',
      '11-20'
    ],
    'ingredients_original_tags' => [
      'en:flour',
      'en:chocolate',
      'en:sugar',
      'en:milk-proteins',
      'en:egg',
      'en:emulsifier',
      'en:e463',
      'en:e432',
      'en:e472',
      'en:acidity-regulator',
      'en:e474',
      'en:e475',
      'en:acid',
      'en:salt',
      'en:cocoa-butter',
      'en:e322',
      'en:e333',
      'en:e330',
      'en:e338'
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
      'en:e463',
      'en:e432',
      'en:e472',
      'en:acidity-regulator',
      'en:e474',
      'en:e475',
      'en:acid',
      'en:salt',
      'en:cocoa-butter',
      'en:cocoa',
      'en:e322',
      'en:e333',
      'en:e330',
      'en:e338'
    ],
    'ingredients_text' => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], prot\x{e9}ines de lait, oeuf 1%) - \x{e9}mulsifiants : E463, E432 et E472 - correcteurs d'acidit\x{e9} : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel",
    'lc' => 'fr',
    'unknown_ingredients_n' => 0
  };


is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);




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


$expected_product_ref =
 {
    'additives_n' => 0,
    'additives_old_n' => 0,
    'additives_old_tags' => [],
    'additives_original_tags' => [],
    'additives_tags' => [],
    'amino_acids_tags' => [],
    'ingredients' => [
      {
        'from_palm_oil' => 'yes',
        'id' => 'en:palm-kernel-fat',
        'rank' => 1,
        'text' => 'graisse de palmiste',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      }
    ],
    'ingredients_analysis_tags' => [
      'en:palm-oil',
      'en:vegan',
      'en:vegetarian'
    ],
    'ingredients_from_or_that_may_be_from_palm_oil_n' => 1,
    'ingredients_from_palm_oil_n' => 1,
    'ingredients_from_palm_oil_tags' => [
      'huile-de-palme'
    ],
    'ingredients_hierarchy' => [
      'en:palm-kernel-fat',
      'en:oil-and-fat',
      'en:vegetable-oil-and-fat',
      'en:palm-kernel-oil-and-fat'
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
      'en:oil-and-fat',
      'en:vegetable-oil-and-fat',
      'en:palm-kernel-oil-and-fat'
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



$product_ref = {
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
	'has_sub_ingredients' => 'yes',
        'percent' => '41',
        'rank' => 1,
        'text' => 'Marmelade d\'oranges'
      },
      {
        'id' => 'en:orange-pulp',
	'has_sub_ingredients' => 'yes',
        'percent' => '0.6',
        'processing' => 'en:concentrated',
        'rank' => 2,
        'text' => 'pulpe d\'orange ',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:gelling-agent',
	'has_sub_ingredients' => 'yes',
        'rank' => 3,
        'text' => "g\x{e9}lifiant"
      },
      {
        'id' => 'en:e440a',
        'rank' => 4,
        'text' => 'pectines',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:acid',
	'has_sub_ingredients' => 'yes',
        'rank' => 5,
        'text' => 'acidifiant'
      },
      {
        'id' => 'en:e330',
        'rank' => 6,
        'text' => 'acide citrique',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:acidity-regulator',
	'has_sub_ingredients' => 'yes',
        'rank' => 7,
        'text' => "correcteurs d'acidit\x{e9}"
      },
      {
        'id' => 'en:natural-orange-flavouring',
        'rank' => 8,
        'text' => "ar\x{f4}me naturel d'orange",
        'vegan' => 'maybe',
        'vegetarian' => 'maybe'
      },
      {
        'id' => 'en:thickener',
	'has_sub_ingredients' => 'yes',
        'rank' => 9,
        'text' => "\x{e9}paississant"
      },
      {
        'id' => 'en:e415',
        'rank' => 10,
        'text' => 'gomme xanthane',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:chocolate',
	'has_sub_ingredients' => 'yes',
        'percent' => '24.9',
        'rank' => 11,
        'text' => 'chocolat',
        'vegan' => 'maybe',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:lactose-and-milk-proteins',
        'rank' => 12,
        'text' => "lactose et prot\x{e9}ines de lait",
        'vegan' => 'no',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:wheat-flour',
        'rank' => 13,
        'text' => "farine de bl\x{e9}",
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:sugar',
        'rank' => 14,
        'text' => 'sucre',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:egg',
        'rank' => 15,
        'text' => 'oeufs',
        'vegan' => 'no',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:glucose-fructose-syrup',
        'rank' => 16,
        'text' => 'sirop de glucose-fructose',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'from_palm_oil' => 'no',
        'id' => 'en:colza-oil',
        'rank' => 17,
        'text' => 'huile de colza',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:raising-agent',
	'has_sub_ingredients' => 'yes',
        'rank' => 18,
        'text' => "poudre \x{e0} lever"
      },
      {
        'id' => 'en:salt',
        'rank' => 19,
        'text' => 'sel',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:emulsifier',
	'has_sub_ingredients' => 'yes',
        'rank' => 20,
        'text' => "\x{e9}mulsifiant"
      },
      {
        'id' => 'en:soya-lecithin',
        'rank' => 21,
        'text' => "l\x{e9}cithine de soja",
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:glucose-fructose-syrup',
        'text' => 'sirop de glucose-fructose',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:sugar',
        'text' => 'sucre',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:orange-pulp',
        'percent' => '4.5',
        'text' => 'pulpe d\'orange',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:concentrated-orange-juice',
	'has_sub_ingredients' => 'yes',
        'percent' => '1.4',
        'text' => "jus d'orange concentr\x{e9}",
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e333',
        'text' => 'citrate de calcium',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:sodium-citrate',
        'text' => 'citrate de sodium'
      },
      {
        'id' => 'en:sugar',
        'text' => 'sucre',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:cocoa-paste',
        'text' => "p\x{e2}te de cacao",
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:cocoa-butter',
        'text' => 'beurre de cacao',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => "fr:graisses v\x{e9}g\x{e9}tales d'illipe",
        'text' => "graisses v\x{e9}g\x{e9}tales d'illipe"
      },
      {
        'id' => "fr:graisses v\x{e9}g\x{e9}tales de mangue",
        'text' => "graisses v\x{e9}g\x{e9}tales de mangue"
      },
      {
        'id' => "fr:graisses v\x{e9}g\x{e9}tales de sal",
        'text' => "graisses v\x{e9}g\x{e9}tales de sal"
      },
      {
        'from_palm_oil' => 'no',
        'id' => 'en:shea-butter',
        'text' => "graisses v\x{e9}g\x{e9}tales de karit\x{e9}",
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'from_palm_oil' => 'yes',
        'id' => 'en:palm-fat',
        'text' => "graisses v\x{e9}g\x{e9}tales de palme",
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:flavouring',
        'text' => "ar\x{f4}me",
        'vegan' => 'maybe',
        'vegetarian' => 'maybe'
      },
      {
        'id' => 'en:emulsifier',
	'has_sub_ingredients' => 'yes',
        'text' => "\x{e9}mulsifiant"
      },
      {
        'id' => 'en:soya-lecithin',
        'text' => "l\x{e9}cithine de soja",
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e503',
        'text' => 'carbonate acide d\'ammonium',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e450i',
        'text' => 'diphosphate disodique',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      },
      {
        'id' => 'en:e500',
        'text' => 'carbonate acide de sodium',
        'vegan' => 'yes',
        'vegetarian' => 'yes'
      }
    ],
    'ingredients_analysis_tags' => [
      'en:palm-oil',
      'en:non-vegan',
      'en:vegetarian-status-unknown'
    ],
    'ingredients_hierarchy' => [
      'fr:Marmelade d\'oranges',
      'en:orange-pulp',
      'en:fruit',
      'en:citrus-fruit',
      'en:orange',
      'en:gelling-agent',
      'en:e440a',
      'en:acid',
      'en:e330',
      'en:acidity-regulator',
      'en:natural-orange-flavouring',
      'en:flavouring',
      'en:natural-flavouring',
      'en:thickener',
      'en:e415',
      'en:chocolate',
      'en:lactose-and-milk-proteins',
      'en:protein',
      'en:animal-protein',
      'en:milk-proteins',
      'en:lactose',
      'en:wheat-flour',
      'en:cereal',
      'en:wheat',
      'en:flour',
      'en:cereal-flour',
      'en:sugar',
      'en:egg',
      'en:glucose-fructose-syrup',
      'en:glucose',
      'en:fructose',
      'en:colza-oil',
      'en:oil-and-fat',
      'en:vegetable-oil-and-fat',
      'en:rapeseed-oil',
      'en:raising-agent',
      'en:salt',
      'en:emulsifier',
      'en:soya-lecithin',
      'en:e322',
      'en:concentrated-orange-juice',
      'en:fruit-juice',
      'en:orange-juice',
      'en:e333',
      'en:sodium-citrate',
      'en:minerals',
      'en:sodium',
      'en:cocoa-paste',
      'en:cocoa',
      'en:cocoa-butter',
      "fr:graisses v\x{e9}g\x{e9}tales d'illipe",
      "fr:graisses v\x{e9}g\x{e9}tales de mangue",
      "fr:graisses v\x{e9}g\x{e9}tales de sal",
      'en:shea-butter',
      'en:vegetable-fat',
      'en:palm-fat',
      'en:palm-oil-and-fat',
      'en:e503',
      'en:e450i',
      'en:e450',
      'en:e500'
    ],
    'ingredients_n' => 41,
    'ingredients_n_tags' => [
      '41',
      '41-50'
    ],
    'ingredients_original_tags' => [
      'fr:Marmelade d\'oranges',
      'en:orange-pulp',
      'en:gelling-agent',
      'en:e440a',
      'en:acid',
      'en:e330',
      'en:acidity-regulator',
      'en:natural-orange-flavouring',
      'en:thickener',
      'en:e415',
      'en:chocolate',
      'en:lactose-and-milk-proteins',
      'en:wheat-flour',
      'en:sugar',
      'en:egg',
      'en:glucose-fructose-syrup',
      'en:colza-oil',
      'en:raising-agent',
      'en:salt',
      'en:emulsifier',
      'en:soya-lecithin',
      'en:glucose-fructose-syrup',
      'en:sugar',
      'en:orange-pulp',
      'en:concentrated-orange-juice',
      'en:e333',
      'en:sodium-citrate',
      'en:sugar',
      'en:cocoa-paste',
      'en:cocoa-butter',
      "fr:graisses v\x{e9}g\x{e9}tales d'illipe",
      "fr:graisses v\x{e9}g\x{e9}tales de mangue",
      "fr:graisses v\x{e9}g\x{e9}tales de sal",
      'en:shea-butter',
      'en:palm-fat',
      'en:flavouring',
      'en:emulsifier',
      'en:soya-lecithin',
      'en:e503',
      'en:e450i',
      'en:e500'
    ],
    'ingredients_tags' => [
      'fr:marmelade-d-oranges',
      'en:orange-pulp',
      'en:fruit',
      'en:citrus-fruit',
      'en:orange',
      'en:gelling-agent',
      'en:e440a',
      'en:acid',
      'en:e330',
      'en:acidity-regulator',
      'en:natural-orange-flavouring',
      'en:flavouring',
      'en:natural-flavouring',
      'en:thickener',
      'en:e415',
      'en:chocolate',
      'en:lactose-and-milk-proteins',
      'en:protein',
      'en:animal-protein',
      'en:milk-proteins',
      'en:lactose',
      'en:wheat-flour',
      'en:cereal',
      'en:wheat',
      'en:flour',
      'en:cereal-flour',
      'en:sugar',
      'en:egg',
      'en:glucose-fructose-syrup',
      'en:glucose',
      'en:fructose',
      'en:colza-oil',
      'en:oil-and-fat',
      'en:vegetable-oil-and-fat',
      'en:rapeseed-oil',
      'en:raising-agent',
      'en:salt',
      'en:emulsifier',
      'en:soya-lecithin',
      'en:e322',
      'en:concentrated-orange-juice',
      'en:fruit-juice',
      'en:orange-juice',
      'en:e333',
      'en:sodium-citrate',
      'en:minerals',
      'en:sodium',
      'en:cocoa-paste',
      'en:cocoa',
      'en:cocoa-butter',
      'fr:graisses-vegetales-d-illipe',
      'fr:graisses-vegetales-de-mangue',
      'fr:graisses-vegetales-de-sal',
      'en:shea-butter',
      'en:vegetable-fat',
      'en:palm-fat',
      'en:palm-oil-and-fat',
      'en:e503',
      'en:e450i',
      'en:e450',
      'en:e500'
    ],
    'ingredients_text' => "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentr\x{e9} 1.4% (\x{e9}quivalent jus d'orange 7.8%), pulpe d'orange concentr\x{e9}e 0.6% (\x{e9}quivalent pulpe d'orange 2.6%), g\x{e9}lifiant (pectines), acidifiant (acide citrique), correcteurs d'acidit\x{e9} (citrate de calcium, citrate de sodium), ar\x{f4}me naturel d'orange, \x{e9}paississant (gomme xanthane)), chocolat 24.9% (sucre, p\x{e2}te de cacao, beurre de cacao, graisses v\x{e9}g\x{e9}tales (illipe, mangue, sal, karit\x{e9} et palme en proportions variables), ar\x{f4}me, \x{e9}mulsifiant (l\x{e9}cithine de soja), lactose et prot\x{e9}ines de lait), farine de bl\x{e9}, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre \x{e0} lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, \x{e9}mulsifiant (l\x{e9}cithine de soja).",
    'lc' => 'fr',
    'unknown_ingredients_n' => 4
  };

	

is_deeply($product_ref->{ingredients_original_tags}, $expected_product_ref->{ingredients_original_tags}) || diag explain $product_ref->{ingredients_original_tags};

is_deeply($product_ref, $expected_product_ref) || diag explain $product_ref;


# test synonyms for flavouring/flavour/flavor/flavoring
$product_ref = {
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

$expected_product_ref = 
 {
    'ingredients' => [
      {
        'id' => 'en:natural-orange-flavouring',
        'rank' => 1,
        'text' => 'Natural orange flavor',
	'vegan' => 'maybe',
	'vegetarian' => 'maybe'
      },
      {
        'id' => 'en:lemon-flavouring',
        'rank' => 2,
        'text' => 'Lemon flavouring',
	'vegan' => 'maybe',
	'vegetarian' => 'maybe'
      }
    ],
    'ingredients_analysis_tags' => [
      'en:palm-oil-free',
      'en:maybe-vegan',
      'en:maybe-vegetarian'
    ],
    'ingredients_hierarchy' => [
      'en:natural-orange-flavouring',
      'en:flavouring',
      'en:natural-flavouring',
      'en:lemon-flavouring'
    ],
    'ingredients_n' => 2,
    'ingredients_n_tags' => [
      '2',
      '1-10'
    ],
    'ingredients_original_tags' => [
      'en:natural-orange-flavouring',
      'en:lemon-flavouring'
    ],
    'ingredients_tags' => [
      'en:natural-orange-flavouring',
      'en:flavouring',
      'en:natural-flavouring',
      'en:lemon-flavouring'
    ],
    'ingredients_text' => 'Natural orange flavor, Lemon flavouring',
    'lc' => 'en',
    'unknown_ingredients_n' => 0
  };



is_deeply($product_ref, $expected_product_ref) or diag explain $product_ref;


$product_ref = {
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



$expected_product_ref = {
	    'ingredients' => [
	      {
	        'id' => "fr:p\x{e2}te de cacao de Madagascar",
	        'labels' => 'en:fair-trade, en:organic',
	        'percent' => '75',
	        'rank' => 1,
	        'text' => "p\x{e2}te de cacao de Madagascar"
	      },
	      {
	        'id' => 'en:cane-sugar',
	        'labels' => 'en:fair-trade, en:organic',
	        'rank' => 2,
	        'text' => 'sucre de canne',
	        'vegan' => 'yes',
	        'vegetarian' => 'yes'
	      },
	      {
	        'id' => 'en:cocoa-butter',
	        'labels' => 'en:fair-trade, en:organic',
	        'rank' => 3,
	        'text' => 'beurre de cacao',
	        'vegan' => 'yes',
	        'vegetarian' => 'yes'
	      }
	    ],
	    'ingredients_analysis_tags' => [
	      'en:palm-oil-content-unknown',
	      'en:vegan-status-unknown',
	      'en:vegetarian-status-unknown'
	    ],
	    'ingredients_hierarchy' => [
	      "fr:p\x{e2}te de cacao de Madagascar",
	      'en:cane-sugar',
	      'en:sugar',
	      'en:cocoa-butter',
	      'en:cocoa'
	    ],
	    'ingredients_n' => 3,
	    'ingredients_n_tags' => [
	      '3',
	      '1-10'
	    ],
	    'ingredients_original_tags' => [
	      "fr:p\x{e2}te de cacao de Madagascar",
	      'en:cane-sugar',
	      'en:cocoa-butter'
	    ],
	    'ingredients_tags' => [
	      'fr:pate-de-cacao-de-madagascar',
	      'en:cane-sugar',
	      'en:sugar',
	      'en:cocoa-butter',
	      'en:cocoa'
	    ],
	    'ingredients_text' => "p\x{e2}te de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce \x{e9}quitable et de l'agriculture biologique (100% du poids total).",
	    'lc' => 'fr',
	    'unknown_ingredients_n' => 1
};

is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);


$product_ref = {
        lc => "fr",
        ingredients_text => "gélifiant (pectines)",
};

extract_ingredients_from_text($product_ref);

is_deeply ($product_ref->{ingredients_original_tags}, [
"en:gelling-agent",
"en:e440a",
]) or diag explain $product_ref;


$product_ref = {
        lc => "fr",
        ingredients_text => "Fraise 12,3% ; Orange 6.5%, Pomme (3,5%)",
};

extract_ingredients_from_text($product_ref);


is_deeply ($product_ref->{ingredients}, 
[
	     {
	            'id' => 'en:strawberry',
	            'percent' => '12.3',
	            'rank' => 1,
	            'text' => 'Fraise',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes',
	          },
	          {
	            'id' => 'en:orange',
	            'percent' => '6.5',
	            'rank' => 2,
	            'text' => 'Orange',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes',
	          },
	          {
	            'id' => 'en:apple',
	            'percent' => '3.5',
	            'rank' => 3,
	            'text' => 'Pomme',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes',
	          }
	        ]
) or diag explain $product_ref;



$product_ref = {
        lc => "fr",
        ingredients_text => "Fraise origine France, Cassis (origine Afrique du Sud), Framboise (origine : Belgique), Pamplemousse bio, Orange (bio), Citron (issue de l'agriculture biologique), cacao et beurre de cacao (commerce équitable), cerises issues de l'agriculture biologique",
};

extract_ingredients_from_text($product_ref);


is_deeply ($product_ref->{ingredients}, 
	   [
	        {
	          'id' => 'en:strawberry',
	          'origin' => 'France',
	          'rank' => 1,
	          'text' => 'Fraise',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
	        {
	          'id' => 'en:blackcurrant',
	          'origin' => 'Afrique du Sud',
	          'rank' => 2,
	          'text' => 'Cassis',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
	        {
	          'id' => 'en:raspberry',
	          'origin' => 'Belgique',
	          'rank' => 3,
	          'text' => 'Framboise',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
	        {
	          'id' => 'en:grapefruit',
	          'labels' => 'en:organic',
	          'rank' => 4,
	          'text' => 'Pamplemousse',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
	        {
	          'id' => 'en:orange',
	          'labels' => 'en:organic',
	          'rank' => 5,
	          'text' => 'Orange',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
	        {
	          'id' => 'en:lemon',
	          'labels' => 'en:organic',
	          'rank' => 6,
	          'text' => 'Citron',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
	        {
	          'id' => 'en:cocoa',
	          'labels' => 'en:fair-trade',
	          'rank' => 7,
	          'text' => 'cacao',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
	        {
	          'id' => 'en:cocoa-butter',
	          'labels' => 'en:fair-trade',
	          'rank' => 8,
	          'text' => 'beurre de cacao',
	          'vegan' => 'yes',
	          'vegetarian' => 'yes'
	        },
     {
            'id' => 'en:cherry',
            'labels' => 'en:organic',
            'rank' => 9,
            'text' => 'cerises',
            'vegan' => 'yes',
            'vegetarian' => 'yes'
          }

	      ],
	
) or diag explain $product_ref;


$product_ref = {
        lc => "fr",
        ingredients_text => "émulsifiant : lécithines (tournesol), arôme)(UE), farine de blé 33% (France), sucre, beurre concentré* 6,5% (France)",
};

extract_ingredients_from_text($product_ref);


is_deeply ($product_ref->{ingredients}, 
[
	     {
	            'id' => 'en:emulsifier',
	            'rank' => 1,
		    'has_sub_ingredients' => 'yes',
	            'text' => "\x{e9}mulsifiant"
	          },
	          {
	            'id' => 'en:sunflower-lecithin',
	            'rank' => 2,
	            'text' => "l\x{e9}cithines de tournesol",
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:flavouring',
	            'origin' => 'en:european-union',
	            'rank' => 3,
	            'text' => "ar\x{f4}me",
	            'vegan' => 'maybe',
	            'vegetarian' => 'maybe'
	          },
	          {
	            'id' => 'en:wheat-flour',
	            'origin' => 'en:france',
	            'percent' => '33',
	            'rank' => 4,
	            'text' => "farine de bl\x{e9}",
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:sugar',
	            'rank' => 5,
	            'text' => 'sucre',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:butterfat',
	            'origin' => 'en:france',
	            'percent' => '6.5',
	            'rank' => 6,
	            'text' => "beurre concentr\x{e9}",
	            'vegan' => 'no',
	            'vegetarian' => 'yes',
	            'from_palm_oil' => 'no',
	          }
	        ],
	
) or diag explain $product_ref;



$product_ref = {
        lc => "fr",
        ingredients_text => "80% jus de pomme biologique, 20% de coing biologique, sel marin, 98% chlorure de sodium (France, Italie)",
};

extract_ingredients_from_text($product_ref);


is_deeply ($product_ref->{ingredients}, 

[
	     {
	            'id' => 'en:apple-juice',
	            'labels' => 'en:organic',
	            'percent' => '80',
	            'rank' => 1,
	            'text' => 'jus de pomme',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:quince',
	            'labels' => 'en:organic',
	            'percent' => '20',
	            'rank' => 2,
	            'text' => 'coing',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:sea-salt',
	            'rank' => 3,
	            'text' => 'sel marin',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:sodium-chloride',
	            'origin' => 'France, Italie',
	            'percent' => '98',
	            'rank' => 4,
	            'text' => 'chlorure de sodium'
	          }
	        ],
	
	
) or diag explain $product_ref;


$product_ref = {
        lc => "fr",
        ingredients_text => "mono - et diglycérides d'acides gras d'origine végétale, huile d'origine végétale, gélatine (origine végétale)",
};

extract_ingredients_from_text($product_ref);


is_deeply ($product_ref->{ingredients}, 

[
     {
            'from_palm_oil' => 'maybe',
            'id' => 'en:e471',
            'rank' => 1,
            'text' => "mono- et diglyc\x{e9}rides d'acides gras",
            'vegan' => 'en:yes',
            'vegetarian' => 'en:yes'
          },
          {
            'from_palm_oil' => 'maybe',
            'id' => 'en:oil',
            'rank' => 2,
            'text' => 'huile',
            'vegan' => 'en:yes',
            'vegetarian' => 'en:yes'
          },
          {
            'id' => 'en:e428',
            'rank' => 3,
            'text' => "g\x{e9}latine",
            'vegan' => 'en:yes',
            'vegetarian' => 'en:yes'
          }
        ],	
	
) or diag explain $product_ref;


$product_ref = {
        lc => "fr",
        ingredients_text => "jus d'orange (sans conservateur), saumon (msc), sans gluten",
};

extract_ingredients_from_text($product_ref);

is ($product_ref->{labels}, "en:gluten-free") or diag explain $product_ref;
is_deeply ($product_ref->{labels_tags}, ["en:gluten-free"]) or diag explain $product_ref;

is_deeply ($product_ref->{ingredients}, 

[
	     {
	            'id' => 'en:orange-juice',
	            'labels' => 'en:no-preservatives',
	            'rank' => 1,
	            'text' => 'jus d\'orange',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:salmon',
	            'labels' => 'en:sustainable-seafood-msc',
	            'rank' => 2,
	            'text' => 'saumon',
	            'vegan' => 'no',
	            'vegetarian' => 'no'
	          }
	
        ],	
	
) or diag explain $product_ref;


$product_ref = {
        lc => "fr",
        ingredients_text => "tomates pelées cuites, rondelle de citron, dés de courgette",
};

extract_ingredients_from_text($product_ref);

is_deeply ($product_ref->{ingredients}, 

[
	     {
	            'id' => 'en:tomato',
	            'processing' => 'en:cooked, en:peeled',
	            'rank' => 1,
	            'text' => 'tomates  ',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:lemon',
	            'processing' => 'en:sliced',
	            'rank' => 2,
	            'text' => ' citron',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          },
	          {
	            'id' => 'en:courgette',
	            'processing' => 'en:diced',
	            'rank' => 3,
	            'text' => ' courgette',
	            'vegan' => 'yes',
	            'vegetarian' => 'yes'
	          }
	
        ],	
	
) or diag explain $product_ref;



done_testing();
