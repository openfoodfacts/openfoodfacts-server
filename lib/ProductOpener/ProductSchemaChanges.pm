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

ProductOpener::ProductSchemaChanges - convert product data between different schema versions

=head1 DESCRIPTION

C<ProductOpener::ProductSchemaChanges> is used to convert product data between different schema versions.

It can convert older product data (e.g. from old revisions of products) to the current schema version.

And for API backward compatibility, it can also convert the current product data to older schema versions.

=head2 Schema version numbering

Starting from March 2024, we will now include a new field in the product data called "schema_version", which will be an integer, starting at 1001.

The schema version will be incremented by 1 each time we make a change to the product data schema.

Products without a schema_version field will be considered to be at a schema version under 1000

=head2 Schema conversion functions

We will keep a list of functions that can convert product data between different schema versions.

=cut

package ProductOpener::ProductSchemaChanges;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		$current_schema_version
		&convert_product_schema
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any qw($log);

use ProductOpener::Food qw/default_unit_for_nid/;
use ProductOpener::Tags qw/compute_field_tags/;
use ProductOpener::Products qw/normalize_code/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Booleans qw/normalize_boolean/;
use ProductOpener::Images qw/normalize_generation_ref/;
use ProductOpener::Nutrition qw/generate_nutrient_aggregated_set_from_sets/;

use Data::DeepAccess qw(deep_get deep_set);
use boolean ':all';
use List::Util qw/any/;

$current_schema_version = 1002;

my (%upgrade_functions, %downgrade_functions);

=head1 FUNCTIONS

=head2 convert_product_schema ($product_ref, $to_version)

Convert product data between different schema versions.

=cut

sub convert_product_schema ($product_ref, $to_version) {

	# If the product data does not have a schema_version field, it is 1000 or lower
	# If the product data contains environmental_score_grade, it is 1000, otherwise we set it to 998
	# so that we can run the 998 to 999 upgrade function (barcode normalization)
	my $from_version = $product_ref->{schema_version} // 999;
	if ($from_version < 1000 and exists $product_ref->{environmental_score_grade}) {
		$from_version = 1000;
	}

	$log->debug("convert_product_schema - from_version: $from_version, to_version: $to_version",
		{product_ref => $product_ref})
		if $log->is_debug();

	if ($from_version < $to_version) {
		# incrementally upgrade schema
		for (my $schema_version = $from_version; $schema_version < $to_version; $schema_version++) {
			if (exists $upgrade_functions{$schema_version}) {
				$upgrade_functions{$schema_version}->($product_ref);
			}
		}
	}
	elsif ($from_version > $to_version) {
		# incrementally downgrade version
		for (my $schema_version = $from_version; $schema_version > $to_version; $schema_version--) {
			if (exists $downgrade_functions{$schema_version}) {
				$downgrade_functions{$schema_version}->($product_ref);
			}
		}
	}

	$product_ref->{schema_version} = $to_version;

	return;
}

%upgrade_functions = (
	998 => \&convert_schema_998_to_999_change_barcode_normalization,
	999 => \&convert_schema_999_to_1000_rename_ecoscore_fields_to_environmental_score,
	1000 => \&convert_schema_1000_to_1001_remove_ingredients_hierarchy_taxonomize_brands,
	1001 => \&convert_schema_1001_to_1002_refactor_images_object,
	1002 => \&convert_schema_1002_to_1003_refactor_product_nutrition_schema,
);

%downgrade_functions = (
	1000 => \&convert_schema_1000_to_999_rename_ecoscore_fields_to_environmental_score,
	1001 => \&convert_schema_1001_to_1000_remove_ingredients_hierarchy_taxonomize_brands,
	1002 => \&convert_schema_1002_to_1001_refactor_images_object,
	1003 => \&convert_schema_1003_to_1002_refactor_product_nutrition_schema,
);

=head2 998 to 999 - Change in barcode normalization

Change in normalization of leading 0s.

=cut

sub convert_schema_998_to_999_change_barcode_normalization ($product_ref) {

	my $code = normalize_code($product_ref->{code});
	$product_ref->{code} = $code;
	if (defined $product_ref->{id}) {
		$product_ref->{id} = $code;
	}
	if ($server_options{private_products}) {
		$product_ref->{_id} = $product_ref->{owner} . "/" . $code;
	}
	else {
		$product_ref->{_id} = $code;
	}

	return;
}

=head2 999 to 1000 - Rename ecoscore fields to environmental_score fields - API v3.1

2024/12/12 - 

=cut

sub convert_schema_999_to_1000_rename_ecoscore_fields_to_environmental_score ($product_ref) {

	# 2024/12: ecoscore fields were renamed to environmental_score
	foreach my $subfield (qw/data grade score tags/) {
		if (defined $product_ref->{"ecoscore_" . $subfield}) {
			# If we already have corresponding environmental_score fields, we keep them
			if (not defined $product_ref->{"environmental_score_" . $subfield}) {
				$product_ref->{"environmental_score_" . $subfield} = $product_ref->{"ecoscore_" . $subfield};
			}
			delete $product_ref->{"ecoscore_" . $subfield};
		}
	}

	return;
}

sub convert_schema_1000_to_999_rename_ecoscore_fields_to_environmental_score ($product_ref) {

	# 2024/12: ecoscore fields were renamed to environmental_score
	foreach my $subfield (qw/data grade score tags/) {
		if (defined $product_ref->{"environmental_score_" . $subfield}) {
			$product_ref->{"ecoscore_" . $subfield} = $product_ref->{"environmental_score_" . $subfield};
			delete $product_ref->{"environmental_score_" . $subfield};
		}
	}

	return;
}

=head2 1000 to 1001 - Remove the ingredients_hierarchy field - API v3.2

2012/03/14

- Remove the ingredients_hierarchy field, which was a duplicate of the ingredients_tags field
- Taxonomize brands

=cut

sub convert_schema_1000_to_1001_remove_ingredients_hierarchy_taxonomize_brands ($product_ref) {

	# The ingredients_hierarchy array contained exactly the same data as the ingredients_tags array
	delete $product_ref->{ingredients_hierarchy};

	# Taxonomize brands
	# we use the main language of the product, but the brands taxonomy is language-less
	# (all canonical entries use the language less xx: prefix) so any language would give the same result
	if (defined $product_ref->{brands}) {
		compute_field_tags($product_ref, $product_ref->{lang}, "brands");
	}

	return;
}

sub convert_schema_1001_to_1000_remove_ingredients_hierarchy_taxonomize_brands ($product_ref) {

	# The ingredients_hierarchy array contained exactly the same data as the ingredients_tags array
	if (exists $product_ref->{ingredients_tags}) {
		$product_ref->{ingredients_hierarchy} = $product_ref->{ingredients_tags};
	}

	# remove brands_lc and brands_hierarchy
	delete $product_ref->{brands_lc};
	delete $product_ref->{brands_hierarchy};
	# brands should already contain the list of brands, so we do not need to regenerate it from brands_hierarchy
	# brands_tags contains xx: prefixed tags, we can remove the xx: prefix to get the non-taxonomized canonical tags we had before
	if (exists $product_ref->{brands_tags}) {
		for my $brand_tag (@{$product_ref->{brands_tags}}) {
			$brand_tag =~ s/^xx://;
		}
	}

	return;
}

=head2 1001 to 1002 - Refactor the images object

The images object is restructured to separate uploaded images from selected images

=cut

sub convert_schema_1001_to_1002_refactor_images_object ($product_ref) {

	if (exists $product_ref->{images}) {
		my $uploaded_ref = {};
		my $selected_ref = {};
		foreach my $imgid (%{$product_ref->{images}}) {
			# Uploaded images have an imageid which is a string containing an integer starting from 1
			if ($imgid =~ /^\d+$/) {
				$uploaded_ref->{$imgid} = $product_ref->{images}->{$imgid};
			}
			# Selected images have an imageid which is a string containing a word and a 2 letter language code (e.g. ingredients_fr)
			elsif ($imgid =~ /^(\w+)_(\w\w)$/) {
				my ($type, $lc) = ($1, $2);
				# Put keys related to cropping / rotation / normalization inside a "generation" structure
				my $image_ref = $product_ref->{images}->{$imgid};
				my $new_image_ref = {
					imgid => $image_ref->{imgid},
					rev => $image_ref->{rev},
					sizes => $image_ref->{sizes},
				};
				my $generation_ref = normalize_generation_ref($image_ref);
				if (defined $generation_ref) {
					$new_image_ref->{generation} = $generation_ref;
				}
				deep_set($selected_ref, $type, $lc, $new_image_ref);
			}
		}
		$product_ref->{images} = {
			uploaded => $uploaded_ref,
			selected => $selected_ref,
		};
	}

	return;
}

sub convert_schema_1002_to_1001_refactor_images_object ($product_ref) {

	# We need to convert the images object back to the old format
	if (exists $product_ref->{images}) {
		my $images_ref = $product_ref->{images};
		my $new_images_ref = {};
		# Copy uploaded images
		if (exists $images_ref->{uploaded}) {
			# We need to copy the uploaded images back to the main images object
			foreach my $imgid (keys %{$images_ref->{uploaded}}) {
				$new_images_ref->{$imgid} = $images_ref->{uploaded}{$imgid};
			}
		}
		# Copy selected images
		if (exists $images_ref->{selected}) {
			foreach my $type (keys %{$images_ref->{selected}}) {
				foreach my $lc (keys %{$images_ref->{selected}->{$type}}) {
					my $image_ref = $images_ref->{selected}->{$type}->{$lc};
					my $new_image_ref = {};
					# copy imgid, rev, sizes
					$new_image_ref->{imgid} = $image_ref->{imgid};
					$new_image_ref->{rev} = $image_ref->{rev};
					$new_image_ref->{sizes} = $image_ref->{sizes};
					# copy keys from the generation structure to the image structure
					# and delete the generation structure
					foreach my $key (keys %{$image_ref->{generation}}) {
						$new_image_ref->{$key} = $image_ref->{generation}->{$key};
						# Normalize boolean values to "true" or "false" strings
						if (($key eq 'normalize') or ($key eq 'white_magic')) {
							$new_image_ref->{$key}
								= isTrue(normalize_boolean($new_image_ref->{$key})) ? "true" : "false";
						}
					}
					$new_images_ref->{$type . "_" . $lc} = $new_image_ref;
				}
			}
		}

		# Replace the images object with the new one
		$product_ref->{images} = $new_images_ref;
	}

	return;
}

=head2 1002 to 1003 - Refactor the product nutrition schema - API v3.4

The nutrition schema is updated to allow storing several nutrition sets

=cut

sub convert_schema_1002_to_1003_refactor_product_nutrition_schema ($product_ref) {
	# generate the same update time for the nutrition sets that are going to be created
	my $update_time = time() + 0;

	$product_ref->{nutrition} = {};
	$product_ref->{nutrition}{unspecified_nutrients} = [];

	# only create sets for which the nutrient values are given and not computed
	my $new_nutrition_sets_ref = {};
	my $no_nutrition_data = defined $product_ref->{no_nutrition_data} && $product_ref->{no_nutrition_data} eq "on";

	if ($no_nutrition_data) {
		$product_ref->{nutrition}{no_nutrition_data} = true;
	}
	else {
		my $nutrition_given_as_prepared
			= defined $product_ref->{nutrition_data_prepared} && $product_ref->{nutrition_data_prepared} eq "on";
		my $nutrition_given_as_sold = defined $product_ref->{nutrition_data} && $product_ref->{nutrition_data} eq "on";

		if ($nutrition_given_as_sold) {
			my $nutrition_given_for_100g
				= defined $product_ref->{nutrition_data_per} && $product_ref->{nutrition_data_per} eq "100g";
			my $nutrition_given_for_serving
				= defined $product_ref->{nutrition_data_per} && $product_ref->{nutrition_data_per} eq "serving";

			if ($nutrition_given_for_100g) {
				$new_nutrition_sets_ref->{"100g"} = {};
			}
			elsif ($nutrition_given_for_serving) {
				$new_nutrition_sets_ref->{serving} = {};
			}
		}
		if ($nutrition_given_as_prepared) {
			my $nutrition_given_for_100g = defined $product_ref->{nutrition_data_prepared_per}
				&& $product_ref->{nutrition_data_prepared_per} eq "100g";
			my $nutrition_given_for_serving = defined $product_ref->{nutrition_data_prepared_per}
				&& $product_ref->{nutrition_data_prepared_per} eq "serving";

			if ($nutrition_given_for_100g) {
				$new_nutrition_sets_ref->{"prepared_100g"} = {};
			}
			elsif ($nutrition_given_for_serving) {
				$new_nutrition_sets_ref->{prepared_serving} = {};
			}
		}
	}

	# hash used to easily access nutrient fields of old set and set preparation values of new sets
	my $nutrition_preparations_ref = {
		"prepared_100g" => {state => "prepared", modifier_state => "_prepared"},
		"prepared_serving" => {state => "prepared", modifier_state => "_prepared"},
		"100g" => {state => "as_sold", modifier_state => ""},
		"serving" => {state => "as_sold", modifier_state => ""},
	};

	if (defined $product_ref->{nutriments} && !$no_nutrition_data) {
		my %hash_nutrients = map {/^([a-z][a-z\-]*[a-z]?)(?:_\w+)?$/ ? ($1 => 1) : ()}
			keys %{$product_ref->{nutriments}};

		my @nutrients = keys %hash_nutrients;

		# add unspecified nutrients to the unspecified list
		# those nutrients won't be added to the nutrient sets
		foreach my $nutrient (@nutrients) {
			# if nutrient modifier is "-" then this nutrient is unspecified
			if (defined $product_ref->{nutriments}{$nutrient . "_modifier"}
				and $product_ref->{nutriments}{$nutrient . "_modifier"} eq "-")
			{
				push(@{$product_ref->{nutrition}{unspecified_nutrients}}, $nutrient);
			}
		}

		# Generates the nutrition sets,
		# which, for old data, are all from source "packaging"
		foreach my $set_type (keys %$new_nutrition_sets_ref) {
			$new_nutrition_sets_ref->{$set_type}{preparation} = $nutrition_preparations_ref->{$set_type}{state};
			$new_nutrition_sets_ref->{$set_type}{source} = "packaging";
			$new_nutrition_sets_ref->{$set_type}{last_updated_t} = $update_time;

			$new_nutrition_sets_ref->{$set_type}{per_unit}
				= set_per_unit($product_ref->{product_quantity_unit}, $product_ref->{serving_quantity_unit}, $set_type);

			# set per_quantity as the serving quantity if the set is generated with nutrient quantities per serving,
			# or as 100 if it is generated with quantities per 100g/ml
			$new_nutrition_sets_ref->{$set_type}{per_quantity}
				= ($set_type eq "serving" or $set_type eq "prepared_serving")
				? $product_ref->{serving_quantity}
				: 100;

			# set per as serving if the set is generated with nutrient quantities per serving,
			# or as 100g or 100ml if it is generated with quantities per 100g/ml
			$new_nutrition_sets_ref->{$set_type}{per}
				= ($set_type eq "serving" or $set_type eq "prepared_serving")
				? "serving"
				: "100" . $new_nutrition_sets_ref->{$set_type}{per_unit};

			$new_nutrition_sets_ref->{$set_type}{nutrients} = {};

			foreach my $nutrient (@nutrients) {
				# only add the nutrient value if it is provided for the set type
				if (defined $product_ref->{nutriments}{$nutrient . '_' . $set_type} && !any {$_ eq $nutrient}
					@{$product_ref->{nutrition}{unspecified_nutrients}})
				{
					my $nutrient_value = $product_ref->{nutriments}{$nutrient . '_' . $set_type};
					my $nutrient_set_ref = {};
					$nutrient_set_ref->{value} = $nutrient_value;
					$nutrient_set_ref->{unit} = default_unit_for_nid($nutrient);
					# the 1002 version products do not have a value string so the float value is converted to string
					$nutrient_set_ref->{value_string} = sprintf("%s", $nutrient_value);

					my $nutrient_field_modifier
						= $nutrient . ($nutrition_preparations_ref->{$set_type}{modifier_state}) . "_modifier";
					if (defined $product_ref->{nutriments}{$nutrient_field_modifier}) {
						$nutrient_set_ref->{modifier} = $product_ref->{nutriments}{$nutrient_field_modifier};
					}
					$new_nutrition_sets_ref->{$set_type}{nutrients}{$nutrient} = $nutrient_set_ref;
				}
			}
		}
	}

	# add the created sets to the new nutrition field
	$product_ref->{nutrition}{input_sets} = [
		grep {defined $_ && %{$_->{nutrients}}} (
			$new_nutrition_sets_ref->{"prepared_100g"}, $new_nutrition_sets_ref->{prepared_serving},
			$new_nutrition_sets_ref->{"100g"}, $new_nutrition_sets_ref->{serving}
		)
	];
	# generate the aggregated set with the created sets
	$product_ref->{nutrition}{aggregated_set}
		= generate_nutrient_aggregated_set_from_sets($product_ref->{nutrition}{input_sets});

	# delete the old nutrition schema from the product and other now useless fields
	delete $product_ref->{nutriments};
	delete $product_ref->{no_nutrition_data};
	delete $product_ref->{nutrition_data};
	delete $product_ref->{nutrition_data_per};
	delete $product_ref->{nutrition_data_prepared};
	delete $product_ref->{nutrition_data_prepared_per};

	return;
}

=head2 set_per_unit

Set the per unit depending on the given product quantity unit, the serving quantity unit
and on the fact that the created set is per 100g or per serving

=cut

sub set_per_unit ($product_quantity_unit, $serving_quantity_unit, $set_type) {
	my $per_unit = undef;
	if (defined $product_quantity_unit) {
		$per_unit = $product_quantity_unit;
	}
	elsif (defined $serving_quantity_unit) {
		$per_unit = $serving_quantity_unit;
	}
	# unit is either g or ml for set types of 100g or prepared_100g because, the default being g
	elsif ($set_type eq "100g" || $set_type eq "prepared_100g") {
		$per_unit = "g";
	}
	return $per_unit;
}

sub convert_schema_1003_to_1002_refactor_product_nutrition_schema ($product_ref, $delete_nutrition_data = true) {
	# if no aggregated set then there is no nutrition information
	if (   !defined $product_ref->{nutrition}{aggregated_set}
		|| !%{$product_ref->{nutrition}{aggregated_set}})
	{
		$product_ref->{no_nutrition_data} = "on";
		$product_ref->{nutriments} = {};
		delete $product_ref->{nutrition};
	}

	else {
		my $nutrient_set_ref = $product_ref->{nutrition}{aggregated_set};
		my $preparation_state = $nutrient_set_ref->{preparation} eq "prepared" ? "_prepared" : "";
		# if per is 100ml then 1002 product version nutrient per field is 100g
		my $per = $nutrient_set_ref->{per} eq "100ml" ? "_100g" : "_" . $nutrient_set_ref->{per};

		# first create the nutriments field
		my $nutriments = {};

		foreach my $nutrient (keys %{$nutrient_set_ref->{nutrients}}) {
			$nutriments->{$nutrient . $preparation_state . $per} = $nutrient_set_ref->{nutrients}{$nutrient}{value};
			$nutriments->{$nutrient . "_unit"} = $nutrient_set_ref->{nutrients}{$nutrient}{unit};
			if (defined $nutrient_set_ref->{nutrients}{$nutrient}{modifier}) {
				$nutriments->{$nutrient . $preparation_state . "_modifier"}
					= $nutrient_set_ref->{nutrients}{$nutrient}{modifier};
			}
		}

		$product_ref->{nutriments} = $nutriments;

		# then add other useful data on the nutrients to the product
		if ($preparation_state eq "") {
			$product_ref->{nutrition_data} = "on";
			$product_ref->{nutrition_data_per} = $product_ref->{nutrition}{aggregated_set}{per};
		}
		else {
			$product_ref->{nutrition_data_prepared} = "on";
			$product_ref->{nutrition_data_prepared_per} = $product_ref->{nutrition}{aggregated_set}{per};
		}

		# finally remove the nutrition field of the 1003 product version if deletion on
		if ($delete_nutrition_data) {
			delete $product_ref->{nutrition};
		}
	}

	return;
}
