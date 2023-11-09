#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::FoodGroups qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Tags qw/:all/;

my @tests = (

	# Product without a category: no food groups
	[{}, []],
	# Products with categories
	[
		{
			"categories" => "milk chocolate",
		},
		['en:sugary-snacks', 'en:chocolate-products']
	],
	[
		{
			"categories" => "mackerels",
		},
		[
			'en:fish-meat-eggs',
			'en:fish-and-seafood',
			'en:fatty-fish'

		]
	],
	[
		{
			"categories" => "chicken thighs",
		},
		['en:fish-meat-eggs', 'en:meat', 'en:poultry']
	],
	# Check that if a meat is not poultry, we get a level 3 en:meat-other-than-poultry entry
	[
		{
			"categories" => "lamb leg",
		},
		['en:fish-meat-eggs', 'en:meat', 'en:meat-other-than-poultry']
	],
	# Beverages with added sugar should be in sweetened beverages
	[
		{
			"categories" => "beverages",
			"lc" => "en",
			"ingredients_text" => "water, high fructose corn syrup",
		},
		['en:beverages', 'en:sweetened-beverages']
	],
	# Alcoholic beverages with sugar should be in alcoholic beverages, not sweetened beverages
	[
		{
			"categories" => "beer",
			"lc" => "en",
			"ingredients_text" => "water, malt, sugar",
		},
		['en:alcoholic-beverages',]
	],
	# Beverages with > 80% milk should not be counted as beverages
	[
		{
			"categories" => "fruit and milk beverages",
			"lc" => "en",
			"ingredients_text" => "milk 90%, orange juice",
		},
		['en:milk-and-dairy-products', 'en:milk-and-yogurt']
	],
	# Beverages with < 80% milk should be counted as beverages
	[
		{
			"categories" => "fruit and milk beverages",
			"lc" => "en",
			"ingredients_text" => "milk 70%, orange juice",
		},
		['en:beverages', 'en:unsweetened-beverages']
	],
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];

	compute_field_tags($product_ref, "en", "categories");

	# We need to process the ingredient tags, as some food groups depend on the presence of sugar, sweeteners etc.
	if (defined $product_ref->{ingredients_text}) {
		extract_ingredients_from_text($product_ref);
	}

	compute_food_groups($product_ref);

	is_deeply($product_ref->{food_groups_tags}, $test_ref->[1]) or diag explain $product_ref;

}

done_testing();
