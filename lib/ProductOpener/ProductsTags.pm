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

=encoding UTF-8

=head1 NAME

ProductOpener::ProductsTags - Handle setting and retrieving tags for products

=head1 SYNOPSIS

..


=head1 DESCRIPTION

..

=cut

package ProductOpener::ProductsTags;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&get_inherited_property_from_categories_tags
		&get_all_tags_having_property
		&has_tag
		&has_one_of_the_tags_from_the_list
		&add_tag
		&remove_tag
		&add_tags_to_field
		&set_field_input_tags_for_source
		&generate_field_tags_from_all_sources
		&compute_field_tags

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Tags qw/get_inherited_property_from_tags get_property canonicalize_taxonomy_tag
	list_taxonomy_tags_in_language canonicalize_allergens_taxonomy_tag exists_taxonomy_tag
	gen_tags_list_with_parents display_taxonomy_tag get_city_code
	init_emb_codes gen_tags_hierarchy_taxonomy
	%taxonomy_fields %tags_fields %emb_codes_cities/;
use ProductOpener::Store qw/get_string_id_for_lang/;
use ProductOpener::PackagerCodes qw/normalize_packager_codes/;
use ProductOpener::IngredientsStrings qw/%may_contain_regexps/;
use Log::Any qw($log);

use URI::Escape::XS;

use Data::DeepAccess qw(deep_get deep_exists deep_set);

my %and = (
	en => " and ",
	cs => " a ",
	da => " og ",
	de => " und ",
	es => " y ",
	fi => " ja ",
	fr => " et ",
	it => " e ",
	nl => " en ",
	pt => " e ",
);

=head2 get_inherited_property_from_categories_tags ($product_ref, $property) {

Iterating from the most specific category, try to get a property for a tag by exploring the taxonomy (using parents).

=head3 Parameters

=head4 $product_ref - the product reference

=head4 $property - the property - string

=head3 Return

=head4 $property_value

The property value if found.

=head4 $matching_category_id

The matching category id if we found a property value.

=cut

sub get_inherited_property_from_categories_tags ($product_ref, $property) {

	if (defined $product_ref->{categories_tags}) {
		# We reverse the list of categories in order to have the most specific categories first
		return (
			get_inherited_property_from_tags("categories", [reverse @{$product_ref->{categories_tags}}], $property));
	}

	return (undef, undef);
}

=head2 get_all_tags_having_property ($product_ref, $tagtype, $prop_name)

For each tag of a given field ($tagtype, can be "labels" or "categories", for example),
and a given property ($prop_name, without last column (:). Can be "incompatible_with:en", for example),
return a hash of tagid <-> property_value
remark: this DOES NOT handle property inheritance

=head3 Return

A hash, where keys are tagid and values are property_value

=head4 Example, get_all_tags_having_property($product_ref, "labels", "incompatible_with:en")


=cut

sub get_all_tags_having_property ($product_ref, $tagtype, $prop_name) {
	my %tag_property_hash = ();
	if (defined $product_ref->{$tagtype . "_tags"}) {
		foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
			my $property_value = get_property($tagtype, $tagid, $prop_name);

			if (defined $property_value) {
				$tag_property_hash{$tagid} = lc($property_value =~ s/\s+/-/gr);
			}
		}
	}

	return \%tag_property_hash;
}

sub has_tag ($product_ref, $tagtype, $tagid) {

	my $return = 0;

	if (defined $product_ref->{$tagtype . "_tags"}) {

		foreach my $tag (@{$product_ref->{$tagtype . "_tags"}}) {

			if ($tag eq $tagid) {
				$return = 1;
				last;
			}
		}
	}
	return $return;
}

# Helper function to tell if a product has a certain tag from the passed list
sub has_one_of_the_tags_from_the_list ($product_ref, $tagtype, $tag_list_ref) {

	foreach my $tag_name (@$tag_list_ref) {
		if (has_tag($product_ref, $tagtype, $tag_name)) {
			return 1;
		}
	}
	return 0;
}

=head1 FUNCTIONS

=head2 add_tag

Adds a tag to a specified tag type in the product reference if it does not already exist.

=head3 Arguments

=head4 $product_ref

A hash reference to the product data.

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens).

=head4 $tagid

The ID of the tag to add.

=head3 Return value

Returns 1 if the tag was added, 0 if it already existed.

=cut

sub add_tag ($product_ref, $tagtype, $tagid) {

	(defined $product_ref->{$tagtype . "_tags"}) or $product_ref->{$tagtype . "_tags"} = [];
	foreach my $existing_tagid (@{$product_ref->{$tagtype . "_tags"}}) {
		if ($tagid eq $existing_tagid) {
			return 0;
		}
	}
	push @{$product_ref->{$tagtype . "_tags"}}, $tagid;
	return 1;
}

sub remove_tag ($product_ref, $tagtype, $tagid) {

	my $return = 0;

	if (defined $product_ref->{$tagtype . "_tags"}) {

		$product_ref->{$tagtype . "_tags_new"} = [];
		foreach my $tag (@{$product_ref->{$tagtype . "_tags"}}) {
			if ($tag ne $tagid) {
				push @{$product_ref->{$tagtype . "_tags_new"}}, $tag;
			}
			else {
				$return = 1;
			}
		}
		$product_ref->{$tagtype . "_tags"} = $product_ref->{$tagtype . "_tags_new"};
		delete $product_ref->{$tagtype . "_tags_new"};
	}
	return $return;
}

=head2 add_tags_to_field ($product_ref, $tag_lc, $field, $additional_fields)

Add a comma separated list of values in the $lc language to a taxonomy field.

Note: this function is only for fields that are generated (e.g. misc tags and data quality tags).
It is not used for input tags fields. Instead set_field_input_tags_for_source() is used.

=head3 Parameters

=head4 $product_ref

Reference to the product hash.

=head4 $tag_lc

The language code of the tags to add.

=head4 $field

The field to which the tags should be added.

=head4 $additional_fields

A comma separated list of tags to add to the field.

=cut

sub add_tags_to_field ($product_ref, $tag_lc, $field, $additional_fields) {
	# add a comma separated list of values in the $lc language to a taxonomy field

	my $current_field = $product_ref->{$field};

	my %existing = ();
	if (defined $product_ref->{$field . "_tags"}) {
		foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
			$existing{$tagid} = 1;
		}
	}

	my @added_tags = ();

	foreach my $tag (split(/,/, $additional_fields)) {

		$tag =~ s/^\s+//;
		$tag =~ s/\s+$//;

		my $tagid;

		if (defined $taxonomy_fields{$field}) {
			$tagid = canonicalize_taxonomy_tag($tag_lc, $field, $tag);
		}
		else {
			$tagid = get_string_id_for_lang($tag_lc, $tag);
		}
		if (not exists $existing{$tagid}) {
			my $current_value = "current: does not exist";
			(defined $product_ref->{$field}) and $current_value = "current: " . $product_ref->{$field};
			#print STDERR "add_tags_to_field - adding $tagid to $field: $current_value\n";
			push @added_tags, $tag;
		}
	}

	if ((scalar @added_tags) > 0) {

		my $value;

		if (defined $taxonomy_fields{$field}) {
			# we do not know the language of the current value of $product_ref->{$field}
			# so regenerate it in the current language used by the interface / caller
			$value = list_taxonomy_tags_in_language($tag_lc, $field, $product_ref->{$field . "_hierarchy"});
			#print STDERR "add_tags_to_fields value: $value\n";
		}
		else {
			$value = $product_ref->{$field};
		}
		(defined $value) or $value = "";

		$product_ref->{$field} = $value . ", " . join(", ", @added_tags);

		if ($product_ref->{$field} =~ /^, /) {
			$product_ref->{$field} = $';
		}

		compute_field_tags($product_ref, $tag_lc, $field);
	}

	return;
}

=head2 set_field_input_tags_for_source ($product_ref, $tag_lc, $field, $source, $input_tags)

New function to set the input tags for a field and a source. (e.g. categories for the manufacturer source)

Note that there is special logic for the allergens field, to split traces from allergens if the user entered them together in the allergens field.
Those traces might be overridden by the client if it also calls set_field_input_tags_for_source with empty traces after setting allergens.

=head3 Parameters

=head4 $product_ref

Reference to the product hash

=head4 $tag_lc

The language code of the input tags

=head4 $field

The field for which we want to set the input tags (e.g. categories, labels, allergens, etc.)

=head4 $source

The source of the input tags (e.g. manufacturer, user, etc.)

=head4 $input_tags

The input tags to set for the field and source

=head4 $add

Optional flag to indicate whether to add the input tags to existing tags (default is 0, which replaces existing tags)

=cut

sub set_field_input_tags_for_source ($product_ref, $tag_lc, $field, $source, $input_tags, $add = 0,
	$last_updated_t = undef)
{

	$last_updated_t //= time();

	if ($field eq "allergens") {

		# If traces were entered in the allergens field, split them
		# Use the language the tag have been entered in

		my $traces_regexp;
		if ((defined $tag_lc) and (defined $may_contain_regexps{$tag_lc})) {
			$traces_regexp = $may_contain_regexps{$tag_lc};
		}

		$log->debug("set_field_input_tags_for_source",
			{field => $field, input_tags => $input_tags, traces_regexp => $traces_regexp})
			if $log->is_debug();

		if (    (defined $traces_regexp)
			and ($input_tags =~ /\b($traces_regexp)\b\s*:?\s*/i))
		{
			# Remove traces from allergens
			$input_tags = $`;
			my $traces_value = $';

			$input_tags =~ s/\s+$//;
			$traces_value =~ s/\s+$//;
			# We add the traces to the existing traces field
			set_field_input_tags_for_source($product_ref, $tag_lc, "traces", $source, $traces_value, 1,
				$last_updated_t);
		}
	}

	# brands are a language less taxonomy, the input tag_lc is not used, we use xx instead
	if ($field eq "brands") {
		$tag_lc = "xx";
	}

	my @normalized_input_tags = ();
	my %seen = ();
	my $and = $and{$tag_lc} || " and ";

	foreach my $tag (split(/,/, $input_tags)) {

		$tag =~ s/^\s+//;
		$tag =~ s/\s+$//;

		next if $tag eq "";

		my $normalized_tag;

		# Special case for allergens and traces: we also use the ingredients taxonomy to check if it has an allergen property
		if (($field eq "allergens") or ($field eq "traces")) {
			$normalized_tag = canonicalize_allergens_taxonomy_tag($tag_lc, $tag);
		}
		elsif ($field eq 'emb_codes') {
			# We normalize codes (e.g. FR 69-238-010 CE" -> "FR 69.238.010 EC")
			# and use the string id to match the canonical ids that we used before the tag refactoring (e.g. "FR 69.238.010 EC" -> "fr-69-238-010-ec")
			$normalized_tag = get_string_id_for_lang("no_language", normalize_packager_codes($tag));
		}
		elsif (defined $taxonomy_fields{$field}) {
			$normalized_tag = canonicalize_taxonomy_tag($tag_lc, $field, $tag);
		}
		else {
			$normalized_tag = $tag;
		}

		my @canon_tags = ($normalized_tag);

		# For taxonomies, try to split unrecognized tags (e.g. "known tag and other known tag" -> "known tag, other known tag"
		if (    (defined $taxonomy_fields{$field})
			and ($tag =~ /^(.*)$and(.*)$/i)
			and (not exists_taxonomy_tag($field, $normalized_tag)))
		{

			my $tag1 = $1;
			my $tag2 = $2;

			my $canon_tag1 = canonicalize_taxonomy_tag($tag_lc, $field, $tag1);
			my $canon_tag2 = canonicalize_taxonomy_tag($tag_lc, $field, $tag2);

			if (    (exists_taxonomy_tag($field, $canon_tag1))
				and (exists_taxonomy_tag($field, $canon_tag2)))
			{
				@canon_tags = ($canon_tag1, $canon_tag2);
			}
		}

		foreach my $canon_tag (@canon_tags) {
			if (not exists $seen{$canon_tag}) {
				$seen{$canon_tag} = 1;
				push @normalized_input_tags, $canon_tag;
			}
		}
	}

	if (    ($add)
		and (defined $product_ref->{tags_sources}{$field}{$source}{tags})
		and (scalar @{$product_ref->{tags_sources}{$field}{$source}{tags}} > 0))
	{
		my %existing = map {$_ => 1} @{$product_ref->{tags_sources}{$field}{$source}{tags}};
		foreach my $tag (@normalized_input_tags) {
			if (not exists $existing{$tag}) {
				push @{$product_ref->{tags_sources}{$field}{$source}{tags}}, $tag;
			}
		}
	}

	else {
		deep_set($product_ref, "tags_sources", $field, $source, "tags", \@normalized_input_tags);
	}

	deep_set($product_ref, "tags_sources", $field, $source, "last_updated_t", $last_updated_t);

	# We generate the [field]_tags field from all sources
	generate_field_tags_from_all_sources($product_ref, $field);

	return;
}

=head2 generate_field_tags_from_all_sources ($product_ref, $tagtype)

This function gathers all the input tags for a field from all sources, and generates the final tags for the field,
including parents for taxonomy fields.

=cut

sub generate_field_tags_from_all_sources ($product_ref, $tagtype) {

	my %all_input_tags = ();

	if (defined $product_ref->{tags_sources}{$tagtype}) {
		foreach my $source (keys %{$product_ref->{tags_sources}{$tagtype}}) {

			$log->debug(
				"generate_field_tags_from_all_sources - source",
				{
					tagtype => $tagtype,
					source => $source,
					source_data => $product_ref->{tags_sources}{$tagtype}{$source}
				}
			) if $log->is_debug();

			if (defined $product_ref->{tags_sources}{$tagtype}{$source}{tags}) {
				foreach my $tag (@{$product_ref->{tags_sources}{$tagtype}{$source}{tags}}) {
					$all_input_tags{$tag} = 1;
				}
			}
		}
	}

	my @all_input_tags_list = sort keys %all_input_tags;

	$log->debug("generate_field_tags_from_all_sources - all input tags", {all_input_tags_list => \@all_input_tags_list})
		if $log->is_debug();

	$product_ref->{$tagtype . "_tags"} = [gen_tags_list_with_parents("en", $tagtype, \@all_input_tags_list)];

	# For brands, also generate the "brands" field that is used for display
	if ($tagtype eq "brands") {
		$product_ref->{$tagtype}
			= join(", ", map {display_taxonomy_tag("en", $tagtype, $_)} @{$product_ref->{$tagtype . "_tags"}});
	}

	# For EMB codes, also generate the cities_tags
	if ($tagtype eq 'emb_codes') {
		$product_ref->{"cities_tags"} = [];
		foreach my $tag (@{$product_ref->{$tagtype . "_tags"}}) {
			my $city_code = get_city_code($tag);
			if (defined $emb_codes_cities{$city_code}) {
				push @{$product_ref->{"cities_tags"}},
					get_string_id_for_lang("no_language", $emb_codes_cities{$city_code});
			}
		}
	}

	$log->debug("generate_field_tags_from_all_sources - result",
		{$tagtype . "_tags" => $product_ref->{$tagtype . "_tags"}})
		if $log->is_debug();

	return;
}

=head2 compute_field_tags ($product_ref, $tag_lc, $field)

Generate the tags hierarchy from the comma separated list of $field with default language $tag_lc

This function was used primarily before we refactored tags with tags_sources (schema version < 1005).

It is still used to upgrade old products to newer schema (see ProductSchemaChanges.pm)

=cut

sub compute_field_tags ($product_ref, $tag_lc, $field) {
	# generate the tags hierarchy from the comma separated list of $field with default language $tag_lc

	# fields that should not have a different normalization (accentuation etc.) based on language
	if ($field eq "teams") {
		$tag_lc = "no_language";
	}

	# brands are a language less taxonomy, the input tag_lc is not used, we use xx instead
	if ($field eq "brands") {
		$tag_lc = "xx";
	}

	init_emb_codes() unless %emb_codes_cities;
	# generate the hierarchy of tags from the field values

	if (defined $taxonomy_fields{$field}) {
		$product_ref->{$field . "_lc"} = $tag_lc;    # save the language for the field, useful for debugging
		$product_ref->{$field . "_hierarchy"} = [gen_tags_hierarchy_taxonomy($tag_lc, $field, $product_ref->{$field})];
		$product_ref->{$field . "_tags"} = [];
		foreach my $tag (@{$product_ref->{$field . "_hierarchy"}}) {
			push @{$product_ref->{$field . "_tags"}}, $tag;
		}
	}
	# tags fields without an associated taxonomy
	elsif (defined $tags_fields{$field}) {

		my $value = $product_ref->{$field};

		$product_ref->{$field . "_tags"} = [];
		if ($field eq 'emb_codes') {
			$product_ref->{"cities_tags"} = [];
			$value = normalize_packager_codes($product_ref->{emb_codes});
		}

		foreach my $tag (split(',', $value)) {
			if (get_string_id_for_lang($tag_lc, $tag) ne '') {
				# There is only one field value for all languages, use "no_language" to normalize
				push @{$product_ref->{$field . "_tags"}}, get_string_id_for_lang("no_language", $tag);
				if ($field eq 'emb_codes') {
					my $city_code = get_city_code($tag);
					if (defined $emb_codes_cities{$city_code}) {
						push @{$product_ref->{"cities_tags"}},
							get_string_id_for_lang("no_language", $emb_codes_cities{$city_code});
					}
				}
			}
		}
	}

	return;
}

1;
