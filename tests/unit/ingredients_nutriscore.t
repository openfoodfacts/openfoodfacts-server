#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
#use Log::Any::Adapter 'TAP';
use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

my @ingredients = (

	["en", "bananas", "yes"],
	["en", "flour", undef],
	["fr", "fraises", "yes"],
	["fr", "noisettes", "yes"],
	["fr", "légumes", "yes"],
	["fr", "pommes de terre", "no"],
);

foreach my $test_ref (@ingredients) {

	my $ingredient_id = canonicalize_taxonomy_tag($test_ref->[0], "ingredients", $test_ref->[1]);

	is(get_inherited_property("ingredients", $ingredient_id, "nutriscore_fruits_vegetables_nuts:en"), $test_ref->[2]);

}

# test the estimate percent of fruits and vegetables

my @tests = (
	[{lc => "fr", ingredients_text => ""}, undef],
	[{lc => "fr", ingredients_text => "eau, sucre, noisettes"}, 16.6666666666667],
	[{lc => "fr", ingredients_text => "banane 50%, fraise 30%, eau"}, 80],
	[{lc => "fr", ingredients_text => "banane 50%, gâteau (fraise 30%, framboise 5%, farine), eau"}, 85],
	[{lc => "fr", ingredients_text => "banane, gâteau (fraise 30%, framboise 5%, farine), eau"}, 85],
	[
		{
			lc => "fr",
			ingredients_text =>
				"Courgette grillée 37,5%, tomate pelée 20%, poivron jaune 17%, oignon rouge grillé 8%, eau, huile d'olive vierge extra 3,9%, oignon, olive noire entière dénoyautée saumurée 2,5% (olive, eau, sel, correcteurs d'acidité : acide citrique, acide lactique), ail, basilic 0,9%, amidon de riz, sel"
		},
		# add_fruit() currently matches "olive noire entière dénoyautée saumurée 2,5% (..)" to 2.5% fruit, even though it has sub-ingredients that are not fruits
		# TODO: investigate on actual product data to see if trying to fix this would have more true positives than false positives
		93.8
	],
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_fruits = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is(
		(
			defined $product_ref->{nutriments}
			? $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"}
			: undef
		),
		$expected_fruits
	) or diag explain $product_ref->{ingredients};
}

# test the estimate percent of milk

@tests = (
	[{lc => "fr", ingredients_text => ""}, undef],
	[{lc => "fr", ingredients_text => "lait"}, 100],
	[{lc => "fr", ingredients_text => "lait entier"}, 100],
	[{lc => "fr", ingredients_text => "lait frais"}, 100],
	[{lc => "fr", ingredients_text => "lait de vache"}, 100],
	[{lc => "fr", ingredients_text => "lait pasteurisé"}, 100],
	[{lc => "fr", ingredients_text => "lait de coco"}, 0],
	[{lc => "fr", ingredients_text => "lait, sucre, noisettes"}, 66.6666666666667],
	[{lc => "fr", ingredients_text => "lait écrémé 50%, fraise 30%, eau"}, 50],
	[
		{lc => "fr", ingredients_text => "banane 50%, gâteau (fraise, framboise, lait demi-écrémé), eau"},
		7.29166666666666
	],
	[{lc => "fr", ingredients_text => "lait frais, gâteau (lait 30%, framboise 5%, farine), eau"}, 80],
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_value = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is(estimate_nutriscore_2021_milk_percent_from_ingredients($product_ref), $expected_value)
		or diag explain $product_ref->{ingredients};
}


# test the estimate percent of red meat

@tests = (
	[{lc => "fr", ingredients_text => ""}, undef],
	[{lc => "fr", ingredients_text => "viande de porc"}, 100],
	[{lc => "fr", ingredients_text => "canard"}, 0],
	[{lc => "fr", ingredients_text => "côte d'agneau"}, 100],
	[{lc => "fr", ingredients_text => "jambon de porc 50%, viande de kangourou 20%, eau"}, 70],
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_value = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is(estimate_nutriscore_2023_red_meat_percent_from_ingredients($product_ref), $expected_value)
		or diag explain $product_ref->{ingredients};
}


done_testing();

