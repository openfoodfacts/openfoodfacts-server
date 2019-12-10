#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;


my @tests = (

[{ lc=>"en", categories=>"cookies", nutriments=>{energy_100g=>3460, fat_100g=>90, "saturated-fat_100g"=>15, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 20, "e"],
[{ lc=>"en", categories=>"olive oils", nutriments=>{energy_100g=>3460, fat_100g=>92, "saturated-fat_100g"=>14, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 6, "c"],
[{ lc=>"en", categories=>"colza oils", nutriments=>{energy_100g=>3760, fat_100g=>100, "saturated-fat_100g"=>7, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 5, "c"],
[{ lc=>"en", categories=>"walnut oils", nutriments=>{energy_100g=>3378, fat_100g=>100, "saturated-fat_100g"=>10, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 6, "c"],
[{ lc=>"en", categories=>"sunflower oils", nutriments=>{energy_100g=>3378, fat_100g=>100, "saturated-fat_100g"=>10, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 11, "d"],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	compute_field_tags($product_ref, $product_ref->{lc}, "categories");
	special_process_product($product_ref);
	compute_nutrition_score($product_ref);

	is($product_ref->{nutrition_grade_fr}, $test_ref->[2]);
	is($product_ref->{nutriments}{"nutrition-score-fr"}, $test_ref->[1]) or diag explain $product_ref;

}


done_testing();
