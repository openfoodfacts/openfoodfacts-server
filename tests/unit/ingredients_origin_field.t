#!/usr/bin/perl -w

# Tests that the origin field is parsed for the first product analyzed by a process,
# when the origins regexps have not been built yet by parsing an ingredients list.
# These cases need a process of their own, so keep them in this file.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Ingredients qw/extract_ingredients_from_text/;

sub origins_from_origin_field() {
	my $product_ref = {
		lc => "fr",
		ingredients_text_fr => "Sardines 69%, huile d'olive vierge extra 29%, sel.",
		origin_fr => "Origine des sardines : France, Origine de l'huile d'olive vierge : Espagne",
	};
	extract_ingredients_from_text($product_ref);
	return {
		specific_ingredients => [map {[$_->{id}, $_->{origins}]} @{$product_ref->{specific_ingredients}}],
		ingredients => {map {$_->{id} => $_->{origins}} grep {defined $_->{origins}} @{$product_ref->{ingredients}}},
	};
}

my $expected = {
	specific_ingredients => [["en:sardine", "en:france"], ["en:virgin-olive-oil", "en:spain"]],
	ingredients => {"en:sardine" => "en:france", "en:extra-virgin-olive-oil" => "en:spain"},
};

is(origins_from_origin_field(), $expected, "first product analyzed by the process");
is(origins_from_origin_field(), $expected, "second product analyzed by the process");

done_testing();
