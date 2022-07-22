#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use JSON;
use Getopt::Long;
use File::Basename "dirname";

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Nutriscore qw/:all/;



my $test_name = "nutriscore";
my $tests_dir = dirname(__FILE__);
my $expected_dir = $tests_dir . "/expected_test_results/" . $test_name;

my $usage = <<TXT

The expected results of the tests are saved in $tests_dir/expected_test_results/$test_name

To verify differences and update the expected test results,
actual test results can be saved by passing --update-expected-results

The directory will be created if it does not already exist.

TXT
;

my $update_expected_results;

GetOptions ("update-expected-results"   => \$update_expected_results)
  or die("Error in command line arguments.\n\n" . $usage);

  
if ((defined $update_expected_results) and (! -e $expected_dir)) {
	mkdir($expected_dir, 0755) or die("Could not create $expected_dir directory: $!\n");
}

init_emb_codes();

my @tests = (

["cookies", { lc=>"en", categories=>"cookies", nutriments=>{energy_100g=>3460, fat_100g=>90, "saturated-fat_100g"=>15, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}],
["olive-oil", { lc=>"en", categories=>"olive oils", nutriments=>{energy_100g=>3460, fat_100g=>92, "saturated-fat_100g"=>14, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}],
["colza-oil", { lc=>"en", categories=>"colza oils", nutriments=>{energy_100g=>3760, fat_100g=>100, "saturated-fat_100g"=>7, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}],
["walnut-oil", { lc=>"en", categories=>"walnut oils", nutriments=>{energy_100g=>3378, fat_100g=>100, "saturated-fat_100g"=>10, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}],
["sunflower-oil", { lc=>"en", categories=>"sunflower oils", nutriments=>{energy_100g=>3378, fat_100g=>100, "saturated-fat_100g"=>10, sugars_100g=>0, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}],

# saturated fat 1.03 should be rounded to 1.0 which is not strictly greater than 1.0
["breakfast-cereals", { lc=>"en", categories=>"breakfast cereals", nutriments=>{energy_100g=>2450, fat_100g=>100, "saturated-fat_100g"=>1.03, sugars_100g=>31, sodium_100g=>0.221, fiber_100g=>6.9, proteins_100g=>10.3}}],

# dairy drink with milk >= 80% are considered food and not beverages

["dairy-drinks-without-milk", { lc=>"en", categories=>"dairy drinks", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Water, sugar"}],
["milk", { lc=>"en", categories=>"milk", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Milk"}],
["dairy-drink-with-80-percent-milk", { lc=>"en", categories=>"dairy drinks", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Fresh milk 80%, sugar"}],
["beverage-with-80-percent-milk", { lc=>"en", categories=>"beverages", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Fresh milk 80%, sugar"}],
["dairy-drink-with-less-than-80-percent-milk", { lc=>"en", categories=>"dairy drinks", nutriments=>{energy_100g=>3378, fat_100g=>10, "saturated-fat_100g"=>5, sugars_100g=>10, sodium_100g=>0, fiber_100g=>2, proteins_100g=>5},
	ingredients_text=>"Milk, sugar"}],
	
# mushrooms are counted as fruits/vegetables
["mushrooms", { lc=>"fr", categories=>"meals", nutriments=>{energy_100g=>667, fat_100g=>8.4, "saturated-fat_100g"=>1.2, sugars_100g=>1.1, sodium_100g=>0.4, fiber_100g=>10.9, proteins_100g=>2.4},
	ingredients_text=>"Pleurotes* 69% (Origine UE), chapelure de mais"}],

# fruit content indicated at the end of the ingredients list
[
	"fr-gaspacho",
	{
			lc => "fr",
			categories => "gaspachos",
			ingredients_text => "Tomate,concombre,poivron,oignon,eau,huile d'olive vierge extra (1,1%),vinaigre de vin,pain de riz,sel,ail,jus de citron,teneur en légumes: 89%",
			nutriments=>{energy_100g=>148, fat_100g=>10, "saturated-fat_100g"=>0.2, sugars_100g=>3, sodium_100g=>0.2, fiber_100g=>1.1, proteins_100g=>0.9},	
	}

],

# spring waters
["spring-water-no-nutrition", { lc=>"en", categories=>"spring water", nutriments=>{}}],
["flavored-spring-water-no-nutrition", { lc=>"en", categories=>"flavoured spring water", nutriments=>{}}],
["flavored-spring-with-nutrition", { lc=>"en", categories=>"flavoured spring water", nutriments=>{energy_100g=>378, fat_100g=>0, "saturated-fat_100g"=>0, sugars_100g=>3, sodium_100g=>0, fiber_100g=>0, proteins_100g=>0}}],

# Cocoa and chocolate powders
["cocoa-and-chocolate-powders", { lc => "en", "categories" => "cocoa and chocolate powders", nutriments=>{energy_prepared_100g=>287, fat_prepared_100g=>0, "saturated-fat_prepared_100g"=>1.1, sugars_prepared_100g=>6.3, sodium_prepared_100g=>0.045, fiber_prepared_100g=>1.9, proteins_prepared_100g=>3.8}}],

# fruits and vegetables estimates from category or from ingredients
[
	"en-orange-juice-category-and-ingredients",
	{
			lc => "en",
			categories => "orange juices",
			ingredients_text => "orange juice 50%, water, sugar",
			nutriments=>{energy_100g=>182, fat_100g=>0, "saturated-fat_100g"=>0, sugars_100g=>8.9, sodium_100g=>0.2, fiber_100g=>0.5, proteins_100g=>0.2},	
	}
],
[
	"en-orange-juice-category",
	{
			lc => "en",
			categories => "orange juices",
			nutriments=>{energy_100g=>182, fat_100g=>0, "saturated-fat_100g"=>0, sugars_100g=>8.9, sodium_100g=>0.2, fiber_100g=>0.5, proteins_100g=>0.2},	
	}
],

# categories without Nutri-Score

[
	"en-beers-category",
	{
			lc => "en",
			categories => "beers",
			nutriments=>{energy_100g=>182, fat_100g=>0, "saturated-fat_100g"=>0, sugars_100g=>8.9, sodium_100g=>0.2, fiber_100g=>0.5, proteins_100g=>0.2},	
	}
],

);


my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	compute_field_tags($product_ref, $product_ref->{lc}, "categories");
	extract_ingredients_from_text($product_ref);
	special_process_product($product_ref);
	compute_nutrition_score($product_ref);

	# Save the result
	
	if (defined $update_expected_results) {
		open (my $result, ">:encoding(UTF-8)", "$expected_dir/$testid.json") or die("Could not create $expected_dir/$testid.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close ($result);
	}
	else {
		# Compare the result with the expected result
		
		if (open (my $expected_result, "<:encoding(UTF-8)", "$expected_dir/$testid.json")) {

			local $/; #Enable 'slurp' mode
			my $expected_product_ref = $json->decode(<$expected_result>);
			is_deeply ($product_ref, $expected_product_ref) or diag explain $product_ref;
		}
		else {
			fail("could not load $expected_dir/$testid.json");
			diag explain $product_ref;
		}
	}
}

is (compute_nutriscore_grade(1.56, 1, 0), "c");


done_testing();
