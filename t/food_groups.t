#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::FoodGroups qw/:all/;
use ProductOpener::Tags qw/:all/;

my @tests = (

  [
        {
          "categories" => "milk chocolate",
        },
        [
            
        ]
  ]

);

foreach my $test_ref (@tests) {

    my $product_ref = $test_ref->[0];

    compute_field_tags($product_ref, "en", "categories");
    compute_food_groups($product_ref);

    is_deeply($product_ref->{food_groups_tags}, $test_ref->[1]) or diag explain $product_ref;

}

done_testing();
