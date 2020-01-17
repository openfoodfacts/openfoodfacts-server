#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
#use Log::Any::Adapter 'TAP', filter => "none";
use Log::Any::Adapter 'TAP', filter => "info";

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::ImportConvert qw/:all/;

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

$product_ref = { "product_name" => "Champagne brut 35,5 CL" };
assign_quantity_from_field($product_ref, "product_name");
is($product_ref->{product_name}, "Champagne brut");
is($product_ref->{quantity}, "35,5 CL");

$product_ref = { "lc" => "fr", "product_name_fr" => "Soupe bio" };
@fields = qw(product_name_fr);
match_labels_in_product_name($product_ref);
is($product_ref->{labels}, 'en:organic') or diag explain $product_ref;

@fields = qw(quantity net_weight_value_unit);
$product_ref = { "lc" => "fr", net_weight_value_unit => "250 gr", quantity => "10.11.2019" }; clean_weights($product_ref);
is($product_ref->{quantity}, "250 g") or diag explain $product_ref;

$product_ref = { "lc" => "fr", net_weight_value_unit => "250 gr", quantity => "2 tranches" }; clean_weights($product_ref);
is($product_ref->{quantity}, "2 tranches (250 g)") or diag explain $product_ref;

$product_ref = { "lc" => "fr", emb_codes => "EMB 60282A - Gouvieux (Oise, France)" }; 
@fields = ("emb_codes");
clean_fields($product_ref);
is($product_ref->{emb_codes}, "EMB 60282A") or diag explain $product_ref;


# Test extract_nutrition_facts_from_text

my @tests = (
	["fr", "Pour 100 g : Energie 750 kJ / 180 kcal Matières grasses 9.3 g dont acides gras saturés 3.4 g Glucides 9.1 g dont sucres 1.3 g Fibres alimentaires 2.7 g Protéines 12.7 g Sel 1 g", { 'carbohydrates'=>['9.1','g',''], 'energy-kcal'=>['180','kcal',''], 'energy-kj'=>['750','kJ',''], 'fat'=>['9.3','g',''], 'fiber'=>['2.7','g',''], 'proteins'=>['12.7','g',''], 'salt'=>['1','g',''], 'saturated-fat'=>['3.4','g',''], 'sugars'=>['1.3','g',''], }],
	["fr", "pour 100g :
		Energie (kJ) : 1694
		Energie (kcal) : 401
		Graisses (g) : 5.1
		dont acides gras saturés (g) : 0.6
		Glucides (g) : 74.8
		dont sucres (g) : 7.3
		Fibres alimentaires (g) : 3.9
		Protéines (g) : 11.9
		Sodium (g) : 0,0048
		Sel (g) : 0.01", { 'carbohydrates'=>['74.8','g',''], 'energy-kcal'=>['401','kcal',''], 'energy-kj'=>['1694','kJ',''], 'fat'=>['5.1','g',''], 'fiber'=>['3.9','g',''], 'proteins'=>['11.9','g',''], 'salt'=>['0.01','g',''], 'saturated-fat'=>['0.6','g',''], 'sodium'=>['0,0048','g',''], 'sugars'=>['7.3','g',''] }],
	["fr", "pour 100g :
		Energie (kJ) : 
		Energie (kcal) : 
		Graisses (g) : 
		dont acides gras saturés (g) : 
		Glucides (g) : 
		dont sucres (g) : 
		Fibres alimentaires (g) : 
		Protéines (g) : 
		Sel (g) :", {}],
	["fr", "pour 100g :
		Energie (kJ) : 2989
		Energie (kcal) : 727
		Graisses (g) : 80
		dont acides gras saturés (g) : 52
		Glucides (g) : 1
		dont sucres (g) : 0
		Fibres alimentaires (g) : Traces
		Protéines (g) : 0.7
		Sodium (g) : 0,79
		Sel (g) : 2", { 'carbohydrates'=>['1','g',''], 'energy-kcal'=>['727','kcal',''], 'energy-kj'=>['2989','kJ',''], 'fat'=>['80','g',''], 'fiber'=>['0','g','~'], 'proteins'=>['0.7','g',''], 'salt'=>['2','g',''], 'saturated-fat'=>['52','g',''], 'sodium'=>['0,79','g',''], 'sugars'=>['0','g',''] }],
);

foreach my $test_ref (@tests) {

	my $nutrients_ref = {};
	extract_nutrition_facts_from_text($test_ref->[0], $test_ref->[1], $nutrients_ref);
	if (not is_deeply($nutrients_ref, $test_ref->[2])) {
		print STDERR "failed nutrients extraction for lc: $test_ref->[0] - text: $test_ref->[1]\n";
		# display the results in a format we can easily copy to the test
		my $results = "{";
		foreach my $nid (sort keys %$nutrients_ref) {
			$results .= " '" . $nid . "'=>['" 
			. $nutrients_ref->{$nid}[0] . "','"
			. $nutrients_ref->{$nid}[1] . "','"
			. $nutrients_ref->{$nid}[2] . "'],"
		}
		$results =~ s/,$//;
		$results .= " }";
		print STDERR $results . "\n";
	}
}

done_testing();
