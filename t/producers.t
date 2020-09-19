#!/usr/bin/perl -w

use utf8;

use Modern::Perl '2017';

use Test::More;
use Test::Number::Delta;
#use Log::Any::Adapter 'TAP', filter => "none";
use Log::Any::Adapter 'TAP';

use ProductOpener::Producers qw/:all/;
use ProductOpener::Store qw/:all/;

init_fields_columns_names_for_lang("en");
init_fields_columns_names_for_lang("fr");
init_fields_columns_names_for_lang("es");

my @tests = (
["fr", "glucides", { field=>"carbohydrates_100g_value_unit"}],
["fr", "nom-produit", { field=>"product_name_fr"}],
["fr", "marque", { field=>"brands"}],
["fr", "liste-ingredients", { field=>"ingredients_text_fr"}],
["fr", "bio", { field=>"labels_specific", tag=>"Bio"}],

["fr", "glucides", { field=>"carbohydrates_100g_value_unit"}],
["fr", "glucides preparé", { field=>"carbohydrates_prepared_100g_value_unit"}],
["fr", "glucides (valeur)", { field=>"carbohydrates_100g_value_unit", value_unit => "value"}],
["fr", "glucides - unité", { field=>"carbohydrates_100g_value_unit", value_unit => "unit"}],
["fr", "glucides-100g", { field=>"carbohydrates_100g_value_unit" }],
["fr", "glucides-100-gr", { field=>"carbohydrates_100g_value_unit" }],
["fr", "glucides-par-portion", { field=>"carbohydrates_serving_value_unit"}],
["fr", "glucides-prepare-par-portion", { field=>"carbohydrates_prepared_serving_value_unit"}],
["fr", "fer-mg-par-portion", { field=>"iron_serving_value_unit", value_unit=>'value_in_mg'}],
["fr", "Fer (portion) mg", { field=>"iron_serving_value_unit", value_unit=>'value_in_mg'}],
["en", "energy-kj_prepared", { field=>"energy-kj_prepared_100g_value_unit", value_unit=>'value_in_kj'}],
["en", "energy-kcal_prepared", { field=>"energy-kcal_prepared_100g_value_unit", value_unit=>'value_in_kcal'}],
["en", "energy-kcal_prepared_value", { field=>"energy-kcal_prepared_100g_value_unit", value_unit=>'value'}],

["es", "proteinas", { field=>"proteins_100g_value_unit"}],
["es", "proteinas g", { field=>"proteins_100g_value_unit", value_unit=>"value_in_g"}],
["es", "sal", { field=>"salt_100g_value_unit" }],
["es", "sal mg", { field=>"salt_100g_value_unit", value_unit=>"value_in_mg"}],

["en", "image_front_url", { field=>"image_front_url_en"}],
["fr", "image_front_url", { field=>"image_front_url_fr"}],
["fr", "image_front_url_fr", { field=>"image_front_url_fr"}],
["fr", "image_front_fr_url", { field=>"image_front_url_fr"}],

["es", "Valor Energético", { field=>"energy_100g_value_unit"}],
["es", "Valor Energético KJ", { field=>"energy-kj_100g_value_unit", value_unit=>'value_in_kj'}],
["es", "Valor Energético 100 gr", { field=>"energy_100g_value_unit"}],
["es", "Valor Energético 100gr", { field=>"energy_100g_value_unit"}],
["es", "Valor Energético KJ / 100 gr", { field=>"energy-kj_100g_value_unit", value_unit=>'value_in_kj'}],
["es", "Valor Energético KJ / 100gr", { field=>"energy-kj_100g_value_unit", value_unit=>'value_in_kj'}],
["es", "Valor Energético KJ por porción", { field=>"energy-kj_serving_value_unit", value_unit=>'value_in_kj'}],

["en", "vitamin c (µg)", { field=>"vitamin-c_100g_value_unit", value_unit=>"value_in_mcg"}],
["en", "folates_ug_100g", { 'field' => 'folates_100g_value_unit', 'value_unit' => 'value_in_mcg' }],
["en", "vitamin-a_iu_100g", { 'field' => 'vitamin-a_100g_value_unit', 'value_unit' => 'value_in_iu' }],
["en", "soluble-fiber_g_100g", { 'field' => 'soluble-fiber_100g_value_unit', 'value_unit' => 'value_in_g' }],

# English fields in another language
["fr", "name", {'field' => 'product_name_fr'}],
["fr", "product name", {'field' => 'product_name_fr'}],

# nutrient in unit
["en", "energy in kJ", { 'field' => 'energy-kj_100g_value_unit', 'value_unit' => 'value_in_kj'}],
["en", "carbohydrates in mg", { 'field' => 'carbohydrates_100g_value_unit', 'value_unit' => 'value_in_mg' }],
["fr", "énergie en kJ", {  'field' => 'energy-kj_100g_value_unit', 'value_unit' => 'value_in_kj' }],

["fr", "% Fruits et Légumes", {'field' => 'fruits-vegetables-nuts_100g_value_unit', 'value_unit' => 'value_in_percent'}],
["fr", "Fruits et Légumes", {'field' => 'fruits-vegetables-nuts_100g_value_unit'}],
["fr", "Glucides (%)", {'field' => 'carbohydrates_100g_value_unit', 'value_unit' => 'value_in_percent'}],
["fr", "Fibres (en g)", {'field' => 'fiber_100g_value_unit', 'value_unit' => 'value_in_g'}],
["fr", "Fibres 100g", { 'field' => 'fiber_100g_value_unit'}],
["fr", "Fibres (en g) / 100g", {'field' => 'fiber_100g_value_unit', 'value_unit' => 'value_in_g'}],
["fr", "Fibres / 100g (en g)", {'field' => 'fiber_100g_value_unit', 'value_unit' => 'value_in_g'}],

["es", "azucar", {'field' => 'sugars_100g_value_unit'}],
["es", "hidratos de carbono", {'field' => 'carbohydrates_100g_value_unit'}],
["es", "grasas saturadas (g)", {'field' => 'saturated-fat_100g_value_unit', 'value_unit' => 'value_in_g'}],
["es", "fibra alimenticia", {'field' => 'fiber_100g_value_unit'}],

);

foreach my $test_ref (@tests) {

	my $fieldid = get_string_id_for_lang("no_language", normalize_column_name($test_ref->[1]));
	my $result_ref = match_column_name_to_field( $test_ref->[0], $fieldid );
	is_deeply($result_ref, $test_ref->[2])
		or diag explain { test => $test_ref, fieldid => $fieldid, result => $result_ref };

}

done_testing();
