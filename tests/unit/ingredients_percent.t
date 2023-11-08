#!/usr/bin/perl -w

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

my @tests = (

	['sugar', {lc => "en", ingredients_text => "sugar"},],

	['sugar-milk', {lc => "en", ingredients_text => "sugar, milk"},],

	['sugar-milk-water', {lc => "en", ingredients_text => "sugar, milk, water"},],

	['sugar-90-percent-milk', {lc => "en", ingredients_text => "sugar 90%, milk"},],

	['sugar-milk-10-percent', {lc => "en", ingredients_text => "sugar, milk 10%"},],

	['sugar-milk-10-percent-water', {lc => "en", ingredients_text => "sugar, milk 10%, water"},],

	['sugar-water-milk-10-percent', {lc => "en", ingredients_text => "sugar, water, milk 10%"},],

	# Ingredients with sub-ingredients

	['chocolate-1-sub-ingredient', {lc => "en", ingredients_text => "chocolate (cocoa)"},],

	['chocolate-2-sub-ingredients', {lc => "en", ingredients_text => "chocolate (cocoa, sugar), milk"},],

	[
		'chocolate-sub-sub-ingredients',
		{lc => "en", ingredients_text => "chocolate (cocoa [cocoa paste 70%, cocoa butter], sugar)"},
	],

	# Make sure we can handle impossible values gracefully

	# This ingredient string caused an infinite loop:
	#  "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"

	[
		'impossible-values-infinte-loop-bug',
		{lc => "fr", ingredients_text => "beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%"},
	],

	[
		'impossible-values-sub-ingredients',
		{
			lc => "fr",
			ingredients_text =>
				"farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%)"
		},
	],

	['flour-chocolate-egg', {lc => "en", ingredients_text => "Flour, chocolate (cocoa, sugar, soy lecithin), egg"},],

	# For lists like  "Beans (52%), Tomatoes (33%), Water, Sugar, Cornflour, Salt, Spirit Vinegar"
	# we can set a maximum on Sugar, Cornflour etc. that takes into account that all ingredients
	# that appear before will have an higher quantity.
	# e.g. the percent max of Water to be set to 100 - 52 -33 = 15%
	# the max of sugar to be set to 15 / 2 = 7.5 %
	# the max of cornflour to be set to 15 / 3 etc.

	[
		'propagate-max-percent',
		{lc => "en", ingredients_text => "Beans (52%), Tomatoes (33%), Water, Sugar, Cornflour, Salt, Spirit Vinegar"},
	],

	['minimum-percent', {lc => "es", ingredients_text => "Leche. Cacao: 27% mínimo"},],

	# All ingredients have % specified, but the total is not 100%
	# We now scale them to 100%.
	# Note: currently the min part is ignored, we set percent instead of percent_min
	[
		'scale-percents-when-sum-greater-than-100',
		{lc => "es", ingredients_text => "Leche min 12.2%, Cacao: min 7%, Avellanas (mínimo 0,8%)"},
	],

	# bug #3762 "min" in "cumin"
	# bug #3762 "min" in "cumin"
	[
		'min-in-cumin-bug',
		{lc => "fr", ingredients_text => "sel (min 20%), poivre (min. 10%), piment (min : 5%), cumin 0,4%, ail : 0.1%"},
	],

	# Relative percent

	[
		'relative-percent',
		{lc => "en", ingredients_text => "fruits 50% (apple 40%, pear 30%, cranberry, lemon), sugar"},
	],

	# Absolute percent

	[
		'absolute-percent',
		{lc => "en", ingredients_text => "fruits 50% (apple 20%, pear 15%, cranberry, lemon), sugar"},
	],

	# Relative percent with no indicated percent on the parent ingredient, but with a percent min = percent max on the parent ingredient
	[
		'relative-percent-with-no-percent-on-parent',
		{lc => "en", ingredients_text => "water (60%), fruit concentrate (apple 40%, mango 30%, citrus)"},
	],

	# Relative percent with a different percent min and percent max on the parent ingredient
	[
		'relative-percent-with-different-percent-min-and-percent-max-on-parent',
		{lc => "en", ingredients_text => "water (60%), fruit concentrate (apple 40%, mango 30%, citrus), sugar"},
	],

	# Missing % that is not the first or the last
	[
		'missing-percent-not-first-or-last',
		{lc => "fr", ingredients_text => "Jus de pomme (57,3%), jus de carotte, jus de gingembre (2,5%)."},
	],

	# Where flavourings or other ingredients with a maximum percentage are not the first ingredient then
	# use their maximum percentage
	['ingredient-with-max-percent', {lc => "en", ingredients_text => "milk, flavouring"},],

	# Can get percent_max from parent ingredient
	[
		'ingredient-with-max-percent-from-parent-ingredient',
		{lc => "en", ingredients_text => "milk, natural flavouring"},
	],

	# Where flavourings are the first ingredient then ignore maximum percentages
	[
		'ingredient-with-max-percent-is-first-ingredient',
		{lc => "en", ingredients_text => "flavouring, lemon flavouring"},
	],

	# Where maximum would prevent ingredients from adding up to 100% then ignore it
	[
		'ingredient-with-max-percent-but-sum-less-than-100-percent',
		{lc => "en", ingredients_text => "milk 80%, flavouring"},
	],

	# Where maximum is lower than later ingredients then ignore it
	[
		'ingredient-with-max-percent-but-lower-than-later-ingredients',
		{lc => "en", ingredients_text => "milk, flavouring, sugar 10%"},
	],

	# Where two ingredients have a maximum then apply it
	['2-ingredients-with-max-percent', {lc => "en", ingredients_text => "milk, lemon flavouring, orange flavouring"},],

	# Ingredients indicated in grams, with a sum different than 100 (here 200)
	# The percents need to be scaled to take into account the actual sum
	# This works only if we have actual percent values for all ingredients
	[
		'ingredients-in-grams-with-sum-greater-than-100',
		{lc => "en", ingredients_text => "milk (160g), sugar (30g), lemon flavouring (10g)"},
	],
	# smaller sum than 100, sub ingredients, ingredients not in quantity order (as in a recipe)
	[
		'ingredients-in-grams-with-sum-lesser-than-100-not-in-quantity-order',
		{lc => "en", ingredients_text => "milk (10g), fruits 30g (apples, pears), lemon flavouring (10g)"},
	],
	# This test currently does not give very good results, as we have one ingredient without quantity,
	# so we can't do much about it
	[
		'ingredients-in-grams-with-1-ingredient-missing-a-quantity',
		{lc => "en", ingredients_text => "milk (160g), sugar (30g), lemon flavouring"},
	],

	# Trigger illegal division by zero - https://github.com/openfoodfacts/openfoodfacts-server/issues/8782
	[
		'illegal-division-by-zero-bug-0-percent',
		{
			lc => "fr",
			ingredients_text => 'légumes 0% (épices et aromates (contient oignon et safran &lt;0.1%), sel)',
		},
	],

	# Ingredients in other quantities than grams
	[
		'ingredients-in-different-quantities',
		{
			lc => 'en',
			ingredients_text => "lemon 1 KG, orange juice 10cl, sugar 5g, salt 0.5mg, apple juice 1L, ice cream 100ml",
		}
	],
	# parse texts like: "Tomato (160g of tomato per 100g of final product)"
	[
		'specific-ingredients-en',
		{
			lc => "en",
			ingredients_text => "water. Total Milk Content 73%."
		},
	],
	[
		'specific-ingredients-da',
		{
			lc => "da",
			ingredients_text =>
				"40% solbær, sukker, vand, geleringsmiddel (E440), konserveringsmiddel (E202). Fremstillet af 40 g frugt pr. 100 g."
		},
	],
	[
		'specific-ingredients-es',
		{
			lc => "es",
			ingredients_text =>
				"Tomate* (160g de tomate por cada 100g de producto final), melocotón, azúcar moreno de caña integral, zumo de limon. Elabora con 59 g de fruta por 100 g. Contenido total de azúcares 60 g por 100g. 160g de tomate por cada 100g de producto final."
		},
	],
	[
		'specific-ingredients-hr',
		{
			lc => "hr",
			ingredients_text =>
				"Šećer, suha smokva (46%) (sumporni dioksid), voda, regulator kiselosti: limunska kiselina, zgušnjivač: voćni pektin. Proizvedeno od 80g voća na 100g gotovog proizvoda. Ukupni šećeri 65g na 100g proizvoda. Ukupni šećeri: 60g na 100g gotovog proizvoda. Proizvedeno od 42 g voća na 100 g gotovog proizvoda."
		},
	],
	[
		'specific-ingredients-nl',
		{
			lc => "nl",
			ingredients_text =>
				"perziken (50%), suiker, geleermiddel (citruspectine), citroensap uit concentraat, conserveermiddel (kaliumsorbaat),antioxidant (ascorbinezuur), zoetstof (steviolglycosiden). Bereid met 50g vruchten per 100g."
		},
	],
	[
		'specific-ingredients-sv',
		{
			lc => "sv",
			ingredients_text =>
				"Lingon 50%*, socker*, vatten, förtjockningsmedel (pektin), surhetsreglerande medel (citronsyra). *KRAV-certifierad ekologisk ingrediens. Fruktmängd: 50g per 100g. Total mängd socker är 35 g per 100 g sylt. Fruktmängd: 52g per 100 g sylt. Bärmängd: 40 g bär per 100g. Total mängd socker: 45g per 100g sylt. Total mängd socker 44 g, varav tillsatt socker 41g per 100g sylt."
		},
	],
	# max sugar and salt from nutrition facts
	[
		'max-sugar-salt-nutrition-facts',
		{
			lc => "en",
			ingredients_text => "water, sugar, salt",
			nutrition_data_per => "100g",
			nutriments => {
				sugars_100g => 10,
				salt_100g => 5,
			},
		},
	],
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	parse_ingredients_text_service($product_ref, {});
	if (compute_ingredients_percent_min_max_values(100, 100, $product_ref->{ingredients}) < 0) {
		delete_ingredients_percent_values($product_ref->{ingredients});
	}

	compute_ingredients_percent_estimates(100, $product_ref->{ingredients});

	compare_to_expected_results(
		$product_ref->{ingredients},
		"$expected_result_dir/$testid.json",
		$update_expected_results
	);
}

done_testing();
