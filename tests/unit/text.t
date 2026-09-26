#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;

use ProductOpener::Text qw/normalize_unicode_bold/;

# Test: no bold characters → unchanged
is(normalize_unicode_bold('Whey Powder (Milk)'), 'Whey Powder (Milk)', 'plain text unchanged');

# Test: single bold character bounded by word boundaries → wrapped in underscores
# 𝐌 = U+1D40C (Mathematical Bold Capital M)
is(normalize_unicode_bold("Whey Powder (\x{1D40C} Milk)"),
	'Whey Powder (_M_ Milk)', 'single bold char bounded → underscore-wrapped');

# Test: contiguous bold run bounded by word boundaries → wrapped in underscores
# 𝐒 = U+1D412, 𝐨 = U+1D428, 𝐲 = U+1D432, 𝐚 = U+1D41A
is(normalize_unicode_bold("Sugar, \x{1D412}\x{1D428}\x{1D432}\x{1D41A} Lecithin"),
	'Sugar, _Soya_ Lecithin', 'contiguous bold run bounded → underscore-wrapped');

# Test: bold run not bounded by word boundary on one side → plain ASCII
# 𝐌 = U+1D40C appended after a letter
is(normalize_unicode_bold("Whey\x{1D40C} Powder"),
	'WheyM Powder', 'bold char in middle of word → plain ASCII');

# Test: fullwidth bold characters → underscore-wrapped
# Ｌ = U+FF2C, Ａ = U+FF21, Ｂ = U+FF22
is(normalize_unicode_bold("Whey Power (\x{FF2C}\x{FF21}\x{FF22})"),
	'Whey Power (_LAB_)', 'fullwidth run → underscore-wrapped');

# Test: bold digit
# 𝟎 = U+1D7CE (Mathematical Bold Digit 0)
is(normalize_unicode_bold("E\x{1D7CE}100"),
	'E0100', 'bold digit not word-bounded → plain ASCII');

# Test: bold run at start and end of string (word-bounded on both sides)
# 𝐚 = U+1D41A, 𝐛 = U+1D41B
is(normalize_unicode_bold("\x{1D41A}\x{1D41B}"),
	'_ab_', 'bold run at start/end of string → underscore-wrapped');

# Test: empty string
is(normalize_unicode_bold(''), '', 'empty string returns empty string');

# Test: undefined input
is(normalize_unicode_bold(undef), undef, 'undefined input returns undefined');

done_testing();
