#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

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
                                           'fr:farine',
                                           'en:chocolate',
                                           'en:sugar',
                                           'fr:protéines de lait',
                                           'en:egg',
                                           'fr:émulsifiants',
                                           'fr:E463',
                                           'fr:E432 et E472',
                                           'fr:correcteurs d\'acidité',
                                           'fr:e475',
                                           'en:acidifier',
                                           'en:salt',
                                           'en:cocoa-butter',
                                           'fr:e322',
                                           'fr:E333 E474',
                                           'en:citric-acid',
                                           'fr:acide-phosphorique'
                                         ],
          'ingredients_hierarchy' => [
                                       'fr:farine',
                                       'en:chocolate',
                                       'en:sugar',
                                       "fr:prot\x{c3}\x{a9}ines de lait",
                                       'en:egg',
                                       "fr:\x{c3}\x{a9}mulsifiants",
                                       'fr:E463',
                                       'fr:E432 et E472',
                                       "fr:correcteurs d'acidit\x{c3}\x{a9}",
                                       'fr:e475',
                                       'en:acidifier',
                                       'en:salt',
                                       'en:cocoa-butter',
                                       'en:cocoa',
                                       'fr:e322',
                                       'fr:E333 E474',
                                       'en:citric-acid',
                                       'fr:acide-phosphorique'
                                     ],
          'ingredients_tags' => [
                                  'fr:farine',
                                  'en:chocolate',
                                  'en:sugar',
                                  'fr:prota-ines-de-lait',
                                  'en:egg',
                                  'fr:a-mulsifiants',
                                  'fr:e463',
                                  'fr:e432-et-e472',
                                  'fr:correcteurs-d-acidita',
                                  'fr:e475',
                                  'en:acidifier',
                                  'en:salt',
                                  'en:cocoa-butter',
                                  'en:cocoa',
                                  'fr:e322',
                                  'fr:e333-e474',
                                  'en:citric-acid',
                                  'fr:acide-phosphorique'
                                ],
          'ingredients_text' => 'farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d\'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel',
          'lc' => 'fr',
          'ingredients' => [
                             {
                               'percent' => '12',
                               'text' => 'farine',
                               'id' => 'fr:farine',
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
                               'id' => 'en:acidifier',
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
                               'id' => 'fr:acide-phosphorique'
                             }
                           ],
          'unknown_ingredients_n' => 6,
          'ingredients_n' => 17

        };



is_deeply($product_ref, $expected_product_ref);

done_testing();
