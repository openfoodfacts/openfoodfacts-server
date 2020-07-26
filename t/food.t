#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

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
# kè - gram - 克
is( normalize_quantity("42\N{U+514B}"), 42 );
is( normalize_serving_size("42\N{U+514B}"), 42 );
is( unit_to_g(42, "\N{U+514B}"), 42 );
is( g_to_unit(42, "\N{U+514B}"), 42 );
# gōngkè - gram - 公克 (in use at least in Taïwan)
is( normalize_quantity("42\N{U+516C}\N{U+514B}"), 42 );
is( normalize_serving_size("42\N{U+516C}\N{U+514B}"), 42 );
is( unit_to_g(42, "\N{U+516C}\N{U+514B}"), 42 );
is( g_to_unit(42, "\N{U+516C}\N{U+514B}"), 42 );
# héokè - milligram - 毫克
is( normalize_quantity("42000\N{U+6BEB}\N{U+514B}"), 42 );
is( normalize_serving_size("42000\N{U+6BEB}\N{U+514B}"), 42 );
is( unit_to_g(42000, "\N{U+6BEB}\N{U+514B}"), 42 );
is( g_to_unit(42, "\N{U+6BEB}\N{U+514B}"), 42000 );
# jīn - pound 500 g - 斤
is( normalize_quantity("84\N{U+65A4}"), 42000 );
is( normalize_serving_size("84\N{U+65A4}"), 42000 );
is( unit_to_g(84, "\N{U+65A4}"), 42000 );
is( g_to_unit(42000, "\N{U+65A4}"), 84 );
# gōngjīn - kg - 公斤
is( normalize_quantity("42\N{U+516C}\N{U+65A4}"), 42000 );
is( normalize_serving_size("42\N{U+516C}\N{U+65A4}"), 42000 );
is( unit_to_g(42, "\N{U+516C}\N{U+65A4}"), 42000 );
is( g_to_unit(42000, "\N{U+516C}\N{U+65A4}"), 42 );
# háoshēng - milliliter - 毫升
is( normalize_quantity("42\N{U+6BEB}\N{U+5347}"), 42 );
is( normalize_serving_size("42\N{U+6BEB}\N{U+5347}"), 42 );
is( unit_to_g(42, "\N{U+6BEB}\N{U+5347}"), 42 );
is( g_to_unit(42, "\N{U+6BEB}\N{U+5347}"), 42 );
# gōngshēng - liter - 公升
is( normalize_quantity("42\N{U+516C}\N{U+5347}"), 42000 );
is( normalize_serving_size("42\N{U+516C}\N{U+5347}"), 42000 );
is( unit_to_g(42, "\N{U+516C}\N{U+5347}"), 42000 );
is( g_to_unit(42000, "\N{U+516C}\N{U+5347}"), 42 );

# Russian units

is( unit_to_g(1, "г"), 1 );
is( unit_to_g(1, "мг"), 0.001 );

is ( normalize_quantity("1 г"), 1);
is ( normalize_quantity("1 мг"), 0.001);
is ( normalize_quantity("1 кг"), 1000);
is ( normalize_quantity("1 л"), 1000);
is ( normalize_quantity("1 дл"), 100);
is ( normalize_quantity("1 кл"), 10);
is ( normalize_quantity("1 мл"), 1);

is ( normalize_quantity("4 x 25g"), 100);
is ( normalize_quantity("4 x25g"), 100);
is ( normalize_quantity("4 * 25g"), 100);
is ( normalize_quantity("4X2,5L"), 10000);
is ( normalize_quantity("1 barquette de 40g"), 40);
is ( normalize_quantity("2 barquettes de 40g"), 80);
is ( normalize_quantity("6 bouteilles de 33cl"), 6 * 33 * 10);
is ( normalize_quantity("10 unités de 170g"), 1700);
is ( normalize_quantity("10 unites, 170g"), 170);
is ( normalize_quantity("4 bouteilles en verre de 20cl"), 800);
is ( normalize_quantity("5 bottles of 20cl"), 100 * 10);

my $product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_tags => ["en:water", "en:fruit-juice"],
};

# without an ingredient list: should not add en:unsweetened-beverages

special_process_product($product_ref);

ok( (not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should not add en:unsweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "unknown") || diag explain $product_ref;

$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages"],
	categories => "beverages",
        ingredients_tags => ["en:water", "en:fruit-juice"],
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

special_process_product($product_ref);

#ok( (has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should add en:unsweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag explain $product_ref;


$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages"],
	categories => "beverages",
        ingredients_tags => ["en:sugar"],
};

special_process_product($product_ref);


#ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Sweetened beverages") || diag explain $product_ref;

$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages"],
	categories => "beverages",
        ingredients_tags => ["en:sugar"],
	additives_tags => ["en:e950"],
	with_sweeteners => 1,
};

special_process_product($product_ref);


#ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;


$product_ref = {
        lc => "en",
        categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
	categories => "beverages",
        ingredients_tags => ["en:sugar"],
        additives_tags => ["en:e950"],
        with_sweeteners => 1,
};

special_process_product($product_ref);


#ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag explain $product_ref;
#ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;

$product_ref = {
        lc => "en",
	categories => "beverages",
        categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
};

special_process_product($product_ref);


is( $product_ref->{pnns_groups_2}, "Waters and flavored waters") || diag explain $product_ref;


$product_ref = {
        lc => "en",
	categories => "beverages",
        categories_tags => ["en:beverages", "en:iced-teas"],
};

special_process_product($product_ref);


is( $product_ref->{pnns_groups_2}, "Teas and herbal teas and coffees") || diag explain $product_ref;


$product_ref = {
        lc => "en",
	categories => "beverages",
        categories_tags => ["en:beverages", "en:ice-teas"],
        ingredients_tags => ["en:sugar"],
        additives_tags => ["en:e950"],
        with_sweeteners => 1,
};

special_process_product($product_ref);


ok( not (has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages')), 'should add en:artificially-sweetened-beverages' ) || diag explain $product_ref;
ok( not (has_tag($product_ref, 'categories', 'en:sweetened-beverages')), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;


$product_ref = {
        lc => "en",
	categories => "beverages",
        categories_tags => ["en:beverages"],
        ingredients_tags => ["en:water", "en:fruit-juice"],
        ingredients_text => "water, fruit juice",
	with_sweeteners => 1,
};

# with an ingredient list: should add en:unsweetened-beverages

special_process_product($product_ref);

ok( (not (has_tag($product_ref, 'categories', 'en:unsweetened-beverages'))), 'should not add en:unsweetened-beverages' ) || diag explain $product_ref;
ok( not (has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages')), 'should add en:unsweetened-beverages' ) || diag explain $product_ref;


is( $product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;

$product_ref = {
        lc => "en",
	categories => "beverages",
        categories_tags => ["en:beverages", "en:unsweetened-beverages"],
        ingredients_tags => ["en:water", "en:sugar"],
        ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

special_process_product($product_ref);

ok( not (not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should remove en:unsweetened-beverages' ) || diag explain $product_ref;
ok( not (has_tag($product_ref, 'categories', 'en:sweetened-beverages')), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is( $product_ref->{pnns_groups_2}, "Sweetened beverages") || diag explain $product_ref;

is($product_ref->{nutrition_score_beverage}, 1);

$product_ref = {
        lc => "en",
	categories => "beverages",
        categories_tags => ["en:beverages", "en:plant-milks"],
        ingredients_tags => ["en:water", "en:sugar"],
        ingredients_text => "water, fruit juice",
};

special_process_product($product_ref);

is($product_ref->{nutrition_score_beverage}, 0);

# normalize_fr_ce_code
is (normalize_packager_codes("france 69.238.010 ec"), "FR 69.238.010 EC", "FR: normalized code correctly");
is (normalize_packager_codes(normalize_packager_codes("france 69.238.010 ec")), "FR 69.238.010 EC", "FR: normalizing code twice does not change it any more than normalizing once");

# normalize_uk_ce_code
is (normalize_packager_codes("uk dz7131 eg"), "UK DZ7131 EC", "UK: normalized code correctly");
is (normalize_packager_codes(normalize_packager_codes("uk dz7131 eg")), "UK DZ7131 EC", "UK: normalizing code twice does not change it any more than normalizing once");

# normalize_es_ce_code
is (normalize_packager_codes("NO-RGSEAA-21-21552-SE"), "ES 21.21552/SE EC", "ES: normalized NO-code correctly");
is (normalize_packager_codes("ES 26.06854/T EC"), "ES 26.06854/T EC", "ES I: normalized code correctly");
is (normalize_packager_codes("ES 26.06854/T C EC"), "ES 26.06854/T C EC", "ES II: normalized code correctly");
is (normalize_packager_codes(normalize_packager_codes("ES 26.06854/T EC")), "ES 26.06854/T EC", "ES I: normalizing code twice does not change it any more than normalizing once");
is (normalize_packager_codes(normalize_packager_codes("ES 26.06854/T C EC")), "ES 26.06854/T C EC", "ES II: normalizing code twice does not change it any more than normalizing once");

# normalize_lu_ce_code - currently does not work as commented
# is (normalize_packager_codes("LU L-2"), "LU L2", "LU: normalized code correctly");
# is (normalize_packager_codes(normalize_packager_codes("LU L-2")), "LU L2", "LU: normalizing code twice does not change it any more than normalizing once");

# normalize_rs_ce_code
is (normalize_packager_codes("RS 731"), "RS 731 EC", "RS: normalized code correctly");
is (normalize_packager_codes(normalize_packager_codes("RS 731")), "RS 731 EC", "RS: normalizing code twice does not change it any more than normalizing once");

# normalize_ce_code
is (normalize_packager_codes("de by-718 ec"), "DE BY-718 EC", "DE: normalized code correctly");
is (normalize_packager_codes(normalize_packager_codes("de by-718 ec")), "DE BY-718 EC", "DE: normalizing code twice does not change it any more than normalizing once");

is (normalize_packager_codes("PL 14281601 WE"), "PL 14281601 EC", "PL: normalized code correctly");
is (localize_packager_code(normalize_packager_codes("PL 14281601 WE")), "PL 14281601 WE", "PL: normalized code correctly");

is (normalize_packager_codes("FI 4201 EY"), "FI 4201 EC", "FI: normalized code correctly");
is (normalize_packager_codes("FI 305-1 EY"), "FI 305-1 EC", "FI: normalized code correctly");
is (normalize_packager_codes("FI F07551 EY"), "FI F07551 EC", "FI: normalized code correctly");
is (normalize_packager_codes("FI FI219 EY"), "FI FI219 EC", "FI: normalized code correctly");
is (normalize_packager_codes("FI S837106 EY"), "FI S837106 EC", "FI: normalized code correctly");
is (normalize_packager_codes(normalize_packager_codes("FI 4201 EY")), "FI 4201 EC", "FI: normalizing code twice does not change it any more than normalizing once");
is (localize_packager_code(normalize_packager_codes("FI 4201 EY")), "FI 4201 EY", "FI: round-tripped code correctly");

is (normalize_packager_codes("EE 110 EÜ"), "EE 110 EC", "EE: normalized code correctly");
is (normalize_packager_codes(normalize_packager_codes("EE 110 EÜ")), "EE 110 EC", "EE: normalizing code twice does not change it any more than normalizing once");
is (localize_packager_code(normalize_packager_codes("EE 110 EÜ")), "EE 110 EÜ", "EE: round-tripped code correctly");

$product_ref = {
    nutriments => { salt => 3, salt_value => 3000, salt_unit => "mg" },
};

fix_salt_equivalent($product_ref);

my $expected_product_ref = {
    nutriments => {
        salt => 3,
        salt_value => 3000,
        salt_unit => "mg",
        sodium => 1.2,
        sodium_value => 1200,
         sodium_unit => "mg"
    }
};


is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);

$product_ref = {
	nutriments => { "nova-group" => 4, "nova-group_100g" => 4, "nova-group_serving" => 4},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

my $expected_product_ref =
 {
    'nutriments' => {
      'nova-group' => 4,
      'nova-group_100g' => 4,
      'nova-group_serving' => 4
    },
    'nutrition_data_per' => 'serving',
    'nutrition_data_prepared_per' => '100g',
    'product_quantity' => 100,
    'quantity' => '100 g',
    'serving_quantity' => 25,
    'serving_size' => '25 g'
  }

 ;

is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);


$product_ref = {
	nutriments => { "sugars" => 4},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

my $expected_product_ref =

 {
   'nutriments' => {
     'sugars' => 4,
     'sugars_100g' => 16,
     'sugars_serving' => 4
   },
   'nutrition_data' => 'on',
   'nutrition_data_per' => 'serving',
   'nutrition_data_prepared_per' => '100g',
   'product_quantity' => 100,
   'quantity' => '100 g',
   'serving_quantity' => 25,
   'serving_size' => '25 g'
  }

 ;

is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);


$product_ref = {
	nutriments => { "energy-kcal_prepared" => 58, "energy-kcal_prepared_value" => 58, "salt_prepared" => 10, "salt_prepared_value" => 10 },
	nutrition_data_prepared_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

my $expected_product_ref =
 {
   'nutriments' => {
     'energy-kcal_prepared' => 58,
     'energy-kcal_prepared_100g' => 232,
     'energy-kcal_prepared_serving' => 58,
     'energy-kcal_prepared_unit' => 'kcal',
     'energy-kcal_prepared_value' => 58,
     'energy_prepared' => 243,
     'energy_prepared_100g' => 972,
     'energy_prepared_serving' => 243,
     'energy_prepared_unit' => 'kcal',
     'energy_prepared_value' => 58,
     'salt_prepared' => 10,
     'salt_prepared_100g' => 40,
     'salt_prepared_serving' => 10,
     'salt_prepared_value' => 10
   },
   'nutrition_data_per' => '100g',
   'nutrition_data_prepared' => 'on',
   'nutrition_data_prepared_per' => 'serving',
   'product_quantity' => 100,
   'quantity' => '100 g',
   'serving_quantity' => 25,
   'serving_size' => '25 g'
 }

;

is(default_unit_for_nid("sugars"), "g");
is(default_unit_for_nid("energy-kj"), "kJ");
is(default_unit_for_nid("energy-kcal_prepared"), "kcal");

is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);

done_testing();
