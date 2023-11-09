#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

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
	# check that the label overrides the en:non-vegan for "miel" / honey
	# (just for testing, it should not happen)
	[
		{lc => "fr", labels_tags => ["en:vegan"], ingredients_text => "miel"},
		["en:palm-oil-free", "en:vegan", "en:vegetarian"]
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

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is_deeply($product_ref->{ingredients_analysis_tags}, $expected_tags) or diag explain $product_ref;
}

done_testing();
