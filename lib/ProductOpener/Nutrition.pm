# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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

ProductOpener::Nutrition - functions related to nutrition facts of food products

=head1 DESCRIPTION

C<ProductOpener::Nutrition> contains functions specific to food products, in particular
related to the new schema of nutrition facts. This module provides functions It does not contain functions related to ingredients which
are in the C<ProductOpener::Ingredients> module.

..

=cut

package ProductOpener::Nutrition;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&generate_nutrient_set_preferred_from_sets
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Clone qw/clone/;

use ProductOpener::Tags qw/:all/;
use ProductOpener::Units qw/unit_to_kcal unit_to_kj unit_to_g g_to_unit/;

=head1 FUNCTIONS

=head2 generate_nutrient_set_preferred_from_sets

Generates and returns a hash reference of the preferred nutrient set from the given list of nutrient sets.

The generated set is a combined set of nutrients with the preferred sources, per references and preparation states 
and with normalized units.

=head3 Arguments

=head4 $nutrient_sets_ref

Array of nutrients sets used to generate the preferred set

=head3 Return values

The generated preferred nutrient set

=cut

sub generate_nutrient_set_preferred_from_sets ($nutrient_sets_ref) {
	if (!defined $nutrient_sets_ref) {
		return;
	}
	my @nutrient_sets = @$nutrient_sets_ref;

	my $nutrient_set_preferred_ref = {};

	if (@nutrient_sets) {
		@nutrient_sets = sort_sets_by_priority(@nutrient_sets);

		if (%{$nutrient_sets[0]}) {
			# set preparation, per, per_quantity and per_unit of preferred set as values of the nutrient_set with the highest priority
			$nutrient_set_preferred_ref->{preparation} = $nutrient_sets[0]{preparation};
			$nutrient_set_preferred_ref->{per} = $nutrient_sets[0]{per};
			$nutrient_set_preferred_ref->{per_quantity} = $nutrient_sets[0]{per_quantity};
			$nutrient_set_preferred_ref->{per_unit} = $nutrient_sets[0]{per_unit};
		}

		set_nutrient_values($nutrient_set_preferred_ref, @nutrient_sets);
	}
	return $nutrient_set_preferred_ref;
}

=head2 sort_sets_by_priority

Sorts hashes of nutrient sets in a given array based on a custom priority.

The priority is based on the sources, the per references and the preparation states present in the nutrient sets.

=head3 Arguments

=head4 @nutrient_sets

Unsorted array nutrient sets hashes

=head3 Return values

Sorted array nutrient sets hashes

=cut

sub sort_sets_by_priority (@nutrient_sets) {
	my %source_priority = (
		manufacturer => 0,
		packaging => 1,
		usda => 2,
		estimate => 3,
		_default => 4,
	);

	my %per_priority = (
		"100g" => 0,
		"100ml" => 1,
		serving => 2,
		_default => 3,
	);

	my %preparation_priority = (
		prepared => 0,
		as_sold => 1,
		_default => 2,
	);

	return (
		sort {
			my $source_key_a = defined $a->{source} ? $a->{source} : '_default';
			my $source_key_b = defined $b->{source} ? $b->{source} : '_default';
			my $source_a = $source_priority{$source_key_a};
			my $source_b = $source_priority{$source_key_b};

			my $per_key_a = defined $a->{per} ? $a->{per} : '_default';
			my $per_key_b = defined $b->{per} ? $b->{per} : '_default';
			my $per_a = $per_priority{$per_key_a};
			my $per_b = $per_priority{$per_key_b};

			my $preparation_key_a = defined $a->{preparation} ? $a->{preparation} : '_default';
			my $preparation_key_b = defined $b->{preparation} ? $b->{preparation} : '_default';
			my $preparation_a = $preparation_priority{$preparation_key_a};
			my $preparation_b = $preparation_priority{$preparation_key_b};

			# sort priority : source then per then preparation
			return $source_a <=> $source_b || $per_a <=> $per_b || $preparation_a <=> $preparation_b;
		} @nutrient_sets
	);
}

=head2 set_nutrient_values

For each nutrient appearing in the nutrient sets array, sets its values in the preferred set.

The units of the nutrients quantities are normalized (g, kJ or kcal).

Each nutrient is only added once. Its value is the one in the set with the highest priority.

If the preparation value in a set is different from the one in the preferred set, the nutrient is not added to the preferred set.

=head3 Arguments

=head4 $nutrient_set_preferred_ref

The generated preferred nutrient set.

=head4 @nutrient_sets

The sorted array of nutrient set hashes used to generate the preferred set.

=cut

sub set_nutrient_values ($nutrient_set_preferred_ref, @nutrient_sets) {
	foreach my $nutrient_set_ref (@nutrient_sets) {
		# set nutrient values from set if preparation state is the same as in the preferred set and if set has nutrients
		if (    defined $nutrient_set_ref->{preparation}
			and $nutrient_set_ref->{preparation} eq $nutrient_set_preferred_ref->{preparation}
			and exists $nutrient_set_ref->{nutrients}
			and ref $nutrient_set_ref->{nutrients} eq 'HASH')
		{
			foreach my $nutrient (keys %{$nutrient_set_ref->{nutrients}}) {
				# for each nutrient, set its values if values are not already present in preferred set
				# (ie if nutrient not present in other set with highest priority)
				if (!exists $nutrient_set_preferred_ref->{nutrients}{$nutrient}) {
					$nutrient_set_preferred_ref->{nutrients}{$nutrient}
						= clone($nutrient_set_ref->{nutrients}{$nutrient});
					convert_nutrient_to_standard_unit($nutrient_set_preferred_ref->{nutrients}{$nutrient}, $nutrient);
					convert_nutrient_to_wanted_per(
						$nutrient_set_preferred_ref->{nutrients}{$nutrient},
						$nutrient_set_ref->{per_quantity},
						$nutrient_set_ref->{per_unit},
						$nutrient_set_preferred_ref->{per_quantity},
						$nutrient_set_preferred_ref->{per_unit}
					);
					$nutrient_set_preferred_ref->{nutrients}{$nutrient}{source} = $nutrient_set_ref->{source};
					$nutrient_set_preferred_ref->{nutrients}{$nutrient}{source_per} = $nutrient_set_ref->{per};
				}
			}
		}
	}
	return;
}

=head2 convert_nutrient_to_standard_unit

Normalizes the unit of the nutrient value if necessary.

The normalized units are g, kJ or kcal based on the nutrient.

=head3 Arguments

=head4 $nutrient_ref

Hash of the nutrient to normalize

=head4 $nutrient_name

Name of the nutrient to normalize

=cut

sub convert_nutrient_to_standard_unit ($nutrient_ref, $nutrient_name) {
	if ($nutrient_name eq "energy-kcal") {
		if ($nutrient_ref->{unit} ne "kcal") {
			$nutrient_ref->{value} = unit_to_kcal($nutrient_ref->{value}, $nutrient_ref->{unit});
			$nutrient_ref->{value_string} = sprintf("%s", $nutrient_ref->{value});
			$nutrient_ref->{unit} = "kcal";
		}
	}
	elsif ($nutrient_name eq "energy" or $nutrient_name eq "energy-kj") {
		if ($nutrient_ref->{unit} ne "kJ") {
			$nutrient_ref->{value} = unit_to_kj($nutrient_ref->{value}, $nutrient_ref->{unit});
			$nutrient_ref->{value_string} = sprintf("%s", $nutrient_ref->{value});
			$nutrient_ref->{unit} = "kJ";
		}
	}
	elsif ($nutrient_ref->{unit} ne "g") {
		$nutrient_ref->{value} = unit_to_g($nutrient_ref->{value}, $nutrient_ref->{unit});
		$nutrient_ref->{value_string} = sprintf("%s", $nutrient_ref->{value});
		$nutrient_ref->{unit} = "g";
	}
	return;
}

=head2 convert_nutrient_to_wanted_per

Converts the value of the amount of the nutrient based on the wanted per reference if necessary.

=head3 Arguments

=head4 $nutrient_ref

Hash of the nutrient set with the value to convert

=head4 $original_per_quantity

Current per amount of the nutrient

=head4 $original_per_unit

Current per unit of the nutrient

=head4 $wanted_per_quantity

Wanted per amount of the nutrient

=head4 $wanted_per_unit

Wanted per unit of the nutrient

=cut

sub convert_nutrient_to_wanted_per ($nutrient_ref, $original_per_quantity, $original_per_unit, $wanted_per_quantity,
	$wanted_per_unit)
{
	if ($original_per_quantity != $wanted_per_quantity) {
		my $original_value = $nutrient_ref->{value};

		# set value of nutrient according to wanted per amount + unit
		my $per_conversion_factor = g_to_unit(unit_to_g($original_per_quantity, $original_per_unit), $wanted_per_unit);
		$nutrient_ref->{value} = ($original_value * $wanted_per_quantity) / $per_conversion_factor;
		$nutrient_ref->{value_string} = sprintf("%s", $nutrient_ref->{value});
	}
	return;
}

1;
