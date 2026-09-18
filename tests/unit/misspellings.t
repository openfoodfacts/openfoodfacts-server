#!/usr/bin/perl -w

# Tests of ProductOpener::Misspellings

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use utf8;
use ProductOpener::Misspellings qw/apply_misspelling_replacements init_misspellings/;

# Test basic replacement (fr)
my $text = 'dès';
apply_misspelling_replacements("ingredients_misspellings", 'fr', \$text);
is($text, 'dés', 'basic fr misspelling replacement');

# Test case preservation - title case
$text = 'Dès';
apply_misspelling_replacements("ingredients_misspellings", 'fr', \$text);
is($text, 'Dés', 'case preserved (title case)');

# Test case preservation - all lowercase
$text = 'dès';
apply_misspelling_replacements("ingredients_misspellings", 'fr', \$text);
is($text, 'dés', 'case preserved (lowercase)');

# Test case preservation - all uppercase
$text = 'DÈS';
apply_misspelling_replacements("ingredients_misspellings", 'fr', \$text);
is($text, 'DÉS', 'case preserved (uppercase)');

# Test xx: with mixed-case target (output as-is)
$text = 'marks & spencers';
apply_misspelling_replacements("ingredients_brands_misspellings", 'en', \$text);
is($text, 'Marks & Spencer', 'xx: mixed-case target output as-is');

# Test xx: with all-uppercase input and mixed-case target
$text = 'MARKS & SPENCERS';
apply_misspelling_replacements("ingredients_brands_misspellings", 'en', \$text);
is($text, 'Marks & Spencer', 'xx: uppercase input with mixed-case target');

# Test no replacement when language does not match
$text = 'dès';
apply_misspelling_replacements("ingredients_misspellings", 'en', \$text);
is($text, 'dès', 'no replacement for non-matching language');

# Test word boundary (no partial match in a longer word)
$text = 'cadès';
apply_misspelling_replacements("ingredients_misspellings", 'fr', \$text);
is($text, 'cadès', 'no replacement inside longer words (word boundary)');

# Test multiple replacements in one string
$text = 'dès et dès';
apply_misspelling_replacements("ingredients_misspellings", 'fr', \$text);
is($text, 'dés et dés', 'multiple replacements in one string');

# Test ingredients_brands_misspellings in fr
$text = 'Cake marks & spencers';
apply_misspelling_replacements("ingredients_brands_misspellings", 'fr', \$text);
is($text, 'Cake Marks & Spencer', 'ingredients_brands_misspellings in fr');

done_testing();
