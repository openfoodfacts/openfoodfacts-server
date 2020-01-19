#!/usr/bin/perl -w

use Modern::Perl '2017';

use Test::More;
use Test::Number::Delta;
use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Producers qw/:all/;
use ProductOpener::Store qw/:all/;

init_fields_columns_names_for_lang("en");
init_fields_columns_names_for_lang("fr");

my @tests = (
["fr", "glucides", { field=>"carbohydrates_100g_value_unit"}],
["fr", "nom-produit", { field=>"product_name_fr"}],
["fr", "marque", { field=>"brands"}],
["fr", "liste-ingredients", { field=>"ingredients_text_fr"}],
["fr", "bio", { field=>"labels_specific", tag=>"Bio"}],

["fr", "glucides", { field=>"carbohydrates_100g_value_unit"}],
["fr", "glucides-100g", { field=>"carbohydrates_100g_value_unit" }],
["fr", "glucides-100-gr", { field=>"carbohydrates_100g_value_unit" }],
["fr", "glucides-par-portion", { field=>"carbohydrates_serving_value_unit"}],
["fr", "fer-mg-par-portion", { field=>"iron_serving_value_unit", value_unit=>'value_in_mg'}],
["fr", "Fer (portion) mg", { field=>"iron_serving_value_unit", value_unit=>'value_in_mg'}],

);

foreach my $test_ref (@tests) {

	my $fieldid = get_string_id_for_lang("no_language", $test_ref->[1]);
	my $result_ref = match_column_name_to_field("fr", $fieldid);	
	is_deeply($result_ref, $test_ref->[2])
		or diag explain { test => $test_ref, fieldid => $fieldid, result => $result_ref };

}

done_testing();
