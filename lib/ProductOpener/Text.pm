# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

package ProductOpener::Text;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&normalize_percentages
					
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

 use vars @EXPORT_OK ;

 use CLDR::Number;
 use CLDR::Number::Format::Percent;

sub normalize_percentages($$) {

	my ($text, $locale) = @_;

	my $cldr = CLDR::Number->new(locale => $locale);
	my $perf = $cldr->percent_formatter( maximum_fraction_digits => 2 );
	my $regex = _get_locale_percent_regex($cldr, $perf);

	$text =~ s/$regex/''._format_percentage($1, $cldr, $perf).''/eg;
	return $text;

}

%ProductOpener::Text::regexes = ();
sub _get_locale_percent_regex($$) {

	my ($cldr, $perf) = @_;

	my $locale = $cldr->locale;
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
		$regex = qr/(%\h*[$p$m]?(?:\d{3}$g)*\d+(?:$d\d+)*)/;
	}
	else {
		$regex = qr/([$p$m]?(?:\d{3}$g)*\d+(?:$d\d+)*\h*%)/;
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
	$value =~ s/$g//g;
	# 1.2 replace decimal sign with a decimal dot
	$value =~ s/$d/\./g;
	# 2 make percent
	$value = $value / 100.0;
	# 3 format with given locale and return
	return $perf->format($value);

}

1;
