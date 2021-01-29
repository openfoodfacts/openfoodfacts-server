#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
#use Log::Any::Adapter 'TAP';
use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

my @ingredients = (

	[ "en", "bananas",         "yes" ],
	[ "en", "flour",           undef ],
	[ "fr", "fraises",         "yes" ],
	[ "fr", "noisettes",       "yes" ],
	[ "fr", "légumes",         "yes" ],
	[ "fr", "pommes de terre", "no" ],
);

foreach my $test_ref (@ingredients) {

	my $ingredient_id = canonicalize_taxonomy_tag($test_ref->[0], "ingredients", $test_ref->[1]);

	is(get_inherited_property("ingredients", $ingredient_id, "nutriscore_fruits_vegetables_nuts:en"), $test_ref->[2]);;

}


# dummy product for testing

my @tests = (
[ { lc => "fr", ingredients_text => "" }, undef ],
[ { lc => "fr", ingredients_text => "eau, sucre, noisettes" }, 0 ],
[ { lc => "fr", ingredients_text => "banane 50%, fraise 30%, eau" }, 80 ],
[ { lc => "fr", ingredients_text => "banane 50%, gâteau (fraise 30%, framboise 5%, farine), eau" }, 85 ],
[ { lc => "fr", ingredients_text => "banane, gâteau (fraise 30%, framboise 5%, farine), eau" }, 70 ],
[ { lc => "fr", ingredients_text => "Courgette grillée 37,5%, tomate pelée 20%, poivron jaune 17%, oignon rouge grillé 8%, eau, huile d'olive vierge extra 3,9%, oignon, olive noire entière dénoyautée saumurée 2,5% (olive, eau, sel, correcteurs d'acidité : acide citrique, acide lactique), ail, basilic 0,9%, amidon de riz, sel" }, 89.8 ],
);


foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_fruits = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is (
		(defined $product_ref->{nutriments} ? $product_ref->{nutriments}{"fruits-vegetables-nuts-estimate-from-ingredients_100g"} : undef),
		$expected_fruits
	) or diag explain $product_ref->{ingredients};
}

done_testing();

