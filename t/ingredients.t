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
	'lc' => 'fr',
          'ingredients_n_tags' => [
                                    '17',
                                    '11-20'
                                  ],
'ingredients_tags' => [
                                  'fr:farine',
                                  'fr:chocolat',
                                  'en:sugar',
                                  'fr:prota-ines-de-lait',
                                  'fr:oeuf',
                                  'fr:a-mulsifiants',
                                  'fr:e463',
                                  'fr:e432-et-e472',
                                  'fr:correcteurs-d-acidita',
                                  'fr:e475',
                                  'fr:acidifiant',
                                  'en:salt',
                                  'fr:beurre-de-cacao',
                                  'fr:e322',
                                  'fr:e333-e474',
                                  'fr:acide-citrique',
                                  'fr:acide-phosphorique'
                                ],

'ingredients_hierarchy' => [
                                       'fr:farine',
                                       'fr:chocolat',
                                       'en:sugar',
                                       'fr:prota-ines-de-lait',
                                       'fr:oeuf',
                                       'fr:a-mulsifiants',
                                       'fr:e463',
                                       'fr:e432-et-e472',
                                       'fr:correcteurs-d-acidita',
                                       'fr:e475',
                                       'fr:acidifiant',
                                       'en:salt',
                                       'fr:beurre-de-cacao',
                                       'fr:e322',
                                       'fr:e333-e474',
                                       'fr:acide-citrique',
                                       'fr:acide-phosphorique'
                                     ],

          'ingredients' => [
                             {
                               'percent' => '12',
                               'text' => 'farine',
                               'id' => 'farine',
                               'rank' => 1
                             },
                             {
                               'text' => 'chocolat',
                               'id' => 'chocolat',
                               'rank' => 2
                             },
                             {
                               'percent' => '10',
                               'text' => 'sucre',
                               'id' => 'sucre',
                               'rank' => 3
                             },
                             {
                               'text' => 'protéines de lait',
                               'id' => 'prota-ines-de-lait',
                               'rank' => 4
                             },
                             {
                               'text' => 'oeuf',
                               'id' => 'oeuf',
                               'rank' => 5
                             },
                             {
                               'text' => 'émulsifiants',
                               'id' => 'a-mulsifiants',
                               'rank' => 6
                             },
                             {
                               'text' => 'E463',
                               'id' => 'e463',
                               'rank' => 7
                             },
                             {
                               'text' => 'E432 et E472',
                               'id' => 'e432-et-e472',
                               'rank' => 8
                             },
                             {
                               'text' => 'correcteurs d\'acidité',
                               'id' => 'correcteurs-d-acidita',
                               'rank' => 9
                             },
                             {
                               'text' => 'E475',
                               'id' => 'e475',
                               'rank' => 10
                             },
                             {
                               'text' => 'acidifiant',
                               'id' => 'acidifiant',
                               'rank' => 11
                             },
                             {
                               'text' => 'sel',
                               'id' => 'sel',
                               'rank' => 12
                             },
                             {
                               'percent' => '15',
                               'text' => 'beurre de cacao',
                               'id' => 'beurre-de-cacao'
                             },
                             {
                               'text' => 'E322',
                               'id' => 'e322'
                             },
                             {
                               'text' => 'E333 E474',
                               'id' => 'e333-e474'
                             },
                             {
                               'text' => 'acide citrique',
                               'id' => 'acide-citrique'
                             },
                             {
                               'text' => 'acide phosphorique',
                               'id' => 'acide-phosphorique'
                             }
                           ],
          'ingredients_n' => 17,
	  'unknown_ingredients_n' => 6,
          'ingredients_text' => 'farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d\'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel'
        };



is_deeply($product_ref, $expected_product_ref);

done_testing();
