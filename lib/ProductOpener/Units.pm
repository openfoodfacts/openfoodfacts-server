# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

ProductOpener::Units - functions to convert units

=head1 DESCRIPTION

=cut

package ProductOpener::Units;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&unit_to_g
		&g_to_unit

		&unit_to_kcal

		&unit_to_mmoll
		&mmoll_to_unit

		&normalize_serving_size
		&normalize_quantity

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Numbers qw/:all/;

=head1 FUNCTIONS

=head2 unit_to_kcal($value, $unit)

Converts <xx><unit> into <xx> kcal.

=cut

sub unit_to_kcal ($value, $unit) {
	$unit = lc($unit);

	(not defined $value) and return $value;

	($unit eq 'kj') and return int($value / 4.184 + 0.5);

	# return value without modification if it's already in kcal
	return $value + 0;    # + 0 to make sure the value is treated as number
}

=head2 unit_to_g($value, $unit)

Converts <xx><unit> into <xx>grams. Eg.:
unit_to_g(2,kg) => returns 2000
unit_to_g(520,mg) => returns 0.52

=cut

# This is a key:value pairs
# The keys are the unit names and the values are the multipliers we can use to convert to a standard unit.
# We can divide by these values to do the reverse ie, Convert from standard to non standard
my %unit_conversion_map = (
	# kg = 公斤 - gōngjīn = кг
	"\N{U+516C}\N{U+65A4}" => 1000,
	# l = 公升 - gōngshēng = л = liter
	"\N{U+516C}\N{U+5347}" => 1000,
	'kg' => 1000,
	'kgs' => 1000,
	'кг' => 1000,
	'l' => 1000,
	'liter' => 1000,
	'liters' => 1000,
	'л' => 1000,
	# mg = 毫克 - háokè = мг
	"\N{U+6BEB}\N{U+514B}" => 0.001,
	'mg' => 0.001,
	'мг' => 0.001,
	'mcg' => 0.000001,
	'µg' => 0.000001,
	'oz' => 28.349523125,
	'fl oz' => 30,
	'dl' => 100,
	'дл' => 100,
	'cl' => 10,
	'кл' => 10,
	# 斤 - jīn = 500 Grams
	"\N{U+65A4}" => 500,
	# Standard units: No conversion units
	# Value without modification if it's already grams or 克 (kè) or 公克 (gōngkè) or г
	'g' => 1,
	'' => 1,
	' ' => 1,
	'kj' => 1,
	'克' => 1,
	'公克' => 1,
	'г' => 1,
	'мл' => 1,
	'ml' => 1,
	'mmol/l' => 1,
	"\N{U+6BEB}\N{U+5347}" => 1,
	'% vol' => 1,
	'ph' => 1,
	'%' => 1,
	'% dv' => 1,
	'% vol (alcohol)' => 1,
	'iu' => 1,
	# Division factors for "non standard unit" to mmoll conversions
	'mol/l' => 0.001,
	'mval/l' => 2,
	'ppm' => 100,
	"\N{U+00B0}rh" => 40.080,
	"\N{U+00B0}fh" => 10.00,
	"\N{U+00B0}e" => 7.02,
	"\N{U+00B0}dh" => 5.6,
	'gpg' => 5.847,
	'lb' => 453.59237,
	'lbs' => 453.59237,
	'pound' => 453.59237,
	'pounds' => 453.59237,
);

sub unit_to_g ($value, $unit) {
	$unit = lc($unit);

	if ($unit =~ /^(fl|fluid)(\.| )*(oz|once|ounce)/) {
		$unit = "fl oz";
	}

	(not defined $value) and return $value;

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;
	$value eq '' and return $value;

	if (exists($unit_conversion_map{$unit})) {
		return $value * $unit_conversion_map{$unit};
	}

	(($unit eq 'kcal') or ($unit eq 'ккал')) and return int($value * 4.184 + 0.5);

	# We return with + 0 to make sure the value is treated as number (needed when outputting json and to store in mongodb as a number)
	# lets not assume that we have a valid unit
	return;
}

=head2 g_to_unit($value, $unit)

Converts <xx>grams into <xx><unit>. Eg.:
g_to_unit(2000,kg) => returns 2
g_to_unit(0.52,mg) => returns 520

=cut

sub g_to_unit ($value, $unit) {
	$unit = lc($unit);

	if ((not defined $value) or ($value eq '')) {
		return "";
	}

	$unit eq 'fl. oz' and $unit = 'fl oz';
	$unit eq 'fl.oz' and $unit = 'fl oz';

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;

	$value eq '' and return $value;

	# Divide with the values in the hash
	if (exists($unit_conversion_map{$unit})) {
		return $value / $unit_conversion_map{$unit};
	}

	(($unit eq 'kcal') or ($unit eq 'ккал')) and return int($value / 4.184 + 0.5);

	# return value without modification if unit is already grams or 克 (kè) or 公克 (gōngkè) or г
	return $value + 0;
	# + 0 to make sure the value is treated as number
	# (needed when outputting json and to store in mongodb as a number)
}

sub unit_to_mmoll ($value, $unit) {
	$unit = lc($unit);

	if ((not defined $value) or ($value eq '')) {
		return '';
	}

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;

	# Divide with the values in the hash
	if (exists($unit_conversion_map{$unit})) {
		return $value / $unit_conversion_map{$unit};
	}

	return $value + 0;
}

sub mmoll_to_unit ($value, $unit) {
	$unit = lc($unit);

	if ((not defined $value) or ($value eq '')) {
		return '';
	}

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;

	# Multiply with the values in the hash
	if (exists($unit_conversion_map{$unit})) {
		return $value * $unit_conversion_map{$unit};
	}

	return $value + 0;
}

my $international_units = qr/kg|kgs|g|mg|µg|oz|l|dl|cl|ml|(fl(\.?)(\s)?oz|lb|lbs|pound|pounds)/i;
# Chinese units: a good start is https://en.wikipedia.org/wiki/Chinese_units_of_measurement#Mass
my $chinese_units = qr/
	(?:[\N{U+6BEB}\N{U+516C}]?\N{U+514B})|  # 毫克 or 公克 or 克 or (克 kè is the Chinese word for gram)
	                                        #                      (公克 gōngkè is for "metric gram")
	(?:\N{U+516C}?\N{U+65A4})|              # 公斤 or 斤 or         (公斤 gōngjīn is a "metric kg")
	(?:[\N{U+6BEB}\N{U+516C}]?\N{U+5347})|  # 毫升 or 公升 or 升     (升 is liter)
	\N{U+5428}                              # 吨                    (ton?)
	/ix;
my $russian_units = qr/г|мг|кг|л|дл|кл|мл/i;
my $units = qr/$international_units|$chinese_units|$russian_units/i;

=head2 normalize_quantity($quantity)

Returns the size in g or ml for the whole product. Eg.:
normalize_quantity(1 barquette de 40g) returns 40
normalize_quantity(20 tranches 500g)   returns 500
normalize_quantity(6x90g)              returns 540
normalize_quantity(2kg)                returns 2000

Returns undef if no quantity was detected.

=cut

sub normalize_quantity ($quantity) {

	my $q = undef;
	my $u = undef;

	# 12 pots x125 g
	# 6 bouteilles de 33 cl
	# 6 bricks de 1 l
	# 10 unités, 170 g
	# 4 bouteilles en verre de 20cl
	if ($quantity =~ /(\d+)(\s(\p{Letter}| )+)?(\s)?( de | of |x|\*)(\s)?((\d+)(\.|,)?(\d+)?)(\s)?($units)\s*\b/i) {
		my $m = $1;
		$q = lc($7);
		$u = $12;
		$q = convert_string_to_number($q);
		$q = unit_to_g($q * $m, $u);
	}
	elsif ($quantity =~ /((\d+)(\.|,)?(\d+)?)(\s)?($units)\s*\b/i) {
		$q = lc($1);
		$u = $6;
		$q = convert_string_to_number($q);
		$q = unit_to_g($q, $u);
	}

	return $q;
}

=head2 normalize_serving_size($serving)

Returns the size in g or ml for the serving. Eg.:
normalize_serving_size(1 barquette de 40g)->returns 40
normalize_serving_size(2.5kg)->returns 2500

=cut

sub normalize_serving_size ($serving) {

	# Regex captures any <number>( )?<unit-identifier> group, but leaves allowances for a preceding
	# token to allow for patterns like "One bag (32g)", "1 small bottle (180ml)" etc
	if ($serving =~ /^(.*[ \(])?(?<quantity>(\d+)(\.|,)?(\d+)?)( )?(?<unit>\w+)\b/i) {
		my $q = $+{quantity};
		my $u = normalize_unit($+{unit});
		$q = convert_string_to_number($q);

		return unit_to_g($q, $u);
	}

	#$log->trace("serving size normalized", { serving => $serving, q => $q, u => $u }) if $log->is_trace();
	return;
}

# @todo we should have equivalences for more units if we are supporting this
my @unit_equivalences_list = (
	['g', qr/gram(s)?/],
	['g', qr/gramme(s)?/],    # French
);

=head2 normalize_unit ( $unit )

Normalizes units to their standard symbolic forms so that we can support unit names and alternative
representations in our normalization logic.

=cut

sub normalize_unit ($originalUnit) {

	foreach my $unit_name (@unit_equivalences_list) {
		if ($originalUnit =~ $unit_name->[1]) {
			return $unit_name->[0];
		}
	}

	return $originalUnit;
}

1;

