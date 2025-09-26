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
		&generate_nutrient_aggregated_set_from_sets
		&get_specific_nutrition_input_set
		&get_nutrition_input_sets_in_a_hash
		&convert_nutrition_input_sets_hash_to_array
		&get_source_for_site_and_org
		&get_preparations_for_product_type
		&get_pers_for_product_type
		&get_default_per_for_product
		&get_unit_options_for_nutrient
		&assign_nutrient_modifier_value_string_and_unit
		&assign_nutrition_values_from_old_request_parameters
		&assign_nutrition_values_from_request_parameters
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

# FIXME: remove single_param and use request_param
use ProductOpener::HTTP qw/single_param request_param/;

use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::Numbers qw/convert_string_to_number remove_insignificant_digits/;

use Log::Any qw($log);

use Encode;
use Data::DeepAccess qw(deep_get deep_set);

=head1 FUNCTIONS

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

	# store original index to get index source of nutrients for generated set
	my @input_sets = map {{index => $_, set => $input_sets_ref->[$_]}} 0 .. $#$input_sets_ref;
	my $aggregated_nutrient_set_ref = {};

	if (@input_sets) {
		@input_sets = sort_sets_by_priority(@input_sets);
		# remove sets with quantities that are impossible to transform to 100g
		# ie sets with unknow per quantity
		@input_sets = grep {defined $_->{set}{per_quantity} && $_->{set}{per_quantity} ne ""} @input_sets;

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

The priority is based on the sources, the per references and the preparation states present in the nutrient sets.

=head3 Arguments

=head4 @input_sets

Unsorted array nutrient sets hashes

=head3 Return values

Sorted array nutrient sets hashes

=cut

sub sort_sets_by_priority (@input_sets) {
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
		"1kg" => 2,
		serving => 3,
		_default => 4,
	);

	my %preparation_priority = (
		prepared => 0,
		as_sold => 1,
		_default => 2,
	);

	return (
		sort {
			my $source_key_a = defined $a->{set}{source} ? $a->{set}{source} : '_default';
			my $source_key_b = defined $b->{set}{source} ? $b->{set}{source} : '_default';
			my $source_a = $source_priority{$source_key_a};
			my $source_b = $source_priority{$source_key_b};

			my $per_key_a = defined $a->{set}{per} ? $a->{set}{per} : '_default';
			my $per_key_b = defined $b->{set}{per} ? $b->{set}{per} : '_default';
			my $per_a = $per_priority{$per_key_a};
			my $per_b = $per_priority{$per_key_b};

			my $preparation_key_a = defined $a->{set}{preparation} ? $a->{set}{preparation} : '_default';
			my $preparation_key_b = defined $b->{set}{preparation} ? $b->{set}{preparation} : '_default';
			my $preparation_a = $preparation_priority{$preparation_key_a};
			my $preparation_b = $preparation_priority{$preparation_key_b};

			# sort priority : source then per then preparation
			return $source_a <=> $source_b || $per_a <=> $per_b || $preparation_a <=> $preparation_b;
		} @input_sets
	);
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
			foreach my $nutrient (keys %{$nutrient_set_ref->{nutrients}}) {
				# for each nutrient, set its values if values are not already present in aggregated set
				# (ie if nutrient not present in other set with higher priority)
				if (!exists $aggregated_nutrient_set_ref->{nutrients}{$nutrient}) {
					$aggregated_nutrient_set_ref->{nutrients}{$nutrient}
						= clone($nutrient_set_ref->{nutrients}{$nutrient});
					delete $aggregated_nutrient_set_ref->{nutrients}{$nutrient}{value_string};
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
	my $standard_unit = default_unit_for_nid($nutrient_name);

	if ($standard_unit ne $nutrient_ref->{unit}) {
		if ($standard_unit eq "kcal") {
			$nutrient_ref->{value} = unit_to_kcal($nutrient_ref->{value}, $nutrient_ref->{unit});
		}
		elsif ($standard_unit eq "kJ") {
			$nutrient_ref->{value} = unit_to_kj($nutrient_ref->{value}, $nutrient_ref->{unit});
		}
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

=head2 convert_nutrition_input_sets_hash_to_array ($input_sets_hash_ref)

Converts a hash reference of input sets back to an array reference, which is the format we store in the product structure

Input sets are normalized:
- nutrients with undefined or empty values are removed
- nutrient with a modifier "-" are removed and added to the unspecified nutrients array
- input sets with no nutrients are removed
- the source, preparation and per values from the input sets hash keys are set in the input set

=head3 Arguments

=head4 $input_sets_hash_ref

Reference to hash of input sets

=head3 Return values

Reference to array of input sets

=cut

sub convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref) {

	$log->debug("convert_nutrition_input_sets_hash_to_array: start", {input_sets_hash_ref => $input_sets_hash_ref})
		if $log->is_debug();

	my $input_sets_ref = [];
	if (defined $input_sets_hash_ref and ref $input_sets_hash_ref eq 'HASH') {
		foreach my $source (sort keys %{$input_sets_hash_ref}) {
			foreach my $preparation (sort keys %{$input_sets_hash_ref->{$source}}) {
				foreach my $per (sort keys %{$input_sets_hash_ref->{$source}{$preparation}}) {

					my $input_set_ref = $input_sets_hash_ref->{$source}{$preparation}{$per};

					remove_empty_nutrient_values_and_normalize_input_set($input_set_ref);

					# Empty input sets are not stored
					if (!exists $input_set_ref->{nutrients} or (keys %{$input_set_ref->{nutrients}}) == 0) {
						next;
					}

					# Set the source, preparation and per as they may be only in the keys
					$input_set_ref->{source} = $source;
					$input_set_ref->{preparation} = $preparation;
					$input_set_ref->{per} = $per;
					push(@{$input_sets_ref}, $input_set_ref);
				}
			}
		}
	}
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

	my @preparations = ("as_sold", "prepared");

	# Pet food only has "as_sold"
	if ($product_type eq "petfood") {
		@preparations = ("as_sold");
	}
	return @preparations;
}

=head2 get_pers_for_product_type

Returns the list of valid per quantities for a given product type.

=head3 Arguments

=head4 $product_type

Type of the product (food, petfood, etc)

=head3 Return values

List of valid per references for the given product type

=cut

sub get_pers_for_product_type ($product_type) {

	my @pers = ("100g", "100ml", "serving");

	# Pet food only has "per1kg"
	if ($product_type eq "petfood") {
		@pers = ("1kg");
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
		$default_per = $category_default_per;
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
	# pet nutrients (analytical_constituents) are always in percent
	elsif (($nid eq 'crude-fat')
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

	if (   (defined get_property("nutrients", "zz:$nid", "dv_value:en"))
		or ($nid =~ /^new_/))
	{
		push @units, '% DV';
	}
	if (   (defined get_property("nutrients", "zz:$nid", "iu_value:en"))
		or ($nid =~ /^new_/))
	{
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

	# We can have a modifier with value '-' to indicate that we have no value
	# It will be recorded in the unspecified_nutrients array by the remove_empty_nutrient_values_and_normalize_input_set() function

	if ($modifier eq '') {
		$modifier = undef;
	}

	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "modifier", $modifier);

	if ($value_string eq '') {
		$value_string = undef;
	}

	my $value;

	if (defined $value_string) {
		$value_string = convert_string_to_number($value_string);
		$value_string = remove_insignificant_digits($value_string);

		# empty unit?
		if ((not defined $unit) or ($unit eq "")) {
			$unit = default_unit_for_nid($nid);
		}

		$value = convert_string_to_number($value_string);
	}

	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "value_string", $value_string);
	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "value", $value);
	deep_set($input_sets_hash_ref, $source, $preparation, $per, "nutrients", $nid, "unit", $unit);

	return;
}

=head2 assign_nutrition_values_from_old_request_parameters ( $product_ref, $nutriment_table, $source )

This function provides backward compatibility for apps that use product edit API v2 (/cgi/product_jqm_multingual.pl)
before the introduction of the new nutrition data schema.

It reads the old nutrition data parameters from the request, and assigns them to the new product nutrition structure.

=head3 Parameters

=head4 $product_ref

Reference to the product hash where the nutrition data will be stored.

=head4 $nutriment_table

The nutriment table to use. It should be one of the keys of %nutriments_tables in Config.pm

=head4 $source

The source of the nutrition data. e.g. "packaging" or "manufacturer"

=cut

sub assign_nutrition_values_from_old_request_parameters ($product_ref, $nutriment_table, $source) {

	# Nutrition data

	$log->debug("Nutrition data") if $log->is_debug();

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

	foreach my $checkbox ("no_nutrition_data", "nutrition_data", "nutrition_data_prepared") {

		if (defined single_param($checkbox)) {
			my $checkbox_value = decode utf8 => single_param($checkbox);
			if (($checkbox_value eq '1') or ($checkbox_value eq "on")) {
				$product_ref->{$checkbox} = "on";
			}
			else {
				$product_ref->{$checkbox} = "";
			}
		}
		elsif (defined single_param($checkbox . "_displayed")) {
			$product_ref->{$checkbox} = "";
		}
	}

	# Assign all the nutrient values

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {

		next if (($nid =~ /_/) and ($nid !~ /_prepared$/));

		$nid =~ s/_prepared$//;

		if (    (not exists_taxonomy_tag("nutrients", "zz:$nid"))
			and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid}))
		{
			push @unknown_nutriments, $nid;
			$log->debug("unknown_nutriment", {nid => $nid}) if $log->is_debug();
		}
	}

	# It is possible to add nutrients that we do not know about
	# by using parameters like new_0, new_1 etc.
	my @new_nutriments = ();
	my $new_max = single_param('new_max') || 0;
	for (my $i = 1; $i <= $new_max; $i++) {
		push @new_nutriments, "new_$i";
	}

	# If we have only 1 of the salt and sodium values,
	# delete any existing values for the other one,
	# and it will be computed from the one we have
	foreach my $product_type ("", "_prepared") {
		my $saltnid = "salt${product_type}";
		my $sodiumnid = "sodium${product_type}";

		my $salt = single_param("nutriment_${saltnid}");
		my $sodium = single_param("nutriment_${sodiumnid}");

		if ((defined $sodium) and (not defined $salt)) {
			delete $product_ref->{nutriments}{$saltnid};
			delete $product_ref->{nutriments}{$saltnid . "_unit"};
			delete $product_ref->{nutriments}{$saltnid . "_value"};
			delete $product_ref->{nutriments}{$saltnid . "_modifier"};
			delete $product_ref->{nutriments}{$saltnid . "_label"};
			delete $product_ref->{nutriments}{$saltnid . "_100g"};
			delete $product_ref->{nutriments}{$saltnid . "_serving"};
		}
		elsif ((defined $salt) and (not defined $sodium)) {
			delete $product_ref->{nutriments}{$sodiumnid};
			delete $product_ref->{nutriments}{$sodiumnid . "_unit"};
			delete $product_ref->{nutriments}{$sodiumnid . "_value"};
			delete $product_ref->{nutriments}{$sodiumnid . "_modifier"};
			delete $product_ref->{nutriments}{$sodiumnid . "_label"};
			delete $product_ref->{nutriments}{$sodiumnid . "_100g"};
			delete $product_ref->{nutriments}{$sodiumnid . "_serving"};
		}
	}

	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments, @new_nutriments) {
		next if $nutriment =~ /^\#/;

		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;

		next if $nid =~ /^nutrition-score/;

		# Unit and label are the same for as sold and prepared nutrition table
		my $enid = encodeURIComponent($nid);

		# We can have nutrient values for the product as sold, or prepared
		foreach my $product_type ("", "_prepared") {

			my $unit = remove_tags_and_quote(decode utf8 => single_param("nutriment_${enid}_unit"));
			my $label = remove_tags_and_quote(decode utf8 => single_param("nutriment_${enid}_label"));

			# do not delete values if the nutriment is not provided
			next if (not defined single_param("nutriment_${enid}${product_type}"));

			my $value = remove_tags_and_quote(decode utf8 => single_param("nutriment_${enid}${product_type}"));

			# energy: (see bug https://github.com/openfoodfacts/openfoodfacts-server/issues/2396 )
			# 1. if energy-kcal or energy-kj is set, delete existing energy data
			if (($nid eq "energy-kj") or ($nid eq "energy-kcal")) {
				delete $product_ref->{nutriments}{"energy${product_type}"};
				delete $product_ref->{nutriments}{"energy_unit"};
				delete $product_ref->{nutriments}{"energy_label"};
				delete $product_ref->{nutriments}{"energy${product_type}_value"};
				delete $product_ref->{nutriments}{"energy${product_type}_modifier"};
				delete $product_ref->{nutriments}{"energy${product_type}_100g"};
				delete $product_ref->{nutriments}{"energy${product_type}_serving"};
			}
			# 2. if the nid passed is just energy, set instead energy-kj or energy-kcal using the passed unit
			elsif (($nid eq "energy") and ((lc($unit) eq "kj") or (lc($unit) eq "kcal"))) {
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
			normalize_nutriment_value_and_modifier(\$value, \$modifier);
			assign_nid_modifier_value_and_unit($product_ref, $nid . ${product_type}, $modifier, $value, $unit);
		}

		# If we don't have a value for the product and the prepared product, delete the unit and label
		if (    (not defined $product_ref->{nutriments}{$nid})
			and (not defined $product_ref->{nutriments}{$nid . "_prepared"}))
		{
			delete $product_ref->{nutriments}{$nid . "_unit"};
			delete $product_ref->{nutriments}{$nid . "_label"};
		}
	}

	if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {

		# Delete all non-carbon-footprint nids.
		foreach my $key (keys %{$product_ref->{nutriments}}) {
			next if $key =~ /_/;
			next if $key eq 'carbon-footprint';

			delete $product_ref->{nutriments}{$key};
			delete $product_ref->{nutriments}{$key . "_unit"};
			delete $product_ref->{nutriments}{$key . "_value"};
			delete $product_ref->{nutriments}{$key . "_modifier"};
			delete $product_ref->{nutriments}{$key . "_label"};
			delete $product_ref->{nutriments}{$key . "_100g"};
			delete $product_ref->{nutriments}{$key . "_serving"};
		}
	}
	return;
}

=head2 assign_nutrition_values_from_request_parameters ( $request_ref, $product_ref, $nutriment_table, $source )

This function is used by the web product edit form and apps that use product edit API v2
(/cgi/product_jqm_multingual.pl) after the introduction of the new nutrition data schema.

It reads the new nutrition data parameters from the request, and assigns them to the new product nutrition structure.

=head3 Parameters

=head4 $request_ref

Reference to the request object

=head4 $product_ref

Reference to the product hash where the nutrition data will be stored.

=head4 $nutriment_table

The nutriment table to use. It should be one of the keys of %nutriments_tables in Config.pm

=head4 $source

The source of the nutrition data. e.g. "packaging" or "manufacturer"

=cut

sub assign_nutrition_values_from_request_parameters ($request_ref, $product_ref, $nutriment_table, $source) {

	my @preparations = get_preparations_for_product_type($product_ref->{product_type});
	my @pers = get_pers_for_product_type($product_ref->{product_type});

	$log->debug(
		"assign_nutrition_values_from_request_parameters - start",
		{source => $source, preparations => \@preparations, pers => \@pers}
	) if $log->is_debug();

	# We use a temporary input sets hash to ease setting values
	my $input_sets_hash_ref = get_nutrition_input_sets_in_a_hash($product_ref);

	# Assign all the nutrient values

	foreach my $nutrient (@{$nutriments_tables{$nutriment_table}}) {
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
					normalize_nutriment_value_and_modifier(\$value_string, \$modifier);
					assign_nutrient_modifier_value_string_and_unit($input_sets_hash_ref, $source, $preparation, $per,
						$nid, $modifier, $value_string, $unit);
				}
			}
		}
	}

	# Convert back the input sets hash to array
	deep_set($product_ref, "nutrition", "input_sets", convert_nutrition_input_sets_hash_to_array($input_sets_hash_ref));

	return;
}

=head2 remove_empty_nutrient_values_and_normalize_input_set ($input_set_ref)

Removes nutrients with empty values from an input set.

If a nutrient has a modifier equal to "-", it means no value is specified on the packaging.

The nutrient is removed from the input set and added to the unspecified_nutrients array.

=head3 Arguments

=head4 $input_set_ref

Reference to the input set hash

=cut

sub remove_empty_nutrient_values_and_normalize_input_set ($input_set_ref) {

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
			# If the value_string is undefined or empty, we remove the nutrient from the input set
			elsif ((not defined $nutrient_ref->{value_string}) or ($nutrient_ref->{value_string} eq '')) {
				delete $input_set_ref->{nutrients}{$nid};
			}
			# If the modifier is undefined or empty, we remove it from the nutrient
			elsif ((not defined $nutrient_ref->{modifier}) or ($nutrient_ref->{modifier} eq '')) {
				delete $nutrient_ref->{modifier};
			}
		}
	}
	return;
}

1;
