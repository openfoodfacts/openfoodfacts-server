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

ProductOpener::Attributes - Generate product attributes that can be requested through the API

=head1 SYNOPSIS

Apps can request through the API product attributes that are returned in
the same structured format for all attributes.

=head1 DESCRIPTION

See https://wiki.openfoodfacts.org/Product_Attributes

=cut


package ProductOpener::Attributes;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);


BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
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

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;

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

The return value is cached for each language in the %attribute_groups hash.

=cut

# Global structure to cache the return structure for each language
my %attribute_groups = ();

sub list_attributes($) {

	my $target_lc = shift;	

	$log->debug("list attributes", { target_lc => $target_lc }) if $log->is_debug();

	# Construct the return structure only once for each language
	
	if (not defined $attribute_groups{$target_lc}) {
		
		$attribute_groups{$target_lc} = [];
		
		if (defined $options{attribute_groups}) {
			
			foreach my $options_attribute_group_ref (@{$options{attribute_groups}}) {
				
				my $group_id = $options_attribute_group_ref->[0];
				my $attributes_ref = $options_attribute_group_ref->[1];
				
				my $group_ref = initialize_attribute_group($group_id, $target_lc);
				
				foreach my $attribute_id (@{$attributes_ref}) {
					
					my $attribute_ref = initialize_attribute($attribute_id, $target_lc);
					push @{$group_ref->{attributes}}, $attribute_ref;
				}
				
				push @{$attribute_groups{$target_lc}}, $group_ref;
			}
		}
	}
	
	return $attribute_groups{$target_lc};
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

sub initialize_attribute_group($$) {

	my $group_id = shift;		
	my $target_lc = shift;
	
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

- Name - e.g. "Nutri-Score"
- Setting name - e.g. "Good nutritional quality (Nutri-Score)"
- Warning
- Short description
- Description

=cut

sub initialize_attribute($$) {
	
	my $attribute_id = shift;
	my $target_lc = shift;
	
	my $attribute_ref = {id => $attribute_id};
	
	if ($target_lc ne "data") {
		
		# Allergens
		
		# Nutrient levels
		
		if ($attribute_id =~ /^(low)_(salt|sugars|fat|saturated_fat)$/) {
		
			my $level = $1;
			my $nid = $2;
			$nid =~ s/_/-/g;
			
			$attribute_ref->{name} = $Nutriments{$nid}{$lc};
			$attribute_ref->{setting_name} = sprintf(lang_in_other_lc($target_lc, "nutrient_in_quantity"), $Nutriments{$nid}{$target_lc} ,
				lang_in_other_lc($target_lc, $level . "_quantity"));
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

sub override_general_value($$$$) {
	
	my $attribute_ref = shift;
	my $target_lc = shift;
	my $field = shift;
	my $stringid = shift;
	
	my $string = lang_in_other_lc($target_lc, $stringid);
	if ($string ne "") {
		$attribute_ref->{$field} = $string;
	}
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

sub compute_attribute_nutriscore($$) {

	my $product_ref = shift;
	my $target_lc = shift;

	$log->debug("compute nutriscore attribute", { code => $product_ref->{code} }) if $log->is_debug();

	my $attribute_id = "nutriscore";
	
	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);
	
	if (defined $product_ref->{nutriscore_data}) {
		$attribute_ref->{status} = "known";
		
		my $nutriscore_data_ref = $product_ref->{nutriscore_data};
		my $is_beverage = $nutriscore_data_ref->{is_beverage};
		my $is_water = $nutriscore_data_ref->{is_water};
		my $nutrition_score = $nutriscore_data_ref->{score};
		my $grade = $nutriscore_data_ref->{grade};
		
		$log->debug("compute nutriscore attribute - known", { code => $product_ref->{code},
			is_beverage => $is_beverage, is_water => $is_water,
			nutrition_score => $nutrition_score,
			grade => $grade }) if $log->is_debug();
		
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
				$match = 80 - ($nutrition_score - (- 15)) / (1 - (- 15)) * 20;
			}
			elsif ($nutrition_score <= 5) {
				# Grade C
				$match = 60 - ($nutrition_score - 1) / (5 - 1) * 20;
			}
			elsif ($nutrition_score <= 9) {
				# Grade D
				$match = 40 - ($nutrition_score - 5) / (9 - 5) * 20;
			}
			else {
				# Grade E
				$match = 20 - ($nutrition_score - 9) / (40 - 9) * 20;
			}
		}
		else {

			if ($nutrition_score <= -1) {
				# Grade A
				$match = 100 - ($nutrition_score - (- 15)) / (-1 - (- 15)) * 20;
			}
			elsif ($nutrition_score <= 2) {
				# Grade B
				$match = 80 - ($nutrition_score - (- 1)) / (2 - (- 1)) * 20;
			}
			elsif ($nutrition_score <= 10) {
				# Grade C
				$match = 60 - ($nutrition_score - 2) / (10 - 2) * 20;
			}
			elsif ($nutrition_score <= 18) {
				# Grade D
				$match = 40 - ($nutrition_score - 10) / (18 - 10) * 20;
			}
			else {
				# Grade E
				$match = 20 - ($nutrition_score - 18) / (40 - 18) * 20;
			}
		}
		
		$attribute_ref->{match} = $match;
		
		if ($target_lc ne "data") {
			$attribute_ref->{title} = sprintf(lang("attribute_nutriscore_grade_title"), uc($grade));		
			$attribute_ref->{description} = lang("attribute_nutriscore_" . $grade . "_description");
			$attribute_ref->{description_short} = lang("attribute_nutriscore_" . $grade . "_description_short");
		}
		$attribute_ref->{icon_url} = "$static_subdomain/images/misc/nutriscore-$grade.svg";
	}
	else {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{match} = 0;
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
- NOVA 3: 50%
- NOVA 4: 0%

=cut

sub compute_attribute_nova($$) {

	my $product_ref = shift;
	my $target_lc = shift;

	$log->debug("compute nova attribute", { code => $product_ref->{code} }) if $log->is_debug();

	my $attribute_id = "nova";
	
	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);
		
	if (defined $product_ref->{nova_group}) {
		$attribute_ref->{status} = "known";
		
		my $nova_group = $product_ref->{nova_group};
		
		$log->debug("compute nutriscore attribute - known", { code => $product_ref->{code},
			nova_group => $nova_group}) if $log->is_debug();
		
		# Compute match based on NOVA group
		
		my $match = 0;
		
		if (($nova_group == 1) or ($nova_group == 2)) {
			$match = 100;
		}
		elsif ($nova_group == 3) {
			$match = 50;
		}
	
		$attribute_ref->{match} = $match;
		
		if ($target_lc ne "data") {
			$attribute_ref->{title} = sprintf(lang("attribute_nova_group_title"), $nova_group);
			$attribute_ref->{description} = lang("attribute_nova_" . $nova_group . "_description");
			$attribute_ref->{description_short} = lang("attribute_nova_" . $nova_group . "_description_short");
		}
		$attribute_ref->{icon_url} = "$static_subdomain/images/misc/nova-group-$nova_group.svg";
		
	}
	else {
		$attribute_ref->{status} = "unknown";
		$attribute_ref->{match} = 0;
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

sub compute_attribute_has_tag($$$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $tagtype = shift;
	my $tagid = shift;	

	$log->debug("compute attributes for product", { code => $product_ref->{code} }) if $log->is_debug();

	my $attribute_id = $tagid;
	$attribute_id =~ s/^en://;
	$attribute_id =~ s/-|:/_/g;
	$attribute_id = $tagtype . "_" . $attribute_id;
	
	# Initialize general values that do not depend on the product (or that will be overriden later)
	
	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);
	
	$attribute_ref->{status} = "known";
	
	# TODO: decide when to mark status unknown (e.g. new products)

	if (has_tag($product_ref, $tagtype, $tagid)) {
		$attribute_ref->{match} = 100;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_" . $attribute_id . "_yes_title");
			# Override default texts if specific texts are available
			override_general_value($product_ref, $target_lc, "description", "attribute_" . $attribute_id . "_yes_description");
			override_general_value($product_ref, $target_lc, "description_short", "attribute_" . $attribute_id . "_yes_description_short");	
		}
	}
	else {
		$attribute_ref->{match} = 0;
		if ($target_lc ne "data") {
			$attribute_ref->{title} = lang_in_other_lc($target_lc, "attribute_" . $attribute_id . "_no_title");
			# Override default texts if specific texts are available
			override_general_value($product_ref, $target_lc, "description", "attribute_" . $attribute_id . "_no_description");
			override_general_value($product_ref, $target_lc, "description_short", "attribute_" . $attribute_id . "_no_description_short");
		}
	}
	
	return $attribute_ref;
}


=head2 compute_attribute_nutrient_quantity($product_ref, $target_lc, $level, $nid);

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

sub compute_attribute_nutrient_quantity($$$$) {

	my $product_ref = shift;
	my $target_lc = shift;
	my $level = shift;
	my $nid = shift;	

	$log->debug("compute attributes nutrient quantity for product", { code => $product_ref->{code}, level => $level, nid => $nid }) if $log->is_debug();

	my $attribute_id = $level . "_" . $nid;
	$attribute_id =~ s/-/_/g;
	
	# Initialize general values that do not depend on the product (or that will be overriden later)
	
	my $attribute_ref = initialize_attribute($attribute_id, $target_lc);
	
	# Food::compute_nutrient_level() has already determined if we have enough data to compute the nutrient levels
	
	if ((not defined $product_ref->{nutrient_levels}) or (not defined $product_ref->{nutrient_levels}{$nid})) {
		$attribute_ref->{status} = "unknown";
	}
	else {
		$attribute_ref->{status} = "known";
		
		$attribute_ref->{title} = sprintf(lang_in_other_lc($target_lc, "nutrient_in_quantity"), $Nutriments{$nid}{$target_lc} ,
			lang_in_other_lc($target_lc, $product_ref->{nutrient_levels}{$nid} . "_quantity"));
		
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
		
			if ($value <= $low) {
				$match = 80 + 20 * ($low - $value) / $low;
			}
			elsif ($value <= $high) {
				$match = 20 + 60 * ($high - $value) / ($high - $low);
			}
			elsif ($value < $high * 2) {
				$match = 20 * ($value - $high) / $high;
			}
			else {
				$match = 0;
			}
			
			$attribute_ref->{match} = $match;
		}
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

sub add_attribute_to_group($$$$) {
	
	my $product_ref = shift;
	my $target_lc = shift;
	my $group_id = shift;
	my $attribute_ref = shift;
	
	$log->debug("add_attribute_to_group", { target_lc => $target_lc, group_id => $group_id, attribute_ref => $attribute_ref }) if $log->is_debug();	
	
	if (defined $attribute_ref) {
		my $group_ref;
		# Select the requested group
		foreach my $each_group_ref (@{$product_ref->{"attribute_groups_" . $target_lc}}) {
			$log->debug("add_attribute_to_group - existing group", { group_ref => $group_ref,group_id => $group_id }) if $log->is_debug();	
			if ($each_group_ref->{id} eq $group_id) {
				$group_ref = $each_group_ref;
				last;
			}
		}
		# Add group if it doesn't exist yet
		if ((not defined $group_ref) or ($group_ref->{id} ne $group_id)) {
			
			$log->debug("add_attribute_to_group - create new group", { group_ref => $group_ref, group_id => $group_id }) if $log->is_debug();
			
			$group_ref = initialize_attribute_group($group_id, $target_lc);
			
			push @{$product_ref->{"attribute_groups_" . $target_lc}}, $group_ref;
		}
		
		push @{$group_ref->{attributes}}, $attribute_ref;
	}
}


=head2 compute_attributes ( $product_ref, $target_lc )

Compute all attributes for a product, with strings (descriptions, recommendations etc.)
in a specific language, and return them in an array of attribute groups.

=head3 Arguments

=head4 product reference $product_ref

Loaded from the MongoDB database, Storable files, or the OFF API.

=head4 language code $target_lc (or "data")

Returned attributes contain both data and strings intended to be displayed to users.
This parameter sets the desired language for the user facing strings.

If $target_lc is equal to "data", no strings are returned.

=head3 Return values

Attributes are returned in the "attribute_groups_[$target_lc]" array of the product reference
passed as input.

The array contains attribute groups, and each attribute group contains individual attributes.

=cut

sub compute_attributes($$) {

	my $product_ref = shift;
	my $target_lc = shift;	

	$log->debug("compute attributes for product", { code => $product_ref->{code}, target_lc => $target_lc }) if $log->is_debug();

	# Initialize attributes
	
	$product_ref->{"attribute_groups_" . $target_lc} = [];
	
	# Populate the attributes groups and the attributes of each group
	# in a default order (a meaningful order that apps / clients can decide to reorder or not)
	
	my $attribute_ref;
	
	# Nutritional quality
	
	$attribute_ref = compute_attribute_nutriscore($product_ref, $target_lc);
	add_attribute_to_group($product_ref, $target_lc, "nutritional_quality", $attribute_ref);
	
	foreach my $nutrient ("salt", "fat", "sugars", "saturated-fat") {
		$attribute_ref = compute_attribute_nutrient_quantity($product_ref, $target_lc, "low", $nutrient);
		add_attribute_to_group($product_ref, $target_lc, "nutritional_quality", $attribute_ref);
	}
	
	# Processing
	
	$attribute_ref = compute_attribute_nova($product_ref, $target_lc);
	add_attribute_to_group($product_ref, $target_lc, "processing", $attribute_ref);	
		
	# Labels groups
	
	foreach my $label_id ("en:organic", "en:fair-trade") {
		
		$attribute_ref = compute_attribute_has_tag($product_ref, $target_lc, "labels", $label_id);
		add_attribute_to_group($product_ref, $target_lc, "labels", $attribute_ref);
	}
	
	$log->debug("computed attributes for product", { code => $product_ref->{code}, target_lc => $target_lc,
		"attribute_groups_" . $target_lc => $product_ref->{"attribute_groups_" . $target_lc} }) if $log->is_debug();
}

1;
