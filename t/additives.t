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

is($product_ref->{additives}, ' [ acide-citrique -> en:e330  -> exists  -- ok  ]  [ colorant -> fr:colorant  ]  [ e120 -> en:e120  -> exists  -- ok  ]  [ vitamine-c -> en:e300  -> exists  -- ok  ]  [ vitamine-e -> en:e306  -> exists  -- ok  ]  [ vitamine-500 -> fr:vitamine-500  ]  [ vitamine -> fr:vitamine  ] ');

is_deeply($product_ref->{additives_tags}, [
                                'en:e330',
                                'en:e120',
                                'en:e300',
                                'en:e306'
                              ],
);

# E316 detection - https://github.com/openfoodfacts/openfoodfacts-server/issues/269

$product_ref = {
        lc => "fr",
        ingredients_text => "Poitrine de porc, sel, conservateurs : lactate de potassium, nitrite de sodium, arôme naturel, sirop de glucose, antioxydant : érythorbate de sodium"
};

extract_ingredients_classes_from_text($product_ref);

is_deeply($product_ref->{additives_tags}, [
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
#print STDERR Dumper($product_ref->{additives_tags});

is_deeply($product_ref->{additives_tags}, [
                                'en:e503',
                                'en:e500',
                                'en:e330',
                                'en:e392',
                              ],
);


$product_ref = {
        lc => "fr",
        ingredients_text => "carbonates de sodium et d'ammonium, nitrate de sodium et de potassium.",
};

extract_ingredients_classes_from_text($product_ref);

#use Data::Dumper;
#print STDERR Dumper($product_ref->{additives_tags});

is_deeply($product_ref->{additives_tags}, [
                                'en:e500',
                                'en:e503',
                                'en:e251',
                                'en:e252',
                              ],
);


done_testing();
