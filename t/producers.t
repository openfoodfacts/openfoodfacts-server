#!/usr/bin/perl -w

use Modern::Perl '2017';

use Test::More;
use Test::Number::Delta;
use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Producers qw/:all/;

init_fields_columns_names_for_lang("en");
init_fields_columns_names_for_lang("fr");

is_deeply(match_column_name_to_field("fr", "glucides"), { field=>"carbohydrates_100g_value_unit"});
is_deeply(match_column_name_to_field("fr", "nom-produit"), { field=>"product_name_fr"});
is_deeply(match_column_name_to_field("fr", "marque"), { field=>"brands"});
is_deeply(match_column_name_to_field("fr", "liste-ingredients"), { field=>"ingredients_text_fr"});
is_deeply(match_column_name_to_field("fr", "bio"), { field=>"labels_specific", tag=>"Bio"});

done_testing();
