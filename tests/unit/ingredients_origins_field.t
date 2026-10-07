#!/usr/bin/perl -w

# Tests of the parsing of the origins field (origin_[lc]) by extract_ingredients_from_text()
#
# Note: this test is in its own file on purpose, so that it runs in a new process:
# extract_ingredients_from_text() parses the origins field before the ingredients list,
# and the origins regexps used to be initialized only when the ingredients list was parsed,
# so the origins field of the first product processed by a new process (e.g. a new Apache worker)
# was silently ignored.

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Ingredients qw/extract_ingredients_from_text/;

my $product_ref = {
	lc => "fr",
	ingredients_text => "Sardines, huile d'olive vierge extra, sel",
	origin_fr => "Origine des sardines : France, Origine de l'huile d'olive vierge : Espagne",
};

extract_ingredients_from_text($product_ref);

# Origins of specific ingredients extracted from the origins field
is(
	[map {{id => $_->{id}, origins => $_->{origins}}} @{$product_ref->{specific_ingredients} || []}],
	[{id => "en:sardine", origins => "en:france"}, {id => "en:virgin-olive-oil", origins => "en:spain"}],
	"specific ingredients are extracted from the origins field in a new process"
) || diag(Dumper($product_ref->{specific_ingredients}));

# Origins assigned to the matching ingredients of the ingredients list
# (extra virgin olive oil is a child of virgin olive oil)
is(
	[map {{id => $_->{id}, origins => $_->{origins}}} @{$product_ref->{ingredients} || []}],
	[
		{id => "en:sardine", origins => "en:france"},
		{id => "en:extra-virgin-olive-oil", origins => "en:spain"},
		{id => "en:salt", origins => undef},
	],
	"origins are assigned to the ingredients that match the specific ingredients"
) || diag(Dumper($product_ref->{ingredients}));

done_testing();
