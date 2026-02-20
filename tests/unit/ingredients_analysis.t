#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/extract_ingredients_from_text/;

# dummy product for testing

my @tests = (
	[{lc => "fr", ingredients_text => ""}, undef],
	[{lc => "fr", ingredients_text => "eau, sucre, noisettes"}, ["en:palm-oil-free", "en:vegan", "en:vegetarian"]],
	[{lc => "fr", ingredients_text => "lait demi-écrémé 67%"}, ["en:palm-oil-free", "en:non-vegan", "en:vegetarian"]],
	[
		{lc => "fr", ingredients_text => "viande de boeuf, lait, sel"},
		["en:palm-oil-free", "en:non-vegan", "en:non-vegetarian"]
	],
	[{lc => "fr", ingredients_text => "huiles végétales"}, ["en:may-contain-palm-oil", "en:vegan", "en:vegetarian"]],
	[{lc => "fr", ingredients_text => "huile de palme"}, ["en:palm-oil", "en:vegan", "en:vegetarian"]],
	[{lc => "fr", ingredients_text => "huiles végétales (palme, colza)"}, ["en:palm-oil", "en:vegan", "en:vegetarian"]],
	[
		{lc => "fr", ingredients_text => "huiles végétales (tournesol, colza)"},
		["en:palm-oil-free", "en:vegan", "en:vegetarian"]
	],
	[
		{lc => "fr", ingredients_text => "huile de palme, unknown ingredient"},
		["en:palm-oil", "en:vegan-status-unknown", "en:vegetarian-status-unknown"]
	],
	[
		{lc => "fr", ingredients_text => "unknown ingredient"},
		["en:palm-oil-content-unknown", "en:vegan-status-unknown", "en:vegetarian-status-unknown"]
	],
	[
		{lc => "fr", ingredients_text => "sucre, unknown ingredient"},
		["en:palm-oil-content-unknown", "en:vegan-status-unknown", "en:vegetarian-status-unknown"]
	],
	[{lc => "fr", ingredients_text => "sucre, colorant: e150"}, ["en:palm-oil-free", "en:vegan", "en:vegetarian"]],
	[
		{lc => "en", ingredients_text => "fat, proteins"},
		["en:may-contain-palm-oil", "en:maybe-vegan", "en:maybe-vegetarian"]
	],
	[
		{lc => "en", ingredients_text => "vegetable fat, vegetable proteins"},
		["en:may-contain-palm-oil", "en:vegan", "en:vegetarian"]
	],
	[{lc => "en", ingredients_text => "modified palm oil"}, ["en:palm-oil", "en:vegan", "en:vegetarian"]],
	[{lc => "en", ingredients_text => "lactic ferments"}, ["en:palm-oil-free", "en:maybe-vegan", "en:vegetarian"]],
	[
		{lc => "fr", ingredients_text => "huiles végétales (huile de tournesol', huile de colza)"},
		["en:palm-oil-free", "en:vegan", "en:vegetarian"]
	],
	[{lc => "fr", ingredients_text => "huiles végétales"}, ["en:may-contain-palm-oil", "en:vegan", "en:vegetarian"]],
	[{lc => "fr", ingredients_text => "huile de poisson"}, ["en:palm-oil-free", "en:non-vegan", "en:non-vegetarian"]],

	# labels overrides

	[{lc => "fr", labels_tags => ["en:palm-oil-free"]}, ["en:palm-oil-free"]],
	[{lc => "fr", labels_tags => ["en:vegan"]}, ["en:vegan", "en:vegetarian"]],
	[{lc => "fr", labels_tags => ["en:vegetarian"]}, ["en:vegetarian"]],
	[{lc => "fr", labels_tags => ["en:non-vegetarian"]}, ["en:non-vegan", "en:non-vegetarian"]],
	[
		{lc => "fr", labels_tags => ["en:palm-oil-free"], ingredients_text => "huiles végétales"},
		["en:palm-oil-free", "en:vegan", "en:vegetarian"]
	],
	[{lc => "fr", ingredients_text => "miel"}, ["en:palm-oil-free", "en:non-vegan", "en:vegetarian"]],
	# check that products with conflicting label and ingredient information get set to a “maybe” status
	# these _shouldn’t_ exist, but sometimes they do
	[
		{lc => "fr", labels_tags => ["en:vegan"], ingredients_text => "miel"},
		["en:palm-oil-free", "en:maybe-vegan", "en:vegetarian"]
	],
	[
		{lc => "da", labels_tags => ["en:vegan"], ingredients_text => "kød"},
		["en:palm-oil-free", "en:maybe-vegan", "en:maybe-vegetarian"]
	],
	[
		{lc => "da", labels_tags => ["en:vegetarian"], ingredients_text => "kød"},
		["en:palm-oil-free", "en:non-vegan", "en:maybe-vegetarian"]
	],
	[
		{lc => "sv", labels_tags => ["en:palm-oil-free"], ingredients_text => "palmolja"},
		["en:may-contain-palm-oil", "en:vegan", "en:vegetarian"]
	],

	# unknown ingredients

	[{lc => "en", ingredients_text => ""}, undef],
	[
		{lc => "en", ingredients_text => "unknown ingredient"},
		["en:palm-oil-content-unknown", "en:vegan-status-unknown", "en:vegetarian-status-unknown"]
	],
	[
		{lc => "en", ingredients_text => "flour, unknown ingredient"},
		["en:palm-oil-content-unknown", "en:vegan-status-unknown", "en:vegetarian-status-unknown"]
	],
	# mark the product as palm oil free even though there is one unknown ingredients (out of many ingredients)
	[
		{lc => "en", ingredients_text => "flour, sugar, eggs, milk, salt, water, unknown ingredient"},
		["en:palm-oil-free", "en:non-vegan", "en:vegetarian-status-unknown"]
	],

	# vegan maybe ingredients
	[
		{lc => "en", ingredients_text => "coagulating enzyme"},
		["en:palm-oil-free", "en:maybe-vegan", "en:maybe-vegetarian"]
	],
	[
		{lc => "en", ingredients_text => "coagulating enzyme (vegetal)"},
		["en:palm-oil-free", "en:vegan", "en:vegetarian"]
	],
	[
		{lc => "en", ingredients_text => "something unknown (vegetal)"},
		["en:palm-oil-content-unknown", "en:vegan", "en:vegetarian"]
	],

	# unknown ingredient with sub ingredients: ignore the parent and use the sub ingredients to make the determination
	[
		{lc => "en", ingredients_text => "unknown ingredient (milk, sugar)"},
		["en:palm-oil-free", "en:non-vegan", "en:vegetarian"]
	],
	# known ingredient (but with no vegan / vegetarian property) with sub ingredients: use the sub ingredients to make the determination
	[
		{lc => "en", ingredients_text => "chocolate (milk, sugar)"},
		["en:palm-oil-free", "en:non-vegan", "en:vegetarian"]
	],
	# same with one unknown sub ingredient
	[
		{lc => "en", ingredients_text => "chocolate (milk, unknown ingredient)"},
		["en:palm-oil-free", "en:non-vegan", "en:vegetarian-status-unknown"]
	],
	# non vegan parent with vegan sub ingredients
	[
		{lc => "en", ingredients_text => "gelatin (sugar, water)"},
		["en:palm-oil-free", "en:non-vegan", "en:non-vegetarian"]
	],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is($product_ref->{ingredients_analysis_tags}, $expected_tags) or diag Dumper $product_ref;
}

done_testing();
