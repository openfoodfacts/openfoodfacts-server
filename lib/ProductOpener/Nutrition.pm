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

=encoding utf8

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
		&generate_nutrient_aggregated_set
		&generate_nutrient_aggregated_set_from_sets
		&get_specific_nutrition_input_set
		&get_nutrition_input_sets_in_a_hash
		&convert_nutrition_input_sets_hash_to_array
		&get_source_for_site_and_org
		&get_preparations_for_product_type
		&get_pers_for_product_type
		&get_default_per_for_product
		&get_unit_options_for_nutrient
		&normalize_nutrient_value_string_and_modifier
		&assign_nutrient_modifier_value_string_and_unit
		&assign_nutrition_values_from_old_request_parameters
		&assign_nutrition_values_from_request_parameters
		&assign_nutrition_values_from_imported_csv_product
		&assign_nutrition_values_from_imported_csv_product_old_fields
		&assign_nutrition_values_from_request_object
		&compute_estimated_nutrients
		&add_nutrition_fields_from_product_to_populated_fields
		&filter_out_nutrients_not_in_taxonomy
		&convert_sodium_to_salt
		&convert_salt_to_sodium
		&get_non_estimated_nutrient_per_100g_or_100ml_for_preparation
		&has_non_estimated_nutrition_data
		&get_nutrition_data_as_key_values_pairs
		&has_no_nutrition_data_on_packaging
		&remove_empty_nutrition_data

		&compute_energy_from_nutrients_for_nutrients_set
		%energy_from_nutrients

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Clone qw/clone/;

use ProductOpener::Food qw/default_unit_for_nid/;
use ProductOpener::Tags qw/:all get_inherited_property_from_categories_tags/;
use ProductOpener::Units qw/unit_to_kcal unit_to_kj unit_to_g g_to_unit get_standard_unit/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::API qw/add_error add_warning/;
use ProductOpener::NutritionEstimation qw/estimate_nutrients_from_ingredients/;

# FIXME: remove single_param and use request_param
use ProductOpener::HTTP qw/single_param request_param/;

use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::Numbers qw/convert_string_to_number remove_insignificant_digits/;
use ProductOpener::Units qw/normalize_product_quantity_and_serving_size/;
use ProductOpener::Ingredients
	qw/estimate_added_sugars_percent_from_ingredients estimate_nutriscore_2021_fruits_vegetables_nuts_percent_from_ingredients estimate_nutriscore_2023_fruits_vegetables_legumes_percent_from_ingredients/;

use Log::Any qw($log);

use Encode;
use Data::DeepAccess qw(deep_exists deep_get deep_set);
use boolean;

=head1 FUNCTIONS


=cut

=head2 add_computed_values_to_nutrient_sets ($input_sets_ref)

Adds computed values to each nutrient set in the given array of nutrient sets:

- energy is computed from macronutrients if enough macronutrients are available
- salt and sodium are computed from each other

Values are stored in the value_computed field of each nutrient.

=head3 Arguments

=head4 $input_sets_ref

Reference to array of nutrient sets

=cut

sub add_computed_values_to_nutrient_sets ($input_sets_ref) {

	foreach my $nutrient_set_ref (@$input_sets_ref) {

		# set nutrient values from set if preparation state is the same as in the aggregated set and if set has nutrients
		if (exists $nutrient_set_ref->{nutrients}) {

			# If we have enough macronutrients, we compute the energy values and store them in value_computed
			compute_energy_from_nutrients_for_nutrients_set($nutrient_set_ref->{nutrients}, "kj");
			compute_energy_from_nutrients_for_nutrients_set($nutrient_set_ref->{nutrients}, "kcal");

			# Add salt and sodium values computed from each other and store them in value_computed
			my $salt_value = deep_get($nutrient_set_ref, qw/nutrients salt value/);
			my $salt_unit = deep_get($nutrient_set_ref, qw/nutrients salt unit/);
			my $salt_modifier = deep_get($nutrient_set_ref, qw/nutrients salt modifier/);
			my $sodium_value = deep_get($nutrient_set_ref, qw/nutrients sodium value/);
			my $sodium_unit = deep_get($nutrient_set_ref, qw/nutrients sodium unit/);
			my $sodium_modifier = deep_get($nutrient_set_ref, qw/nutrients sodium modifier/);

			if (defined $salt_value) {
				# If we have an existing sodium nutrient, we keep its values (including unit and modifier)
				# and we will just add value_computed
				# Otherwise, we create the sodium nutrient with unit and modifier from salt nutrient
				if (not defined $nutrient_set_ref->{nutrients}{"sodium"}) {
					$nutrient_set_ref->{nutrients}{"sodium"} = {unit => $salt_unit // 'g',};
					if (defined $salt_modifier) {
						$nutrient_set_ref->{nutrients}{"sodium"}{modifier} = $salt_modifier;
					}
				}
				# If the sodium unit is different from salt unit, we convert salt value to sodium unit first
				if (defined $sodium_unit and defined $salt_unit and $sodium_unit ne $salt_unit) {
					$salt_value = g_to_unit(unit_to_g($salt_value, $salt_unit), $sodium_unit);
				}
				$nutrient_set_ref->{nutrients}{"sodium"}{value_computed}
					= remove_insignificant_digits(convert_salt_to_sodium($salt_value)) + 0;
			}

			if (defined $sodium_value) {
				# If we have an existing salt nutrient, we keep its values (including unit and modifier)
				# and we will just add value_computed
				# Otherwise, we create the salt nutrient with unit and modifier from sodium nutrient
				if (not defined $nutrient_set_ref->{nutrients}{"salt"}) {
					$nutrient_set_ref->{nutrients}{"salt"} = {unit => $sodium_unit // 'g',};
					if (defined $sodium_modifier) {
						$nutrient_set_ref->{nutrients}{"salt"}{modifier} = $sodium_modifier;
					}
				}
				# If the salt unit is different from sodium unit, we convert sodium value to salt unit first
				if (defined $salt_unit and defined $sodium_unit and $salt_unit ne $sodium_unit) {
					$sodium_value = g_to_unit(unit_to_g($sodium_value, $sodium_unit), $salt_unit);
				}
				$nutrient_set_ref->{nutrients}{"salt"}{value_computed}
					= remove_insignificant_digits(convert_sodium_to_salt($sodium_value)) + 0;
			}
		}
	}

	return;
}

=head2 generate_nutrient_aggregated_set

Generates the aggregated nutrient set for a product from its input sets and stores it in the product hash.

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=head3 Return values

None

=cut

sub generate_nutrient_aggregated_set ($product_ref) {
	if (!defined $product_ref) {
		return;
	}

	my $input_sets_ref = deep_get($product_ref, qw/nutrition input_sets/);
	add_computed_values_to_nutrient_sets($input_sets_ref);
	my $aggregated_set_ref = generate_nutrient_aggregated_set_from_sets($input_sets_ref);
	if (defined $aggregated_set_ref) {
		deep_set($product_ref, qw/nutrition aggregated_set/, $aggregated_set_ref);
	}

	remove_empty_nutrition_data($product_ref);

	return;
}

=head2 generate_nutrient_aggregated_set_from_sets

Generates and returns a hash reference of the aggregated nutrient set from the given list of nutrient sets.

The generated set is a combined set of nutrients with the preferred sources, per references and preparation states 
and with normalized units.

=head3 Arguments

=head4 $input_sets_ref

Array of nutrients sets used to generate the aggregated set

=head3 Return values

The generated aggregated nutrient set

=cut

sub generate_nutrient_aggregated_set_from_sets ($input_sets_ref) {
	if (!defined $input_sets_ref) {
		return;
	}

	# Make sure the input sets are sorted by priority
	sort_sets_by_priority($input_sets_ref);

	# store original index to get index source of nutrients for generated set
	my @input_sets = map {{index => $_, set => $input_sets_ref->[$_]}} 0 .. $#$input_sets_ref;
	my $aggregated_nutrient_set_ref = {};

	if (@input_sets) {
		# remove sets with quantities that are impossible to transform to 100g
		# ie sets with unknow per quantity
		@input_sets = grep {defined $_->{set}{per_quantity} && $_->{set}{per_quantity} ne ""} @input_sets;

		# Remove sets that have a per quantity that is less than 5g or 5ml, so that we don't extrapolate very small quantities to 100g
		@input_sets = grep {unit_to_g($_->{set}{per_quantity}, $_->{set}{per_unit}) >= 5} @input_sets;

		if (defined $input_sets[0] and %{$input_sets[0]} and %{$input_sets[0]{set}}) {
			# set preparation and per of aggregated set as values of the nutrient_set with the highest priority
			$aggregated_nutrient_set_ref->{preparation} = $input_sets[0]{set}{preparation};

			# set per only if given per unit can be converted to g or to ml
			my $standard_unit = get_standard_unit($input_sets[0]{set}{per_unit});
			if ($standard_unit eq "g") {
				$aggregated_nutrient_set_ref->{per} = "100g";
			}
			elsif ($standard_unit eq "ml") {
				$aggregated_nutrient_set_ref->{per} = "100ml";
			}
		}

		set_nutrient_values($aggregated_nutrient_set_ref, @input_sets);
	}
	return $aggregated_nutrient_set_ref;
}

=head2 sort_sets_by_priority

Sorts hashes of nutrient sets in a given array based on a custom priority.
The array is sorted in place and also returned.

The priority is based on the sources, the per references and the preparation states present in the nutrient sets.

=head3 Arguments

=head4 $input_sets_ref

Reference to array of unsorted input nutrient sets

=cut

sub sort_sets_by_priority ($input_sets_ref) {
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
		"1l" => 2,    # for water
		"1kg" => 3,    # for pet food
		serving => 4,
		_default => 5,
	);

	my %preparation_priority = (
		prepared => 0,
		as_sold => 1,
		_default => 2,
	);

	@$input_sets_ref =

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
		} @$input_sets_ref;

	return @$input_sets_ref;
}

=head2 get_non_estimated_nutrient_per_100g_or_100ml_for_preparation ($product_ref, $preparation, $nid)

Gets the value of a nutrient from the first non-estimated input set with per = 100g or 100ml.
We take the first value defined in the sorted input set, that we can convert to 100g or 100ml.

This function is needed to estimate the % of ingredients, in order to set the max for ingredients like salt and sugar.

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=head4 $preparation

Preparation state to look for in the input sets

=head4 $nid of the nutrient to get

=cut

sub get_non_estimated_nutrient_per_100g_or_100ml_for_preparation ($product_ref, $preparation, $nid) {

	my $input_sets_ref = deep_get($product_ref, qw/nutrition input_sets/);

	if (!defined $input_sets_ref) {
		return;
	}

	# Make sure the input sets are sorted by priority
	sort_sets_by_priority($input_sets_ref);

	foreach my $set_ref (@{$input_sets_ref}) {
		my $source = deep_get($set_ref, qw/source/);
		my $set_preparation = deep_get($set_ref, qw/preparation/);
		# We may have per = 100g but per_quantity undefined (e.g. from unit tests)
		# So we call set_per_quantity_and_unit() to set per_quantity and per_unit
		set_per_quantity_and_unit($product_ref, $set_ref);
		my $per_quantity = deep_get($set_ref, qw/per_quantity/);
		my $nutrient_value = deep_get($set_ref, "nutrients", $nid, "value");

		if (    (defined $source)
			and ($source ne "estimate")
			and (defined $preparation)
			and ($set_preparation eq $preparation)
			and (defined $per_quantity)
			and (defined $nutrient_value))
		{
			my $nutrient_ref = clone($set_ref->{nutrients}{$nid});
			convert_nutrient_to_standard_unit($nutrient_ref, $nid);
			convert_nutrient_to_100g($nutrient_ref, $set_ref->{per}, $set_ref->{per_quantity},
				$set_ref->{per_unit}, $set_ref->{per});
			return $nutrient_ref->{value};
		}
	}

	return;
}

=head2 set_nutrient_values

For each nutrient appearing in the nutrient sets array, sets its values in the aggregated set.

The units of the nutrients quantities are normalized (g, kJ or kcal).

Each nutrient is only added once. Its value is the one in the set with the highest priority.

If the preparation value in a set is different from the one in the aggregated set, the nutrient is not added to the aggregated set.

=head3 Arguments

=head4 $aggregated_nutrient_set_ref

The generated aggregated nutrient set.

=head4 @input_sets

The sorted array of nutrient set hashes used to generate the aggregated set.

=cut

sub set_nutrient_values ($aggregated_nutrient_set_ref, @input_sets) {
	foreach my $element_ref (@input_sets) {
		my $nutrient_set_ref = $element_ref->{set};
		my $index = $element_ref->{index};

		# set nutrient values from set if preparation state is the same as in the aggregated set and if set has nutrients
		if (    defined $nutrient_set_ref->{preparation}
			and $nutrient_set_ref->{preparation} eq $aggregated_nutrient_set_ref->{preparation}
			and exists $nutrient_set_ref->{nutrients}
			and ref $nutrient_set_ref->{nutrients} eq 'HASH')
		{
			foreach my $nutrient (sort keys %{$nutrient_set_ref->{nutrients}}) {

				# for each nutrient, set its values if values are not already present in aggregated set
				# (ie if nutrient not present in other set with higher priority)

				# skip energy (we should have only energy-kj and/or energy-kcal in sets, so it should not happen)
				next if $nutrient eq "energy";

				if (!exists $aggregated_nutrient_set_ref->{nutrients}{$nutrient}) {
					$aggregated_nutrient_set_ref->{nutrients}{$nutrient}
						= clone($nutrient_set_ref->{nutrients}{$nutrient});
					delete $aggregated_nutrient_set_ref->{nutrients}{$nutrient}{value_string};
					# If we don't have a value but a value_computed, use it as value and set the modifier to ~ (unless there is another modifier already)
					if (    (!defined $aggregated_nutrient_set_ref->{nutrients}{$nutrient}{value})
						and (defined $aggregated_nutrient_set_ref->{nutrients}{$nutrient}{value_computed}))
					{
						$aggregated_nutrient_set_ref->{nutrients}{$nutrient}{value}
							= $aggregated_nutrient_set_ref->{nutrients}{$nutrient}{value_computed};
						delete $aggregated_nutrient_set_ref->{nutrients}{$nutrient}{value_computed};
						$aggregated_nutrient_set_ref->{nutrients}{$nutrient}{modifier} //= '~';
					}
					# Normalize units to standard units (g, kJ or kcal)
					convert_nutrient_to_standard_unit($aggregated_nutrient_set_ref->{nutrients}{$nutrient}, $nutrient);
					convert_nutrient_to_100g(
						$aggregated_nutrient_set_ref->{nutrients}{$nutrient},
						$nutrient_set_ref->{per},
						$nutrient_set_ref->{per_quantity},
						$nutrient_set_ref->{per_unit},
						$aggregated_nutrient_set_ref->{per}
					);
					$aggregated_nutrient_set_ref->{nutrients}{$nutrient}{source} = $nutrient_set_ref->{source};
					$aggregated_nutrient_set_ref->{nutrients}{$nutrient}{source_per} = $nutrient_set_ref->{per};
					$aggregated_nutrient_set_ref->{nutrients}{$nutrient}{source_index} = $index;
				}
			}

			# In the aggregated set:

			# We also add a energy nutrient (in kJ) which is equal to the energy-kj nutrient if it exists,
			# or the energy-kcal set (with the value converted to kJ) if energy-kj does not exist
			if (    exists $aggregated_nutrient_set_ref->{nutrients}{"energy-kj"}
				and exists $aggregated_nutrient_set_ref->{nutrients}{"energy-kj"}{value})
			{
				$aggregated_nutrient_set_ref->{nutrients}{"energy"}
					= clone($aggregated_nutrient_set_ref->{nutrients}{"energy-kj"});
			}
			elsif ( exists $aggregated_nutrient_set_ref->{nutrients}{"energy-kcal"}
				and exists $aggregated_nutrient_set_ref->{nutrients}{"energy-kcal"}{value})
			{
				$aggregated_nutrient_set_ref->{nutrients}{"energy"}
					= clone($aggregated_nutrient_set_ref->{nutrients}{"energy-kcal"});
				convert_nutrient_to_standard_unit($aggregated_nutrient_set_ref->{nutrients}{"energy"}, "energy");
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

=head4 $nutrient_id

Name of the nutrient to normalize

=cut

sub convert_nutrient_to_standard_unit ($nutrient_ref, $nutrient_id) {
	my $standard_unit = default_unit_for_nid($nutrient_id);

	if ($standard_unit ne $nutrient_ref->{unit}) {

		my $iu_value = get_property("nutrients", "zz:" . $nutrient_id, "iu_value:en");
		my $dv_value = get_property("nutrients", "zz:" . $nutrient_id, "dv_value:en");

		# Convert values passed in international units IU or % of daily value % DV to the default unit for the nutrient,
		# using the conversion factors in the nutrients taxonomy
		# e.g. for vitamin A
		# dv_value:en: 1500
		# iu_value:en: 0.3
		# unit:en: µg
		# unit_ca:en: % DV
		# unit_us:en: % DV
		if (    (uc($nutrient_ref->{unit}) eq 'IU')
			and (defined $iu_value))
		{
			$nutrient_ref->{value} *= $iu_value;
			$nutrient_ref->{unit} = get_property("nutrients", "zz:" . $nutrient_id, "unit:en");
		}
		elsif ( (uc($nutrient_ref->{unit}) eq '% DV')
			and (defined get_property("nutrients", "zz:" . $nutrient_id, "dv_value:en")))
		{
			$nutrient_ref->{value} *= $dv_value / 100;
			$nutrient_ref->{unit} = get_property("nutrients", "zz:" . $nutrient_id, "unit:en");
		}

		# Now convert to standard unit

		# Energy in kJ and kcal
		if ($standard_unit eq "kcal") {
			$nutrient_ref->{value} = unit_to_kcal($nutrient_ref->{value}, $nutrient_ref->{unit});
		}
		elsif ($standard_unit eq "kJ") {
			$nutrient_ref->{value} = unit_to_kj($nutrient_ref->{value}, $nutrient_ref->{unit});
		}
		# Everything else in g or %
		else {
			$nutrient_ref->{value} = unit_to_g($nutrient_ref->{value}, $nutrient_ref->{unit});
		}

		$nutrient_ref->{unit} = $standard_unit;
	}
	return;
}

=head2 convert_nutrient_to_100g

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

sub convert_nutrient_to_100g ($nutrient_ref, $original_per, $original_per_quantity, $original_per_unit, $wanted_per) {
	if ($original_per ne $wanted_per) {
		my $original_value = $nutrient_ref->{value};
		my $wanted_per_unit = $wanted_per eq "100g" ? "g" : "ml";

		# set value of nutrient according to wanted per unit
		my $per_conversion_factor = g_to_unit(unit_to_g($original_per_quantity, $original_per_unit), $wanted_per_unit);
		$nutrient_ref->{value} = ($original_value * 100) / $per_conversion_factor;

	}
	return;
}

=head2 get_specific_nutrition_input_set ($product_ref, $source, $preparation, $per)

Returns the input set matching the given source, preparation and per values.

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=head4 $source

Source of the input set to find

=head4 $preparation

Preparation state of the input set to find

=head4 $per

Per reference of the input set to find

=head3 Return values

The input set hash reference if found, undef otherwise

=cut

sub get_specific_nutrition_input_set($product_ref, $source, $preparation, $per) {

	my $input_sets_ref = deep_get($product_ref, qw/nutrition input_sets/);
	if ((defined $input_sets_ref) and (ref $input_sets_ref eq 'ARRAY')) {
		foreach my $set_ref (@{$input_sets_ref}) {
			if (    exists $set_ref->{source}
				and $set_ref->{source} eq $source
				and exists $set_ref->{preparation}
				and $set_ref->{preparation} eq $preparation
				and exists $set_ref->{per}
				and $set_ref->{per} eq $per)
			{
				return $set_ref;
			}
		}
	}
	return;
}

=head2 set_per_quantity_and_unit($product_ref, $input_set_ref)

Fill the per_quantity and per_unit field of nutrients input set,
based upon the "per" value of the nutrient input set,
or product serving_quantity and unit for "serving".

=head3 Arguments

=head4 $product_ref - product

=head4 $input_set_ref - nutrient input set

It is modified to add per_quantity and per_unit.

=cut

sub set_per_quantity_and_unit($product_ref, $input_set_ref) {
	if (defined $input_set_ref) {
		my $per = deep_get($input_set_ref, qw/per/);
		return if not defined $per;
		# Set the per quantity and unit for 100g, 100ml, 1l and 1kg
		if ($per eq "100g") {
			$input_set_ref->{per_quantity} = 100;
			$input_set_ref->{per_unit} = "g";
		}
		elsif ($per eq "100ml") {
			$input_set_ref->{per_quantity} = 100;
			$input_set_ref->{per_unit} = "ml";
		}
		elsif ($per eq "1kg") {
			$input_set_ref->{per_quantity} = 1000;
			$input_set_ref->{per_unit} = "g";
		}
		elsif ($per eq "1l") {
			$input_set_ref->{per_quantity} = 1000;
			$input_set_ref->{per_unit} = "ml";
		}
		# If possible convert per serving to quantity + unit from product
		elsif ($per eq "serving") {
			if (    (defined $product_ref->{serving_quantity})
				and (defined $product_ref->{serving_quantity_unit}))
			{
				$input_set_ref->{per_quantity} = $product_ref->{serving_quantity};
				$input_set_ref->{per_unit} = $product_ref->{serving_quantity_unit};
			}
		}

	}
	return;
}

=head2 get_nutrition_input_sets_in_a_hash ($product_ref)

Returns the input sets of a product in a hash reference for easier access,
so that we can use $input_sets_hash_ref->{$source}{$preparation}{$per} to get a specific input set.

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=head3 Return values

The hash reference of input sets

=cut

sub get_nutrition_input_sets_in_a_hash($product_ref) {
	my $input_sets_ref = deep_get($product_ref, qw/nutrition input_sets/);
	my $input_sets_hash_ref = {};
	if ((defined $input_sets_ref) and (ref $input_sets_ref eq 'ARRAY')) {
		foreach my $set_ref (@{$input_sets_ref}) {
			if (exists $set_ref->{source} and exists $set_ref->{preparation} and exists $set_ref->{per}) {
				$input_sets_hash_ref->{$set_ref->{source}}{$set_ref->{preparation}}{$set_ref->{per}} = $set_ref;
			}
		}
	}

	$log->debug("get_nutrition_input_sets_in_a_hash: result",
		{input_sets_ref => $input_sets_ref, input_sets_hash_ref => $input_sets_hash_ref})
		if $log->is_debug();

	return $input_sets_hash_ref;
}

=head2 convert_nutrition_input_sets_hash_to_array ($input_sets_hash_ref, $product_ref)

Converts a hash reference of input sets back to an array reference, which is the format we store in the product structure

Input sets are normalized:
- nutrients with undefined or empty values are removed
- nutrient with a modifier "-" are removed and added to the unspecified nutrients array
- input sets with no nutrients are removed
- the source, preparation and per values from the input sets hash keys are set in the input set

The nutrients sets are sorted with sort_sets_by_priority()

=head3 Arguments

=head4 $input_sets_hash_ref

Reference to hash of input sets

=head4 $product_ref

Used to get the serving size (quantity + unit) if needed for input sets with per = "serving"

=head3 Return values

Reference to array of input sets

=cut

sub convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref, $product_ref) {

	$log->debug("convert_nutrition_input_sets_hash_to_array: start", {input_sets_hash_ref => $input_sets_hash_ref})
		if $log->is_debug();

	my $input_sets_ref = [];
	if (defined $input_sets_hash_ref and ref $input_sets_hash_ref eq 'HASH') {
		foreach my $source (sort keys %{$input_sets_hash_ref}) {
			foreach my $preparation (sort keys %{$input_sets_hash_ref->{$source}}) {
				foreach my $per (sort keys %{$input_sets_hash_ref->{$source}{$preparation}}) {

					my $input_set_ref = $input_sets_hash_ref->{$source}{$preparation}{$per};

					remove_empty_nutrient_values_and_set_unspecified_nutrients($input_set_ref);

					# Empty input sets are not stored
					if (
						(
							   (not exists $input_set_ref->{nutrients})
							or ((scalar keys %{$input_set_ref->{nutrients}}) == 0)
						)
						and (not exists $input_set_ref->{unspecified_nutrients})
						)
					{
						next;
					}

					# Set the source, preparation and per as they may be only in the keys
					# if we just created the input set from nutrient values
					$input_set_ref->{source} = $source;
					$input_set_ref->{preparation} = $preparation;
					$input_set_ref->{per} = $per;

					set_per_quantity_and_unit($product_ref, $input_set_ref);

					push(@{$input_sets_ref}, $input_set_ref);
				}
			}
		}
	}

	sort_sets_by_priority($input_sets_ref);

	$log->debug("convert_nutrition_input_sets_hash_to_array: end", {input_sets_ref => $input_sets_ref})
		if $log->is_debug();

	return $input_sets_ref;
}

=head2 get_source_for_site_and_org ( $org_id = undef )

Returns the default source of nutrition data for the current site and organization.

=head3 Arguments

=head4 $org_id

Organization id

=head3 Return values

- "packaging" for the public platform
- "manufacturer" for the pro platform

=cut

sub get_source_for_site_and_org ($org_id = undef) {

	my $source = "packaging";
	if ($server_options{producers_platform}) {
		$source = "manufacturer";
		if (defined $org_id) {
			# e.g. org-database-usda
			if ($org_id =~ /^org-database-(.+)$/) {
				$source = "database-" . $1;
			}
			# e.g. org-label-gmo-project (in practice labels should not send nutrition data)
			if ($org_id =~ /^org-label-(.+)$/) {
				$source = "label-" . $1;
			}
			# At some point we used the pro platform to allow users to bulk enter data (e.g. for scan parties)
			elsif ($org_id =~ /^user-(.+)$/) {
				$source = "packaging";
			}
		}
	}
	return $source;
}

=head2 get_preparations_for_product_type

Returns the list of valid preparation states for a given product type.

=head3 Arguments

=head4 $product_type

Type of the product (food, petfood, etc)

=head3 Return values

List of valid preparation states for the given product type

=cut

sub get_preparations_for_product_type ($product_type) {

	my @preparations = ();

	if (defined $options{product_types_preparations}{$product_type}) {
		@preparations = @{$options{product_types_preparations}{$product_type}};
	}

	return @preparations;
}

# %valid_pers contains the possible values for nutrient input_set "per" field.
my %valid_pers = (
	'100g' => 1,
	'100ml' => 1,
	'1kg' => 1,
	'1l' => 1,
	'serving' => 1,
);

=head2 get_pers_for_product_type

Returns the list of valid per quantities for a given product type.

=head3 Arguments

=head4 $product_type

Type of the product (food, petfood, etc)

=head3 Return values

List of valid per references for the given product type

=cut

sub get_pers_for_product_type ($product_type) {

	my @pers = ();

	if (defined $options{product_types_pers}{$product_type}) {
		@pers = @{$options{product_types_pers}{$product_type}};
	}

	return @pers;
}

sub get_default_per_for_product ($product_ref, $preparation = "as_sold") {
	my $product_type = deep_get($product_ref, qw/product_type/);
	if (!defined $product_type) {
		$product_type = "food";
	}

	my $default_per = "100g";
	if ($product_type eq "petfood") {
		$default_per = "1kg";
	}

	# beverage, sauces etc. default per is 100ml
	my $category_default_per
		= get_inherited_property_from_categories_tags($product_ref, "default_nutrition_${preparation}_per:en");
	if (defined $category_default_per) {
		$category_default_per = lc($category_default_per);
		if (exists $valid_pers{$category_default_per}) {
			$default_per = $category_default_per;
		}
	}
	return $default_per;
}

=head2 get_unit_options_for_nutrient ($nid)

Returns the list of valid unit options for a given nutrient.

=head3 Arguments

=head4 $nid

Nutrient id

=head3 Return values

Reference to an array of valid unit options for the given nutrient

=cut

sub get_unit_options_for_nutrient ($nid) {

	my @units = ();

	if (($nid eq 'alcohol')) {
		@units = ('% vol');
	}    # alcohol in % vol / °
	elsif (($nid eq 'energy-kj')) {@units = ('kJ');}
	elsif (($nid eq 'energy-kcal')) {@units = ('kcal');}
	elsif ($nid =~ /^energy/) {
		@units = ('kJ', 'kcal');
	}
	elsif ($nid eq 'water-hardness') {
		@units = ('mol/l', 'mmol/l', 'mval/l', 'ppm', "\N{U+00B0}rH", "\N{U+00B0}fH", "\N{U+00B0}e", "\N{U+00B0}dH",
			'gpg');
	}
	# fruits / vegetables / legumes / nuts for nutriscore 2021 and 2023 are always in percent
	# pet nutrients (analytical_constituents) are always in percent
	elsif (($nid =~ /^fruits/)
		or ($nid eq 'crude-fat')
		or ($nid eq 'crude-protein')
		or ($nid eq 'crude-ash')
		or ($nid eq 'crude-fibre')
		or ($nid eq 'moisture'))
	{
		@units = ('%');
	}
	else {

		@units = ('g', 'mg', 'µg');
	}

	my @units_options;

	if (defined get_property("nutrients", "zz:$nid", "dv_value:en")) {
		push @units, '% DV';
	}
	if (defined get_property("nutrients", "zz:$nid", "iu_value:en")) {
		push @units, 'IU';
	}

	foreach my $unit (@units) {
		my $label = $unit;
		# Display both mcg and µg as different food labels show the unit differently
		if ($unit eq 'µg') {
			$label = "mcg/µg";
		}
		elsif ($unit eq '% vol') {
			$label = "% vol/°";
		}

		push(
			@units_options,
			{
				id => $unit,
				label => $label,
			}
		);
	}

	return \@units_options;
}

=head2 normalize_nutrient_value_string_and_modifier ( $value_ref, $modifier_ref )

Each nutrient value is entered as a string (by users on the product edit form,
or through the API). The string value may not always be numeric (e.g. it can include a < sign).

This function normalizes the string value to remove signs, and stores extra information in the "modifier" field.

Modifiers may also be inputted directly (e.g. through the API), and are normalized as well.

=head3 Arguments

=head4 string value reference $value_ref

Input and output string value reference. The value will be normalized.

=head4 modifier reference $modifier_ref

Input and output modifier reference. The value will be normalized if it is defined.

=head3 Possible return values

=head4 value

- 0 if the input value indicates traces
- Number (as a string)
- undef for 'NaN' (not a number, sometimes sent by broken API clients)

=head4 modifier

<, >, ≤, ≥, ~ character sign, for lesser, greater, lesser or equal, greater or equal, and about
- (minus sign) character when the input value is - (or other dashes) : indicates that the value is not present on the package

=cut

# Unicode category 'Punctuation, Dash', SWUNG DASH and MINUS SIGN
my $dashes = qr/(?:\p{Pd}|\N{U+2053}|\N{U+2212})/i;

sub normalize_nutrient_value_string_and_modifier ($value_ref, $modifier_ref) {

	# Note: in regexps below, the first matching alternative is used, so the longest strings must be first
	# e.g. maximum before max
	my $inferior_regexp = "<|&lt;|inférieur|inferieur|inferior|inf|less than|less|menor|menos";
	my $superior_regexp = ">|&gt;|greater|more than|more|superior|mayor|más";
	my $approximately_regexp = "~|≈|about|environ|env|aprox|alrededor";
	my $maximum_regexp = "<=|&lt;=|\N{U+2264}|maximum|maxi|max";
	my $minimum_regexp = ">=|&gt;=|\N{U+2265}|minimum|mini|min";

	# Normalize the modifier if defined
	if (defined ${$modifier_ref}) {
		# remove extra spaces
		${$modifier_ref} =~ s/^\s+//;
		${$modifier_ref} =~ s/\s+$//;
		if (${$modifier_ref} =~ /^($maximum_regexp)$/) {
			${$modifier_ref} = "\N{U+2264}";
		}
		elsif (${$modifier_ref} =~ /^($inferior_regexp)$/) {
			${$modifier_ref} = '<';
		}
		elsif (${$modifier_ref} =~ /^($minimum_regexp)$/) {
			${$modifier_ref} = "\N{U+2265}";
		}
		elsif (${$modifier_ref} =~ /^($superior_regexp)$/) {
			${$modifier_ref} = '>';
		}
		elsif (${$modifier_ref} =~ /^($approximately_regexp)$/) {
			${$modifier_ref} = '~';
		}
		elsif (${$modifier_ref} =~ /^-$/) {
			${$modifier_ref} = '-';
		}
		else {
			# unknown modifier
			${$modifier_ref} = undef;
		}
	}

	# Normalize the value string

	return if not defined ${$value_ref};

	# empty or null value
	if ((${$value_ref} =~ /^\s*$/) or (lc(${$value_ref}) =~ /nan/)) {
		${$value_ref} = undef;
	}
	# < , >, etc. signs
	elsif (${$value_ref} =~ /($maximum_regexp)( )?/) {
		${$value_ref} =~ s/($maximum_regexp)( )?//;
		${$modifier_ref} = "\N{U+2264}";
	}
	elsif (${$value_ref} =~ /($inferior_regexp)( )?/i) {
		${$value_ref} =~ s/($inferior_regexp)( )?//i;
		${$modifier_ref} = '<';
	}
	elsif (${$value_ref} =~ /($minimum_regexp)/) {
		${$value_ref} =~ s/($minimum_regexp)( )?//;
		${$modifier_ref} = "\N{U+2265}";
	}
	elsif (${$value_ref} =~ /($superior_regexp)/i) {
		${$value_ref} =~ s/($superior_regexp)( )?//i;
		${$modifier_ref} = '>';
	}
	elsif (${$value_ref} =~ /($approximately_regexp)/i) {
		${$value_ref} =~ s/($approximately_regexp)( )?//i;
		${$modifier_ref} = '~';
	}
	elsif (${$value_ref} =~ /\b(trace|traces|traza|trazas)\b/i) {
		${$value_ref} = 0;
		${$modifier_ref} = '~';
	}
	# - indicates that there is no value specified on the package
	elsif (${$value_ref} =~ /^\s*$dashes\s*$/) {
		${$value_ref} = undef;
		${$modifier_ref} = '-';
	}

	# Remove extra spaces
	if (defined ${$value_ref}) {
		${$value_ref} =~ s/^\s+//;
		${$value_ref} =~ s/\s+$//;
	}

	return;
}

=head2 assign_nutrient_modifier_value_string_and_unit ($input_sets_hash_ref, $source, $preparation, $per, $nid, $modifier, $value_string, $unit)

Assign a value with a unit and an optional modifier (< or ~) to a nutrient in the nutriments structure.

If a modifier, value_string or unit is undef or empty, the corresponding field is set to undef.

=head3 Parameters

=head4 $input_sets_hash_ref

Reference to the hash of input sets, as returned by get_nutrition_input_sets_in_a_hash

=head4 $source

Source of the nutrition data: e.g. "packaging", "manufacturer"

=head4 $preparation

"as_sold" or "prepared"

=head4 $per

"100g", "100ml", "serving", "1kg" (for pet food)

=head4 $nid

Nutrient id

=head4 value_string

=head4 unit

=cut

sub assign_nutrient_modifier_value_string_and_unit ($input_sets_hash_ref, $source, $preparation, $per, $nid, $modifier,
	$value_string, $unit)
{
	#$log->debug("assign_nutrient_modifier_value_string_and_unit: start",
	#	{source => $source, preparation => $preparation, per => $per, nid => $nid, modifier => $modifier, value_string => $value_string, unit => $unit})
	#	if $log->is_debug();

	# Get the nutrient id in the nutrients taxonomy from the nid (without a prefix)
	my $nutrient_id = "zz:" . $nid;
	if (not exists_taxonomy_tag("nutrients", $nutrient_id)) {
		$log->error("assign_nutrient_modifier_value_string_and_unit: nutrient does not exist in the nutrients taxonomy",
			{nutrient_id => $nutrient_id, nid => $nid})
			if $log->is_error();
		return;
	}

	normalize_nutrient_value_string_and_modifier(\$value_string, \$modifier);

	# We can have a modifier with value '-' to indicate that we have no value
	# It will be recorded in the unspecified_nutrients array by the remove_empty_nutrient_values_and_set_unspecified_nutrients() function

	if ((defined $modifier) and ($modifier eq '')) {
		$modifier = undef;
	}

	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "modifier", $modifier);

	if ((defined $value_string) and ($value_string eq '')) {
		$value_string = undef;
	}

	my $value;

	if (defined $value_string) {
		# Clean the value string
		$value_string = remove_tags_and_quote($value_string);
		$value_string = convert_string_to_number($value_string);
		$value_string = remove_insignificant_digits($value_string);

		# empty unit?
		if ((not defined $unit) or ($unit eq "")) {
			$unit = default_unit_for_nid($nid);
		}
		else {
			# Check the unit is one of the unit options for the nutrient
			my $valid_units_ref = get_unit_options_for_nutrient($nid);
			my $recognized_unit = 0;
			my $lc_unit = lc($unit);
			$lc_unit =~ s/^\s+|\s+$//g;    # trim spaces
			foreach my $unit_option_ref (@{$valid_units_ref}) {
				if (lc($unit_option_ref->{id}) eq $lc_unit) {
					$recognized_unit = 1;
					$unit = $unit_option_ref->{id};
					last;
				}
			}
			# If we did not recognize the unit, add an error and skip the value
			if (not $recognized_unit) {
				# FIXME: for API v3, we need to return an error to the caller
				$log->error("assign_nutrient_modifier_value_string_and_unit: unrecognized unit",
					{unit => $unit, nid => $nid})
					if $log->is_error();
				return;
			}
		}

		$value = convert_string_to_number($value_string);
	}

	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "value_string", $value_string);
	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "value", $value);
	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "unit", $unit);

	return;
}

sub assign_no_nutrition_data_from_request_parameters ($request_ref, $product_ref) {

	# Note: browsers do not send any value for checkboxes that are unchecked,
	# so the web form also has a field (suffixed with _displayed) to allow us to uncheck the box.

	# API:
	# - check: no_nutrition_data is passed "on" or 1
	# - uncheck: no_nutrition_data is passed an empty value ""
	# - no action: the no_nutrition_data field is not sent, and no_nutrition_data_displayed is not sent
	#
	# Web:
	# - check: no_nutrition_data is passed "on"
	# - uncheck: no_nutrition_data is not sent but no_nutrition_data_displayed is sent

	# We use only the no_nutrition_data checkbox to map it to no_nutrition_data_on_packaging
	# The old nutrition_data and nutrition_data_prepared checkboxes were only used to show/hide the nutrition data sections on the web form
	# They do not map to any field in the new product structure

	my $checkbox_value = request_param($request_ref, "no_nutrition_data");
	if (defined $checkbox_value) {

		if (($checkbox_value eq '1') or ($checkbox_value eq "on")) {
			$product_ref->{nutrition}{no_nutrition_data_on_packaging} = true;
		}
		elsif (deep_exists($product_ref, qw/nutrition no_nutrition_data_on_packaging/)) {
			delete $product_ref->{nutrition}{no_nutrition_data_on_packaging};
		}
	}
	elsif (defined request_param($request_ref, "no_nutrition_data_displayed")) {
		if (deep_exists($product_ref, qw/nutrition no_nutrition_data_on_packaging/)) {
			delete $product_ref->{nutrition}{no_nutrition_data_on_packaging};
		}
	}

	return;
}

=head2 assign_nutrition_values_from_old_request_parameters ( $request_ref, $product_ref, $nutrient_table, $source )

This function provides backward compatibility for apps that use product edit API v2 (/cgi/product_jqm_multingual.pl)
before the introduction of the new nutrition data schema.

It reads the old nutrition data parameters from the request, and assigns them to the new product nutrition structure.

=head3 Parameters

=head4 $request_ref

Reference to the request parameters hash

=head4 $product_ref

Reference to the product hash where the nutrition data will be stored.

=head4 $nutrient_table

The nutriment table to use. It should be one of the keys of %nutrients_tables in Config.pm

=head4 $source

The source of the nutrition data. e.g. "packaging" or "manufacturer"

=cut

sub assign_nutrition_values_from_old_request_parameters ($request_ref, $product_ref, $nutrient_table, $source) {

	# Nutrition data

	$log->debug("Nutrition data") if $log->is_debug();

	assign_no_nutrition_data_from_request_parameters($request_ref, $product_ref);

	# We use a temporary input sets hash to ease setting values
	my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);

	if (has_no_nutrition_data_on_packaging($product_ref)) {

		# Delete all nutrition input sets for the source
		delete $input_sets_hash_ref->{$source};
	}
	else {

		# Assign all the nutrient values

		# We can have nutrient values for the product as sold, or prepared
		foreach my $preparation ("as_sold", "_prepared") {

			my $preparation_suffix = ($preparation eq "as_sold") ? "" : "_prepared";

			# If nutrition_data_per or nutrition_data_prepared_per is passed, use it for the per of the nutrient
			# otherwise default to 100g, 100ml or 1kg (for pet food)
			my $per = get_default_per_for_product($product_ref, $preparation);
			my $per_param = request_param($request_ref, "nutrition_data${preparation_suffix}_per");
			if (defined $per_param) {
				$per_param = decode utf8 => $per_param;
				if ($per_param =~ /^(100g|100ml|1kg|1l|serving)$/) {
					$per = $per_param;
				}
			}

			# If we have nutrition per serving, get the serving_size field from the product (or from the request if passed)
			# so that we can set the serving_quantity and serving_unit fields on the input set
			if ($per eq "serving") {
				my $serving_size_param = request_param($request_ref, "serving_size");
				if (defined $serving_size_param) {
					$product_ref->{serving_size} = decode utf8 => $serving_size_param;
					# Make sure we have a normalized serving size and unit
					normalize_product_quantity_and_serving_size($product_ref);
				}

				if (defined $product_ref->{serving_quantity}) {
					# set the per_quantity and per_unit fields of the input set
					$log->debug(
						"serving size for per serving",
						{
							serving_size => $product_ref->{serving_size},
							serving_quantity => $product_ref->{serving_quantity},
							serving_unit => $product_ref->{serving_unit}
						}
					) if $log->is_debug();
					deep_set($input_sets_hash_ref, $source, $preparation, $per, "per_quantity",
						$product_ref->{serving_quantity});
					deep_set($input_sets_hash_ref, $source, $preparation, $per, "per_unit",
						$product_ref->{serving_unit});
				}
				else {
					# no valid serving size, we will record the per serving values but without serving size
					$log->debug("no valid serving size for per serving nutrition data in API call",
						{serving_size => $product_ref->{serving_size}})
						if $log->is_debug();
				}
			}

			foreach my $nutriment (@{$nutrients_tables{$nutrient_table}}) {
				next if $nutriment =~ /^\#/;

				my $nid = $nutriment;
				$nid =~ s/^(-|!)+//g;
				$nid =~ s/-$//g;

				next if $nid =~ /^nutrition-score/;

				my $unit = request_param($request_ref, "nutriment_${nid}_unit");
				my $value_string = request_param($request_ref, "nutriment_${nid}${preparation_suffix}");

				# do not delete values if the nutriment is not provided
				next if (not defined $value_string);

				# energy: (see bug https://github.com/openfoodfacts/openfoodfacts-server/issues/2396 )
				# if the nid passed is just energy, set instead energy-kj or energy-kcal using the passed unit
				if (($nid eq "energy") and ((lc($unit) eq "kj") or (lc($unit) eq "kcal"))) {
					$nid = $nid . "-" . lc($unit);
					$log->debug("energy without unit, set nid with unit instead", {nid => $nid, unit => $unit})
						if $log->is_debug();
				}

				if ($nid eq 'alcohol') {
					$unit = '% vol';
				}

				# pet nutrients (analytical_constituents) are always in percent
				if (   ($nid eq 'crude-fat')
					or ($nid eq 'crude-protein')
					or ($nid eq 'crude-ash')
					or ($nid eq 'crude-fibre')
					or ($nid eq 'moisture'))
				{
					$unit = '%';
				}

				# Set the nutrient values
				my $modifier;
				normalize_nutrient_value_string_and_modifier(\$value_string, \$modifier);
				assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation, $per,
					$nid, $modifier, $value_string, $unit);
			}
		}
	}

	# Convert back the input sets hash to array
	deep_set($product_ref, "nutrition", "input_sets",
		convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref, $product_ref));

	return;
}

=head2 assign_nutrition_values_from_request_parameters ( $request_ref, $product_ref, $nutrient_table, $source )

This function is used by the web product edit form and apps that use product edit API v2
(/cgi/product_jqm_multingual.pl) after the introduction of the new nutrition data schema.

It reads the new nutrition data parameters from the request, and assigns them to the new product nutrition structure.

=head3 Parameters

=head4 $request_ref

Reference to the request object

=head4 $product_ref

Reference to the product hash where the nutrition data will be stored.

=head4 $nutrient_table

The nutriment table to use. It should be one of the keys of %nutrients_tables in Config.pm

=head4 $source

The source of the nutrition data. e.g. "packaging" or "manufacturer"

=cut

sub assign_nutrition_values_from_request_parameters ($request_ref, $product_ref, $nutrient_table, $source) {

	my @preparations = get_preparations_for_product_type($product_ref->{product_type});
	my @pers = get_pers_for_product_type($product_ref->{product_type});

	$log->debug(
		"assign_nutrition_values_from_request_parameters - start",
		{source => $source, preparations => \@preparations, pers => \@pers}
	) if $log->is_debug();

	assign_no_nutrition_data_from_request_parameters($request_ref, $product_ref);

	# We use a temporary input sets hash to ease setting values
	my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);

	# Assign all the nutrient values

	foreach my $nutrient (@{$nutrients_tables{$nutrient_table}}) {
		next if $nutrient =~ /^\#/;

		my $nid = $nutrient;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		next if $nid =~ /^nutrition-score/;

		# nutrient values and units are passed for the different input sets (for each preparation type and for each per quantity)
		# with parameters like:
		#
		# nutrition_input_sets_prepared_100ml_nutrients_saturated-fat_value_string
		# nutrition_input_sets_prepared_100ml_nutrients_saturated-fat_unit
		#
		# Note: the parameters are long because they mimic the structure of the product nutrition hash
		# with _ instead of . so that they can be passed as HTML form parameters without escaping.

		# Go through all the possible input sets
		foreach my $preparation (@preparations) {
			foreach my $per (@pers) {

				my $input_set_nutrient_id = "nutrition_input_sets_${preparation}_${per}_nutrients_${nid}";

				my $value_string = request_param($request_ref, "${input_set_nutrient_id}_value_string");

				if (defined $value_string) {
					my $unit = request_param($request_ref, "${input_set_nutrient_id}_unit");
					my $modifier = request_param($request_ref, "${input_set_nutrient_id}_modifier");
					assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation, $per,
						$nid, $modifier, $value_string, $unit);
				}
			}
		}
	}

	# Convert back the input sets hash to array
	deep_set($product_ref, "nutrition", "input_sets",
		convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref, $product_ref));

	return;
}

=head2 assign_nutrition_values_from_imported_csv_product ( $imported_csv_product_ref, $product_ref, $nutrient_table )

This function is used by Import.pm to import new nutrition data from an imported product (though a CSV file) to an existing product.

It reads the new nutrition data parameters from the imported product, and assigns them to the new product nutrition structure.

Note: the serving_size fields need to be imported first, as we need it to set the per_quantity and per_unit fields of the "serving" input sets.

Note: a source is not specified as argument to this function, as it should be set in the field names.

=head3 Parameters

=head4 $imported_csv_product_ref

Reference to the imported product hash where the nutrition data will be read.

All the fields in the imported product are at the root level, e.g. nutrition.input_sets.as_sold.100g.nutrients.energy.value_string

=head4 $product_ref

Reference to the product hash where the nutrition data will be stored.

=head4 $nutrient_table

The nutriment table to use. It should be one of the keys of %nutrients_tables in Config.pm

=head4 $source

The source of the nutrition data. e.g. "packaging" or "manufacturer"

=cut

sub assign_nutrition_values_from_imported_csv_product ($imported_csv_product_ref, $product_ref) {

	my @preparations = get_preparations_for_product_type($product_ref->{product_type});
	my @pers = get_pers_for_product_type($product_ref->{product_type});

	# We use a temporary input sets hash to ease setting values
	my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);

	# We identify all the sources included in the imported product fields
	# We look for fields that start with nutrition.input_sets.${source}.${preparation}.${per}.nutrients.
	my %sources = ();
	foreach my $field (keys %{$imported_csv_product_ref}) {
		if ($field =~ /^nutrition\.input_sets\.([a-zA-Z0-9_-]+)\.([a-z_]+)\.(100g|100ml|1kg|1l|serving)\.nutrients\./) {
			my $source = $1;
			$sources{$source} = 1;
		}
	}
	my @sources = sort keys %sources;

	# Assign all the nutrient values

	foreach my $nutrient_tagid (sort(get_all_taxonomy_entries("nutrients"))) {

		my $nid = $nutrient_tagid;
		$nid =~ s/^zz://g;

		next if $nid =~ /^nutrition-score/;

		# nutrient values and units are passed for the different input sets (for each preparation type and for each per quantity)
		# with parameters like:
		#
		# nutrition.input_sets.packaging.prepared.100ml.nutrients.saturated-fat.value_string
		# nutrition.input_sets.packaging.prepared.100ml.nutrients.saturated-fat.unit
		#
		# Note: the parameters are long because they mimic the structure of the product nutrition hash

		# Go through all the possible input sets
		foreach my $preparation (@preparations) {
			foreach my $per (@pers) {
				foreach my $source (@sources) {

					my $input_set_nutrient_id = "nutrition.input_sets.${source}.${preparation}.${per}.nutrients.${nid}";

					my $value_string = $imported_csv_product_ref->{"${input_set_nutrient_id}.value_string"};

					($nid eq 'salt') and $log->debug(
						"imported csv product nutrient value",
						{
							input_set_nutrient_id => $input_set_nutrient_id,
							value_string => $value_string,
							key => "${input_set_nutrient_id}.value_string"
						}
					) if $log->is_debug();

					if (defined $value_string) {

						$log->debug("imported csv product nutrient value found",
							{input_set_nutrient_id => $input_set_nutrient_id, value_string => $value_string})
							if $log->is_debug();

						my $unit = $imported_csv_product_ref->{"${input_set_nutrient_id}.unit"};
						my $modifier = $imported_csv_product_ref->{"${input_set_nutrient_id}.modifier"};
						assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation,
							$per, $nid, $modifier, $value_string, $unit);
					}
				}
			}
		}
	}

	# Convert back the input sets hash to array
	deep_set($product_ref, "nutrition", "input_sets",
		convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref, $product_ref));

	$log->debug("assign_nutrition_values_from_imported_csv_product - done", {product_ref => $product_ref->{nutrition}})
		if $log->is_debug();

	# FIXME / TODO: indicate if there are modifications

	return;
}

=head2 import_nutrients_old_fields($args_ref, $imported_product_ref, $product_ref, $stats_ref, $modified_ref, $modified_fields_ref, $differing_ref, $differing_fields_ref, $nutrients_edited_ref, $time)

Import nutrient values from old style fields like fat_100g_value, fat_100g_unit, fat_prepared_100g_value, etc.

We consider the source to be "packaging" on the public platform, and "manufacturer" on the producers platform

Note: the serving_size fields need to be imported first, as we need it to set the per_quantity and per_unit fields of the "serving" input sets.

=cut

sub assign_nutrition_values_from_imported_csv_product_old_fields (
	$args_ref, $imported_product_ref, $product_ref, $stats_ref,
	$modified_ref, $modified_fields_ref, $differing_ref, $differing_fields_ref,
	$nutrients_edited_ref, $time, $source
	)
{
	# We use a temporary input sets hash to ease setting values
	my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);

	my $code = $imported_product_ref->{code};

	foreach my $nutrient_tagid (sort(get_all_taxonomy_entries("nutrients"))) {

		my $nid = $nutrient_tagid;
		$nid =~ s/^zz://g;

		next if $nid =~ /^nutrition-score/;

		# for prepared product
		my $nidp = $nid . "_prepared";

		# We may have nid_value, nid_100g_value or nid_serving_value.

		foreach my $type ("", "_prepared") {

			foreach my $per ("", "_100g", "_serving") {

				my $value;
				my $unit;

				if (    (defined $imported_product_ref->{$nid . $type . $per . "_value"})
					and ($imported_product_ref->{$nid . $type . $per . "_value"} ne ""))
				{
					$value = $imported_product_ref->{$nid . $type . $per . "_value"};
				}

				if (    (defined $imported_product_ref->{$nid . $type . $per . "_unit"})
					and ($imported_product_ref->{$nid . $type . $per . "_unit"} ne ""))
				{
					$unit = $imported_product_ref->{$nid . $type . $per . "_unit"};
				}

				# Energy can be: 852KJ/ 203Kcal
				# calcium_100g_value_unit = 50 mg
				# 10g
				if (not defined $value) {
					if (defined $imported_product_ref->{$nid . $type . $per . "_value_unit"}) {

						# Assign energy-kj and energy-kcal values from energy field

						if (    ($nid eq "energy")
							and ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /\b([0-9]+)(\s*)kJ/i))
						{
							if (not defined $imported_product_ref->{$nid . "-kj" . $type . $per . "_value_unit"}) {
								$imported_product_ref->{$nid . "-kj" . $type . $per . "_value_unit"} = $1 . " kJ";
							}
						}
						if (
								($nid eq "energy")
							and ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /\b([0-9]+)(\s*)kcal/i)
							)
						{
							if (not defined $imported_product_ref->{$nid . "-kcal" . $type . $per . "_value_unit"}) {
								$imported_product_ref->{$nid . "-kcal" . $type . $per . "_value_unit"} = $1 . " kcal";
							}
						}

						if ($imported_product_ref->{$nid . $type . $per . "_value_unit"}
							=~ /^(~?<?>?=?\s?([0-9]*(\.|,))?[0-9]+)(\s*)([a-zµ%]+)$/i)
						{
							$value = $1;
							$unit = $5;
						}
						# We might have only a number even if the field is set to value_unit
						# in that case, use the default unit
						elsif ($imported_product_ref->{$nid . $type . $per . "_value_unit"}
							=~ /^(([0-9]*(\.|,))?[0-9]+)(\s*)$/i)
						{
							$value = $1;
						}
					}
				}

				# calcium_100g_value_in_mcg

				if (not defined $value) {
					foreach my $u ('kj', 'kcal', 'kg', 'g', 'mg', 'mcg', 'l', 'dl', 'cl', 'ml', 'iu', 'percent') {
						my $value_in_u = $imported_product_ref->{$nid . $type . $per . "_value" . "_in_" . $u};
						if ((defined $value_in_u) and ($value_in_u ne "")) {
							$value = $value_in_u;
							$unit = $u;
						}
					}
				}

				if ($nid eq 'alcohol') {
					$unit = '% vol';
				}

				# Standardize units
				if (defined $unit) {
					if ($unit eq "kj") {
						$unit = "kJ";
					}
					elsif ($unit eq "mcg") {
						$unit = "µg";
					}
					elsif ($unit eq "iu") {
						$unit = "IU";
					}
					elsif ($unit eq "percent") {
						$unit = '%';
					}
				}

				my $modifier = undef;

				# Remove bogus values (e.g. nutrition facts for multiple nutrients): 1 digit followed by letters followed by more digits
				if ((defined $value) and ($value =~ /\d.*[a-z].*\d/)) {
					$log->debug("nutrient with strange value, skipping",
						{nid => $nid, type => $type, value => $value, unit => $unit})
						if $log->is_debug();
					$value = undef;
				}

				if ((defined $value) and ($value ne '')) {

					$log->debug("nutrient with defined and non empty value",
						{nid => $nid, type => $type, value => $value, unit => $unit})
						if $log->is_debug();
					$stats_ref->{"products_with_nutrition" . $type}{$code} = 1;

					# if the nid is "energy" and we have a unit, set "energy-kj" or "energy-kcal"
					if (($nid eq "energy") and ((lc($unit) eq "kj") or (lc($unit) eq "kcal"))) {
						$nid = "energy-" . lc($unit);
					}

					my $preparation = ($type eq "") ? "as_sold" : "prepared";

					# If the per is "" (not specified in the field name), we use the value from the
					# nutrition_data_per or nutrition_data_prepared_per field if it exists,
					# otherwise we default to 100g
					my $new_per;
					if ($per eq "") {
						my $nutrition_data_per = $imported_product_ref->{"nutrition_data" . $type . "_per"};
						if (defined $nutrition_data_per) {
							$nutrition_data_per = lc($nutrition_data_per);
							if ($nutrition_data_per =~ /^(100g|100ml|1kg|1l|serving)$/) {
								$new_per = $nutrition_data_per;
							}
						}
					}
					else {
						$new_per = $per;
						$new_per =~ s/^_//g;
					}
					if (not defined $new_per) {
						$new_per = get_default_per_for_product($product_ref, $preparation);
					}

					assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation,
						$new_per, $nid, $modifier, $value, $unit);

				}
			}
		}
	}

	# Convert back the input sets hash to array
	deep_set($product_ref, "nutrition", "input_sets",
		convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref, $product_ref));

	return;
}

=head2 assign_nutrition_values_from_request_object ( $request_ref, $product_ref )

This function is used by the product edit API v3 (/api/v3/product) to write the nutrition data.
Nutrition data is passed in nutrition.input_sets as an array of input sets.

It reads the nutrition data from the request, and assigns them to the new product nutrition structure.

=head3 Parameters

=head4 $request_ref

Reference to the request object

=head4 $product_ref

Reference to the product hash where the nutrition data will be stored.

=cut

sub assign_nutrition_values_from_request_object ($request_ref, $product_ref) {

	my $request_body_ref = $request_ref->{body_json};
	my $response_ref = $request_ref->{api_response};

	$request_ref->{updated_product_fields}{nutrition} = 1;

	if (ref($request_body_ref->{product}{nutrition}) ne 'HASH') {
		add_error(
			$response_ref,
			{
				message => {id => "invalid_type_must_be_object"},
				field => {id => "nutrition"},
				impact => {id => "field_ignored"},
			},
			200
		);
	}
	else {
		# We use a temporary input sets hash to ease setting values
		my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);

		# Go through every input set passed in the request
		if (exists $request_body_ref->{product}{nutrition}{input_sets}
			and ref($request_body_ref->{product}{nutrition}{input_sets}) eq 'ARRAY')
		{
			my $input_set_index = -1;
			foreach my $input_set_ref (@{$request_body_ref->{product}{nutrition}{input_sets}}) {

				$input_set_index++;

				my $ignore_set = 0;

				if (ref($input_set_ref) ne 'HASH') {
					add_error(
						$response_ref,
						{
							message => {id => "invalid_type_must_be_object"},
							field => {id => "nutrition.inputs_sets[$input_set_index]"},
							impact => {id => "input_set_ignored"},
						},
						200
					);
					next;
				}

				my $source = $input_set_ref->{source};
				my $preparation = $input_set_ref->{preparation};
				my $per = $input_set_ref->{per};

				if ((not defined $source) or ($source eq "")) {
					add_error(
						$response_ref,
						{
							message => {id => "missing_field"},
							field => {id => "nutrition.inputs_sets[$input_set_index].source"},
							impact => {id => "input_set_ignored"},
						},
						200
					);
					$ignore_set = 1;
				}
				if ((not defined $preparation) or ($preparation eq "")) {
					add_error(
						$response_ref,
						{
							message => {id => "missing_field"},
							field => {id => "nutrition.inputs_sets[$input_set_index].preparation"},
							impact => {id => "input_set_ignored"},
						},
						200
					);
					$ignore_set = 1;
				}
				if ((not defined $per) or ($per eq "")) {
					add_error(
						$response_ref,
						{
							message => {id => "missing_field"},
							field => {id => "nutrition.inputs_sets[$input_set_index].per"},
							impact => {id => "input_set_ignored"},
						},
						200
					);
					$ignore_set = 1;
				}

				if ($ignore_set) {
					next;
				}

				# If we are passed unspecified_nutrients, set them in the input set
				# If unspecified_nutrients is undef, we delete the field
				if (exists $input_set_ref->{unspecified_nutrients}) {

					# If unspecified_nutrients exists but is undef, we delete the field
					if (not defined $input_set_ref->{unspecified_nutrients}) {
						if (exists $input_sets_hash_ref->{$source}{$preparation}{$per}{unspecified_nutrients}) {
							delete $input_sets_hash_ref->{$source}{$preparation}{$per}{unspecified_nutrients};
						}
					}
					elsif (ref($input_set_ref->{unspecified_nutrients}) eq 'ARRAY') {
						# We only keep valid nutrient ids
						my @unspecified_nutrients = ();
						foreach my $nid (@{$input_set_ref->{unspecified_nutrients}}) {
							if (exists $valid_nutrients{$nid}) {
								push @unspecified_nutrients, $nid;
							}
							else {
								add_error(
									$response_ref,
									{
										message => {id => "unknown_nutrient"},
										field => {
											id => "nutrition.inputs_sets[$input_set_index].unspecified_nutrients",
											value => $nid
										},
										impact => {id => "nutrient_ignored"},
									},
									200
								);
							}
						}
						if (scalar(@unspecified_nutrients) > 0) {
							deep_set($input_sets_hash_ref, $source, $preparation, $per, "unspecified_nutrients",
								\@unspecified_nutrients);
						}
						else {
							if (exists $input_sets_hash_ref->{$source}{$preparation}{$per}{unspecified_nutrients}) {
								delete $input_sets_hash_ref->{$source}{$preparation}{$per}{unspecified_nutrients};
							}
						}
					}
					else {
						add_error(
							$response_ref,
							{
								message => {id => "invalid_type_must_be_array_or_null"},
								field => {id => "nutrition.inputs_sets[$input_set_index].unspecified_nutrients"},
								impact => {id => "field_ignored"},
							},
							200
						);
					}
				}

				if (exists $input_set_ref->{nutrients}) {

					# If nutrients exists but is undef, we delete the set completely
					if (not defined $input_set_ref->{nutrients}) {
						delete $input_sets_hash_ref->{$source}{$preparation}{$per};
						next;
					}

					if (ref($input_set_ref->{nutrients}) eq 'HASH') {
						foreach my $nid (sort keys %{$input_set_ref->{nutrients}}) {

							# Check the nutrient id is valid
							if (not exists $valid_nutrients{$nid}) {
								add_error(
									$response_ref,
									{
										message => {id => "unknown_nutrient"},
										field => {id => "nutrition.inputs_sets[$input_set_index].nutrients.$nid"},
										impact => {id => "nutrient_ignored"},
									},
									200
								);
								next;
							}

							# If the nutrient exists but is undef, we delete it from the input set
							if (not defined $input_set_ref->{nutrients}{$nid}) {
								if (exists $input_sets_hash_ref->{$source}{$preparation}{$per}{nutrients}{$nid}) {
									delete $input_sets_hash_ref->{$source}{$preparation}{$per}{nutrients}{$nid};
								}
								next;
							}

							my $nutrient_ref = $input_set_ref->{nutrients}{$nid};
							if (ref($nutrient_ref) ne 'HASH') {
								add_error(
									$response_ref,
									{
										message => {id => "invalid_type_must_be_object"},
										field => {id => "nutrition.inputs_sets[$input_set_index].nutrients.$nid"},
										impact => {id => "nutrient_ignored"},
									},
									200
								);
								next;
							}
							my $modifier = $nutrient_ref->{modifier};
							my $value_string = $nutrient_ref->{value_string};
							my $unit = $nutrient_ref->{unit};
							if (not defined $value_string) {
								add_error(
									$response_ref,
									{
										message => {id => "missing_field"},
										field => {
											id => "nutrition.inputs_sets[$input_set_index].nutrients.$nid.value_string"
										},
										impact => {id => "nutrient_ignored"},
									},
									200
								);
								next;
							}
							assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation,
								$per, $nid, $modifier, $value_string, $unit);

						}
					}
					else {
						add_error(
							$response_ref,
							{
								message => {id => "invalid_type_must_be_object_or_null"},
								field => {id => "nutrition.inputs_sets[$input_set_index].nutrients"},
								impact => {id => "field_ignored"},
							},
							200
						);
					}
				}
			}
		}

		# Convert back the input sets hash to array
		deep_set($product_ref, "nutrition", "input_sets",
			convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref, $product_ref));
	}
	return;
}

=head2 compute_estimated_nutrients ( $product_ref )

Compute estimated nutrients from ingredients.

If we have a high enough confidence (95% of the ingredients (by quantity) have a known nutrient profile),
we store the result in an nutrient input set with the source "estimate".

Otherwise we remove the estimated nutrients input set if it exists.

=cut

sub compute_estimated_nutrients ($product_ref) {

	# We use a temporary input sets hash to ease setting values
	my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);
	my $source = "estimate";
	my $preparation = "as_sold";
	my $modifier = '~';    # estimated value modifier

	# For the per, we get the default per for the product, and use 100g if it is a weight,
	# or 100ml if it is a volume, as the estimated nutrients are always per 100g or 100ml.
	# So for pet food, even though the default per is 1kg, we use 100g for the estimated nutrients.
	my $per = get_default_per_for_product($product_ref, $preparation);
	if ($per =~ /kg$/) {
		$per = "100g";
	}
	elsif ($per =~ /l$/) {
		$per = "100ml";
	}

	# Remove any existing estimated nutrients input set
	delete $input_sets_hash_ref->{$source}{$preparation}{$per};

	if (defined $product_ref->{ingredients}) {
		# compute estimated nutrients from ingredients
		my $results_ref = estimate_nutrients_from_ingredients($product_ref->{ingredients});

		# only take the result if we have at least 95% of ingredients with nutrients
		if (($results_ref->{total} > 0) and (($results_ref->{total_with_nutrients} / $results_ref->{total}) >= 0.95)) {

			while (my ($nid, $value) = each(%{$results_ref->{nutrients}})) {
				my $unit = default_unit_for_nid($nid);
				# We currently assign value_string (which will also set value)
				# Not sure if it makes sense to only set value and have no value_string
				assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation,
					$per, $nid, $modifier, $value, $unit);
			}

			add_tag($product_ref, "misc", "en:nutrients-estimated-from-ingredients");
		}
		else {
			add_tag($product_ref, "misc",
				"en:nutrients-not-estimated-from-ingredients-too-few-ingredients-with-nutrition-data");
		}

		# Compute % of specific ingredients needed for Nutri-Score
		my $fruits_vegetable_nuts
			= estimate_nutriscore_2021_fruits_vegetables_nuts_percent_from_ingredients($product_ref);
		my $fruits_vegetables_legumes
			= estimate_nutriscore_2023_fruits_vegetables_legumes_percent_from_ingredients($product_ref);
		my $added_sugars = estimate_added_sugars_percent_from_ingredients($product_ref);
		assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation,
			$per, 'fruits-vegetables-nuts', $modifier, $fruits_vegetable_nuts, '%');
		assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation,
			$per, 'fruits-vegetables-legumes', $modifier, $fruits_vegetables_legumes, '%');

		# Added sugars for added sugars panel
		assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation,
			$per, 'added-sugars', $modifier, $added_sugars, 'g');

		# If some nutrients were estimated, include "Estimate from ingredients" as the source description
		if (exists $input_sets_hash_ref->{$source}{$preparation}{$per}{nutrients}) {
			deep_set($input_sets_hash_ref, $source, $preparation, $per, "source_description",
				"Estimate from ingredients");
		}
	}
	else {
		add_tag($product_ref, "misc", "en:nutrients-not-estimated-from-ingredients-no-ingredients");
	}

	# Convert back the input sets hash to array
	deep_set($product_ref, "nutrition", "input_sets",
		convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref, $product_ref));

	return;
}

=head2 remove_empty_nutrient_values_and_set_unspecified_nutrients ($input_set_ref)

Removes nutrients with empty values from an input set.

If a nutrient has a modifier equal to "-", it means no value is specified on the packaging.

The nutrient is removed from the input set and added to the unspecified_nutrients array.

=head3 Arguments

=head4 $input_set_ref

Reference to the input set hash

=cut

sub remove_empty_nutrient_values_and_set_unspecified_nutrients ($input_set_ref) {

	if (exists $input_set_ref->{nutrients} and ref $input_set_ref->{nutrients} eq 'HASH') {
		foreach my $nid (sort keys %{$input_set_ref->{nutrients}}) {
			my $nutrient_ref = $input_set_ref->{nutrients}{$nid};
			# If we have a modifier equal to a dash - , it means no value is specified on the packaging
			# We remove the nutrient from the input set
			if (defined $nutrient_ref->{modifier} and $nutrient_ref->{modifier} eq '-') {
				delete $input_set_ref->{nutrients}{$nid};
				# add it to the unspecified_nutrients array if it's not already there
				if (not defined $input_set_ref->{unspecified_nutrients}) {
					$input_set_ref->{unspecified_nutrients} = [];
				}
				if (not grep {$_ eq $nid} @{$input_set_ref->{unspecified_nutrients}}) {
					push @{$input_set_ref->{unspecified_nutrients}}, $nid;
				}
			}
			# If the value is undefined, we remove the nutrient from the input set
			elsif (not defined $nutrient_ref->{value}) {
				delete $input_set_ref->{nutrients}{$nid};
			}
			# If the modifier is undefined or empty, we remove it from the nutrient
			elsif ((not defined $nutrient_ref->{modifier}) or ($nutrient_ref->{modifier} eq '')) {
				delete $nutrient_ref->{modifier};
			}
		}
		# Remove the nutrients hash if it's empty
		if (scalar(keys %{$input_set_ref->{nutrients}}) == 0) {
			delete $input_set_ref->{nutrients};
		}
	}
	return;
}

=head2 add_nutrition_fields_from_product_to_populated_fields($product_ref, \%populated_fields, $sort_key)

This function is used by Export.pm to generate the list of populated nutrition fields for a product.
Export.pm can then create a CSV file with columns that have data for at least one product.

If we have a value for a nutrient in an input set of the product, we add the corresponding field to the populated fields hash,
so that it can be output in the CSV file.

e.g. for an input set like:

input_sets => [
	{
		preparation => "as_sold",
		per => "serving",
		per_quantity => "1",
		per_unit => "l",
		source => "packaging",
		nutrients => {
			"sodium" => {
				value_string => "0.25",
				value => 0.25,
				unit => "g",
			},
			"sugars" => {
				value_string => "2.0",
				value => 2,
				unit => "g",
			}
		}
	},
	{
		preparation => "as_sold",
		per => "serving",
		per_quantity => "50",
		per_unit => "ml",
		source => "manufacturer",
		nutrients => {
			"sugars" => {
				value_string => "0.063",
				value => 0.063,
				unit => "g",
			}
		}
	}
]

We generate those keys and values in the populated fields hash:

{
   "nutrition.input_sets.manufacturer.as_sold.serving.nutrients.sugars.unit" : "nutrition_01-manufacturer_as_sold_serving_2-nutrients_043-sugars_unit",
   "nutrition.input_sets.manufacturer.as_sold.serving.nutrients.sugars.value" : "nutrition_01-manufacturer_as_sold_serving_2-nutrients_043-sugars_value",
   "nutrition.input_sets.manufacturer.as_sold.serving.nutrients.sugars.value_string" : "nutrition_01-manufacturer_as_sold_serving_2-nutrients_043-sugars_value_string",
   "nutrition.input_sets.manufacturer.as_sold.serving.per_quantity" : "nutrition_01-manufacturer_as_sold_serving_0-root_per_quantity",
   "nutrition.input_sets.manufacturer.as_sold.serving.per_unit" : "nutrition_01-manufacturer_as_sold_serving_0-root_per_unit",
   "nutrition.input_sets.packaging.as_sold.serving.nutrients.sodium.unit" : "nutrition_01-packaging_as_sold_serving_2-nutrients_068-sodium_unit",
   "nutrition.input_sets.packaging.as_sold.serving.nutrients.sodium.value" : "nutrition_01-packaging_as_sold_serving_2-nutrients_068-sodium_value",
   "nutrition.input_sets.packaging.as_sold.serving.nutrients.sodium.value_string" : "nutrition_01-packaging_as_sold_serving_2-nutrients_068-sodium_value_string",
   "nutrition.input_sets.packaging.as_sold.serving.nutrients.sugars.unit" : "nutrition_01-packaging_as_sold_serving_2-nutrients_043-sugars_unit",
   "nutrition.input_sets.packaging.as_sold.serving.nutrients.sugars.value" : "nutrition_01-packaging_as_sold_serving_2-nutrients_043-sugars_value",
   "nutrition.input_sets.packaging.as_sold.serving.nutrients.sugars.value_string" : "nutrition_01-packaging_as_sold_serving_2-nutrients_043-sugars_value_string",
   "nutrition.input_sets.packaging.as_sold.serving.per_quantity" : "nutrition_01-packaging_as_sold_serving_0-root_per_quantity",
   "nutrition.input_sets.packaging.as_sold.serving.per_unit" : "nutrition_01-packaging_as_sold_serving_0-root_per_unit"
}


The key is the CSV field name, and the value is a sort key used to sort the fields in the CSV file.

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=head4 \%populated_fields

Reference to the hash of populated fields

=head4 $sort_key

A string used to sort the fields in the CSV file.
The nutrition fields sort keys will be prefixed by this sort key.

=cut

sub add_nutrition_fields_from_product_to_populated_fields($product_ref, $populated_fields_ref, $sort_key) {

	if (not defined $product_ref->{nutrition}) {
		return;
	}

	# Fields at the root of nutrition
	my $item_number = 0;
	foreach my $field ("no_nutrition_data_on_packaging") {
		if (defined deep_get($product_ref, "nutrition", $field)) {
			$populated_fields_ref->{$field} = $sort_key . '_0-root_' . sprintf("%02d", $item_number);
		}
		$item_number++;
	}

	# Aggregated set: not needed at first for exporting and importing data as it is generated from the input sets
	# TODO: export when $export_args_ref->{export_nutrition_aggregated_set} = 1;

	# Input sets

	# Get the sets in a hash to ease processing
	my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);
	if (defined $input_sets_hash_ref) {
		foreach my $source (sort keys %{$input_sets_hash_ref}) {
			foreach my $preparation (sort keys %{$input_sets_hash_ref->{$source}}) {
				foreach my $per (sort keys %{$input_sets_hash_ref->{$source}{$preparation}}) {

					my $input_set_ref = $input_sets_hash_ref->{$source}{$preparation}{$per};

					my $input_set_sort_key
						= $sort_key . '_'
						. sprintf("%02d", $item_number) . '-'
						. $source . '_'
						. $preparation . '_'
						. $per;

					# Fields at the root of the input set
					foreach my $field ("per_quantity", "per_unit") {
						if (defined $input_set_ref->{$field}) {
							$populated_fields_ref->{"nutrition.input_sets.${source}.${preparation}.${per}.${field}"}
								= $input_set_sort_key . '_0-root_' . $field;
						}
					}

					# unspecified_nutrients
					if (    defined $input_set_ref->{unspecified_nutrients}
						and ref($input_set_ref->{unspecified_nutrients}) eq 'ARRAY'
						and scalar(@{$input_set_ref->{unspecified_nutrients}}) > 0)
					{
						$populated_fields_ref->{
							"nutrition.input_sets.${source}.${preparation}.${per}.unspecified_nutrients"}
							= $input_set_sort_key . '_1-unspecified_nutrients';
					}

					# nutrients
					if ((defined $input_set_ref->{nutrients})
						and ref($input_set_ref->{nutrients}) eq 'HASH')
					{
						my $nutrients_ref = $input_set_ref->{nutrients};

						# We go through nutrients in the order of the off_europe nutrients table
						# Go through the nutriment table
						my $nutrient_number = 0;

						foreach my $nutriment (@{$nutrients_tables{off_europe}}) {

							next if $nutriment =~ /^\#/;
							my $nid = $nutriment;

							$nutrient_number++;

							$nid =~ s/^(-|!)+//g;
							$nid =~ s/-$//g;

							next if $nid =~ /^nutrition-score/;

							my $nutrient_ref = $nutrients_ref->{$nid};

							if ((defined $nutrient_ref) and (ref($nutrient_ref) eq 'HASH')) {
								foreach my $field ("modifier", "value_string", "value", "unit") {
									if (defined $nutrient_ref->{$field}) {
										$populated_fields_ref->{
											"nutrition.input_sets.${source}.${preparation}.${per}.nutrients.${nid}.${field}"
											}
											= $input_set_sort_key
											. '_2-nutrients_'
											. sprintf("%03d", $nutrient_number) . '-'
											. $nid . '_'
											. $field;
									}
								}
							}
						}
					}
				}
			}
		}
	}

	return;
}

=head2 filter_out_nutrients_not_in_taxonomy ($product_ref)

In the old nutrition facts schema (2025 and before), we authorized users to add any nutrient they wanted, even if they did not exist in the taxonomy.
In the new nutrition facts schema, we only authorize nutrients that exist in the taxonomy.

This function tries to map unknown nutrients to known nutrients in the taxonomy (as the taxonomy is evolving, some nutrients that were unknown before may now exist in the taxonomy).
It then filters out nutrients that do not exist in the taxonomy and that could not be mapped to known nutrients.

Removes nutrients from the product's C<nutriments> hash that are not present in the taxonomy.

=head3 Example input data

The following are examples of unknown nutrients that may be present in the C<nutriments> hash:

  # unknown nutrient prefixed with language
  'fr-nitrate' => 0.38,
  'fr-nitrate_100g' => 0.38,
  'fr-nitrate_label' => "Nitrate",
  'fr-nitrate_serving' => 0.0038,
  'fr-nitrate_unit' => "g",
  'fr-nitrate_value' => 0.38,

  # unknown nutrient not prefixed with language (old fields)
  'sulfat' => 0.0141,
  'sulfat_100g' => 0.0141,
  'sulfat_label' => "Sulfat",
  'sulfat_serving' => 0.141,
  'sulfat_unit' => "mg",
  'sulfat_value' => 14.1,

  # unknown nutrient that is not in the taxonomy
  'en-some-unknown-nutrient' => 1.23,
  'en-some-unknown-nutrient_100g' => 1.23,
  'en-some-unknown-nutrient_label' => "Some unknown nutrient",
  'en-some-unknown-nutrient_unit' => "g",
  'en-some-unknown-nutrient_value' => 1.23,

=cut

sub filter_out_nutrients_not_in_taxonomy ($product_ref) {

	my $nutriments_ref = $product_ref->{nutriments};

	return if not defined $nutriments_ref;

	my %hash_nutrients = map {/^([a-z][a-z\-]*[a-z]?)(?:_\w+)?$/ ? ($1 => 1) : ()} keys %{$product_ref->{nutriments}};

	foreach my $nid (sort keys %hash_nutrients) {

		# check that the nutrient exists in the taxonomy
		my $nutrient_id = "zz:" . $nid;
		if (not exists_taxonomy_tag("nutrients", $nutrient_id)) {
			# Check if we can canonicalize the nid to a known nutrient
			my $exists_in_taxonomy = 0;
			my $canonical_nid
				= canonicalize_taxonomy_tag($product_ref->{lang} || 'en', "nutrients", $nid, \$exists_in_taxonomy);
			# If we did not find a canonical id, the nutrient may be prefixed with the language (e.g. fr-sulfate)
			if (not $exists_in_taxonomy) {
				if ($nid =~ /^([a-z][a-z])-(.+)$/) {
					$canonical_nid = canonicalize_taxonomy_tag($1, "nutrients", $2, \$exists_in_taxonomy);
				}
			}
			# If we found an existing nutrient in the taxonomy, we rename the nutrient in the product
			if ($exists_in_taxonomy) {
				foreach my $field_suffix ("", "_100g", "_serving", "_label", "_unit", "_value") {
					my $old_field = $nid . $field_suffix;
					if (exists $nutriments_ref->{$old_field}) {
						my $new_field = $canonical_nid;
						$new_field =~ s/^zz://;    # remove zz: prefix
						$new_field .= $field_suffix;
						$nutriments_ref->{$new_field} = $nutriments_ref->{$old_field};
					}
				}
			}

			# Delete the old fields
			foreach my $field_suffix ("", "_100g", "_serving", "_label", "_unit", "_value") {
				my $old_field = $nid . $field_suffix;
				if (exists $nutriments_ref->{$old_field}) {
					delete $nutriments_ref->{$old_field};
				}
			}
		}
	}

	return;
}

=head2 convert_sodium_to_salt ( $sodium_value )

Converts a sodium value to its equivalent salt value using the EU standard conversion factor (2.5).

=cut

sub convert_sodium_to_salt ($sodium_value) {

	return $sodium_value * 2.5;
}

=head2 convert_salt_to_sodium ( $salt_value )

Converts a salt value to its equivalent sodium value using the EU standard conversion factor (2.5).

=cut

sub convert_salt_to_sodium ($salt_value) {

	return $salt_value / 2.5;
}

# Nutrients to energy conversion
# Currently only supporting Europe's method (similar to US and Canada 4-4-9, 4-4-9-7 and 4-4-9-7-2)

%energy_from_nutrients = (
	europe => {
		carbohydrates_minus_polyols => {kj => 17, kcal => 4},
		polyols_minus_erythritol => {kj => 10, kcal => 2.4},
		proteins => {kj => 17, kcal => 4},
		fat => {kj => 37, kcal => 9},
		salatrim => {kj => 25, kcal => 6},    # no corresponding nutrients in nutrient tables?
		alcohol => {kj => 29, kcal => 7},
		organic_acids => {kj => 13, kcal => 3},    # no corresponding nutrients in nutrient tables?
		fiber => {kj => 8, kcal => 2},
		erythritol => {kj => 0, kcal => 0},
	},
);

=head2 compute_energy_from_nutrients_for_nutrients_set ( $nutrients_ref, $unit )

Computes the energy from other nutrients for a given input set.

=head3 Parameters

=head4 $nutrients_ref: reference to the nutrients hash.

=head4 $unit: unit to use for energy computation ("kj" or "kcal").

=head3 Returns

The computed energy value.

The value is also stored in energy nutrients hashes as "value_computed".

=cut

sub compute_energy_from_nutrients_for_nutrients_set ($nutrients_ref, $unit) {

	my $computed_energy;

	my $carbohydrates_value = deep_get($nutrients_ref, "carbohydrates", "value");
	my $fat_value = deep_get($nutrients_ref, "fat", "value");
	my $proteins_value = deep_get($nutrients_ref, "proteins", "value");
	# We need at a minimum carbohydrates, fat and proteins to be defined to compute
	# energy.
	if (    (defined $carbohydrates_value)
		and (defined $fat_value)
		and (defined $proteins_value))
	{

		foreach my $nid (keys %{$energy_from_nutrients{europe}}) {

			my $energy_per_gram = $energy_from_nutrients{europe}{$nid}{$unit};
			my $grams = 0;
			# handles nutrient1__minus__nutrient2 case
			if ($nid =~ /_minus_/) {
				my $nid_minus = $';
				$nid = $`;

				# If we are computing carbohydrates minus polyols, and we do not have a value for polyols
				# but we have a value for erythritol (which is a polyol), then we need to remove erythritol
				if (($nid_minus eq "polyols") and (not deep_exists($nutrients_ref, $nid_minus, "value"))) {
					$nid_minus = "erythritol";
				}
				# Similarly for polyols minus erythritol
				if (($nid eq "polyols") and (not deep_exists($nutrients_ref, $nid, "value"))) {
					$nid = "erythritol";
				}

				$grams -= deep_get($nutrients_ref, $nid_minus, "value") || 0;
			}
			$grams += deep_get($nutrients_ref, $nid, "value") || 0;
			$computed_energy += $grams * $energy_per_gram;
		}

		# store computed energy value and the unit (in case it's not there yet if we don't have a not computed value)
		deep_set($nutrients_ref, "energy-${unit}", "value_computed", $computed_energy);
		deep_set($nutrients_ref, "energy-${unit}", "unit", $unit);
	}

	return $computed_energy;
}

=head2 has_non_estimated_nutrition_data ( $product_ref )

Checks if the product has at least one nutrient with a non-estimated value

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=cut

sub has_non_estimated_nutrition_data ($product_ref) {

	# Go through each input set, check if source is different than "estimate"
	# Empty input sets should have been removed before calling this function

	my $inputs_sets_array_ref = deep_get($product_ref, "nutrition", "input_sets");

	if (defined $inputs_sets_array_ref) {
		foreach my $input_set_ref (@{$inputs_sets_array_ref}) {
			my $source = $input_set_ref->{source};
			if (defined $source and ($source ne "estimate")) {
				# We have at least one input set with a non-estimated source
				return 1;
			}
		}
	}

	return 0;
}

=head2 get_nutrition_data_as_key_values_pairs ( $product_ref )

This function is used by ProductOpener::Product::complete_product_history_and_completeness()

It serialize the nutrition data into key-value pairs (flat hashmap) for easier comparison of product history entries.

Estimates are not returned.

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=head3 Returns

A reference to a hash of key-value pairs representing the nutrition data of the product.

=cut

sub get_nutrition_data_as_key_values_pairs ($product_ref) {

	my %nutrition_data_kv_pairs = ();

	my $inputs_sets_array_ref = deep_get($product_ref, "nutrition", "input_sets");

	if (defined $inputs_sets_array_ref) {
		foreach my $input_set_ref (@{$inputs_sets_array_ref}) {
			my $source = $input_set_ref->{source} || "";
			my $preparation = $input_set_ref->{preparation} || "";
			my $per = $input_set_ref->{per} || "";

			# skip estimate from ingredients
			if ($source eq "estimate") {
				next;
			}

			# unspecified_nutrients
			if (exists $input_set_ref->{unspecified_nutrients}
				and ref($input_set_ref->{unspecified_nutrients}) eq 'ARRAY')
			{
				my @sorted_unspecified_nutrients = sort @{$input_set_ref->{unspecified_nutrients}};
				$nutrition_data_kv_pairs{"${source}.${preparation}.${per}.unspecified_nutrients"}
					= join(",", @sorted_unspecified_nutrients);
			}

			# nutrients
			if (    (exists $input_set_ref->{nutrients})
				and (ref($input_set_ref->{nutrients}) eq 'HASH'))
			{
				while (my ($nid, $nutrient_ref) = each(%{$input_set_ref->{nutrients}})) {
					# Note: we skip value_string and only include value, in order to avoid listing 2 entries for 1 nutrient difference
					foreach my $field ("modifier", "value", "unit") {
						if (defined $nutrient_ref->{$field}) {
							$nutrition_data_kv_pairs{"${source}.${preparation}.${per}.nutrients.${nid}.${field}"}
								= $nutrient_ref->{$field};
						}
					}
				}
			}
		}
	}

	return \%nutrition_data_kv_pairs;
}

=head2 has_no_nutrition_data_on_packaging ( $product_ref )

Checks if the product has the no_nutrition_data_on_packaging flag set to true.

=head3 Arguments

=head4 $product_ref

Reference to the product hash

=cut

sub has_no_nutrition_data_on_packaging ($product_ref) {

	my $no_nutrition_data_on_packaging = deep_get($product_ref, "nutrition", "no_nutrition_data_on_packaging");

	if ((defined $no_nutrition_data_on_packaging) and ($no_nutrition_data_on_packaging == true)) {
		return 1;
	}

	return 0;
}

=head2 remove_empty_nutrition_data ( $product_ref )

Remove the empty nutrition data (empty input_sets and/or aggregated_set),
and the nutrition hash if it is empty.

=cut

sub remove_empty_nutrition_data ($product_ref) {

	# Remove empty input sets
	my $input_sets_ref = deep_get($product_ref, "nutrition", "input_sets");
	my $aggregated_set_ref = deep_get($product_ref, "nutrition", "aggregated_set");
	if ((defined $input_sets_ref) and (ref($input_sets_ref) eq 'ARRAY') and (scalar(@{$input_sets_ref}) == 0)) {
		delete $product_ref->{nutrition}{input_sets};
	}
	if (    (defined $aggregated_set_ref)
		and (ref($aggregated_set_ref) eq 'HASH')
		and (scalar(keys %{$aggregated_set_ref}) == 0))
	{
		delete $product_ref->{nutrition}{aggregated_set};
	}
	# Remove nutrition if empty
	if (    (defined $product_ref->{nutrition})
		and (ref($product_ref->{nutrition}) eq 'HASH')
		and (scalar(keys %{$product_ref->{nutrition}}) == 0))
	{
		delete $product_ref->{nutrition};
	}

	return;
}

1;

