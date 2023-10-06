#!/usr/bin/perl -w

# Tests of Ingredients::compute_ingredients_percent_values()

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';
use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Test qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Tests for the computation of the percent values of fruits/vegetables/legumes, milk etc.

# Analysis of individual ingredients (comma or line break separated list in English, will be split and canonicalized)
my $ingredients = "water,
milk, fat free milk, whole milk
ice cream, butter,
fruits, vegetables, legumes,
tomato, bell peppers, mushrooms,
potato, taro,
olives, olive oil, chia seeds,
peanuts, chestnuts,
lamb
some unknown ingredient
";

my @ingredients = ();

foreach my $ingredient (split(/\s*(?:,|\n)\s*/, $ingredients)) {
	# ignore comments
	next if $ingredient =~ /^\s*\#/;
	my $ingredient_id = canonicalize_taxonomy_tag("en", "ingredients", $ingredient);
	push(
		@ingredients,
		{
			ingredient => $ingredient,
			ingredient_id => $ingredient_id,
			is_fruits_vegetables_legumes => ProductOpener::Ingredients::is_fruits_vegetables_legumes($ingredient_id),
			is_fruits_vegetables_nuts_olive_walnut_rapeseed_oils =>
				ProductOpener::Ingredients::is_fruits_vegetables_nuts_olive_walnut_rapeseed_oils($ingredient_id),
			is_milk => ProductOpener::Ingredients::is_milk($ingredient_id),
		}
	);
}

compare_to_expected_results(\@ingredients, "$expected_result_dir/individual_ingredients.json",
	$update_expected_results);

# Analysis of ingredients lists

my @tests = (

	[
		'fruits-water-sugar',
		{lc => "en", ingredients_text => "apple 50%, banana 30%, strawberry 10%, water 5%, sugar 5%"},
	],
	[
		'vegetable-oils',
		{lc => "en", ingredients_text => "olive oil 40%, rapeseed oil 30%, sunflower oil 20%, walnut oil 10%"},
	],

);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

done_testing();
