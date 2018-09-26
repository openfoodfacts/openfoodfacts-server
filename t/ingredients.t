#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

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
                                           'fr:protéines de lait',
                                           'en:egg',
                                           'fr:émulsifiants',
                                           'fr:E463',
                                           'fr:E432 et E472',
                                           'fr:correcteurs d\'acidité',
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
                                       "fr:prot\x{c3}\x{a9}ines de lait",
                                       'en:egg',
                                       "fr:\x{c3}\x{a9}mulsifiants",
                                       'fr:E463',
                                       'fr:E432 et E472',
                                       "fr:correcteurs d'acidit\x{c3}\x{a9}",
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
                                  'fr:prota-ines-de-lait',
                                  'en:egg',
                                  'fr:a-mulsifiants',
                                  'fr:e463',
                                  'fr:e432-et-e472',
                                  'fr:correcteurs-d-acidita',
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
          'ingredients_text' => 'farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d\'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel',
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
                               'text' => 'protéines de lait',
                               'id' => 'fr:protéines de lait',
                               'rank' => 4
                             },
                             {
                               'text' => 'oeuf',
                               'id' => 'en:egg',
                               'rank' => 5
                             },
                             {
                               'text' => 'émulsifiants',
                               'id' => 'fr:émulsifiants',
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
                               'text' => 'correcteurs d\'acidité',
                               'id' => 'fr:correcteurs d\'acidité',
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
          'unknown_ingredients_n' => 6,
          'ingredients_n' => 17

        };


is_deeply($product_ref, $expected_product_ref);




my $product_ref = {
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



done_testing();
