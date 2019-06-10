#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my @tests = (
[
	{
	lc => "fr",
	ingredients_text => "lait demi-écrémé 67%"
},
[ "en:semi-skimmed-milk"]
],
[
	{ lc => "fr",
	ingredients_text => "Saveur vanille : lait demi-écrémé 77%, sucre"},

[
	"fr:Saveur vanille",
	"en:semi-skimmed-milk",
	"en:sugar",
],
],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	extract_ingredients_from_text($product_ref);

	is_deeply ($product_ref->{ingredients_original_tags}, 
		$expected_tags) or diag explain $product_ref;
}


done_testing();
