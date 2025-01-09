#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/exists_taxonomy_tag has_tag get_property %properties/;
use ProductOpener::Food qw/:all/;
use ProductOpener::FoodProducts qw/:all/;

# Note: the categories en:unsweetened-beverages, en:sweetened-beverages, en:artificially-sweetened-beverages
# are now only added temporarily when we compute food groups, they are not kept in the product categories

my $product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
};

# without an ingredient list: should not add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

# ok((not has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should not add en:unsweetened-beverages')
#	|| diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "unknown") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

#ok( (has_tag($product_ref, 'categories', 'en:unsweetened-beverages')), 'should add en:unsweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_text => "water, sugar",
};

specific_processes_for_food_product($product_ref);

#ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages"],
	categories => "beverages",
	ingredients_text => "sugar, e950",
};

specific_processes_for_food_product($product_ref);

#ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
	categories => "beverages",
	ingredients_text => "sugar, e950",
};

specific_processes_for_food_product($product_ref);

#ok( has_tag($product_ref, 'categories', 'en:artificially-sweetened-beverages'), 'should add en:artificially-sweetened-beverages' ) || diag Dumper $product_ref;
#ok( has_tag($product_ref, 'categories', 'en:sweetened-beverages'), 'should add en:sweetened-beverages' ) || diag Dumper $product_ref;

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:waters", "en:flavored-waters"],
};

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Waters and flavored waters") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:iced-teas"],
};

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Teas and herbal teas and coffees") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:ice-teas"],
	ingredients_text => "sugar, sorbitol",
};

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Artificially sweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages"],
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag Dumper $product_ref;

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:unsweetened-beverages"],
	ingredients_tags => ["en:water", "en:sugar"],
	ingredients_text => "water, fruit juice",
};

# with an ingredient list: should add en:unsweetened-beverages

specific_processes_for_food_product($product_ref);

is($product_ref->{pnns_groups_2}, "Unsweetened beverages") || diag Dumper $product_ref;

is($product_ref->{nutrition_score_beverage}, 1);

$product_ref = {
	lc => "en",
	categories => "beverages",
	categories_tags => ["en:beverages", "en:plant-based-milk-alternatives"],
	ingredients_tags => ["en:water", "en:sugar"],
	ingredients_text => "water, fruit juice",
};

specific_processes_for_food_product($product_ref);

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

is($product_ref, $expected_product_ref) or diag Dumper($product_ref);

$product_ref = {
	nutriments => {"nova-group" => 4, "nova-group_100g" => 4, "nova-group_serving" => 4, "alcohol" => 12, "ph" => 7},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_nutrition_data_per_100g_and_per_serving($product_ref);

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
	'product_quantity_unit' => "g",
	'quantity' => '100 g',
	'serving_quantity' => 25,
	'serving_quantity_unit' => "g",
	'serving_size' => '25 g'
};

is($product_ref, $expected_product_ref) or diag Dumper($product_ref);

$product_ref = {
	nutriments => {"sugars" => 4, "salt" => 1},
	nutrition_data_per => "serving",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_nutrition_data_per_100g_and_per_serving($product_ref);

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
	'product_quantity_unit' => "g",
	'quantity' => '100 g',
	'serving_quantity' => 25,
	'serving_quantity_unit' => "g",
	'serving_size' => '25 g'
};

is($product_ref, $expected_product_ref) or diag Dumper($product_ref);

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

compute_nutrition_data_per_100g_and_per_serving($product_ref);

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
	'product_quantity_unit' => 'g',
	'quantity' => '100 g',
	'serving_quantity' => 25,
	'serving_quantity_unit' => 'g',
	'serving_size' => '25 g'
};

is($product_ref, $expected_product_ref) or diag Dumper($product_ref);

# Unknown nutrient

$product_ref = {
	nutriments => {"fr-unknown-nutrient" => 10},
	nutrition_data_prepared_per => "100g",
	quantity => "100 g",
	serving_size => "25 g",
};

compute_nutrition_data_per_100g_and_per_serving($product_ref);

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
	'product_quantity_unit' => "g",
	'quantity' => '100 g',
	'serving_quantity' => 25,
	'serving_quantity_unit' => "g",
	'serving_size' => '25 g'
};

is(default_unit_for_nid("sugars"), "g");
is(default_unit_for_nid("energy-kj"), "kJ");
is(default_unit_for_nid("energy-kcal_prepared"), "kcal");

is($product_ref, $expected_product_ref) or diag Dumper($product_ref);

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
# test compute_nutrition_data_per_100g_and_per_serving with various units
assign_nid_modifier_value_and_unit($product_ref, "salt", $modifier, $value, undef);
assign_nid_modifier_value_and_unit($product_ref, "sugars", $modifier, $value, "g");
assign_nid_modifier_value_and_unit($product_ref, "fat", $modifier, $value, "mg");

compute_nutrition_data_per_100g_and_per_serving($product_ref);

is(
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
) or diag Dumper $product_ref;

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
compute_nutrition_data_per_100g_and_per_serving($product_ref);

is(
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
) or diag Dumper $product_ref;

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
compute_nutrition_data_per_100g_and_per_serving($product_ref);

is(
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
) or diag Dumper $product_ref;

# Test IU and %DV values
$product_ref = {'nutrition_data_per' => '100g'};
assign_nid_modifier_value_and_unit($product_ref, "vitamin-a", undef, 40, "IU");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-e", undef, 40, "IU");
assign_nid_modifier_value_and_unit($product_ref, "calcium", undef, 20, "% DV");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-d", undef, 20, "% DV");
assign_nid_modifier_value_and_unit($product_ref, "vitamin-b1", undef, 100, "% DV");

is(
	$product_ref,
	{
		nutriments => {
			'calcium' => '0.26',
			'calcium_unit' => '% DV',
			'calcium_value' => 20,
			'vitamin-a' => '1.2e-05',
			'vitamin-a_unit' => 'IU',
			'vitamin-a_value' => 40,
			'vitamin-b1' => '0.0012',
			'vitamin-b1_unit' => '% DV',
			'vitamin-b1_value' => 100,
			'vitamin-d' => '4e-06',
			'vitamin-d_unit' => '% DV',
			'vitamin-d_value' => 20,
			'vitamin-e' => '0.0266666666666667',
			'vitamin-e_unit' => 'IU',
			'vitamin-e_value' => 40
		},
		'nutrition_data_per' => '100g',
	}
) or diag Dumper $product_ref;

# Test that 100g values are not extrapolated where serving size <=5
$product_ref = {
	serving_size => '5 g',
	nutrition_data_per => 'serving'
};

assign_nid_modifier_value_and_unit($product_ref, "fat", undef, '1', 'g');
compute_nutrition_data_per_100g_and_per_serving($product_ref);

is(
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
		'serving_quantity_unit' => "g",
		'serving_size' => '5 g'
	}
) or diag Dumper $product_ref;

# Testing for get_nutrient_unit both for India and a country where no unit is described
# Test case for fetching unit for sodium in India
{
	my $unit_in_india = get_nutrient_unit("sodium", "in");
	is($unit_in_india, "mg", "Check if unit_in is fetched correctly for sodium in India");
}

# Test case for fetching unit for sodium outside India (eg: US)
{
	my $unit_in_us = get_nutrient_unit("sodium", "us");
	is($unit_in_us, "mg", "Check if unit_us is fetched correctly for sodium in US");
}

# Test case for fetching unit for sodium outside India (eg: Canada)
{
	my $unit_in_canada = get_nutrient_unit("sodium", "ca");
	is($unit_in_canada, "g", "Check if unit is fetched correctly for sodium in Canada");
}

# Test case for a product that previously had ingredients and additives, and then has its ingredients removed

$product_ref = {
	lc => "en",
	categories => "beverages",
	ingredients_text => "water, fruit juice, citric acid",
};

specific_processes_for_food_product($product_ref);

ok((has_tag($product_ref, 'additives', 'en:e330')), 'should have en:330') || diag Dumper $product_ref;

delete $product_ref->{ingredients_text};

specific_processes_for_food_product($product_ref);

ok((not has_tag($product_ref, 'additives', 'en:e330')), 'should not have en:330') || diag Dumper $product_ref;

# same logic as in process_product_edit_rules.t:
# the single_param function in Display is overwritten (monkey patch)
# to allow to run the function assign_nid_modifier_value_and_unit
# otherwise the following line prevent tests to run as expected:
# "next if (not defined single_param("nutriment_${enid}${product_type}"));"
my @tests = (
	{
		id => "rm insignificants digits",
		desc => "Should round floats",
		form => {
			'nutriment_energy-kj' => '0.40000000596046',
			'nutriment_energy_unit' => 'kJ',
			'nutriment_fat' => '3.99999',
			'nutriment_fat_unit' => 'g',
			'nutriment_salt' => '1.000001',
			'nutriment_salt_unit' => 'g',
		},
		nutriment_table => "off_europe",
		product_ref => {
			'nutriments' => {}
		},
		expected_product_ref => {
			'nutriments' => {
				'energy' => '0.4',
				'energy_100g' => '0.4',
				'energy_unit' => 'kJ',
				'energy_value' => '0.4',
				'energy-kj' => '0.4',
				'energy-kj_100g' => '0.4',
				'energy-kj_unit' => 'kJ',
				'energy-kj_value' => '0.4',
				'fat' => '4',
				'fat_100g' => '4',
				'fat_unit' => 'g',
				'fat_value' => '4',
				'salt' => '1',
				'salt_100g' => '1',
				'salt_unit' => 'g',
				'salt_value' => '1'
			},
			nutrition_data_per => "100g",
			nutrition_data_prepared_per => "100g",
		},
	}
);
my %form = ();
{
	# monkey patch single_param
	my $display_module = mock 'ProductOpener::Display' => (
		override => [
			single_param => sub {
				my ($name) = @_;
				return scalar $form{$name};
			}
		]
	);
	# because this is a direct import in Food we have to monkey patch here too
	my $products_module = mock 'ProductOpener::Food' => (
		override => [
			single_param => sub {
				my ($name) = @_;
				return scalar $form{$name};
			}
		]
	);
	foreach my $test_ref (@tests) {
		eval {
			my $id = $test_ref->{id};
			my $desc = $test_ref->{desc};
			my %product = %{$test_ref->{product_ref}};
			%form = %{$test_ref->{form}};
			assign_nutriments_values_from_request_parameters(\%product, $test_ref->{nutriment_table});
			compute_nutrition_data_per_100g_and_per_serving(\%product);

			is(\%product, $test_ref->{expected_product_ref}, "Result for $id - $desc") || diag Dumper \%product;

		};
		if ($@) {
			diag("Error running test: $@");
		}
	}
}

done_testing();
