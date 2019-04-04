#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Import qw/:all/;

# dummy product for testing

my $product_ref = {
	lc => "es",
	total_weight => "Peso neto: 480 g (6 x 80 g) Peso neto escurrido: 336 g (6x56 g)",
};

clean_weights($product_ref);

diag explain $product_ref;

is($product_ref->{net_weight}, "480 g");

assign_value($product_ref, "energy_value", "2428.000");

is($product_ref->{energy_value}, "2428");

assign_value($product_ref, "fat_value", "2428.0300");

is($product_ref->{fat_value}, "2428.03");

assign_value($product_ref, "sugars_value", "10.6000");

is($product_ref->{sugars_value}, "10.6");

$product_ref->{some_field} = "Fabriqué en France par EMB59481 pour Auchan Production";

match_taxonomy_tags($product_ref, "some_field", "emb_codes",
{ split => ',|( \/ )|\r|\n|\+|:|;|=|\(|\)|\b(et|par|pour|ou)\b', });

is($product_ref->{emb_codes}, "EMB59481");

done_testing();
