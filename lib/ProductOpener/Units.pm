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
use ProductOpener::Tags qw/:all/;
use ProductOpener::Text qw/:all/;

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

=head2 init_units_names()

Create a map of all synonyms in all languages in the units taxonomy to an internal standard unit and conversion factor
Also create a regexp matching all names.

=cut

my %units = ();
my %units_names = ();
my $units_regexp;

sub init_units_names() {

	foreach my $tagid (get_all_taxonomy_entries("units")) {

		my $standard_unit = get_property("units", $tagid, "standard_unit:en");
		my $conversion_factor = get_property("units", $tagid, "conversion_factor:en");
		my $symbol = get_property("units", $tagid, "symbol:en");

		$units{$tagid} = {
			standard_unit => $standard_unit,
			conversion_factor => $conversion_factor,
			symbol => $symbol,
		};

		# If there is a symbol, add it to the unit names
		if (defined $symbol) {
			$units_names{lc($symbol)} = $tagid;
		}

		foreach my $language (sort keys %{$translations_to{"units"}{$tagid}}) {

			foreach my $synonym (get_taxonomy_tag_synonyms($language, "units", $tagid)) {

				# using lc as we want to match case insensitive
				# but not using get_string_id_for_lang as we want to keep symbols like %
				$units_names{lc($synonym)} = $tagid;
			}
		}
	}

	# Construct a regexp that match all unit names
	# We want to match the longest strings first

	$units_regexp = join(
		'|', map {regexp_escape($_)}
			sort {(length $b <=> length $a) || ($a cmp $b)}
			keys %units_names
	);

	return;
}

init_units_names();

=head2 unit_to_g($value, $unit)

Converts <xx><unit> into <xx>grams. Eg.:
unit_to_g(2,kg) => returns 2000
unit_to_g(520,mg) => returns 0.52

=cut

sub unit_to_g ($value, $unit) {

	# Return undef if not passed a defined value
	not defined $value and return;

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;
	$value =~ /^\s*$/ and return $value;

	# Normalize the unit name
	$unit = lc($unit);
	my $unit_id = $units_names{$unit};

	if (defined $unit_id) {

		# For kcal, we want to return a rounded value
		if ($unit eq 'kcal') {
			return int($value * 4.184 + 0.5);
		}

		if (defined $units{$unit_id}{conversion_factor}) {
			return $value * $units{$unit_id}{conversion_factor};
		}
	}
	else {
		$log->warn("unit not found", {unit => $unit}) if $log->is_warn();
	}

	# If the unit is not recognized, we return with + 0 to make sure the value is treated as number
	# (needed when outputting json and to store in mongodb as a number)
	return $value + 0;
}

=head2 g_to_unit($value, $unit)

Converts <xx>grams into <xx><unit>. Eg.:
g_to_unit(2000,kg) => returns 2
g_to_unit(0.52,mg) => returns 520

=cut

sub g_to_unit ($value, $unit) {

	# Return undef if not passed a defined value
	not defined $value and return;

	$value =~ s/,/\./;
	$value =~ s/^(<|environ|max|maximum|min|minimum)( )?//;
	$value =~ /^\s*$/ and return $value;

	# Normalize the unit name
	$unit = lc($unit);
	my $unit_id = $units_names{$unit};

	if (defined $unit_id) {

		# For kcal, we want to return a rounded value
		if ($unit eq 'kcal') {
			return int($value / 4.184 + 0.5);
		}

		if (defined $units{$unit_id}{conversion_factor}) {
			return $value / $units{$unit_id}{conversion_factor};
		}
	}
	else {
		$log->warn("unit not found", {unit => $unit}) if $log->is_warn();
	}

	# If the unit is not recognized, we return with + 0 to make sure the value is treated as number
	# (needed when outputting json and to store in mongodb as a number)
	return $value + 0;
}

sub unit_to_mmoll ($value, $unit) {
	return unit_to_g($value, $unit);
}

sub mmoll_to_unit ($value, $unit) {
	return g_to_unit($value, $unit);
}

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
	if ($quantity
		=~ /(?<number>\d+)(\s(\p{Letter}| )+)?(\s)?( de | of |x|\*)(\s)?(?<quantity>$number_regexp)(\s)?(?<unit>$units_regexp)\b/i
		)
	{
		my $m = $+{number};
		$q = lc($+{quantity});
		$u = $+{unit};
		$q = convert_string_to_number($q);
		$q = unit_to_g($q * $m, $u);
	}
	elsif ($quantity =~ /(?<quantity>$number_regexp)(\s)?(?<unit>$units_regexp)\s*\b/i) {
		$q = lc($+{quantity});
		$u = $+{unit};
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
	if ($serving =~ /^(.*[ \(])?(?<quantity>$number_regexp)( )?(?<unit>$units_regexp)\b/i) {
		my $q = $+{quantity};
		my $u = $+{unit};
		$q = convert_string_to_number($q);

		return unit_to_g($q, $u);
	}

	#$log->trace("serving size normalized", { serving => $serving, q => $q, u => $u }) if $log->is_trace();
	return;
}

1;

