#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

# Based on https://de.wikipedia.org/w/index.php?title=Wasserh%C3%A4rte&oldid=160348959#Einheiten_und_Umrechnung
is( mmoll_to_unit(1, 'mol/l'), 0.001 );
is( mmoll_to_unit('1', 'moll/l'), 1 );
is( mmoll_to_unit(1, 'mmol/l'), 1 );
is( mmoll_to_unit(1, 'mval/l'), 2 );
is( mmoll_to_unit(1, 'ppm'), 100 );
is( mmoll_to_unit(1, "\N{U+00B0}rH"), 40.080 );
is( mmoll_to_unit(1, "\N{U+00B0}fH"), 10.00 );
is( mmoll_to_unit(1, "\N{U+00B0}e"), 7.02 );
is( mmoll_to_unit(1, "\N{U+00B0}dH"), 5.6 );
is( mmoll_to_unit(1, 'gpg'), 5.847 );

is( unit_to_mmoll(1, 'mol/l'), 1000 );
is( unit_to_mmoll('1', 'mmol/l'), 1 );
is( unit_to_mmoll(1, 'mmol/l'), 1 );
is( unit_to_mmoll(1, 'mval/l'), 0.5 );
is( unit_to_mmoll(1, 'ppm'), 0.01 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}rH"), 0.025 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}fH"), 0.1 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}e"), 0.142 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}dH"), 0.1783 );
delta_ok( unit_to_mmoll(1, 'gpg'), 0.171 );

is( mmoll_to_unit(unit_to_mmoll(1, 'ppm'), "\N{U+00B0}dH"), 0.056 );

# Chinese Measurements Source: http://www.new-chinese.org/lernwortschatz-chinesisch-masseinheiten.html
# kè - gram
is( normalize_quantity("42\N{U+514B}"), 42 );
is( normalize_serving_size("42\N{U+514B}"), 42 );
is( unit_to_g(42, "\N{U+514B}"), 42 );
is( g_to_unit(42, "\N{U+514B}"), 42 );
# héokè - milligram
is( normalize_quantity("42000\N{U+6BEB}\N{U+514B}"), 42 );
is( normalize_serving_size("42000\N{U+6BEB}\N{U+514B}"), 42 );
is( unit_to_g(42000, "\N{U+6BEB}\N{U+514B}"), 42 );
is( g_to_unit(42, "\N{U+6BEB}\N{U+514B}"), 42000 );
# jīn - pound 500 g
is( normalize_quantity("84\N{U+65A4}"), 42000 );
is( normalize_serving_size("84\N{U+65A4}"), 42000 );
is( unit_to_g(84, "\N{U+65A4}"), 42000 );
is( g_to_unit(42000, "\N{U+65A4}"), 84 );
# gōngjīn - kg
is( normalize_quantity("42\N{U+516C}\N{U+65A4}"), 42000 );
is( normalize_serving_size("42\N{U+516C}\N{U+65A4}"), 42000 );
is( unit_to_g(42, "\N{U+516C}\N{U+65A4}"), 42000 );
is( g_to_unit(42000, "\N{U+516C}\N{U+65A4}"), 42 );
# háoshēng - milliliter
is( normalize_quantity("42\N{U+6BEB}\N{U+5347}"), 42 );
is( normalize_serving_size("42\N{U+6BEB}\N{U+5347}"), 42 );
is( unit_to_g(42, "\N{U+6BEB}\N{U+5347}"), 42 );
is( g_to_unit(42, "\N{U+6BEB}\N{U+5347}"), 42 );
# gōngshēng - liter
is( normalize_quantity("42\N{U+516C}\N{U+5347}"), 42000 );
is( normalize_serving_size("42\N{U+516C}\N{U+5347}"), 42000 );
is( unit_to_g(42, "\N{U+516C}\N{U+5347}"), 42000 );
is( g_to_unit(42000, "\N{U+516C}\N{U+5347}"), 42 );

my $product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	ingredients_tags => ["en:water", "en:fruit-juice"],
};

# without an ingredient list: should not add en:unsweetened-beverages

special_process_product($product_ref);

ok( (not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should not add en:unsweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, undef) || diag explain $product_ref;

$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages"],
        ingredients_tags => ["en:water", "en:fruit-juice"],
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

special_process_product($product_ref);

ok( (has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should add en:unsweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag explain $product_ref;


$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages"],
        ingredients_tags => ["en:sugar"],
};

special_process_product($product_ref);


ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Sweetened beverages") || diag explain $product_ref;

$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages"],
        ingredients_tags => ["en:sugar"],
	additives_tags => ["en:e950"],
	with_sweeteners => 1,
};

special_process_product($product_ref);


ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;


$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
        ingredients_tags => ["en:sugar"],
        additives_tags => ["en:e950"],
        with_sweeteners => 1,
};

special_process_product($product_ref);


ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag explain $product_ref;
ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;

$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
};

special_process_product($product_ref);


is( $product_ref->{pnns_groups_2}, "Waters and flavored waters") || diag explain $product_ref;


$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages", "en:iced-teas"],
};

special_process_product($product_ref);


is( $product_ref->{pnns_groups_2}, "Teas and herbal teas and coffees") || diag explain $product_ref;


$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages", "en:ice-teas"],
        ingredients_tags => ["en:sugar"],
        additives_tags => ["en:e950"],
        with_sweeteners => 1,
};

special_process_product($product_ref);


ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag explain $product_ref;
ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;


$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages"],
        ingredients_tags => ["en:water", "en:fruit-juice"],
        ingredients_text => "water, fruit juice",
	with_sweeteners => 1,
};

# with an ingredient list: should add en:unsweetened-beverages

special_process_product($product_ref);

ok( (not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should not add en:unsweetened-beverages' ) || diag explain $product_ref;
ok( (has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages')), 'should add en:unsweetened-beverages' ) || diag explain $product_ref;



$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages", "en:unsweetened-beverages"],
        ingredients_tags => ["en:water", "en:sugar"],
        ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

special_process_product($product_ref);

ok( (not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should remove en:unsweetened-beverages' ) || diag explain $product_ref;
ok( (has_tag($product_ref, 'categories', 'en:sweetened-beverages')), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is($product_ref->{nutrition_score_beverage}, 1);

$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages", "en:plant-milks"],
        ingredients_tags => ["en:water", "en:sugar"],
        ingredients_text => "water, fruit juice",
};

special_process_product($product_ref);

is($product_ref->{nutrition_score_beverage}, 0);

done_testing();
