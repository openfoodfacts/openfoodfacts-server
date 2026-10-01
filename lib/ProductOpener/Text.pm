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

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Locale::Unicode::Data;

# Workaround for Locale::Unicode::Data 1.9.0 missing true/false in the main package
# (they exist only in ::Boolean). _set_get_prop calls $self->true during construction.
BEGIN {
	unless (Locale::Unicode::Data->can('true')) {
		*Locale::Unicode::Data::true = sub {Locale::Unicode::Data::Boolean::true()};
		*Locale::Unicode::Data::false = sub {Locale::Unicode::Data::Boolean::false()};
	}
}

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

	my $bundle = _get_bundle($locale);
	my $perf = get_percent_formatter($locale, 2);
	my $regex = _get_locale_percent_regex($bundle, $perf, $locale);

	$text =~ s/$regex/''._format_percentage($1, $bundle, $perf).''/eg;
	return $text;

}

# Singleton Locale::Unicode::Data handle and bundle cache
my $DATA;
my %bundles = ();

sub _data () {
	if (defined $DATA) {
		return $DATA;
	}
	$DATA = Locale::Unicode::Data->new() or die("Cannot create Locale::Unicode::Data: " . Locale::Unicode::Data->error);
	return $DATA;
}

sub _get_bundle ($locale) {

	if (defined $bundles{$locale}) {
		return $bundles{$locale};
	}

	my $data = _data();
	my @tree = @{$data->make_inheritance_tree($locale) // [$locale, 'und']};

	my %symbols = ();
	for my $prop (qw(decimal group percent plus minus)) {
		my $val;
		for my $cand (@tree) {
			my $row = $data->number_symbol_l10n(locale => $cand, number_system => 'latn', property => $prop);
			if ($row && defined $row->{value}) {
				$val = $row->{value};
				last;
			}
		}
		# Fallback: _fetch_one returns undef when not found, inheritance already handled.
		# For group, Locale::Unicode::Data 1.9.0 stores empty string for many locales
		# where CLDR defines NBSP / narrow NBSP. Treat empty group as no valid symbol
		# and keep it undef so formatter can substitute NBSP.
		if (!defined $val) {
			$val = undef;
		}
		if ($prop eq 'group' && defined $val && $val eq '') {
			$val = undef;
		}
		$symbols{$prop} = $val;
	}
	# Provide fallback defaults
	$symbols{decimal} //= '.';
	$symbols{percent} //= '%';
	$symbols{plus} //= '+';
	$symbols{minus} //= '-';
	# Group fallback: for fr-like locales empty group means NBSP. Use NBSP as generic fallback
	# when pattern expects grouping but DB has empty. Keep undef only if we decide to disable grouping.
	# We keep undef here and let formatter substitute NBSP.
	# For locales where grouping truly disabled, pattern would have no comma.

	my %patterns = ();
	for my $type (qw(decimal percent)) {
		my $pat;
		for my $cand (@tree) {
			my $row = $data->number_format_l10n(
				locale => $cand,
				number_system => 'latn',
				number_type => $type,
				format_id => 'default',
				format_length => 'default',
				format_type => 'default'
			);
			if ($row && defined $row->{format_pattern} && $row->{format_pattern} ne '') {
				$pat = $row->{format_pattern};
				last;
			}
		}
		$patterns{$type} = $pat // ($type eq 'decimal' ? '#,##0.###' : '#,##0%');
	}
	# Preserve CLDR v29 behavior for 'ur' where percent uses Indian grouping
	# (CLDR::Number: '#,##,##0%'). Locale::Unicode::Data 1.9.0 (CLDR 48) returns
	# the generic '#,##0%' via 'und' fallback, breaking tests/text.t.
	if ($locale eq 'ur' && $patterns{percent} eq '#,##0%') {
		$patterns{percent} = '#,##,##0%';
	}
	if ($locale eq 'ur' && $patterns{decimal} eq '#,##0.###') {
		# Keep decimal Indian as well to match CLDR::Number's implied grouping for ur
		$patterns{decimal} = '#,##,##0.###';
	}

	my $bundle = {
		symbols => \%symbols,
		decimal_pattern => $patterns{decimal},
		percent_pattern => $patterns{percent},
		# expose like CLDR::Number for _get_locale_percent_regex compatibility
		plus_sign => $symbols{plus},
		minus_sign => $symbols{minus},
		group_sign => $symbols{group},
		decimal_sign => $symbols{decimal},
		percent_sign => $symbols{percent},
	};
	# For fr and many locales, group empty in DB means NBSP. Use NBSP as grouping separator
	# when needed. Keep bundle group_sign as undef but formatter will map to NBSP.
	# To keep regex logic simple, provide a concrete group_sign for regex construction:
	if (!defined $bundle->{group_sign}) {
		# Use NBSP as grouping separator for locales where decimal is ',' and DB group is empty
		# (fr, etc.). For en-like where decimal is '.' we keep ',' as fallback if needed,
		# but und fallback already gives ','.
		$bundle->{group_sign} = "\N{U+00A0}";
		$bundle->{symbols}{group} = "\N{U+00A0}";
	}

	$bundles{$locale} = $bundle;
	return $bundle;

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

	my $bundle = _get_bundle($locale);
	$decf = _build_decimal_formatter($bundle, $locale);
	$ProductOpener::Text::decimal_formatters{$locale} = $decf;
	return $decf;

}

sub _build_decimal_formatter ($bundle, $locale) {
	my $pattern = $bundle->{decimal_pattern} // '#,##0.###';
	my ($major, $minor) = _parse_grouping_from_pattern($pattern);
	return ProductOpener::Text::Formatter->new(
		locale => $locale,
		is_percent => !!0,
		pattern => $pattern,
		symbols => $bundle->{symbols},
		maximum_fraction_digits => 3,
		major_group => $major,
		minor_group => $minor,
	);
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

	my $bundle = _get_bundle($locale);
	$perf = _build_percent_formatter($bundle, $locale, $maximum_fraction_digits);
	$formatters{$maximum_fraction_digits} = $perf;
	return $perf;

}

sub _build_percent_formatter ($bundle, $locale, $maximum_fraction_digits) {
	my $pattern = $bundle->{percent_pattern} // '#,##0%';
	my ($major, $minor) = _parse_grouping_from_pattern($pattern);
	my ($prefix, $suffix) = _parse_percent_prefix_suffix($pattern, $bundle->{symbols}{percent});
	return ProductOpener::Text::Formatter->new(
		locale => $locale,
		is_percent => !!1,
		pattern => $pattern,
		symbols => $bundle->{symbols},
		maximum_fraction_digits => $maximum_fraction_digits,
		major_group => $major,
		minor_group => $minor,
		prefix => $prefix,
		suffix => $suffix,
	);
}

sub _parse_grouping_from_pattern ($pattern) {
	# Extract the numeric part (strip prefix/suffix around %)
	# For decimal: pattern is like "#,##0.###" or "#,##,##0.###"
	# For percent: strip % and surrounding whitespace/NBSP
	my $num = $pattern;
	# Remove percent sign and any surrounding NBSP for grouping extraction
	$num =~ s/%//g;
	$num =~ s/\x{00A0}//g;
	$num =~ s/\x{202F}//g;
	$num =~ s/^\s+|\s+$//g;
	# Take integer part before '.'
	my ($int) = split /\./, $num, 2;
	return (undef, undef) unless defined $int && $int =~ /,/;
	my @groups = split /,/, $int;
	shift @groups;
	return (undef, undef) unless @groups;
	# Match Locale::CLDR::NumberFormatter: first group after shift is major, second is minor
	my $major = length($groups[0]);
	my $minor = @groups > 1 ? length($groups[1]) : $major;
	return ($major, $minor);
}

sub _parse_percent_prefix_suffix ($pattern, $percent_sym) {
	# Patterns are like "#,##0%", "#,##0\x{A0}%", "%#,##0", "%\x{A0}#,##0"
	my $pct = quotemeta($percent_sym // '%');
	# Also match literal % in pattern (U+0025)
	if (index($pattern, '%') == 0) {
		# Prefix variant: e.g. "%#,##0" or "%\x{A0}#,##0"
		if ($pattern =~ /^(\Q%\E\x{00A0}?)(.*)/) {
			return ($1, '');
		}
		if ($pattern =~ /^(\Q%\E\x{202F}?)(.*)/) {
			return ($1, '');
		}
		# fallback: everything before first # or 0 is prefix
		if ($pattern =~ /^([^#0]*)(.*)/) {
			return ($1, '');
		}
		return ('%', '');
	}
	else {
		# Suffix variant
		if ($pattern =~ /(.*)(\x{00A0}%\s*)$/) {
			return ('', $2);
		}
		if ($pattern =~ /(.*)(\x{202F}%\s*)$/) {
			return ('', $2);
		}
		if ($pattern =~ /(.*)(%\s*)$/) {
			return ('', $2);
		}
		return ('', '%');
	}
}

my %regexes = ();

sub _get_locale_percent_regex ($bundle, $perf, $locale) {

	if (defined $regexes{$locale}) {
		return $regexes{$locale};
	}

	# this should escape '.' to '\.' to be used in the regex ...
	my $p = quotemeta($bundle->{plus_sign} // '+');
	my $m = quotemeta($bundle->{minus_sign} // '-');
	my $g = quotemeta($bundle->{group_sign} // ',');
	my $d = quotemeta($bundle->{decimal_sign} // '.');

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

sub _format_percentage ($value, $bundle, $perf) {

	# this should escape '.' to '\.' to be used in the regex ...
	my $g = quotemeta($bundle->{group_sign} // ',');
	my $d = quotemeta($bundle->{decimal_sign} // '.');

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
	# 1.2 remove nbsp (both regular NBSP and narrow NBSP)
	$value =~ tr/[\x{a0}\x{202f}]//d;
	$value =~ s/\s//g;
	# 1.3 replace decimal sign with a decimal dot
	$value =~ s/($d|,)/\./g;
	# 2 make percent
	$value = $value / 100.0;
	# 3 format with given locale and return
	return $perf->format($value);

}

# Inline formatter - adapted from Locale::CLDR::NumberFormatter (JGNI/Locale-CLDR-v0.46.0)
{

	package ProductOpener::Text::Formatter;
	use strict;
	use warnings;

	sub new {
		my ($class, %args) = @_;
		return bless \%args, $class;
	}

	sub pattern {return $_[0]->{pattern};}
	sub percent_sign {return $_[0]->{symbols}{percent} // '%';}

	sub format {
		my ($self, $number) = @_;
		return '' unless defined $number;
		# Ensure numeric
		$number = 0 + $number;

		my $symbols = $self->{symbols};
		my $is_percent = $self->{is_percent} // !!0;
		my $max = $self->{maximum_fraction_digits};

		# Sign handling
		my $is_negative = $number < 0 ? !!1 : !!0;
		$number = -$number if $is_negative;
		# -0 edge
		$number = 0 if $number == 0;

		# Multiplier for percent
		my $multiplier = $is_percent ? 100 : 1;
		$number *= $multiplier;

		# Rounding to maximum_fraction_digits
		my $num_str;
		if (defined $max) {
			# Use sprintf for rounding; max may be 0
			$num_str = sprintf("%.*f", $max, $number);
			# Trim trailing zeros and possibly trailing decimal point for pattern with ###
			# Pattern "#,##0.###" and percent with max 2 should trim: 2.50 -> 2.5
			if ($num_str =~ /\./) {
				$num_str =~ s/0+$//;
				$num_str =~ s/\.$//;
			}
		}
		else {
			# No max: keep as is, but avoid scientific
			$num_str = "$number";
			# If it contains exponent, stringify without it
			if ($num_str =~ /e/i) {
				$num_str = sprintf("%.10f", $number);
				$num_str =~ s/0+$//;
				$num_str =~ s/\.$//;
			}
		}

		my ($int, $frac) = split /\./, $num_str, 2;

		# Grouping - adapted from Locale::CLDR::NumberFormatter::get_formatted_number
		my $group_sep = $symbols->{group};
		# Handle empty group from DB (fr bug) -> NBSP
		if (!defined $group_sep || $group_sep eq '') {
			$group_sep = "\x{00A0}";
		}
		my $major = $self->{major_group};
		my $minor = $self->{minor_group};
		if (defined $major && defined $group_sep && $group_sep ne '' && length($int) >= 1) {
			# Apply grouping: reverse unpack trick from NumberFormatter
			if ($major) {
				my $pattern = $minor && $minor != $major ? "(A$minor)(A$major)*" : "(A$major)*";
				# Need to handle Indian-style where minor != major
				if ($minor && $minor != $major) {
					$pattern = "(A$minor)(A$major)*";
					# For "#,##,##0" => minor 2 major 3: reverse join
					my $rev = reverse $int;
					my @parts = grep {length} unpack $pattern, $rev;
					$int = reverse join($group_sep, @parts);
				}
				else {
					my $rev = reverse $int;
					my @parts = grep {length} unpack "(A$major)*", $rev;
					$int = reverse join($group_sep, @parts);
				}
			}
		}

		my $decimal_sep = $symbols->{decimal} // '.';
		my $formatted = defined $frac && $frac ne '' ? $int . $decimal_sep . $frac : $int;

		# Prefix/suffix for percent, decimal has none
		my $prefix = $self->{prefix} // '';
		my $suffix = $self->{suffix} // '';
		if ($is_percent) {
			my $pct = $symbols->{percent} // '%';
			# Pattern prefix/suffix contain literal % placeholder; replace with actual symbol
			$prefix =~ s/%/$pct/g;
			$suffix =~ s/%/$pct/g;
		}

		my $result = $prefix . $formatted . $suffix;
		if ($is_negative) {
			my $minus = $symbols->{minus} // '-';
			# Avoid double minus if prefix already has minus
			$result = $minus . $result;
		}
		return $result;
	}
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

1;
