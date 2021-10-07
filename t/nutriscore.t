#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Nutriscore qw/:all/;

init_emb_codes();

my @tests = (

[{ lc=>"en", categories=>"cookies", nutriments=>{energy_100g=>3460, fat_100g=>90, "saturated-fat_100g"=>15, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 20, "e"],
[{ lc=>"en", categories=>"olive oils", nutriments=>{energy_100g=>3460, fat_100g=>92, "saturated-fat_100g"=>14, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 6, "c"],
[{ lc=>"en", categories=>"colza oils", nutriments=>{energy_100g=>3760, fat_100g=>100, "saturated-fat_100g"=>7, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 5, "c"],
[{ lc=>"en", categories=>"walnut oils", nutriments=>{energy_100g=>3378, fat_100g=>100, "saturated-fat_100g"=>10, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 6, "c"],
[{ lc=>"en", categories=>"sunflower oils", nutriments=>{energy_100g=>3378, fat_100g=>100, "saturated-fat_100g"=>10, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}, 11, "d"],

# saturated fat 1.03 should be rounded to 1.0 which is not strictly greater than 1.0
[{ lc=>"en", categories=>"breakfast cereals", nutriments=>{energy_100g=>2450, fat_100g=>100, "saturated-fat_100g"=>1.03, sugars_100g=>31, sodium_100g=>0.221, fiber_100g=>6.9, proteins_100g=>10.3}}, 10, "c"],

# dairy drink with milk >= 80% are considered food and not beverages

[{ lc=>"en", categories=>"dairy drinks", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Water, sugar"}, 19, "e"],
[{ lc=>"en", categories=>"dairy drinks", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Milk"}, 14, "d"],
[{ lc=>"en", categories=>"dairy drinks", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Fresh milk 80%, sugar"}, 14, "d"],
[{ lc=>"en", categories=>"dairy drinks", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Milk, sugar"}, 19, "e"],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	compute_field_tags($product_ref, $product_ref->{lc}, "categories");
	extract_ingredients_from_text($product_ref);
	special_process_product($product_ref);
	compute_nutrition_score($product_ref);

	is($product_ref->{nutrition_grade_fr}, $test_ref->[2]);
	is($product_ref->{nutriments}{"nutrition-score-fr"}, $test_ref->[1]) or diag explain $product_ref;

}

is (compute_nutriscore_grade(1.56, 1, 0), "c");


done_testing();
