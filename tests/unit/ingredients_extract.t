#!/usr/bin/perl -w

# Tests of Ingredients::preparse_ingredients_text()

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

my @lists = (
	# en phrases_after_ingredients_list
	[
		"en",
		"carrots, green peas, corn, scallion. *adds a trivial amount of added sugars per serving.",
		"carrots, green peas, corn, scallion.",
	],
	# en ignore_phrases,
	[
		"en",
		"Egg White, Xanthan Gum (not applicable), Salt, Glucono-delta-lactone.",
		"Egg White, Xanthan Gum, Salt, Glucono-delta-lactone.",
	],
);

foreach my $test_ref (@lists) {
	my $lc = $test_ref->[0];    # Language
	my $ingredients_text_from_image = $test_ref->[1];
	my $cut_ingredients_text_from_image = cut_ingredients_text_for_lang($ingredients_text_from_image, $lc);
	print STDERR "input from the picture extraction (ingredients list ($lc)): $ingredients_text_from_image\n";
	print STDERR "cut_ingredients_text_from_image (result from sub routine): $cut_ingredients_text_from_image\n";
	my $expected = $test_ref->[2];
	is(lc($cut_ingredients_text_from_image), lc($expected))
		or print STDERR "Original ingredients: $ingredients_text_from_image ($lc)\n";
}

done_testing();
