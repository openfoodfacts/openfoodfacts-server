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

foreach my $ingredient (split(/\s*(?:,|\n)?\s*/, $ingredients)) {
    # ignore comments
    next if $ingredient =~ /^\s*\#/;
    my $ingredient_id = canonicalize_taxonomy_tag("en", "ingredients", $ingredient);
    push(@ingredients, {
        ingredient => $ingredient,
        ingredient_id => $ingredient_id,
        is_fruits_vegetables_legumes => ProductOpener::Ingredients::is_fruits_vegetables_legumes($ingredient_id),
        is_fruits_vegetables_nuts => ProductOpener::Ingredients::is_fruits_vegetables_nuts($ingredient_id),
        is_milk => ProductOpener::Ingredients::is_milk($ingredient_id),
    });
}

compare_to_expected_results(
    \@ingredients,
    "$expected_result_dir/individual_ingredients.json",
    $update_expected_results
);

# Analysis of ingredients lists

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (

	['sugar-milk-water', {lc => "en", ingredients_text => "sugar, milk, water"},],

	
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	parse_ingredients_text($product_ref);

	compute_ingredients_percent_estimates(100, $product_ref->{ingredients});

	compare_to_expected_results(
		$product_ref->{ingredients},
		"$expected_result_dir/$testid.json",
		$update_expected_results
	);
}

done_testing();
