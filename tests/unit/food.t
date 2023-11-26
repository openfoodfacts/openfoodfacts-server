#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

my $product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_tags => ["en:water", "en:fruit-juice"],
};

# without an ingredient list: should not add en:unsweetened-beverages

special_process_product($product_ref);

ok((not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should not add en:unsweetened-beverages')
	|| diag explain $product_ref;

is($product_ref->{pnns_groups_2}, "unknown") || diag explain $product_ref;

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

is($product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag explain $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_tags => ["en:sugar"],
};

special_process_product($product_ref);

#ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag explain $product_ref;

is($product_ref->{pnns_groups_2}, "Sweetened beverages") || diag explain $product_ref;

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

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;

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

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
};

special_process_product($product_ref);

is($product_ref->{pnns_groups_2}, "Waters and flavored waters") || diag explain $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:iced-teas"],
};

special_process_product($product_ref);

is($product_ref->{pnns_groups_2}, "Teas and herbal teas and coffees") || diag explain $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:ice-teas"],
	ingredients_tags => ["en:sugar"],
	additives_tags => ["en:e950"],
	with_sweeteners => 1,
};

special_process_product($product_ref);

ok(not(has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages')),
	'should add en:artificially-sweetened-beverages')
	|| diag explain $product_ref;
ok(not(has_tag($product_ref, 'categories', 'en:sweetened-beverages')), 'should add en:sweetened-beverages')
	|| diag explain $product_ref;

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;

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

ok((not(has_tag($product_ref, 'categories', 'en:unsweetened-beverages'))), 'should not add en:unsweetened-beverages')
	|| diag explain $product_ref;
ok(not(has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages')),
	'should add en:unsweetened-beverages')
	|| diag explain $product_ref;

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag explain $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:unsweetened-beverages"],
	ingredients_tags => ["en:water", "en:sugar"],
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

special_process_product($product_ref);

ok(not(not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should remove en:unsweetened-beverages')
	|| diag explain $product_ref;
ok(not(has_tag($product_ref, 'categories', 'en:sweetened-beverages')), 'should add en:sweetened-beverages')
	|| diag explain $product_ref;

is($product_ref->{pnns_groups_2}, "Sweetened beverages") || diag explain $product_ref;

is($product_ref->{nutrition_score_beverage}, 1);

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:plant-based-milk-alternatives"],
	ingredients_tags => ["en:water", "en:sugar"],
	ingredients_text => "water, fruit juice",
};

special_process_product($product_ref);

is($product_ref->{nutrition_score_beverage}, 0);

$product_ref = {nutriments => {salt => 3, salt_value => 3000, salt_unit => "mg"},};

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
	nutriments => {"nova-group" => 4, "nova-group_100g" => 4, "nova-group_serving" => 4, "alcohol" => 12, "ph" => 7},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

$expected_product_ref = {
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
	nutriments => {"sugars" => 4, "salt" => 1},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

$expected_product_ref = {
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
	nutriments => {
		"energy-kcal_prepared" => 58,
		"energy-kcal_prepared_value" => 58,
		"salt_prepared" => 10,
		"salt_prepared_value" => 10
	},
	nutrition_data_prepared_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_serving_size_data($product_ref);

$expected_product_ref = {
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
	nutriments => {"fr-unknown-nutrient" => 10},
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

	my $nid = $_;    # Copy instead of alias

	next if $nid =~ /^#/;

	$nid =~ s/^!//;
	$nid =~ s/^-!//;
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
# test we have no modifier
normalize_nutriment_value_and_modifier(\$value, \$modifier);
is($value, "50.1");
is($modifier, undef);
# test compute_serving_size_data with various units
assign_nid_modifier_value_and_unit($product_ref, "salt", $modifier, $value, undef);
assign_nid_modifier_value_and_unit($product_ref, "sugars", $modifier, $value, "g");
assign_nid_modifier_value_and_unit($product_ref, "fat", $modifier, $value, "mg");

compute_serving_size_data($product_ref);

is_deeply(
	$product_ref,
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

is_deeply(
	$product_ref,
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

# Prepared value defined in IU
assign_nid_modifier_value_and_unit($product_ref, "vitamin-a_prepared", "", 468, "IU");

# test support of traces, as well as "nearly" and prepared values
compute_serving_size_data($product_ref);

is_deeply(
	$product_ref,
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
			'sugars_value' => 1,
			'vitamin-a_prepared' => '0.0001404',
			'vitamin-a_prepared_100g' => '0.0001404',
			'vitamin-a_prepared_unit' => 'IU',
			'vitamin-a_prepared_value' => 468,
		},
		'nutrition_data_per' => '100g',
		'nutrition_data_prepared_per' => '100g'
	}
) or diag explain $product_ref;

# Test IU and %DV values
$product_ref = {'nutrition_data_per' => '100g'};
assign_nid_modifier_value_and_unit($product_ref, "vitamin-a", undef, 40, "IU");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-e", undef, 40, "IU");
assign_nid_modifier_value_and_unit($product_ref, "calcium", undef, 20, "% DV");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-d", undef, 20, "% DV");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-b1", undef, 100, "% DV");

is_deeply(
	$product_ref,
	{
		nutriments => {
			'calcium' => '0.2',
			'calcium_unit' => '% DV',
			'calcium_value' => 20,
			'vitamin-a' => '1.2e-05',
			'vitamin-a_unit' => 'IU',
			'vitamin-a_value' => 40,
			'vitamin-b1' => '0.0012',
			'vitamin-b1_unit' => '% DV',
			'vitamin-b1_value' => 100,
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

# Test that 100g values are not extrapolated where serving size <=5
$product_ref = {
	serving_size => '5 g',
	nutrition_data_per => 'serving'
};

assign_nid_modifier_value_and_unit($product_ref, "fat", undef, '1', 'g');
compute_serving_size_data($product_ref);

is_deeply(
	$product_ref,
	{
		'nutriments' => {
			'fat' => '1',
			'fat_serving' => '1',
			'fat_unit' => 'g',
			'fat_value' => '1',
		},
		'nutrition_data_per' => 'serving',
		'nutrition_data_prepared_per' => '100g',
		'serving_quantity' => 5,
		'serving_size' => '5 g'
	}
) or diag explain $product_ref;

done_testing();
