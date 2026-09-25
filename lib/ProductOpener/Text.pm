# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Text - formats decimal numbers and percentages according to locale.

=head1 SYNOPSIS

C<ProductOpener::Text> is used to format decimal numbers and percentages according to locale. 
	
	use ProductOpener::Text qw/:all/;
	
	my $decf = get_decimal_formatter($lc);
	my $perf = get_percent_formatter($lc, 0);
	$salt = $decf->format(g_to_unit($salt, $unit));
	$percent = $perf->format($percent / 100.0);

=head1 DESCRIPTION

The module implements decimal formatting, percent formatting and normalization of percentages on the basis of locale.
Different languages can have different representation for decimal sign and can have different positions for the placement of percent in a value.
The decimal sign could be a '.' (most languages), or it could be a ',' (de - DECIMAL POINT IS COMMA ;-)

=cut

package ProductOpener::Text;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&normalize_percentages

		&get_decimal_formatter
		&get_percent_formatter
		&escape_char
		&escape_single_quote_and_newlines

		&remove_tags_and_quote
		&xml_escape
		&regexp_escape
		&remove_email

		&normalize_unicode_bold

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use CLDR::Number;
use CLDR::Number::Format::Percent;
use Unicode::UCD qw(charinfo);

=head1 FUNCTIONS

=head2 normalize_percentages( TEXT, LOCALE )

C<normalize_percentages()> returns formatted percentage value on the basis of locale since every language has different standards for writing percentage and decimal values.

=head3 Arguments

Two scalar variables text and locale are passed as arguments. Locale is two letter language code (ur for Urdu, de for German, en for English, etc)

=head3 Return values

The function returns a scalar variable that is the result of concatenation of regex, percentage formatting on locale basis. 
If text (scalar variable passed as argument) is not defined or percent sign is not found, the function simply returns the scalar variable text(passed as argument) for performance reasons.

=cut

sub normalize_percentages ($text, $locale) {

	# Bail out of this function if no known percent sign is found.
	# This is purely for performance reasons: CLDR functions are
	# comparatively expensive to run.
	if (
		(not(defined $text))
		or (
			not(   (index($text, "\N{U+0025}") > -1)
				or (index($text, "\N{U+066A}") > -1)
				or (index($text, "\N{U+FE6A}") > -1)
				or (index($text, "\N{U+FF05}") > -1)
				or (index($text, "\N{U+E0025}") > -1))
		)
		)
	{
		return $text;
	}

	my $cldr = _get_cldr($locale);
	my $perf = get_percent_formatter($locale, 2);
	my $regex = _get_locale_percent_regex($cldr, $perf, $locale);

	$text =~ s/$regex/''._format_percentage($1, $cldr, $perf).''/eg;
	return $text;

}

my %cldrs = ();

sub _get_cldr ($locale) {

	if (defined $cldrs{$locale}) {
		return $cldrs{$locale};
	}

	my $cldr = CLDR::Number->new(locale => $locale);
	$cldrs{$locale} = $cldr;
	return $cldr;

}

=head2 get_decimal_formatter( LOCALE )

C<get_decimal_formatter()> formats decimal numbers. It can parse and format decimal numbers in any locale. The formatting is locale sensitive.
This function allows to control the display of leading and trailing zeros, grouping separators, and the decimal separator.
Different languages can have different representation for decimal sign.
The decimal sign could be a '.' (most languages), or it could be a ',' (de - DECIMAL POINT IS COMMA ;-)

=head3 Arguments

A scalar variable locale is passed as argument. Locale is two letter language code (ur for Urdu, de for German, en for English, etc)

=head3 Return values

The function returns a scalar variable that is formatted on the basis of locale.

=cut

%ProductOpener::Text::decimal_formatters = ();

sub get_decimal_formatter ($locale) {

	my $decf = $ProductOpener::Text::decimal_formatters{$locale};
	if (defined $decf) {
		return $decf;
	}

	my $cldr = _get_cldr($locale);
	$decf = $cldr->decimal_formatter;
	$ProductOpener::Text::decimal_formatters{$locale} = $decf;
	return $decf;

}

=head2 escape_char( $s, $char )

Escape character $char in string $s

This is use in templates to say escape single quote or double quote
for expressions displayed with single/double quotes (in json or HTML for example)

=cut

sub escape_char($s, $char) {
	if ($s && $char) {
		# normalize already escaped chars to avoid double escaping
		$s =~ s/\\$char/$char/g;
		$s =~ s/$char/\\$char/g;
	}
	return $s;
}

=head2 escape_single_quote_and_newlines( $s )

Escape single quotes in $s but also transform newlines to spaces

=cut

sub escape_single_quote_and_newlines ($s) {

	if (not defined $s) {
		return '';
	}
	# some app escape single quotes already, so we have \' already
	$s =~ s/\\'/'/g;
	$s =~ s/'/\\'/g;
	$s =~ s/\n/ /g;
	return $s;
}

=head2 get_percent_formatter( LOCALE, MAXIMUM_FRACTION_DIGITS )

C<get_percent_formatter()> formats percentages according to locale. The formatting is locale sensitive.

=head3 Arguments

A scalar variable locale and maximum_fraction_digits are passed as argument. Locale is two letter language code (ur for Urdu, de for German, en for English, etc)
maximum_fraction_digits sets the maximum number of digits allowed in the fraction portion of a number.

=head3 Return values

The function returns a scalar variable of percentage value that is formatted by a locale-specific formatter.

=cut

%ProductOpener::Text::percent_formatters = ();

sub get_percent_formatter ($locale, $maximum_fraction_digits) {

	my $formatters_ref = $ProductOpener::Text::percent_formatters{$locale};
	my %formatters;
	if (not(defined $formatters_ref)) {
		%formatters = ();
		$formatters_ref = \%formatters;
		$ProductOpener::Text::percent_formatters{$locale} = $formatters_ref;
	}
	else {
		%formatters = %{$formatters_ref};
	}

	my $perf = $formatters{$maximum_fraction_digits};
	if (defined $perf) {
		return $perf;
	}

	my $cldr = _get_cldr($locale);
	$perf = $cldr->percent_formatter(maximum_fraction_digits => $maximum_fraction_digits);
	$formatters{$maximum_fraction_digits} = $perf;
	return $perf;

}

my %regexes = ();

sub _get_locale_percent_regex ($cldr, $perf, $locale) {

	if (defined $regexes{$locale}) {
		return $regexes{$locale};
	}

	# this should escape '.' to '\.' to be used in the regex ...
	my $p = quotemeta($cldr->plus_sign);
	my $m = quotemeta($cldr->minus_sign);
	my $g = quotemeta($cldr->group_sign);
	my $d = quotemeta($cldr->decimal_sign);

	# [+-]?(?:\d{3}\.)*\d+(?:,\d+)*\h*% where . is the group sign from the locale, and , is the decimal point - or other way around for tr etc.
	my $regex;
	if (index($perf->pattern, $perf->percent_sign) == 0) {
		$regex = qr/(%\h*[$p$m]?(?:\d{1,3}$g)*\d+(?:($d|\.)\d+)*)/;
	}
	else {
		$regex = qr/([$p$m]?(?:\d{1,3}$g)*\d+(?:($d|\.)\d+)*\h*%)/;
	}

	$regexes{$locale} = $regex;
	return $regex;

}

sub _format_percentage ($value, $cldr, $perf) {

	# this should escape '.' to '\.' to be used in the regex ...
	my $g = quotemeta($cldr->group_sign);
	my $d = quotemeta($cldr->decimal_sign);

	# 1 make the string float parseable by Perl
	# 1.1 remove % and group sign
	$value =~ tr/%//d;
	# if the last group sign is not followed by 3 digits,
	# assume it is in fact a decimal sign.
	# e.g. in French 2,50 is the right form, but 2.50 is very common.
	if ($value !~ /$g(\d{1,2}|\d{4,10})$/) {
		$value =~ s/$g//g;
	}
	else {
		$value =~ s/$g/\./;
	}
	# 1.2 remove nbsp
	$value =~ tr/[\x{a0}]//d;
	# 1.3 replace decimal sign with a decimal dot
	$value =~ s/($d|,)/\./g;
	# 2 make percent
	$value = $value / 100.0;
	# 3 format with given locale and return
	return $perf->format($value);

}

sub remove_tags_and_quote ($s) {

	if (not defined $s) {
		$s = "";
	}

	# Remove tags
	$s =~ s/<(([^>]|\n)*)>//g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/"/&quot;/g;

	# Remove whitespace
	$s =~ s/^\s+|\s+$//g;

	return $s;
}

sub xml_escape ($s) {

	# Remove tags
	$s =~ s/<(([^>]|\n)*)>//g;
	$s =~ s/\&/\&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/"/&quot;/g;

	# Remove whitespace
	$s =~ s/^\s+|\s+$//g;

	return $s;

}

sub regexp_escape ($s) {
	$s =~ s/(\*|\+|\?|\(|\)|\[|\]|\{|\}|\$|\^|\\|\/|\@|\%)/\\$1/g;
	return $s;
}

sub remove_email ($s) {
	# Removes email patterns
	$s =~ s/\b[\w.-]+@[\w.-]+\.[A-Za-z]{2,}\b//g;
	return $s;
}

sub remove_tags ($s) {

	# Remove tags
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;

	return $s;
}

=head2 normalize_unicode_bold( $text )

Normalize Unicode "letter-like" bold and stylistic variant characters found in
ingredient lists (e.g. Mathematical Bold letters U+1D400–U+1D433, Mathematical
Italic, Bold Fraktur, Sans-Serif variants, Fullwidth letters, etc.) into their
plain ASCII equivalents.

When a contiguous run of such characters is bounded by word boundaries (i.e.
the characters before and after the run are not letters or digits), the run is
wrapped in underscore characters (e.g. C<_Milk_>) so that the existing
underscore-based emphasis/allergen syntax in ingredient analysis is triggered.
Runs that are not bounded by word boundaries are converted to plain ASCII
without underscores.

=cut

sub normalize_unicode_bold ($text) {

	return $text unless defined $text;

	my $result = '';
	my $i = 0;
	my $len = length($text);

	while ($i < $len) {
		my $char = substr($text, $i, 1);

		# Determine if this character is a Unicode "bold" / stylistic variant
		my $ascii_char = _unicode_bold_to_ascii($char);

		if (defined $ascii_char) {
			# Collect the maximal run of Unicode bold variant characters
			my $run_start = $i;
			my $converted = $ascii_char;
			$i++;

			while ($i < $len) {
				my $next_char = substr($text, $i, 1);
				my $next_ascii = _unicode_bold_to_ascii($next_char);
				if (defined $next_ascii) {
					$converted .= $next_ascii;
					$i++;
				}
				else {
					last;
				}
			}

			# Check if the run is bounded by non-letter/non-digit characters
			# on both sides (word boundary), so it forms a complete "word"
			my $before_ok = 1;
			if ($run_start > 0) {
				my $before_char = substr($text, $run_start - 1, 1);
				$before_ok = _is_word_boundary($before_char);
			}

			my $after_ok = 1;
			if ($i < $len) {
				my $after_char = substr($text, $i, 1);
				$after_ok = _is_word_boundary($after_char);
			}

			if ($before_ok && $after_ok) {
				$result .= '_' . $converted . '_';
			}
			else {
				$result .= $converted;
			}
		}
		else {
			# Regular character, keep as-is
			$result .= $char;
			$i++;
		}
	}

	return $result;
}

sub _is_word_boundary ($char) {
	# A word boundary is any character that is NOT a letter or digit
	# (letters include Unicode letters, digits include Unicode digits)
	return 0 if $char =~ /\p{Letter}/;
	return 0 if $char =~ /\p{Digit}/;
	return 1;
}

sub _unicode_bold_to_ascii ($char) {
	# Unicode code point
	my $code = ord($char);

	# Mathematical Bold uppercase A-Z: U+1D400 - U+1D419
	if ($code >= 0x1D400 && $code <= 0x1D419) {
		return chr(ord('A') + ($code - 0x1D400));
	}

	# Mathematical Bold lowercase a-z: U+1D41A - U+1D433
	if ($code >= 0x1D41A && $code <= 0x1D433) {
		return chr(ord('a') + ($code - 0x1D41A));
	}

	# Mathematical Italic uppercase A-Z: U+1D434 - U+1D44D
	if ($code >= 0x1D434 && $code <= 0x1D44D) {
		return chr(ord('A') + ($code - 0x1D434));
	}

	# Mathematical Italic lowercase a-z: U+1D44E - U+1D467
	if ($code >= 0x1D44E && $code <= 0x1D467) {
		return chr(ord('a') + ($code - 0x1D44E));
	}

	# Mathematical Bold Fraktur uppercase (some letters): U+1D504 - U+1D51C
	if ($code >= 0x1D504 && $code <= 0x1D51C) {
		return chr(ord('A') + ($code - 0x1D504));
	}

	# Mathematical Bold Fraktur lowercase (some letters): U+1D51E - U+1D537
	if ($code >= 0x1D51E && $code <= 0x1D537) {
		return chr(ord('a') + ($code - 0x1D51E));
	}

	# Mathematical Bold Script uppercase: U+1D468 - U+1D481
	if ($code >= 0x1D468 && $code <= 0x1D481) {
		return chr(ord('A') + ($code - 0x1D468));
	}

	# Mathematical Bold Script lowercase: U+1D482 - U+1D49B
	if ($code >= 0x1D482 && $code <= 0x1D49B) {
		return chr(ord('a') + ($code - 0x1D482));
	}

	# Mathematical Sans-Serif Bold uppercase: U+1D5A0 - U+1D5B9
	if ($code >= 0x1D5A0 && $code <= 0x1D5B9) {
		return chr(ord('A') + ($code - 0x1D5A0));
	}

	# Mathematical Sans-Serif Bold lowercase: U+1D5BA - U+1D5D3
	if ($code >= 0x1D5BA && $code <= 0x1D5D3) {
		return chr(ord('a') + ($code - 0x1D5BA));
	}

	# Fullwidth uppercase letters: U+FF21 - U+FF3A
	if ($code >= 0xFF21 && $code <= 0xFF3A) {
		return chr(ord('A') + ($code - 0xFF21));
	}

	# Fullwidth lowercase letters: U+FF41 - U+FF5A
	if ($code >= 0xFF41 && $code <= 0xFF5A) {
		return chr(ord('a') + ($code - 0xFF41));
	}

	# Mathematical Monospace: U+1D670 - U+1D689
	if ($code >= 0x1D670 && $code <= 0x1D689) {
		return chr(ord('a') + ($code - 0x1D670));
	}

	# Bold digits 0-9: U+1D7CE - U+1D7D7
	if ($code >= 0x1D7CE && $code <= 0x1D7D7) {
		return chr(ord('0') + ($code - 0x1D7CE));
	}

	return undef;
}

1;
