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

ProductOpener::Packaging 

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package ProductOpener::Packaging;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&extract_packaging_from_image
		&init_packaging_taxonomies_regexps
		&get_checked_and_taxonomized_packaging_component_data
		&add_or_combine_packaging_component_data
		&analyze_and_combine_packaging_data
		&parse_packaging_component_data_from_text_phrase
		&guess_language_of_packaging_text
		&apply_rules_to_augment_packaging_component_data
		&aggregate_packaging_by_parent_materials
		&load_categories_packagings_materials_stats
		&get_parent_material

		%packaging_taxonomies
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::Numbers qw/:all/;
use ProductOpener::Units qw/:all/;
use ProductOpener::ImportConvert qw/:all/;

use Data::DeepAccess qw(deep_get deep_val);
use List::Util qw(first);

# We use a global variable in order to load the packaging stats only once
my $categories_packagings_materials_stats_ref;

sub load_categories_packagings_materials_stats() {
	if (not defined $categories_packagings_materials_stats_ref) {
		my $file = "$data_root/data/categories_stats/categories_packagings_materials_stats.all.popular.json";
		# In dev environments, we provide a sample stats file in the data-default directory
		# so that we can run tests with meaningful and unchanging data
		if (!-e $file) {
			my $default_file
				= "$data_root/data-default/categories_stats/categories_packagings_materials_stats.all.popular.json";
			$log->debug("local packaging stats file does not exist, will use default",
				{file => $file, default_file => $default_file})
				if $log->is_debug();
			$file = $default_file;
		}
		$log->debug("loading packagings materials stats", {file => $file}) if $log->is_debug();
		$categories_packagings_materials_stats_ref = retrieve_json($file);
		if (not defined $categories_packagings_materials_stats_ref) {
			$log->debug("unable to load packagings materials stats", {file => $file}) if $log->is_debug();
		}
	}
	return $categories_packagings_materials_stats_ref;
}

=head1 FUNCTIONS

=head2 extract_packagings_from_image( $product_ref $id $ocr_engine $results_ref )

Extract packaging data from packaging info / recycling instructions photo.

=cut

sub extract_packaging_from_image ($product_ref, $id, $ocr_engine, $results_ref) {

	my $lc = $product_ref->{lc};

	if ($id =~ /_(\w\w)$/) {
		$lc = $1;
	}

	extract_text_from_image($product_ref, $id, "packaging_text_from_image", $ocr_engine, $results_ref);

	# TODO: extract structured data from the text
	if (($results_ref->{status} == 0) and (defined $results_ref->{packaging_text_from_image})) {

		$results_ref->{packaging_text_from_image_orig} = $product_ref->{packaging_text_from_image};
	}

	return;
}

=head2 init_packaging_taxonomies_regexps()

This function creates regular expressions that match all variations of
packaging shapes, materials etc. that we want to recognize in packaging text.

=cut

%packaging_taxonomies = (
	"shape" => "packaging_shapes",
	"material" => "packaging_materials",
	"recycling" => "packaging_recycling"
);

my %packaging_taxonomies_regexps = ();

sub init_packaging_taxonomies_regexps() {

	foreach my $taxonomy (values %packaging_taxonomies) {

		$packaging_taxonomies_regexps{$taxonomy}
			= generate_regexps_matching_taxonomy_entries($taxonomy, "list_of_regexps", {});

		$log->debug("init_packaging_taxonomies_regexps - result",
			{taxonomy => $taxonomy, packaging_taxonomies_regexps => $packaging_taxonomies_regexps{$taxonomy}})
			if $log->is_debug();
	}

	return;
}

=head2 parse_packaging_component_data_from_text_phrase($text, $text_language)

This function parses a single phrase (e.g. "5 25cl transparent PET bottles")
and returns a packaging object with properties like units, quantity, material, shape etc.

=head3 Parameters

=head4 $text text

If the text is prefixed by a 2-letter language code followed by : (e.g. fr:),
the language overrides the $text_language parameter (often set to the product language).

This is useful in particular for packaging tags fields added by Robotoff that are prefixed with the language.

It will also be useful when we taxonomize the packaging tags (not taxonomized as of 2022/03/04):
existing packaging tags will be prefixed by the product language.

=head4 $text_language default text language

Can be overrode if the text is prefixed with a language code (e.g. fr:boite en carton)

=head3 Return value

Packaging object (hash) reference with optional properties: recycling, material, shape

=cut

sub parse_packaging_component_data_from_text_phrase ($text, $text_language) {

	$log->debug("parse_packaging_component_data_from_text_phrase - start",
		{text => $text, text_language => $text_language})
		if $log->is_debug();

	if ($text =~ /^([a-z]{2}):/) {
		$text_language = $1;
		$text = $';
	}

	# We might have escaped dots and commas inside numbers from analyze_and_combine_packaging_data()
	$text =~ s/(\d)\\(\.|\,)(\d)/$1$2$3/g;

	# Also try to match the canonicalized form so that we can match the extended synonyms that are only available in canonicalized form
	my $textid = get_string_id_for_lang($text_language, $text);

	my $packaging_ref = {};

	# Match recycling instructions first, as some of them can contain the name of materials
	# e.g. "recycle in paper bin", which should not imply that the material is paper (it could be cardboard)
	foreach my $property ("recycling", "material", "shape") {

		my $tagtype = $packaging_taxonomies{$property};

		foreach my $language ($text_language, "xx") {

			if (defined $packaging_taxonomies_regexps{$tagtype}{$language}) {

				foreach my $regexp_ref (@{$packaging_taxonomies_regexps{$tagtype}{$language}}) {

					my ($tagid, $regexp) = @$regexp_ref;

					my $matched = 0;

					if ($text =~ /\b($regexp)\b/i) {

						my $before = $`;
						$matched = 1;

						$log->debug(
							"parse_packaging_component_data_from_text_phrase - regexp match",
							{
								before => $before,
								text => $text,
								language => $language,
								tagid => $tagid,
								regexp => $regexp
							}
						) if $log->is_debug();

						# If we already have a value for the property,
						# apply the new value only if it is a child of the existing value
						# e.g. if we already have "plastic", we can override it with "PET"
						# Special case for "cardboard" that can be both a shape (card) and a material (cardboard):
						# -> a new shape can be assigned. e.g. "carboard box" -> shape = box
						if (   (not defined $packaging_ref->{$property})
							or (is_a($tagtype, $tagid, $packaging_ref->{$property}))
							or (($property eq "shape") and ($packaging_ref->{$property} eq "en:card")))
						{

							$packaging_ref->{$property} = $tagid;
						}

						# If we have a shape, check if we have a quantity contained (volume or weight)
						# or if there is a number of units at the beginning

						if ($property eq "shape") {

							# Quantity contained: 25cl plastic bottle, plastic bottle (25cl)
							if ($text =~ /\b((\d+((\.|,)\d+)?)\s?(l|dl|cl|ml|g|kg))\b/i) {
								$packaging_ref->{quantity_per_unit} = lc($1);

								# Remove the quantity from $before so that we don't mistake it for a number of units
								$before =~ s/$1//g;
							}

							# Number of units: e.g. 4 plastic bottles (but we should not match the 2 in "2 PEHD plastic bottles")
							# match numbers starting with 1 to 9 to avoid matching 02 PEHD
							if ($before =~ /^([1-9]\d*) /) {
								if (not defined $packaging_ref->{number_of_units}) {
									$packaging_ref->{number_of_units} = $1 + 0;
								}
							}
						}

						# If we have a recycling instruction, check if we can infer the material from it
						# e.g. "recycle in glass bin" --> add the "en:glass" material

						if ($property eq "recycling") {
							my $material
								= get_inherited_property("packaging_recycling", $tagid, "packaging_materials:en");
							if ((defined $material) and (not defined $packaging_ref->{"material"})) {
								$packaging_ref->{"material"} = $material;
							}
						}
					}
					elsif ($textid =~ /(^|-)($regexp)(-|$)/) {

						$matched = 1;

						if (   (not defined $packaging_ref->{$property})
							or (is_a($tagtype, $tagid, $packaging_ref->{$property})))
						{

							$packaging_ref->{$property} = $tagid;

							# Try to remove the matched text
							# The challenge is that $regexp matches the normalized $textid
							# and we want to remove the corresponding unnormalized part in $text
							$regexp =~ s/-/\\W/g;
						}
					}

					if ($matched) {
						# Remove the string that we have matched, so that when we match the "in the paper bin" recycling instruction,
						# we don't also match the "paper" material (it could be cardboard)
						# Exceptions:
						# - Do not remove "cardboard" as we do want to possibly match it as both a material and a shape
						# - Do not remove materials that begin with a number (e.g. "1 PET" in order to not remove the 1 in "1 PET bottle" which is more likely to be a number)
						if (($tagid ne "en:cardboard")
							and not(($regexp =~ /^\d/) and ($regexp =~ /^\d/)))
						{
							$text =~ s/\b($regexp)\b/ MATCHED /i;
							$textid = get_string_id_for_lang($text_language, $text);
							$log->debug(
								"parse_packaging_component_data_from_text_phrase - removed match",
								{text => $text, textid => $textid, tagid => $tagid, regexp => $regexp}
							) if $log->is_debug();
						}
					}
				}
			}
		}
	}

	$log->debug("parse_packaging_component_data_from_text_phrase - result",
		{text => $text, text_language => $text_language, packaging_ref => $packaging_ref})
		if $log->is_debug();

	return $packaging_ref;
}

=head2 guess_language_of_packaging_text($text, \@potential_lcs)

Given a text like "couvercle en métal", this function tries to guess the language of the text based
on how well it matches the packaging taxonomies.

One use is to convert packaging tags for which we don't have a language to a version prefixed by the language.

Candidate languages are provided in an ordered list, and the function returns the one that matches more
properties (material, shape, recycling). In case of a draw, the priority is given according to the order of the list.

=head3 Parameters

=head4 $text text

=head4 \@potential_lcs reference to an ordered list of language codes

=head3 Return value

- undef if no match was found
- or language code of the better matching language

=cut

sub guess_language_of_packaging_text ($text, $potential_lcs_ref) {

	$log->debug("guess_language_of_packaging_text - start", {text => $text, potential_lcs_ref => $potential_lcs_ref})
		if $log->is_debug();

	my $max_lc;
	my $max_properties = 0;

	foreach my $l (@$potential_lcs_ref) {
		my $packaging_ref = parse_packaging_component_data_from_text_phrase($text, $l);
		my $properties = scalar keys %$packaging_ref;

		# if no property was recognized and we still have no candidate,
		# try to see if the entry exists in the packaging taxonomy
		# (which includes preservation which will not be parsed by parse_packaging_component_data_from_text_phrase)

		if (($max_properties == 0) and ($properties == 0)) {
			my $tagid = canonicalize_taxonomy_tag($l, "packaging", $text);
			if (exists_taxonomy_tag("packaging", $tagid)) {
				$properties = 1;
			}
		}

		if ($properties > $max_properties) {
			$max_lc = $l;
			$max_properties = $properties;
			# If we have all properties, bail out
			if ($properties == 3) {
				last;
			}
		}
	}

	return $max_lc;
}

=head2 get_checked_and_taxonomized_packaging_component_data($tags_lc, $input_packaging_ref, $response_ref)

Check and taxonomize packaging component data (e.g. from the product WRITE API, or from the web edit form)

=head3 Parameters

=head4 $input_packaging_ref packaging component

=head4 $response_ref API response object reference

The API response object is used to return warnings and errors to the caller.
If a warning or error is found (e.g. an unrecognized input), it is returned in
the "warnings" or "errors" array of the response object.

=head3 Return value

A taxonomized packaging structure corresponding to the input packaging structure.

=cut

sub get_checked_and_taxonomized_packaging_component_data ($tags_lc, $input_packaging_ref, $response_ref) {

	my $packaging_ref = {};

	my $has_data = 0;

	# Number of units
	if ((not defined $input_packaging_ref->{number_of_units}) or ($input_packaging_ref->{number_of_units} eq "")) {
		add_warning(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "number_of_units"},
				impact => {id => "field_ignored"},
			}
		);
	}
	# Require a positive and non zero number of units
	elsif (($input_packaging_ref->{number_of_units} =~ /^\d+$/) and ($input_packaging_ref->{number_of_units} > 0)) {
		$packaging_ref->{number_of_units} = $input_packaging_ref->{number_of_units} + 0;
		$has_data = 1;
	}
	else {
		add_warning(
			$response_ref,
			{
				message => {id => "invalid_type_must_be_integer"},
				field => {id => "number_of_units", value => $input_packaging_ref->{number_of_units}},
				impact => {id => "field_ignored"},
			}
		);
	}

	# For the following fields, we will ignore values that are 0, empty, unknown or not applicable

	# Quantity per unit
	if (    (defined $input_packaging_ref->{quantity_per_unit})
		and ($input_packaging_ref->{quantity_per_unit} !~ /^\s*(0|$empty_unknown_not_applicable_or_none_regexp)\s*$/i))
	{
		$packaging_ref->{quantity_per_unit} = $input_packaging_ref->{quantity_per_unit};
		$has_data = 1;

		# Quantity contained: 25cl plastic bottle, plastic bottle (25cl)
		if ($packaging_ref->{quantity_per_unit} =~ /\b((\d+((\.|,)\d+)?)\s?(l|dl|cl|ml|g|kg))\b/i) {

			$packaging_ref->{quantity_per_unit_unit} = lc($5);
			$packaging_ref->{quantity_per_unit_value} = convert_string_to_number(lc($2));
		}
	}

	# Weights
	foreach my $weight ("weight_measured", "weight_specified") {
		if (    (defined $input_packaging_ref->{$weight})
			and ($input_packaging_ref->{$weight} !~ /^\s*(0|$empty_unknown_not_applicable_or_none_regexp)\s*$/i))
		{
			if ($input_packaging_ref->{$weight} =~ /^\d+((\.|,)\d+)?$/) {
				$packaging_ref->{$weight} = convert_string_to_number($input_packaging_ref->{$weight});
				$has_data = 1;
			}
			elsif (defined normalize_quantity($input_packaging_ref->{$weight})) {
				$packaging_ref->{$weight}
					= convert_string_to_number(normalize_quantity($input_packaging_ref->{$weight}));
				$has_data = 1;
				add_warning(
					$response_ref,
					{
						message => {id => "invalid_type_must_be_number"},
						field => {
							id => $weight,
							value => $input_packaging_ref->{$weight},
							valued_converted => $packaging_ref->{$weight}
						},
						impact => {id => "value_converted"},
					}
				);
			}
			else {
				add_warning(
					$response_ref,
					{
						message => {id => "invalid_type_must_be_number"},
						field => {id => $weight, value => $input_packaging_ref->{$weight}},
						impact => {id => "field_ignored"},
					}
				);
			}
		}
	}

	# Shape, material and recycling
	foreach my $property ("shape", "material", "recycling") {

		my $tagtype = $packaging_taxonomies{$property};

		if (    (defined $input_packaging_ref->{$property})
			and ($input_packaging_ref->{$property} !~ /^\s*(0|$empty_unknown_not_applicable_or_none_regexp)\s*$/i)
			and (get_fileid($input_packaging_ref->{$property}) !~ /^-*$/))
		{
			my $tagid = canonicalize_taxonomy_tag($tags_lc, $tagtype, $input_packaging_ref->{$property});
			$log->debug(
				"canonicalize input value",
				{
					tags_lc => $tags_lc,
					tagtype => $tagtype,
					input_value => $input_packaging_ref->{$property},
					tagid => $tagid
				}
			) if $log->is_debug();
			if (not exists_taxonomy_tag($tagtype, $tagid)) {
				add_warning(
					$response_ref,
					{
						message => {id => "unrecognized_value"},
						field => {id => $property, value => $tagid},
						impact => {id => "none"},
					}
				);
			}
			$packaging_ref->{$property} = $tagid;
			$has_data = 1;
		}
		else {
			add_warning(
				$response_ref,
				{
					message => {id => "missing_field"},
					field => {id => $property, value => $input_packaging_ref->{$property}},
					impact => {id => "field_ignored"},
				}
			);
		}
	}

	# If we don't have data at all, return undef
	if (not $has_data) {
		return;
	}

	return $packaging_ref;
}

=head2 apply_rules_to_augment_packaging_component_data($product_ref, $packaging_ref)

Use rules to add more properties or more precise properties to a packaging component.
Some rules may depend on the product. (e.g. if the product category is "en:coffees", and the shape
of the packaging component is "en:capsule", we assume the shape is "en:coffee-capsule")

=head3 Parameters

=head4 $product_ref product

=head4 $packaging_ref packaging component

=cut

sub apply_rules_to_augment_packaging_component_data ($product_ref, $packaging_ref) {

	# If the shape is "capsule" and the product is in category "en:coffees", mark the shape as a "coffee capsule"
	if (    (defined $packaging_ref->{"shape"})
		and ($packaging_ref->{"shape"} eq "en:capsule")
		and (has_tag($product_ref, "categories", "en:coffees")))
	{
		$packaging_ref->{"shape"} = "en:coffee-capsule";
	}

	# If the shape is bottle and the material is glass, mark recycling as recycle if recycling is not already set
	if (
			(defined $packaging_ref->{"shape"})
		and ($packaging_ref->{"shape"} eq "en:bottle")
		and (defined $packaging_ref->{"material"})
		and (  ($packaging_ref->{"material"} eq "en:glass")
			or (is_a("packaging_materials", $packaging_ref->{"material"}, "en:glass")))
		)
	{
		if (not defined $packaging_ref->{"recycling"}) {
			$packaging_ref->{"recycling"} = "en:recycle";
		}
	}

	# If we have a shape without a material, check if there is a default material for the shape
	# e.g. "en:Bubble wrap" has the property packaging_materials:en: en:plastic
	if ((defined $packaging_ref->{"shape"}) and (not defined $packaging_ref->{"material"})) {
		my $material = get_inherited_property("packaging_shapes", $packaging_ref->{"shape"}, "packaging_materials:en");
		if (defined $material) {
			$packaging_ref->{"material"} = $material;
		}
	}

	# If we have a material without a shape, check if there is a default shape for the material
	# e.g. "en:tetra-pak" has the shape "en:brick"
	if ((defined $packaging_ref->{"material"}) and (not defined $packaging_ref->{"shape"})) {
		my $shape = get_inherited_property("packaging_materials", $packaging_ref->{"material"}, "packaging_shapes:en");
		if (defined $shape) {
			$packaging_ref->{"shape"} = $shape;
		}
	}
	return;
}

=head2 add_or_combine_packaging_component_data($product_ref, $packaging_ref, $response_ref)

This function adds the data for a packaging component to the packagings data structure,
or if the packaging component data is compatible with an existing component
of the packagings structure, the data is combined.

=head3 Parameters

=head4 $product_ref product

=head4 $packaging_ref packaging component

=head4 $response_ref API response object reference

The API response object is used to return warnings and errors to the caller.
If a warning or error is found (e.g. an unrecognized input), it is returned in
the "warnings" or "errors" array of the response object.

=cut

sub add_or_combine_packaging_component_data ($product_ref, $packaging_ref, $response_ref) {

	$log->debug("add_or_combine_packaging_component_data - start", {packaging_ref => $packaging_ref})
		if $log->is_debug();

	# Non empty packaging?
	if ((scalar keys %$packaging_ref) > 0) {

		# If we have an existing packaging that can correspond, augment it
		# otherwise, add one

		my $matching_packaging_ref;

		foreach my $existing_packaging_ref (@{$product_ref->{packagings}}) {

			my $match = 1;

			foreach my $property (sort keys %$packaging_ref) {

				# If the existing packaging does not have a property, it can match
				if (not defined $existing_packaging_ref->{$property}) {
					next;
				}

				my $tagtype = $packaging_taxonomies{$property};

				# $tagtype can be shape / material / recycling, or undef if the property is something else (e.g. a number of packagings)
				if (not defined $tagtype) {
					# If there is an existing value for the property,
					# check if it is the same
					if ($property eq "number_of_units") {
						# Type is a number
						if ($existing_packaging_ref->{$property} != $packaging_ref->{$property}) {
							$match = 0;
							last;
						}
					}
				}

				# If there is an existing value for the taxonomized property,
				# check if it is either a child or a parent of the value extracted from the packaging text
				elsif ( ($existing_packaging_ref->{$property} ne "en:unknown")
					and ($existing_packaging_ref->{$property} ne $packaging_ref->{$property})
					and (not is_a($tagtype, $existing_packaging_ref->{$property}, $packaging_ref->{$property}))
					and (not is_a($tagtype, $packaging_ref->{$property}, $existing_packaging_ref->{$property})))
				{

					$match = 0;
					last;
				}
			}

			if ($match) {
				$matching_packaging_ref = $existing_packaging_ref;
				last;
			}
		}

		if (not defined $matching_packaging_ref) {
			# Add a new packaging component
			$log->debug("add_or_combine_packaging_component_data - add new packaging component",
				{packaging_ref => $packaging_ref})
				if $log->is_debug();
			push @{$product_ref->{packagings}}, $packaging_ref;
		}
		else {
			# Merge data with matching packaging
			$log->debug(
				"add_or_combine_packaging_component_data - merge with existing packaging component",
				{packaging_ref => $packaging_ref, matching_packaging_ref => $matching_packaging_ref}
			) if $log->is_debug();
			foreach my $property (sort keys %$packaging_ref) {

				my $tagtype = $packaging_taxonomies{$property};

				# If we already have a value for the property,
				# apply the new value only if it is a child of the existing value
				# e.g. if we already have "plastic", we can override it with "PET"
				if (   (not defined $matching_packaging_ref->{$property})
					or ($matching_packaging_ref->{$property} eq "en:unknown")
					or (is_a($tagtype, $packaging_ref->{$property}, $matching_packaging_ref->{$property})))
				{

					$matching_packaging_ref->{$property} = $packaging_ref->{$property};
				}
			}
		}
	}
	return;
}

=head2 migrate_old_number_and_quantity_fields_202211($product_ref)

20221104:
- the number field was renamed to number_of_units
- the quantity field was renamed to quantity_per_unit

rename old fields
this code can be removed once all products have been updated

=cut

sub migrate_old_number_and_quantity_fields_202211 ($product_ref) {

	foreach my $packaging_ref (@{$product_ref->{packagings}}) {
		if (exists $packaging_ref->{number}) {
			if (not exists $packaging_ref->{number_of_units}) {
				$packaging_ref->{number_of_units} = $packaging_ref->{number} + 0;
			}
			delete $packaging_ref->{number};
		}
		if (exists $packaging_ref->{quantity}) {
			if (not exists $packaging_ref->{quantity_per_unit}) {
				$packaging_ref->{quantity_per_unit} = $packaging_ref->{quantity};
				$packaging_ref->{quantity_per_unit_value}
					= convert_string_to_number($packaging_ref->{quantity_per_unit_value});
				$packaging_ref->{quantity_per_unit_unit} = $packaging_ref->{quantity_unit};
			}
			delete $packaging_ref->{quantity};
			delete $packaging_ref->{quantity_value};
			delete $packaging_ref->{quantity_unit};
		}
	}
	return;
}

=head2 canonicalize_packaging_components_properties ($product_ref) {

Re-canonicalize the shape, material and recycling properties of packaging components.
This is useful in particular if the corresponding taxonomies have changed.

=cut

sub canonicalize_packaging_components_properties ($product_ref) {

	foreach my $packaging_ref (@{$product_ref->{packagings}}) {
		foreach my $property ("shape", "material", "recycling") {
			if (defined $packaging_ref->{$property}) {
				my $tagtype = $packaging_taxonomies{$property};
				$packaging_ref->{$property}
					= canonicalize_taxonomy_tag($product_ref->{lc}, $tagtype, $packaging_ref->{$property});
			}
		}
	}
	return;
}

=head2 set_packaging_facets_tags ($product_ref)

Set packaging_(shapes|materials|recycling)_tags fields, with values from the packaging components of the product.

=cut

sub set_packaging_facets_tags ($product_ref) {

	my %packaging_tags = (
		shape => {},
		material => {},
		recycling => {},
	);

	foreach my $packaging_ref (@{$product_ref->{packagings}}) {
		foreach my $property ("recycling", "material", "shape") {
			if (defined $packaging_ref->{$property}) {
				$packaging_tags{$property}{$packaging_ref->{$property}} = 1;
			}
		}
	}

	$product_ref->{packaging_shapes_tags} = [sort keys %{$packaging_tags{"shape"}}];
	$product_ref->{packaging_materials_tags} = [sort keys %{$packaging_tags{"material"}}];
	$product_ref->{packaging_recycling_tags} = [sort keys %{$packaging_tags{"recycling"}}];

	return;
}

=head2 set_packaging_misc_tags($product_ref)

Set some tags in the /misc/ facet so that we can track the products that have 
(or don't have) packaging data.

=cut

sub set_packaging_misc_tags ($product_ref) {

	if (defined $product_ref->{misc_tags}) {
		remove_tag($product_ref, "misc", "en:packagings-complete");
		remove_tag($product_ref, "misc", "en:packagings-not-complete");
		remove_tag($product_ref, "misc", "en:packagings-empty");
		remove_tag($product_ref, "misc", "en:packagings-not-empty");
		remove_tag($product_ref, "misc", "en:packagings-not-empty-but-not-complete");
		remove_tag($product_ref, "misc", "en:packagings-with-weights");
		remove_tag($product_ref, "misc", "en:packagings-with-all-weights");
		remove_tag($product_ref, "misc", "en:packagings-with-all-weights-complete");
		remove_tag($product_ref, "misc", "en:packagings-with-all-weights-not-complete");
		remove_tag($product_ref, "misc", "en:packagings-with-some-but-not-all-weights");

		# Remove previous misc tag for the number of components
		foreach my $tag ($product_ref->{misc_tags}) {
			if ($tag =~ /^en:packagings-number-of-components-/) {
				remove_tag($product_ref, "misc", $tag);
			}
		}
	}

	# Number of packaging components
	my $number_of_packaging_components
		= (defined $product_ref->{packagings} ? scalar @{$product_ref->{packagings}} : 0);
	# Add the tag for the new number of components
	add_tag($product_ref, "misc", "en:packagings-number-of-components-" . $number_of_packaging_components);

	if ($product_ref->{packagings_complete}) {
		add_tag($product_ref, "misc", "en:packagings-complete");
		add_tag($product_ref, "misc", "en:packagings-not-empty");
	}
	else {
		add_tag($product_ref, "misc", "en:packagings-not-complete");

		if ($number_of_packaging_components == 0) {
			add_tag($product_ref, "misc", "en:packagings-empty");
		}
		else {
			add_tag($product_ref, "misc", "en:packagings-not-empty-but-not-complete");
			add_tag($product_ref, "misc", "en:packagings-not-empty");
		}
	}

	# Check if we have weights for all components
	if ($number_of_packaging_components > 0) {
		my $components_with_weights = 0;
		foreach my $packaging_ref (@{$product_ref->{packagings}}) {
			if ((defined $packaging_ref->{weight_specified}) or (defined $packaging_ref->{weight_measured})) {
				$components_with_weights++;
			}
		}
		if ($components_with_weights > 0) {

			add_tag($product_ref, "misc", "en:packagings-with-weights");

			if ($components_with_weights == $number_of_packaging_components) {
				add_tag($product_ref, "misc", "en:packagings-with-all-weights");
				if ($product_ref->{packagings_complete}) {
					add_tag($product_ref, "misc", "en:packagings-with-all-weights-complete");
				}
				else {
					add_tag($product_ref, "misc", "en:packagings-with-all-weights-not-complete");
				}
			}
			else {
				add_tag($product_ref, "misc", "en:packagings-with-some-but-not-all-weights");
			}
		}
	}

	return;
}

=head2 get_parent_material ($material)

Return the parent material (glass, plastics, metal, paper or cardboard) of a material.
Return unknown if the material does not match one of the parents, or if not defined.

=cut

# Build a cache of parent materials to speed up lookups
my %parent_materials = ();

sub get_parent_material ($material) {

	return "en:unknown" if not defined $material;

	# Check if we already computed the parent material
	my $parent_material = $parent_materials{$material};
	if (defined $parent_material) {
		return $parent_material;
	}
	else {
		# take first matching, most harmful first
		$parent_material = (first {is_a("packaging_materials", $material, $_)}
				("en:plastic", "en:glass", "en:metal", "en:paper-or-cardboard")) // "en:unknown";

		$parent_materials{$material} = $parent_material;

		return $parent_material;
	}
}

=head2 aggregate_packaging_by_parent_materials ($product_ref)

Aggregate the weights of each packaging component by parent material (glass, plastics, metal, paper or cardboard)

=cut

sub aggregate_packaging_by_parent_materials ($product_ref) {

	delete $product_ref->{packagings_materials};

	# We will return an empty hash if we have no packagings components
	my $packagings_materials_ref = {};

	if ((defined $product_ref->{packagings}) and (scalar @{$product_ref->{packagings}} > 0)) {

		# If we have packaging components, we will also return a total entry for all materials
		$packagings_materials_ref->{"all"} = {};

		# Iterate over each packaging component
		foreach my $packaging_ref (@{$product_ref->{packagings}}) {

			# Determine what is the parent material for the component
			my $parent_material = get_parent_material($packaging_ref->{material});

			# Initialize the entry for the parent material if needed (even if we have no weight,
			# it is useful to know that there is some parent material used)
			if (not defined $packagings_materials_ref->{$parent_material}) {
				$packagings_materials_ref->{$parent_material} = {};
			}

			# Weight per unit
			my $weight = $packaging_ref->{weight_specified} // $packaging_ref->{weight_measured};
			if (defined $weight) {
				# Assume we have 1 unit if not specified
				my $total_weight = ($packaging_ref->{number_of_units} || 1) * $weight;

				# Add the weight to the parent material, and to a special "all" entry for all materials
				deep_val($packagings_materials_ref, $parent_material, "weight") += $total_weight;
				deep_val($packagings_materials_ref, "all", "weight") += $total_weight;
			}
		}
	}

	$product_ref->{packagings_materials} = $packagings_materials_ref;

	return;
}

=head2 compute_weight_stats_for_parent_materials($product_ref)

Compute stats for the parent materials of a product:
- % of the weight of a material over the weight of all packaging
- weight of packaging per 100g of product

Also compute the main parent material.

=cut

sub compute_weight_stats_for_parent_materials ($product_ref) {

	# We will determine which packaging material has the greatest weight
	my $packagings_materials_main;
	my $packagings_materials_main_weight = 0;

	my $packagings_materials_ref = $product_ref->{packagings_materials};

	if (defined $packagings_materials_ref) {

		# Iterate over each parent material to compute weight statistics
		my $total_weight = deep_get($packagings_materials_ref, "all", "weight");
		foreach my $parent_material_id (sort keys %$packagings_materials_ref) {
			my $parent_material_ref = $packagings_materials_ref->{$parent_material_id};
			if (defined $parent_material_ref->{weight}) {
				if ($total_weight) {
					$parent_material_ref->{weight_percent} = $parent_material_ref->{weight} / $total_weight * 100;
				}
				if ($product_ref->{product_quantity}) {
					$parent_material_ref->{weight_100g}
						= $parent_material_ref->{weight} / $product_ref->{product_quantity} * 100;
				}
				if (    ($parent_material_id ne "all")
					and ($parent_material_ref->{weight} > $packagings_materials_main_weight))
				{
					$packagings_materials_main = $parent_material_id;
					$packagings_materials_main_weight = $parent_material_ref->{weight};
				}
			}
		}
	}

	# Record the main packaging material
	if (defined $packagings_materials_main) {
		$product_ref->{packagings_materials_main} = $packagings_materials_main;
	}
	else {
		delete $product_ref->{packagings_materials_main};
	}
	return;
}

=head2 initialize_packagings_structure_with_data_from_packaging_text ($product_ref, $response_ref) 

This function populates the packagings structure with data extracted from the packaging_text field.
It is used only when there is no pre-existing data in the packagings structure.

=cut

sub initialize_packagings_structure_with_data_from_packaging_text ($product_ref, $response_ref) {

	my @phrases = ();

	my $number_of_packaging_text_entries = 0;

	# Separate phrases by matching:
	# . , ; and newlines
	# but we want to keep commas and dots that are inside numbers (3.40 or 1,5)
	# so we escape them first
	my $packaging_text = $product_ref->{packaging_text};
	$packaging_text =~ s/(\d)(\.|,)(\d)/$1\\$2$3/g;
	my @packaging_text_entries = split(/(?<!\\)\.|(?<!\\),|;|\n/, $packaging_text);
	push(@phrases, @packaging_text_entries);
	$number_of_packaging_text_entries = scalar @packaging_text_entries;

	# Note: as of 2022/11/29, the "packaging" tags field is not used as input.
	# Corresponding code was removed.

	# Add or merge packaging data from phrases to the existing packagings data structure

	my $i = 0;

	foreach my $phrase (@phrases) {

		$i++;
		$phrase =~ s/^\s+//;
		$phrase =~ s/\s+$//;
		next if $phrase eq "";

		my $parsed_packaging_ref = parse_packaging_component_data_from_text_phrase($phrase, $product_ref->{lc});

		my $packaging_ref
			= get_checked_and_taxonomized_packaging_component_data("en", $parsed_packaging_ref, $response_ref);

		if (defined $packaging_ref) {
			apply_rules_to_augment_packaging_component_data($product_ref, $packaging_ref);

			# For phrases corresponding to the packaging text field, mark the shape as en:unknown if it was not identified
			if (($i <= $number_of_packaging_text_entries) and (not defined $packaging_ref->{shape})) {
				$packaging_ref->{shape} = "en:unknown";
			}

			add_or_combine_packaging_component_data($product_ref, $packaging_ref, $response_ref);
		}
	}

	return;
}

=head2 analyze_and_combine_packaging_data($product_ref, $response_ref)

This function analyzes all the packaging information available for the product:

- the existing packagings data structure
- the packaging_text entered by users or retrieved from the OCR of recycling instructions
(e.g. "glass bottle to recycle, metal cap to discard")
- labels (e.g. FSC)

And combines them in an updated packagings data structure.

Note: as of 2022/11/29, the "packaging" tags field is not used as input.

Note: as of 2023/02/13, the "packaging_text" field is used as input only if
there isn't an existing packagings data structure.
This is to avoid double counting some packaging elements that may be referred to
using different shapes (e.g. pot vs jar, or sleeve vs box etc.)

=cut

sub analyze_and_combine_packaging_data ($product_ref, $response_ref) {

	$log->debug("analyze_and_combine_packaging_data - start", {existing_packagings => $product_ref->{packagings}})
		if $log->is_debug();

	# Create the packagings data structure if it does not exist yet
	# otherwise, we will use and augment the existing data
	if (not defined $product_ref->{packagings}) {
		$product_ref->{packagings} = [];
	}

	# TODO: remove once all products have been migrated
	migrate_old_number_and_quantity_fields_202211($product_ref);

	# Re-canonicalize the packaging components properties, in case the corresponding taxonomies have changed
	canonicalize_packaging_components_properties($product_ref);

	# The packaging text field (populated by OCR of the packaging image and/or contributors or producers)
	# is used as input only if the packagings structure is empty
	if ((scalar @{$product_ref->{packagings}} == 0) and (defined $product_ref->{packaging_text})) {

		initialize_packagings_structure_with_data_from_packaging_text($product_ref, $response_ref);
	}

	# Set the packagings_n field to record the number of packaging components
	my $packagings_n = scalar @{$product_ref->{packagings}};
	if ($packagings_n > 0) {
		$product_ref->{packagings_n} = $packagings_n;
	}
	else {
		delete $product_ref->{packagings_n};
	}

	# Set misc fields to indicate if the packaging data is complete
	set_packaging_misc_tags($product_ref);

	# Set packaging facets tags for shape, material and recycling
	set_packaging_facets_tags($product_ref);

	# Aggregate data per parent material
	aggregate_packaging_by_parent_materials($product_ref);

	# Compute stats for each parent material
	compute_weight_stats_for_parent_materials($product_ref);

	$log->debug("analyze_and_combine_packaging_data - done",
		{packagings => $product_ref->{packagings}, response => $response_ref})
		if $log->is_debug();
	return;
}

1;

