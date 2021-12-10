#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::FoodGroups qw/:all/;
use ProductOpener::Tags qw/:all/;

my @tests = (

  # Product without a category: no food groups
  [
        {
        },
        [
        ]
  ],
  # Products with categories
  [
        {
          "categories" => "milk chocolate",
        },
        [
          'en:sugary-snacks',
          'en:chocolate-products'
        ]
  ],
  [
        {
          "categories" => "mackerels",
        },
        [
          'en:fish-meat-eggs',
          'en:fish-and-seafood',
          'en:fatty-fish'

        ]
  ],  
  [
        {
          "categories" => "chicken thighs",
        },
        [
           'en:fish-meat-eggs',
           'en:meat',
           'en:poultry'
        ]
  ],
  # Check that if a meat is not poultry, we get a level 3 en:meat-other-than-poultry entry
  [
        {
          "categories" => "lamb leg",
        },
        [
          'en:fish-meat-eggs',
          'en:meat',
          'en:meat-other-than-poultry'
        ]
  ],  
);

foreach my $test_ref (@tests) {

    my $product_ref = $test_ref->[0];

    compute_field_tags($product_ref, "en", "categories");
    compute_food_groups($product_ref);

    is_deeply($product_ref->{food_groups_tags}, $test_ref->[1]) or diag explain $product_ref;

}

done_testing();
