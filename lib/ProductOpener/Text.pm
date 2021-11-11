# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&normalize_percentages

		&get_decimal_formatter
		&get_percent_formatter

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

 use vars @EXPORT_OK ;

 use CLDR::Number;
 use CLDR::Number::Format::Percent;

=head1 FUNCTIONS

=head2 normalize_percentages( TEXT, LOCALE )

C<normalize_percentages()> returns formatted percentage value on the basis of locale since every language has different standards for writing percentage and decimal values.

=head3 Arguments

Two scalar variables text and locale are passed as arguments. Locale is two letter language code (ur for Urdu, de for German, en for English, etc)

=head3 Return values

The function returns a scalar variable that is the result of concatenation of regex, percentage formatting on locale basis. 
If text (scalar variable passed as argument) is not defined or percent sign is not found, the function simply returns the scalar variable text(passed as argument) for performance reasons.

=cut

sub normalize_percentages($$) {

	my ($text, $locale) = @_;

	# Bail out of this function if no known percent sign is found.
	# This is purely for performance reasons: CLDR functions are
	# comparatively expensive to run.
	if ((not (defined $text))
		or (not ((index($text, "\N{U+0025}") > -1)
		or (index($text, "\N{U+066A}") > -1)
		or (index($text, "\N{U+FE6A}") > -1)
		or (index($text, "\N{U+FF05}") > -1)
		or (index($text, "\N{U+E0025}") > -1)))) {
			return $text;
	}

	my $cldr = _get_cldr($locale);
	my $perf = get_percent_formatter($locale, 2);
	my $regex = _get_locale_percent_regex($cldr, $perf, $locale);

	$text =~ s/$regex/''._format_percentage($1, $cldr, $perf).''/eg;
	return $text;

}

%ProductOpener::Text::cldrs = ();
sub _get_cldr {

	my ($locale) = @_;

	if (defined $ProductOpener::Text::cldrs{$locale}) {
		return $ProductOpener::Text::cldrs{$locale};
	}

	my $cldr = CLDR::Number->new(locale => $locale);
	$ProductOpener::Text::cldrs{$locale} = $cldr;
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
sub get_decimal_formatter {

	my ($locale) = @_;

	my $decf = $ProductOpener::Text::decimal_formatters{$locale};
	if (defined $decf) {
		return $decf;
	}

	my $cldr = _get_cldr($locale);
	$decf = $cldr->decimal_formatter;
	$ProductOpener::Text::decimal_formatters{$locale} = $decf;
	return $decf;

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
sub get_percent_formatter {

	my ($locale, $maximum_fraction_digits) = @_;

	my $formatters_ref = $ProductOpener::Text::percent_formatters{$locale};
	my %formatters;
	if (not (defined $formatters_ref)) {
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
	$perf = $cldr->percent_formatter( maximum_fraction_digits => $maximum_fraction_digits );
	$formatters{$maximum_fraction_digits} = $perf;
	return $perf;

}

%ProductOpener::Text::regexes = ();
sub _get_locale_percent_regex {

	my ($cldr, $perf, $locale) = @_;

	if (defined $ProductOpener::Text::regexes{$locale}) {
		return $ProductOpener::Text::regexes{$locale};
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

	$ProductOpener::Text::regexes{$locale} = $regex;
	return $regex;

}

sub _format_percentage($$$) {

	my ($value, $cldr, $perf) = @_;

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

1;
