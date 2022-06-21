#!/usr/bin/perl -w

use Modern::Perl '2017';
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

# unit conversion tests
# TODO
# if (!defined(unit_to_g(1, "unknown")))
# {
# 	return 1;
# }
is( unit_to_g(1, "kj"), 1 );
is( unit_to_g(1, "kcal"), 4 );
is( unit_to_g(1000, "kcal"), 4184 );
is( unit_to_g(1.2345, "kg"), 1234.5 );
is( unit_to_g(1, "kJ"), 1 );
is( unit_to_g(10, ""), 10 );
is( unit_to_g(10, " "), 10 );
is( unit_to_g(10, "% vol"), 10 );
is( unit_to_g(10, "%"), 10 );
is( unit_to_g(10, "% vol"), 10 );
is( unit_to_g(10, "% DV"), 10 );
is( unit_to_g(11, "mL"), 11 );
is( g_to_unit(42000, "kg"), 42 );
is( g_to_unit(28.349523125, "oz"), 1 );
is( g_to_unit(30, "fl oz"), 1 );
is( g_to_unit(1, "mcg"), 1000000 );

is ( normalize_quantity("1 г"), 1);
is ( normalize_quantity("1 мг"), 0.001);
is ( normalize_quantity("1 кг"), 1000);
is ( normalize_quantity("1 л"), 1000);
is ( normalize_quantity("1 дл"), 100);
is ( normalize_quantity("1 кл"), 10);
is ( normalize_quantity("1 мл"), 1);

is ( normalize_quantity("250G"), 250);
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


$product_ref = {
	nutriments => { salt => 3, salt_value => 3000, salt_unit => "mg" },
};

fix_salt_equivalent($product_ref);

my $expected_product_ref;

$expected_product_ref = {
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
	nutriments => { "nova-group" => 4, "nova-group_100g" => 4, "nova-group_serving" => 4, "alcohol" => 12, "ph" => 7},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

$expected_product_ref =
{
	'nutriments' => {
		'alcohol' => 12,
		'alcohol_100g' => 12,
		'alcohol_serving' => 12,
		'nova-group' => 4,
		'nova-group_100g' => 4,
		'nova-group_serving' => 4,
		'ph' => 7,
		'ph_100g' => 7,
		'ph_serving' => 7
	},
	'nutrition_data_per' => 'serving',
	'nutrition_data_prepared_per' => '100g',
	'product_quantity' => 100,
	'quantity' => '100 g',
	'serving_quantity' => 25,
	'serving_size' => '25 g'
};

is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);


$product_ref = {
	nutriments => { "sugars" => 4, "salt" => 1},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

$expected_product_ref =
{
	'nutriments' => {
		'sugars' => 4,
		'sugars_100g' => 16,
		'sugars_serving' => 4,
		'salt' => 1,
		'salt_100g' => 4,
		'salt_serving' => 1,
	},
	'nutrition_data' => 'on',
	'nutrition_data_per' => 'serving',
	'nutrition_data_prepared_per' => '100g',
	'product_quantity' => 100,
	'quantity' => '100 g',
	'serving_quantity' => 25,
	'serving_size' => '25 g'
};

is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);


$product_ref = {
	nutriments => { "energy-kcal_prepared" => 58, "energy-kcal_prepared_value" => 58, "salt_prepared" => 10, "salt_prepared_value" => 10 },
	nutrition_data_prepared_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

$expected_product_ref =
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
};

# Unknown nutrient

$product_ref = {
	nutriments => { "fr-unknown-nutrient" => 10 },
	nutrition_data_prepared_per => "100g",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

$expected_product_ref = {
	'nutriments' => {
		'fr-unknown-nutrient' => 10,
		'fr-unknown-nutrient_100g' => 10,
		'fr-unknown-nutrient_serving' => '2.5'
	},
	'nutrition_data' => 'on',
	'nutrition_data_per' => '100g',
	'nutrition_data_prepared_per' => '100g',
	'product_quantity' => 100,
	'quantity' => '100 g',
	'serving_quantity' => 25,
	'serving_size' => '25 g'
};


is(default_unit_for_nid("sugars"), "g");
is(default_unit_for_nid("energy-kj"), "kJ");
is(default_unit_for_nid("energy-kcal_prepared"), "kcal");

is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);

# Check that nutrients typed in by users in the nutrition table product edit form are recognized
is(canonicalize_nutriment("en", "saturated"), "saturated-fat");
is(canonicalize_nutriment("en", "of which saturated"), "saturated-fat");
is(canonicalize_nutriment("fr", "dont sucre"), "sugars");
is(canonicalize_nutriment("fr", "dont saturés"), "saturated-fat");
is(canonicalize_nutriment("fr", "ARA"), "arachidonic-acid");
is(canonicalize_nutriment("fr", "AGS"), "saturated-fat");
is(canonicalize_nutriment("en", "some unknown nutrient"), "en-some-unknown-nutrient");
is(canonicalize_nutriment("fr", "un nutriment inconnu"), "fr-un-nutriment-inconnu");

# Check that the nutrients defined in %nutriments_tables are defined in the nutrients taxonomy

foreach (@{$nutriments_tables{europe}}) {

	my $nid = $_;	# Copy instead of alias

	next if $nid =~ /^#/;

    $nid =~ s/^!//;
    $nid =~ s/^-+//;
    $nid =~ s/-+$//;

	# The nutrient ids do not correspond exactly to the English name, so we use zz:[nutrient id]
	# as the canonical tag id instead of en:[English nutrient name]
	my $tagid = "zz:$nid";
	my $error = 0;

	ok(exists_taxonomy_tag("nutrients", $tagid), "$tagid exists in the nutrients taxonomy");
}

# Test normalize_nutriment_value_and_modifier()
# and assign_nid_modifier_value_and_unit()

$product_ref = {};

my $value = "50.1";
my $modifier;
my $unit;
# test we have no modifier
normalize_nutriment_value_and_modifier(\$value, \$modifier);
is($value, "50.1");
is($modifier, undef);
# test compute_serving_size_data with various units
assign_nid_modifier_value_and_unit($product_ref, "salt", $modifier, $value, undef);
assign_nid_modifier_value_and_unit($product_ref, "sugars", $modifier, $value, "g");
assign_nid_modifier_value_and_unit($product_ref, "fat", $modifier, $value, "mg");

compute_serving_size_data($product_ref);

is_deeply($product_ref,
 {
   'nutriments' => {
     'fat' => '0.0501',
     'fat_100g' => '0.0501',
     'fat_unit' => 'mg',
     'fat_value' => '50.1',
     'salt' => '50.1',
     'salt_100g' => '50.1',
     'salt_unit' => 'g',
     'salt_value' => '50.1',
     'sugars' => '50.1',
     'sugars_100g' => '50.1',
     'sugars_unit' => 'g',
     'sugars_value' => '50.1'
   },
   'nutrition_data_per' => '100g',
   'nutrition_data_prepared_per' => '100g'
 }
) or diag explain $product_ref;

# test various  modifiers : - (not communicated), >=, etc.

$value = '-';
normalize_nutriment_value_and_modifier(\$value, \$modifier);
is($value, undef);
is($modifier, '-');
assign_nid_modifier_value_and_unit($product_ref, "salt", $modifier, $value, "g");

$value = '<= 1';
normalize_nutriment_value_and_modifier(\$value, \$modifier);
is($value, "1");
is($modifier, "≤");
assign_nid_modifier_value_and_unit($product_ref, "sugars", $modifier, $value, "g");

# Delete a value, check all derived fields are deleted as well
$value = '';
normalize_nutriment_value_and_modifier(\$value, \$modifier);
is($value, undef);
is($modifier, undef);
assign_nid_modifier_value_and_unit($product_ref, "fat", $modifier, $value, "g");

# test modifiers are taken into account
compute_serving_size_data($product_ref);

is_deeply($product_ref,
 {
   'nutriments' => {
     'fat_unit' => 'mg',
     'salt_modifier' => '-',
     'salt_unit' => 'g',
     'sugars' => 1,
     'sugars_100g' => 1,
     'sugars_modifier' => "\x{2264}",
     'sugars_unit' => 'g',
     'sugars_value' => 1
   },
   'nutrition_data_per' => '100g',
   'nutrition_data_prepared_per' => '100g'
 }
) or diag explain $product_ref;

# test reporting traces
$value = 'Traces';
normalize_nutriment_value_and_modifier(\$value, \$modifier);
is($value, 0);
is($modifier, '~');
assign_nid_modifier_value_and_unit($product_ref, "fat", $modifier, $value, "g");

# Prepared value

$value = '~ 20,5 ';
normalize_nutriment_value_and_modifier(\$value, \$modifier);
is($value, '20,5');
is($modifier, '~');
assign_nid_modifier_value_and_unit($product_ref, "salt_prepared", $modifier, $value, "g");

# test support of traces, as well as "nearly" and prepared values
compute_serving_size_data($product_ref);

is_deeply($product_ref,
 {
   'nutriments' => {
     'fat' => 0,
     'fat_100g' => 0,
     'fat_modifier' => '~',
     'fat_unit' => 'g',
     'fat_value' => 0,
     'salt_modifier' => '-',
     'salt_prepared' => '20.5',
     'salt_prepared_100g' => '20.5',
     'salt_prepared_modifier' => '~',
     'salt_prepared_unit' => 'g',
     'salt_prepared_value' => '20.5',
     'salt_unit' => 'g',
     'sugars' => 1,
     'sugars_100g' => 1,
     'sugars_modifier' => "\x{2264}",
     'sugars_unit' => 'g',
     'sugars_value' => 1
   },
   'nutrition_data_per' => '100g',
   'nutrition_data_prepared_per' => '100g'
 }
) or diag explain $product_ref;

# Test IU and %DV values
$product_ref = { 'nutrition_data_per' => '100g' };
assign_nid_modifier_value_and_unit($product_ref, "vitamin-a", undef, 40, "IU");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-e", undef, 40, "IU");
assign_nid_modifier_value_and_unit($product_ref, "calcium", undef, 20, "% DV");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-d", undef, 20, "% DV");

is_deeply($product_ref,
 {
	nutriments => {
		'calcium' => '0.2',
		'calcium_unit' => '% DV',
		'calcium_value' => 20,
		'vitamin-a' => '1.2e-05',
		'vitamin-a_unit' => 'IU',
		'vitamin-a_value' => 40,
		'vitamin-d' => '8e-06',
		'vitamin-d_unit' => '% DV',
		'vitamin-d_value' => 20,
		'vitamin-e' => '0.0266666666666667',
		'vitamin-e_unit' => 'IU',
		'vitamin-e_value' => 40
	 },
   'nutrition_data_per' => '100g',
 }
) or diag explain $product_ref;

done_testing();
