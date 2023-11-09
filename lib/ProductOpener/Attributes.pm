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

ProductOpener::Attributes - Generate product attributes that can be requested through the API

=head1 SYNOPSIS

Apps can request through the API product attributes that are returned in
the same structured format for all attributes.

=head1 DESCRIPTION

See https://wiki.openfoodfacts.org/Product_Attributes

If new attributes are added, make sure *to update the list of fields* fetched from MongoDB
in Display.pm (in search_and_display_products subroutine).


=cut

package ProductOpener::Attributes;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&list_attributes
		&initialize_attribute_group
		&initialize_attribute
		&override_general_value
		&add_attribute_to_group
		&compute_attributes
		&compute_attribute_nutriscore
		&compute_attribute_nova
		&compute_attribute_has_tag

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Ecoscore qw/:all/;

use Data::DeepAccess qw(deep_get);

=head1 CONFIGURATION

=head2 Attribute groups and attributes

The list of attribute groups ids and the attribute ids they contained
is defined in the Config.pm file

e.g.

$options{attribute_groups} = [
	[
		"nutritional_quality",
		["nutriscore"]
	],
	[
		"processing",
		["nova","additives"]
	],
[..]

=cut

# Build a hash of attribute groups to make it easier to retrieve all attributes of a specific group
my %attribute_groups = ();

if (defined $options{attribute_groups}) {
	foreach my $attribute_group_ref (@{$options{attribute_groups}}) {
		$attribute_groups{$attribute_group_ref->[0]} = $attribute_group_ref->[1];
	}
}

=head1 FUNCTIONS

=head2 list_attributes ( $target_lc )

List all available attribute groups and attributes,
with strings (names, descriptions etc.) in a specific language,
and return them in an array of attribute groups.

This is used in particular for clients of the API to know which
preferences they can ask users for, and then use for personalized
filtering and ranking.

=head3 Arguments

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head3 Return values

=head4 attribute groups reference $attribute_groups_ref

The return value is a reference to an array of attribute groups that contains individual attributes.

=head3 Caching

The return value is cached for each language in the %localized_attribute_groups hash.

=cut

# Global structure to cache the return structure for each language
my %localized_attribute_groups = ();

sub list_attributes ($target_lc) {

	$log->debug("list attributes", {target_lc => $target_lc}) if $log->is_debug();

	# Construct the return structure only once for each language

	if (not defined $localized_attribute_groups{$target_lc}) {

		$localized_attribute_groups{$target_lc} = [];

		if (defined $options{attribute_groups}) {

			foreach my $options_attribute_group_ref (@{$options{attribute_groups}}) {

				my $group_id = $options_attribute_group_ref->[0];
				my $attributes_ref = $options_attribute_group_ref->[1];

				my $group_ref = initialize_attribute_group($group_id, $target_lc);

				foreach my $attribute_id (@{$attributes_ref}) {

					my $attribute_ref = initialize_attribute($attribute_id, $target_lc);
					push @{$group_ref->{attributes}}, $attribute_ref;
				}

				push @{$localized_attribute_groups{$target_lc}}, $group_ref;
			}
		}
	}

	return $localized_attribute_groups{$target_lc};
}

=head2 initialize_attribute_group ( $group_id, $target_lc )

Create a new attribute group and initialize some fields
(e.g. strings like description, description_short etc.)

The initialization values for the fields are not dependent on a specific product.

=head3 Arguments

=head4 attribute group id $group_id

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

If $target_lc is equal to "data", no strings are returned.

=head3 Return value

A reference to the created attribute group object.

=head3 Initialized fields

- Name - e.g. "Allergens"
- Warning
- Short description
- Description

=cut

sub initialize_attribute_group ($group_id, $target_lc) {

	my $group_ref = {
		id => $group_id,
		attributes => [],
	};

	if ($target_lc ne "data") {
		$group_ref->{name} = lang_in_other_lc($target_lc, "attribute_group_" . $group_id . "_name");

		# Strings defined in the .po files ("attribute_group_[group id]_[field]")

		foreach my $field ("name", "note", "warning", "description", "description_short") {

			my $value = lang_in_other_lc($target_lc, "attribute_group_" . $group_id . "_" . $field);
			if ((defined $value) and ($value ne "")) {
				$group_ref->{$field} = $value;
			}
		}
	}

	return $group_ref;
}

=head2 initialize_attribute ( $attribute_id, $target_lc )

Create a new attribute and initialize attributes fields
(e.g. strings like description, description_short etc.)
for a specific attribute if the corresponding values are defined in the .po translation files.

The initialization values for the fields are not dependent on a specific product.

Some of them may be overridden later (e.g. the title and description) based
on how the attribute matches for the specific product.

=head3 Arguments

=head4 attribute id $attribute_id

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

If $target_lc is equal to "data", no strings are returned.

=head3 Return value

A reference to the created attribute object.

=head3 Initialized fields

- name: e.g. "Nutri-Score"
- setting_name: e.g. "Good nutritional quality (Nutri-Score)"
- icon_url
- panel_id:	Linked knowledge panel (optional)

=cut

sub initialize_attribute ($attribute_id, $target_lc) {

	my $attribute_ref = {id => $attribute_id};

	# Initialize icon for the attribute

	if ($attribute_id eq "nutriscore") {
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutriscore-a.svg";
		$attribute_ref->{panel_id} = "nutriscore";
	}
	elsif ($attribute_id eq "ecoscore") {
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/ecoscore-a.svg";
		$attribute_ref->{panel_id} = "ecoscore";
	}
	elsif ($attribute_id eq "forest_footprint") {
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/forest-footprint-a.svg";
	}
	elsif ($attribute_id eq "nova") {
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nova-group-1.svg";
		$attribute_ref->{panel_id} = "nova";
	}
	elsif ($attribute_id eq "additives") {
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/0-additives.svg";
		$attribute_ref->{panel_id} = "additives";
	}
	elsif ($attribute_id =~ /^allergens_no_(.*)$/) {
		my $allergen = $1;
		$allergen =~ s/_/-/g;
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/no-$allergen.svg";
	}
	elsif ($attribute_id =~ /^(low)_(salt|sugars|fat|saturated_fat)$/) {
		my $nid = $2;
		$nid =~ s/_/-/g;
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutrient-level-$nid-low.svg";
	}
	elsif (($attribute_id eq "vegan") or ($attribute_id eq "vegetarian") or ($attribute_id eq "palm_oil_free")) {
		my $analysis_tag = $attribute_id;
		$analysis_tag =~ s/_/-/g;
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/$analysis_tag.svg";
	}
	elsif ($attribute_id =~ /^(labels)_(.*)$/) {
		my $tagtype = $1;
		my $tag = $2;
		$tag =~ s/_/-/g;

		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/${tag}.svg";
	}

	# Initialize name and setting name if a language is requested

	if ($target_lc ne "data") {

		# Allergens

		if ($attribute_id =~ /^allergens_no_(.*)$/) {

			my $allergen_id = "en:$1";
			$allergen_id =~ s/_/-/g;

			my $allergen = display_taxonomy_tag($target_lc, "allergens", $allergen_id);

			$attribute_ref->{name} = $allergen;
			$attribute_ref->{setting_name} = sprintf(
				lang_in_other_lc($target_lc, "without_s"),
				display_taxonomy_tag($target_lc, "allergens", $allergen_id)
			);
		}

		# Ingredients analysis

		elsif (($attribute_id eq "vegan") or ($attribute_id eq "vegetarian") or ($attribute_id eq "palm_oil_free")) {
			my $analysis_tag = $attribute_id;
			$analysis_tag =~ s/_/-/g;
			my $name = display_taxonomy_tag($target_lc, "ingredients_analysis", "en:$analysis_tag");
			$attribute_ref->{name} = $name;
			$attribute_ref->{setting_name} = $name;

		}

		# Nutrient levels

		elsif ($attribute_id =~ /^(low)_(salt|sugars|fat|saturated_fat)$/) {

			my $level = $1;
			my $nid = $2;
			$nid =~ s/_/-/g;

			$attribute_ref->{name} = display_taxonomy_tag($target_lc, "nutrients", "zz:$nid");
			$attribute_ref->{setting_name} = sprintf(
				lang_in_other_lc($target_lc, "nutrient_in_quantity"),
				display_taxonomy_tag($target_lc, "nutrients", "zz:$nid"),
				lang_in_other_lc($target_lc, $level . "_quantity")
			);
		}

		# Strings defined in the .po files ("attribute_[attribute id]_[field]")

		foreach my $field ("name", "setting_name", "setting_note", "warning", "description", "description_short") {

			my $value = lang_in_other_lc($target_lc, "attribute_" . $attribute_id . "_" . $field);
			if ((defined $value) and ($value ne "")) {
				$attribute_ref->{$field} = $value;
			}
		}

		if ((not defined $attribute_ref->{setting_name}) and (defined $attribute_ref->{name})) {
			$attribute_ref->{setting_name} = $attribute_ref->{name};
		}
	}

	return $attribute_ref;
}

=head2 override_general_value ( $attribute_ref, $field, $stringid )

Attributes fields (e.g. strings like description, description_short etc.)
can be defined in the .po translation files for a given attribute
regardless of the attribute value, or can be specific to a particular value.

=head3 Arguments

=head4 attribute reference $attribute_ref

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 field $field

e.g. description, description_short

=head4 string id $string

String id from the msgctxt field in the .po files
e.g. "attribute_labels_fair_trade_yes_description_short"

=cut

sub override_general_value ($attribute_ref, $target_lc, $field, $stringid) {

	my $string = lang_in_other_lc($target_lc, $stringid);
	if ($string ne "") {
		$attribute_ref->{$field} = $string;
	}
	return;
}

=head2 compute_attribute_nutriscore ( $product_ref, $target_lc )

Computes a nutritional quality attribute based on the Nutri-Score.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match

To differentiate products more finely, the match is based on the Nutri-Score score
that is used to define the Nutri-Score grade from A to E.

- Nutri-Score A: 80 to 100%
- Nutri-Score B: 61 to 80%

=cut

sub compute_attribute_nutriscore ($product_ref, $target_lc) {

	$log->debug("compute nutriscore attribute",
		{code => $product_ref->{code}, nutriscore_data => $product_ref->{nutriscore_data}})
		if $log->is_debug();

	my $attribute_id = "nutriscore";

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	# Nutri-Score A, B, C, D or E
	if ((defined $product_ref->{nutriscore_grade}) and ($product_ref->{nutriscore_grade} =~ /^[a-e]$/)) {
		$attribute_ref->{status} = "known";

		my $nutriscore_data_ref = $product_ref->{nutriscore_data};
		my $is_beverage = $nutriscore_data_ref->{is_beverage};
		my $is_water = $nutriscore_data_ref->{is_water};
		my $nutrition_score = $nutriscore_data_ref->{score};
		my $grade = $nutriscore_data_ref->{grade};

		$log->debug(
			"compute nutriscore attribute - known",
			{
				code => $product_ref->{code},
				is_beverage => $is_beverage,
				is_water => $is_water,
				nutrition_score => $nutrition_score,
				grade => $grade
			}
		) if $log->is_debug();

		# Compute match based on score

		my $match = 0;

		# Score ranges from -15 to 40

		if ($is_beverage) {

			if ($is_water) {
				# Grade A
				$match = 100;
			}
			elsif ($nutrition_score <= 1) {
				# Grade B
				# If the nutrition score is at the lowest limit (-15), make the match 80
				# if the nutrition score is at the highest limit (1), make the match 61
				$match = 80 - ($nutrition_score - (-15)) / (1 - (-15)) * 19;
			}
			elsif ($nutrition_score <= 5) {
				# Grade C
				$match = 60 - ($nutrition_score - 1) / (5 - 1) * 19;
			}
			elsif ($nutrition_score <= 9) {
				# Grade D
				$match = 40 - ($nutrition_score - 5) / (9 - 5) * 19;
			}
			else {
				# Grade E
				$match = 20 - ($nutrition_score - 9) / (40 - 9) * 19;
			}
		}
		else {

			if ($nutrition_score <= -1) {
				# Grade A
				$match = 100 - ($nutrition_score - (-15)) / (-1 - (-15)) * 19;
			}
			elsif ($nutrition_score <= 2) {
				# Grade B
				$match = 80 - ($nutrition_score - (-1)) / (2 - (-1)) * 19;
			}
			elsif ($nutrition_score <= 10) {
				# Grade C
				$match = 60 - ($nutrition_score - 2) / (10 - 2 + 1) * 19;
			}
			elsif ($nutrition_score <= 18) {
				# Grade D
				$match = 40 - ($nutrition_score - 10) / (18 - 10 + 1) * 19;
			}
			else {
				# Grade E
				$match = 20 - ($nutrition_score - 18) / (40 - 18) * 19;
			}
		}

		$attribute_ref->{match} = $match;

		if ($target_lc ne "data") {
			$attribute_ref->{title}
				= sprintf(lang_in_other_lc($target_lc, "attribute_nutriscore_grade_title"), uc($grade));
			$attribute_ref->{description}
				= lang_in_other_lc($target_lc, "attribute_nutriscore_" . $grade . "_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_nutriscore_" . $grade . "_description_short");
		}
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutriscore-$grade.svg";
	}

	# Nutri-Score not-applicable: alcoholic beverages, baby food etc.
	elsif (has_tag($product_ref, "nutrition_grades", "not-applicable")) {
		$attribute_ref->{status} = "known";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutriscore-not-applicable.svg";
		$attribute_ref->{match} = 0;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_nutriscore_not_applicable_title");
			$attribute_ref->{description} = f_lang_in_lc(
				$target_lc,
				"f_attribute_nutriscore_not_applicable_description",
				{
					category => display_taxonomy_tag_name(
						$target_lc, "categories",
						deep_get($product_ref, qw/nutriscore_data nutriscore_not_applicable_for_category/)
					)
				}
			);
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_nutriscore_not_applicable_description_short");
		}
	}

	# Nutri-Score not computed: missing data
	else {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutriscore-unknown.svg";
		$attribute_ref->{match} = 0;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_nutriscore_unknown_title");
			$attribute_ref->{description} = lang_in_other_lc($target_lc, "attribute_nutriscore_unknown_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_nutriscore_unknown_description_short");
		}
	}

	return $attribute_ref;
}

=head2 compute_attribute_ecoscore ( $product_ref, $target_lc, $target_cc )

Computes an environmental impact attribute based on the Eco-Score.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 country code $target_cc

The Eco-Score depends on the country of the consumer (as the transport bonus/malus depends on it)

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match

To differentiate products more finely, the match is based on the Eco-Score score
that is used to define the Eco-Score grade from A to E.

- Eco-Score A: 80 to 100
- Eco-Score B: 60 to 79
- Eco-Score C: 40 to 59
- Eco-Score D: 20 to 39
- Eco-Score E: 0 to 19

=cut

sub compute_attribute_ecoscore ($product_ref, $target_lc, $target_cc) {

	$log->debug("compute ecoscore attribute",
		{code => $product_ref->{code}, ecoscore_data => $product_ref->{ecoscore_data}})
		if $log->is_debug();

	my $attribute_id = "ecoscore";

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	if ((defined $product_ref->{ecoscore_data}) and ($product_ref->{ecoscore_data}{status} eq "known")) {
		$attribute_ref->{status} = "known";

		my $score = $product_ref->{ecoscore_score} // 0;
		my $grade = $product_ref->{ecoscore_grade};

		if (    (defined $product_ref->{ecoscore_data}{"scores"})
			and (defined $product_ref->{ecoscore_data}{"scores"}{$target_cc}))
		{
			$score = $product_ref->{ecoscore_data}{"scores"}{$target_cc} // 0;
			$grade = $product_ref->{ecoscore_data}{"grades"}{$target_cc};
		}

		$log->debug("compute ecoscore attribute - known",
			{code => $product_ref->{code}, score => $score, grade => $grade})
			if $log->is_debug();

		# Compute match based on score

		my $match = 0;

		# Score ranges from 0 to 100 with some maluses and bonuses that can be added
		# Warning: a Eco-Score score of 20 means D grade for the Eco-Score, but a match of 20 is E grade for the attributes
		# So we add 1 to the Eco-Score score to compute the match.
		$match = $score + 1;

		if ($score < 0) {
			$match = 0;
		}
		elsif ($score > 100) {
			$match = 100;
		}

		$attribute_ref->{match} = $match;

		if ($target_lc ne "data") {
			$attribute_ref->{title}
				= sprintf(lang_in_other_lc($target_lc, "attribute_ecoscore_grade_title"), uc($grade));
			$attribute_ref->{description}
				= lang_in_other_lc($target_lc, "attribute_ecoscore_" . $grade . "_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_ecoscore_" . $grade . "_description_short");
		}
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/ecoscore-$grade.svg";
	}
	# Eco-Score is not-applicable
	elsif ((defined $product_ref->{ecoscore_grade}) and ($product_ref->{ecoscore_grade} eq "not-applicable")) {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/ecoscore-not-applicable.svg";
		$attribute_ref->{match} = 0;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_ecoscore_not_applicable_title");
			$attribute_ref->{description} = f_lang_in_lc(
				$target_lc,
				"f_attribute_ecoscore_not_applicable_description",
				{
					category => display_taxonomy_tag_name(
						$target_lc, "categories",
						deep_get($product_ref, qw/ecoscore_data ecoscore_not_applicable_for_category/)
					)
				}
			);
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_ecoscore_not_applicable_description_short");
		}
	}
	# Eco-Score is unknown
	else {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/ecoscore-unknown.svg";
		$attribute_ref->{match} = 0;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_ecoscore_unknown_title");
			$attribute_ref->{description} = lang_in_other_lc($target_lc, "attribute_ecoscore_unknown_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_ecoscore_unknown_description_short");
		}
	}

	return $attribute_ref;
}

=head2 compute_attribute_forest_footprint ( $product_ref, $target_lc )

Computes an environmental impact attribute based on the Forest Footprint.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match

The match is based on the forest footprint
that is used to define the forest footprint grade from A to E.

- Forest footprint A: < 0.5 m² / kg of food
- Forest footprint B: < 1 m² / kg of food
- Forest footprint C: < 1.5 m² / kg of food
- Forest footprint D: < 2 m² / kg of food
- Forest footprint E: >= 2 m² / kg of food

If the forest footprint is not computed, we mark it as non-computed and make the match 100%.

=cut

sub compute_attribute_forest_footprint ($product_ref, $target_lc) {

	$log->debug("compute forest footprint attribute",
		{code => $product_ref->{code}, forest_footprint_data => $product_ref->{forest_footprint_data}})
		if $log->is_debug();

	my $attribute_id = "forest_footprint";

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	if ((defined $product_ref->{forest_footprint_data}) and (defined $product_ref->{forest_footprint_data}{grade})) {

		$attribute_ref->{status} = "known";

		my $grade = $product_ref->{forest_footprint_data}{grade};

		# Compute match based on forest footprint

		my $match = 100 - ($product_ref->{forest_footprint_data}{footprint_per_kg} / 2.5) * 100;

		if ($match < 0) {
			$match = 0;
		}

		$attribute_ref->{match} = $match;

		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_forest_footprint_" . $grade . "_title");
			$attribute_ref->{description}
				= lang_in_other_lc($target_lc, "attribute_forest_footprint_" . $grade . "_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_forest_footprint_" . $grade . "_description_short");
		}
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/forest-footprint-$grade.svg";
	}
	else {
		# If we don't have a forest footprint, we assume it is zero and mark it as known
		# We do keep a greyed out icon until the forest footprint encompasses most sources of deforestation
		# (e.g. not only chicken and eggs, but also other raised animals products and palm oil)
		$attribute_ref->{status} = "known";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/forest-footprint-not-computed.svg";
		$attribute_ref->{match} = 0;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_forest_footprint_not_computed_title");
			$attribute_ref->{description}
				= lang_in_other_lc($target_lc, "attribute_forest_footprint_not_computed_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_forest_footprint_not_computed_description_short");
		}
	}

	return $attribute_ref;
}

=head2 compute_attribute_nova ( $product_ref, $target_lc )

Computes a processing attribute based on the Nova group.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match

- NOVA 1: 100%
- NOVA 2: 100%
- NOVA 3: 75%
- NOVA 4: 0%

=cut

sub compute_attribute_nova ($product_ref, $target_lc) {

	$log->debug("compute nova attribute", {code => $product_ref->{code}}) if $log->is_debug();

	my $attribute_id = "nova";

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	if (defined $product_ref->{nova_group}) {
		$attribute_ref->{status} = "known";

		my $nova_group = $product_ref->{nova_group};

		$log->debug(
			"compute nova attribute - known",
			{
				code => $product_ref->{code},
				nova_group => $nova_group
			}
		) if $log->is_debug();

		# Compute match based on NOVA group

		my %nova_groups_scores = (
			1 => 100,
			2 => 100,
			3 => 75,
			4 => 0,
		);

		$attribute_ref->{match} = $nova_groups_scores{$nova_group + 0};    # Make sure the key is a number

		if ($target_lc ne "data") {
			$attribute_ref->{title} = sprintf(lang_in_other_lc($target_lc, "attribute_nova_group_title"), $nova_group);
			$attribute_ref->{description}
				= lang_in_other_lc($target_lc, "attribute_nova_" . $nova_group . "_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_nova_" . $nova_group . "_description_short");
		}
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nova-group-$nova_group.svg";

	}
	else {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nova-group-unknown.svg";
		$attribute_ref->{match} = 0;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_nova_unknown_title");
			$attribute_ref->{description} = lang_in_other_lc($target_lc, "attribute_nova_unknown_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_nova_unknown_description_short");
		}
	}

	return $attribute_ref;
}

=head2 compute_attribute_additives ( $product_ref, $target_lc )

Computes a processing attribute based on the number of additives.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match

- 0 additive: 100%
- 1 to 4 additives: 80% to 20%
- 5 or more additives: 0%

=cut

sub compute_attribute_additives ($product_ref, $target_lc) {

	$log->debug("compute additives attribute", {code => $product_ref->{code}}) if $log->is_debug();

	my $attribute_id = "additives";

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	if (defined $product_ref->{additives_n}) {
		$attribute_ref->{status} = "known";

		my $additives = $product_ref->{additives_n};

		$log->debug(
			"compute additives attribute - known",
			{
				code => $product_ref->{code},
				additives => $additives
			}
		) if $log->is_debug();

		# Compute match based on number of additives

		my $match = 0;

		if ($additives <= 4) {
			$match = 100 - $additives * 20;
		}

		$attribute_ref->{match} = $match;

		if ($target_lc ne "data") {
			if ($additives == 0) {
				$attribute_ref->{title} = sprintf(lang_in_other_lc($target_lc, "without_s"), lang("additives_p"));
			}
			elsif ($additives == 1) {
				$attribute_ref->{title} = $additives . " " . lang("additives_s");
			}
			else {
				$attribute_ref->{title} = $additives . " " . lang("additives_p");
			}
		}

		# We have 10 icons
		my $n = $additives;
		if ($n > 10) {
			$n = 10;
		}

		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/$n-additives.svg";

	}
	else {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{match} = 0;
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/additives-unknown.svg";
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_additives_unknown_title");
			$attribute_ref->{description} = lang_in_other_lc($target_lc, "attribute_additives_unknown_description");
			$attribute_ref->{description_short}
				= lang_in_other_lc($target_lc, "attribute_additives_unknown_description_short");
			$attribute_ref->{missing} = lang_in_other_lc($target_lc, "missing_ingredients_list");
		}
	}

	return $attribute_ref;
}

=head2 compute_attribute_has_tag ( $product_ref, $target_lc, $tagtype, $tagid )

Checks if the product has a specific tag (e.g. a label)

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 tag type $tagtype

e.g. labels, categories, origins

=head4 tag id $tagid

e.g. en:organic

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match

- 100% if the product has the requested tag
- 0% if the product does not have the requested tag

=cut

sub compute_attribute_has_tag ($product_ref, $target_lc, $tagtype, $tagid) {

	$log->debug("compute attributes for product", {code => $product_ref->{code}}) if $log->is_debug();

	my $attribute_id = $tagid;
	$attribute_id =~ s/^en://;
	$attribute_id =~ s/-|:/_/g;
	$attribute_id = $tagtype . "_" . $attribute_id;

	my $tag = $tagid;
	$tag =~ s/^\w\w://;

	# Initialize general values that do not depend on the product (or that will be overriden later)

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	$attribute_ref->{status} = "known";

	my $value = "";

	# If we don't have any tags for the tagtype, mark the status unknown (e.g. new products)

	if ((not defined $product_ref->{$tagtype . "_tags"}) or ($product_ref->{$tagtype . "_tags"} == 0)) {

		$attribute_ref->{status} = "unknown";
		$value = "unknown";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/${tag}-unknown.svg";
	}
	elsif (has_tag($product_ref, $tagtype, $tagid)) {

		$attribute_ref->{match} = 100;
		$value = "yes";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/${tag}.svg";
	}
	else {
		$attribute_ref->{match} = 0;
		$value = "no";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/not-${tag}.svg";
	}

	if ($target_lc ne "data") {
		$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_" . $attribute_id . "_" . $value . "_title");
		# Override default texts if specific texts are available
		override_general_value($attribute_ref, $target_lc, "description",
			"attribute_" . $attribute_id . "_" . $value . "_description");
		override_general_value($attribute_ref, $target_lc, "description_short",
			"attribute_" . $attribute_id . "_" . $value . "_description_short");
	}

	return $attribute_ref;
}

=head2 compute_attribute_nutrient_level($product_ref, $target_lc, $level, $nid);

Checks if the product has a nutrient in a low or high quantity.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 level $level

"low" or "high"

=head4 nutrient id $nid

e.g. "salt", "sugars", "fat", "saturated-fat"

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match
For "low" levels:

- 100% if the nutrient quantity is 0%
- 80% if the nutrient quantity is the upper threshold for the low traffic light
- 20% if the nutrient quantity is the lower threshold for the high traffic light
- 0% if the nutrient quantity is twice the lower threshold for the high traffic light

Traffic lights levels are defined in Food.pm:

@nutrient_levels = (
	['fat', 3, 20 ],
	['saturated-fat', 1.5, 5],
	['sugars', 5, 12.5],
	['salt', 0.3, 1.5],
);

=cut

sub compute_attribute_nutrient_level ($product_ref, $target_lc, $level, $nid) {

	$log->debug(
		"compute attributes nutrient quantity for product",
		{code => $product_ref->{code}, level => $level, nid => $nid}
	) if $log->is_debug();

	my $attribute_id = $level . "_" . $nid;
	$attribute_id =~ s/-/_/g;

	# Initialize general values that do not depend on the product (or that will be overriden later)

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	# Food::compute_nutrient_level() has already determined if we have enough data to compute the nutrient levels

	if ((not defined $product_ref->{nutrient_levels}) or (not defined $product_ref->{nutrient_levels}{$nid})) {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutrient-level-$nid-unknown.svg";
		if ($target_lc ne "data") {
			$attribute_ref->{title} = sprintf(
				lang_in_other_lc($target_lc, "nutrient_in_quantity"),
				display_taxonomy_tag($target_lc, "nutrients", "zz:$nid"),
				lang_in_other_lc($target_lc, "unknown_quantity")
			);
			$attribute_ref->{missing} = lang_in_other_lc($target_lc, "missing_nutrition_facts");
		}
	}
	else {
		$attribute_ref->{status} = "known";

		my $prepared = "";

		if (has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated")) {
			$prepared = '_prepared';
		}

		foreach my $nutrient_level_ref (@nutrient_levels) {
			my ($nutrient_level_nid, $low, $high) = @{$nutrient_level_ref};

			next if ($nutrient_level_nid ne $nid);

			# divide low and high per 2 for drinks

			if (has_tag($product_ref, "categories", "en:beverages")) {
				$low = $low / 2;
				$high = $high / 2;
			}

			my $value = $product_ref->{nutriments}{$nid . $prepared . "_100g"};

			my $match;

			if ($value < $low) {
				$match = 80 + 20 * ($low - $value) / $low;
				$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutrient-level-$nid-low.svg";
			}
			elsif ($value <= $high) {
				$match = 20 + 60 * ($high - $value) / ($high - $low);
				$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutrient-level-$nid-medium.svg";
			}
			elsif ($value < $high * 2) {
				$match = 20 * ($high * 2 - $value) / $high;
				$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutrient-level-$nid-high.svg";
			}
			else {
				$match = 0;
				$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/nutrient-level-$nid-high.svg";
			}

			$attribute_ref->{match} = $match;

			if ($target_lc ne "data") {
				$attribute_ref->{title} = sprintf(
					lang_in_other_lc($target_lc, "nutrient_in_quantity"),
					display_taxonomy_tag($target_lc, "nutrients", "zz:$nid"),
					lang_in_other_lc($target_lc, $product_ref->{nutrient_levels}{$nid} . "_quantity")
				);
				$attribute_ref->{description_short} = sprintf(
					lang_in_other_lc($target_lc, 'g_per_100g'),
					(sprintf('%.2e', $product_ref->{nutriments}{$nid . $prepared . '_100g'}) + 0.0)
				);
			}
		}
	}

	return $attribute_ref;
}

=head2 compute_attribute_allergen($product_ref, $target_lc, $allergen_id);

Checks if the product contains or may contain traces of an allergen.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 attribute_allergen_id $attribute_allergen_id

"en:gluten", "en:sulphur-dioxide-and-sulphites" : allergen ids from the allergens taxonomy

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match

100: no indication of the allergen or trace of the allergen
20: may contain the allergen as a trace
0: contains allergen

=cut

sub compute_attribute_allergen ($product_ref, $target_lc, $attribute_id) {
	# $attribute_id  ->  e.g. "allergens_no_gluten",

	my $allergen = $attribute_id;
	$allergen =~ s/^allergens_no_//;
	$allergen =~ s/_/-/g;

	my $allergen_id = "en:" . $allergen;

	$log->debug("compute attribute allergen for product",
		{code => $product_ref->{code}, attribute_id => $attribute_id, allergen_id => $allergen_id})
		if $log->is_debug();

	# Initialize general values that do not depend on the product (or that will be overriden later)

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	# There may be conflicting information on allergens (e.g. a product that claims to be "gluten-free",
	# but that also says it may contain traces of cereals containing gluten, or that contains an ingredient
	# that usually contains gluten)

	# The algorithm below is designed to be conservative: information that indicates the presence
	# or the possibility of presence of an allergen prevails on information that indicates its absence

	# - Check for no gluten / lactose-free etc. labels
	# the canonical entry in the taxonomy for those labels is of the form "no-something"
	if (has_tag($product_ref, "labels", "en:no-" . $allergen)) {
		$attribute_ref->{status} = "known";
		$attribute_ref->{debug} = "en:no-$allergen label";
		$attribute_ref->{match} = 100;
	}

	# - Check for "none" in the allergens field
	if (has_tag($product_ref, "allergens", "en:none")) {
		$attribute_ref->{status} = "known";
		$attribute_ref->{debug} = "en:none in allergens";
		$attribute_ref->{match} = 100;
	}

	# - If we have an ingredient list, allergens are extracted and added to the allergens_tags field
	# mark the match as 100, and then let the allergens and traces fields override it
	if ((defined $product_ref->{ingredients_n}) and (defined $product_ref->{unknown_ingredients_n})) {
		if ($product_ref->{unknown_ingredients_n} <= $product_ref->{ingredients_n} / 10) {
			$attribute_ref->{status} = "known";
			$attribute_ref->{debug}
				= $product_ref->{ingredients_n}
				. " ingredients ("
				. $product_ref->{unknown_ingredients_n}
				. " unknown)";
			$attribute_ref->{match} = 100;
		}
		else {
			$attribute_ref->{debug}
				= "too many unknown ingredients: "
				. $product_ref->{ingredients_n}
				. " ingredients ("
				. $product_ref->{unknown_ingredients_n}
				. " unknown)";
		}
	}
	else {
		$attribute_ref->{debug} = "missing ingredients list";
	}

	# - Check for allergen in the traces_tags field
	if (has_tag($product_ref, "traces", $allergen_id)) {
		$attribute_ref->{status} = "known";
		$attribute_ref->{debug} = "$allergen_id in traces";
		$attribute_ref->{match}
			= 20;    # match <= 20 will make products non-matching if the preference is set to mandatory
	}

	# - Check for allergen in the allergens_tags field
	if (has_tag($product_ref, "allergens", $allergen_id)) {
		$attribute_ref->{status} = "known";
		$attribute_ref->{debug} = "$allergen_id in allergens";
		$attribute_ref->{match} = 0;
	}

	# - Check for contains gluten etc. labels
	if (has_tag($product_ref, "labels", "en:contains-" . $allergen)) {
		$attribute_ref->{status} = "known";
		$attribute_ref->{debug} = "en:contains-$allergen label";
		$attribute_ref->{match} = 0;
	}

	# No match: mark the attribute unknown
	if (not defined $attribute_ref->{match}) {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{title} = sprintf(
			lang_in_other_lc($target_lc, "presence_unknown_s"),
			display_taxonomy_tag($target_lc, "allergens", $allergen_id)
		);
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/$allergen-content-unknown.svg";

		if (not($product_ref->{ingredients_n})) {
			# If we don't have ingredients,
			# link to the ingredients panel that will have an action to add ingredients
			$attribute_ref->{panel_id} = "ingredients";
		}
		else {
			# If we have ingredients, then we have too many ingredients that we did not recognize,
			# link to the ingredients analysis details
			$attribute_ref->{panel_id} = "ingredients_analysis_details";
		}
	}
	elsif ($attribute_ref->{match} == 100) {
		$attribute_ref->{title} = sprintf(
			lang_in_other_lc($target_lc, "does_not_contain_s"),
			display_taxonomy_tag($target_lc, "allergens", $allergen_id)
		);
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/no-$allergen.svg";
	}
	elsif ($attribute_ref->{match} == 20) {
		$attribute_ref->{title} = sprintf(
			lang_in_other_lc($target_lc, "may_contain_s"),
			display_taxonomy_tag($target_lc, "allergens", $allergen_id)
		);
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/may-contain-$allergen.svg";
	}
	elsif ($attribute_ref->{match} == 0) {
		$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/contains-$allergen.svg";
		$attribute_ref->{title} = sprintf(
			lang_in_other_lc($target_lc, "contains_s"),
			display_taxonomy_tag($target_lc, "allergens", $allergen_id)
		);
	}

	return $attribute_ref;
}

=head2 compute_attribute_ingredients_analysis($product_ref, $target_lc, $analysis);

Checks properties derived from ingredients analysis
(e.g. vegetarian, vegan, palm oil free)

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 analysis $analysis

There are currently 2 types of ingredients analysis:

- if $analysis contains "-free" at the end (e.g. palm-oil-free), ingredients_analysis_tags contains values like:
contains-palm-oil, may-contain-palm-oil, palm-oil-free and palm-oil-content-unknown

- otherwise, for values like vegan and vegetarian, it contains values like:
vegan, non-vegan, maybe-vegan, vegan-status-unknown

=head3 Return value

The return value is a reference to the resulting attribute data structure.

=head4 % Match
For "low" levels:

- 100% if the property matches
- 20% if the property may match
- 0% if the property does not match

=cut

sub compute_attribute_ingredients_analysis ($product_ref, $target_lc, $analysis) {

	my $attribute_id = $analysis;
	$attribute_id =~ s/-/_/g;

	$log->debug("compute attributes ingredients analysis",
		{code => $product_ref->{code}, attribute_id => $attribute_id, analysis => $analysis})
		if $log->is_debug();

	# Initialize general values that do not depend on the product (or that will be overriden later)

	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);

	my $match;
	my $status;
	my $analysis_tag;

	if ($analysis =~ /^(.*)-free$/) {
		# e.g. palm-oil-free
		my $ingredient = $1;

		if (   has_tag($product_ref, "labels", "en:no-$ingredient")
			or has_tag($product_ref, "ingredients_analysis", "en:$ingredient-free"))
		{
			$match = 100;
			$analysis_tag = "$ingredient-free";
			$status = "known";
		}
		elsif (has_tag($product_ref, "ingredients_analysis", "en:may-contain-$ingredient")) {
			$match = 50;
			$analysis_tag = "may-contain-$ingredient";
			$status = "known";
		}
		elsif (has_tag($product_ref, "ingredients_analysis", "en:$ingredient")) {
			$match = 0;
			$analysis_tag = "contains-$ingredient";
			$status = "known";
		}
		else {
			$status = "unknown";
			$analysis_tag = $ingredient . "-content-unknown";
		}
	}
	else {
		# vegan / vegetarian

		if (   has_tag($product_ref, "labels", "en:$analysis")
			or has_tag($product_ref, "ingredients_analysis", "en:$analysis"))
		{
			$match = 100;
			$analysis_tag = $analysis;
			$status = "known";
		}
		elsif (has_tag($product_ref, "labels", "en:maybe-$analysis")
			or has_tag($product_ref, "ingredients_analysis", "en:maybe-$analysis"))
		{
			$match = 50;
			$analysis_tag = "maybe-$analysis";
			$status = "known";
		}
		elsif (has_tag($product_ref, "labels", "en:non-$analysis")
			or has_tag($product_ref, "ingredients_analysis", "en:non-$analysis"))
		{
			$match = 0;
			$analysis_tag = "non-$analysis";
			$status = "known";
		}
		else {
			$status = "unknown";
			$analysis_tag = "$analysis-status-unknown";
		}
	}

	if (defined $match) {
		$attribute_ref->{match} = $match;
	}

	$attribute_ref->{status} = $status;
	$attribute_ref->{icon_url} = "$static_subdomain/images/attributes/$analysis_tag.svg";
	# the ingredients_analysis taxonomy contains en:palm-oil and not en:contains-palm-oil
	$analysis_tag =~ s/contains-(.*)$/$1/;

	# Link to the corresponding knowledge panel
	if (($status eq "unknown") and not($product_ref->{ingredients_n})) {
		# If the status is unknown, and we don't have ingredients,
		# link to the ingredients panel that will have an action to add ingredients
		# Note that the status may be known (e.g. from labels like "Palm oil free")
		# even if we don't have ingredients
		$attribute_ref->{panel_id} = "ingredients";
	}
	else {
		# Otherwise we link to the panel specific to the ingredients analysis property
		$attribute_ref->{panel_id} = "ingredients_analysis_en:" . $analysis_tag;
	}

	if ($target_lc ne "data") {
		$attribute_ref->{title} = display_taxonomy_tag($target_lc, "ingredients_analysis", "en:$analysis_tag");
	}

	return $attribute_ref;
}

=head2 add_attribute_to_group ( $product_ref, $target_lc, $group_id, $attribute_ref )

Add an attribute to a given attribute group, if the attribute is defined.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

=head4 group id $group_id

e.g. nutritional_quality, allergens, labels

=head4 attribute reference $attribute_ref

=cut

sub add_attribute_to_group ($product_ref, $target_lc, $group_id, $attribute_ref) {

	$log->debug("add_attribute_to_group",
		{target_lc => $target_lc, group_id => $group_id, attribute_ref => $attribute_ref})
		if $log->is_debug();

	if (defined $attribute_ref) {

		# Delete fields that are returned only by /api/v2/attribute_groups to list all the available attributes
		delete $attribute_ref->{setting_name};
		delete $attribute_ref->{setting_note};

		# Compute a 5 level grade from the match score
		# We do it server side to be sure that clients do it the same way
		# and that a Nutri-Score E match of 20 has a grade "e".
		if ($attribute_ref->{status} eq "known") {

			if ($attribute_ref->{match} <= 20) {
				$attribute_ref->{grade} = 'e';
			}
			elsif ($attribute_ref->{match} <= 40) {
				$attribute_ref->{grade} = 'd';
			}
			elsif ($attribute_ref->{match} <= 60) {
				$attribute_ref->{grade} = 'c';
			}
			elsif ($attribute_ref->{match} <= 80) {
				$attribute_ref->{grade} = 'b';
			}
			else {
				$attribute_ref->{grade} = 'a';
			}
		}
		else {
			$attribute_ref->{grade} = 'unknown';
		}

		my $group_ref;
		# Select the requested group
		foreach my $each_group_ref (@{$product_ref->{"attribute_groups_" . $target_lc}}) {
			$log->debug("add_attribute_to_group - existing group", {group_ref => $group_ref, group_id => $group_id})
				if $log->is_debug();
			if ($each_group_ref->{id} eq $group_id) {
				$group_ref = $each_group_ref;
				last;
			}
		}
		# Add group if it doesn't exist yet
		if ((not defined $group_ref) or ($group_ref->{id} ne $group_id)) {

			$log->debug("add_attribute_to_group - create new group", {group_ref => $group_ref, group_id => $group_id})
				if $log->is_debug();

			$group_ref = initialize_attribute_group($group_id, $target_lc);

			push @{$product_ref->{"attribute_groups_" . $target_lc}}, $group_ref;
		}

		push @{$group_ref->{attributes}}, $attribute_ref;
	}
	return;
}

=head2 compute_attributes ( $product_ref, $target_lc, $target_cc, $options_ref )

Compute all attributes for a product, with strings (descriptions, recommendations etc.)
in a specific language, and return them in an array of attribute groups.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc (or "data")

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

If $target_lc is equal to "data", no strings are returned.

=head4 country code $target_cc

Needed for some country specific attributes like the Eco-Score.

=head4 options $options_ref

Defines how some attributes should be computed (or not computed)

- skip_[attribute_id] : do not compute a specific attribute

=head3 Return values

Attributes are returned in the "attribute_groups_[$target_lc]" array of the product reference
passed as input.

The array contains attribute groups, and each attribute group contains individual attributes.

=cut

sub compute_attributes ($product_ref, $target_lc, $target_cc, $options_ref) {

	$log->debug("compute attributes for product", {code => $product_ref->{code}, target_lc => $target_lc})
		if $log->is_debug();

	# Initialize attributes

	$product_ref->{"attribute_groups_" . $target_lc} = [];

	# Populate the attributes groups and the attributes of each group
	# in a default order (a meaningful order that apps / clients can decide to reorder or not)

	my $attribute_ref;

	# Nutritional quality

	$attribute_ref = compute_attribute_nutriscore($product_ref, $target_lc);
	add_attribute_to_group($product_ref, $target_lc, "nutritional_quality", $attribute_ref);

	foreach my $nutrient ("salt", "fat", "sugars", "saturated-fat") {
		$attribute_ref = compute_attribute_nutrient_level($product_ref, $target_lc, "low", $nutrient);
		add_attribute_to_group($product_ref, $target_lc, "nutritional_quality", $attribute_ref);
	}

	# Allergens
	foreach my $allergen_attribute_id (@{$attribute_groups{"allergens"}}) {
		$attribute_ref = compute_attribute_allergen($product_ref, $target_lc, $allergen_attribute_id);
		add_attribute_to_group($product_ref, $target_lc, "allergens", $attribute_ref);
	}

	# Ingredients analysis
	foreach my $analysis ("vegan", "vegetarian", "palm-oil-free") {
		$attribute_ref = compute_attribute_ingredients_analysis($product_ref, $target_lc, $analysis);
		add_attribute_to_group($product_ref, $target_lc, "ingredients_analysis", $attribute_ref);
	}

	# Processing

	$attribute_ref = compute_attribute_nova($product_ref, $target_lc);
	add_attribute_to_group($product_ref, $target_lc, "processing", $attribute_ref);

	$attribute_ref = compute_attribute_additives($product_ref, $target_lc);
	add_attribute_to_group($product_ref, $target_lc, "processing", $attribute_ref);

	# Environment

	if (   (not defined $options_ref)
		or (not defined $options_ref->{skip_ecoscore})
		or (not $options_ref->{skip_ecoscore}))
	{
		$attribute_ref = compute_attribute_ecoscore($product_ref, $target_lc, $target_cc);
		add_attribute_to_group($product_ref, $target_lc, "environment", $attribute_ref);
	}

	if (   (not defined $options_ref)
		or (not defined $options_ref->{skip_forest_footprint})
		or (not $options_ref->{skip_forest_footprint}))
	{
		$attribute_ref = compute_attribute_forest_footprint($product_ref, $target_lc);
		add_attribute_to_group($product_ref, $target_lc, "environment", $attribute_ref);
	}

	# Labels groups

	foreach my $label_id ("en:organic", "en:fair-trade") {

		$attribute_ref = compute_attribute_has_tag($product_ref, $target_lc, "labels", $label_id);
		add_attribute_to_group($product_ref, $target_lc, "labels", $attribute_ref);
	}

	$log->debug(
		"computed attributes for product",
		{
			code => $product_ref->{code},
			target_lc => $target_lc,
			"attribute_groups_" . $target_lc => $product_ref->{"attribute_groups_" . $target_lc}
		}
	) if $log->is_debug();
	return;
}

1;
