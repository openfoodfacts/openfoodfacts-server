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

ProductOpener::Tags - multilingual tags taxonomies (hierarchies of tags)

=head1 SYNOPSIS

C<ProductOpener::Tags> provides functions to build multilingual tags taxonomies from source files,
to use those taxonomies to canonicalize lists of tags, and to display them in different languages.

    use ProductOpener::Tags qw/:all/;

..


=head1 DESCRIPTION

..

=cut

package ProductOpener::Tags;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&canonicalize_tag2
		&canonicalize_tag_link

		&has_tag
		&has_one_of_the_tags_from_the_list
		&add_tag
		&remove_tag
		&is_a

		&get_property
		&get_property_with_fallbacks
		&get_inherited_property
		&get_property_from_tags
		&get_inherited_property_from_tags
		&get_matching_regexp_property_from_tags
		&get_inherited_property_from_categories_tags
		&get_inherited_properties
		&get_tags_grouped_by_property

		%canon_tags
		%tags_images
		%tags_texts
		%level
		%special_tags

		&get_taxonomyid
		&get_taxonomyurl

		&gen_tags_hierarchy_taxonomy
		&gen_ingredients_tags_hierarchy_taxonomy
		&display_tags_hierarchy_taxonomy
		&build_tags_taxonomy
		&build_all_taxonomies
		&list_taxonomy_tags_in_language

		&canonicalize_taxonomy_tag
		&canonicalize_taxonomy_tag_or_die
		&canonicalize_taxonomy_tag_linkeddata
		&canonicalize_taxonomy_tag_weblink
		&canonicalize_taxonomy_tag_link
		&exists_taxonomy_tag
		&display_taxonomy_tag
		&display_taxonomy_tag_name
		&display_taxonomy_tag_link
		&get_taxonomy_tag_and_link_for_lang

		&spellcheck_taxonomy_tag

		&get_tag_css_class
		&get_tag_image

		&display_tag_name
		&display_tag_link
		&display_tags_list
		&display_tag_and_parents
		&display_parents_and_children
		&display_tags_hierarchy
		&export_tags_hierarchy

		&compute_field_tags
		&add_tags_to_field

		&init_tags_texts
		&get_knowledge_content
		&get_city_code
		%emb_codes_cities
		%emb_codes_geo
		%cities
		&init_emb_codes

		%tags_fields
		%writable_tags_fields
		%users_tags_fields
		%taxonomy_fields
		@drilldown_fields
		%language_fields

		%properties

		%language_codes
		%language_codes_reverse

		%country_names
		%country_codes
		%country_codes_reverse
		%country_languages

		%loaded_taxonomies

		%stopwords
		%synonyms_for
		%synonyms_for_extended
		%just_synonyms
		%translations_from
		%translations_to

		%Languages

		&country_to_cc

		&add_user_translation
		&load_users_translations
		&load_users_translations_for_lc
		&add_users_translations_to_taxonomy

		&remove_stopwords_from_start_or_end_of_string
		&get_lc_tagid

		&generate_tags_taxonomy_extract

		&get_all_taxonomy_entries
		&get_taxonomy_tag_synonyms

		&generate_regexps_matching_taxonomy_entries

		&cmp_taxonomy_tags_alphabetically

		&cached_display_taxonomy_tag
		$cached_display_taxonomy_tag_calls
		$cached_display_taxonomy_tag_misses

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Text qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::Index qw/:all/;

use Clone qw(clone);
use List::MoreUtils qw(uniq);

use URI::Escape::XS;
use Log::Any qw($log);
use Digest::SHA1;
use File::Copy;
use MIME::Base64 qw(encode_base64);
use POSIX qw(strftime);
use LWP::UserAgent ();
use Encode;

use GraphViz2;
use JSON::PP;

use Data::DeepAccess qw(deep_get deep_exists);

binmode STDERR, ":encoding(UTF-8)";

=head1 GLOBAL VARIABLES
=cut

=head2 %tags_fields

This defines which are the fields that are list of values.
To this initial list, taxonomized fields will be added by retrieve_tags_taxonomy

=cut

# Fields that are tags
%tags_fields = (
	packaging => 1,
	brands => 1,
	categories => 1,
	labels => 1,
	origins => 1,
	manufacturing_places => 1,
	emb_codes => 1,
	allergens => 1,
	traces => 1,
	purchase_places => 1,
	stores => 1,
	countries => 1,
	states => 1,
	codes => 1,
	debug => 1,
	environment_impact_level => 1,
	data_sources => 1,
	teams => 1,
	categories_properties => 1,
	owners => 1,
	ecoscore => 1,
	# users tags:
	editors => 1,
	photographers => 1,
	informers => 1,
	checkers => 1,
	correctors => 1,
	weighers => 1,
);

# Writable tags fields that can be written directly (e.g. categories, labels) and that are not derived from other fields (e.g. states)
%writable_tags_fields = (
	categories => 1,
	labels => 1,
	origins => 1,
	manufacturing_places => 1,
	emb_codes => 1,
	allergens => 1,
	traces => 1,
	purchase_places => 1,
	stores => 1,
	countries => 1,
);

# Fields that are tags related to users
%users_tags_fields = (
	editors => 1,
	photographers => 1,
	informers => 1,
	checkers => 1,
	correctors => 1,
	weighers => 1,
);

# Fields that have an associated taxonomy
%taxonomy_fields = ();    # populated by retrieve_tags_taxonomy

# Fields that can have different values by language
%language_fields = (
	front_image => 1,
	ingredients_image => 1,
	nutrition_image => 1,
	packaging_image => 1,
	product_name => 1,
	abbreviated_product_name => 1,
	generic_name => 1,
	ingredients_text => 1,
	conservation_conditions => 1,
	other_information => 1,
	packaging_text => 1,
	recycling_instructions_to_recycle => 1,
	recycling_instructions_to_discard => 1,
	producer => 1,
	origin => 1,
	preparation => 1,
	warning => 1,
	recipe_idea => 1,
	customer_service => 1,
	product_infocard => 1,
	ingredients_infocard => 1,
	nutrition_infocard => 1,
	environment_infocard => 1,
);

%canon_tags = ();

my %tags_level = ();
my %tags_direct_parents = ();
my %tags_direct_children = ();
my %tags_all_parents = ();

%stopwords = ();
%just_synonyms = ();
my %just_tags = ();    # does not include synonyms that are only synonyms
my %synonyms = ();
%synonyms_for = ();
%synonyms_for_extended = ();
%translations_from = ();
%translations_to = ();
%level = ();
my %direct_parents = ();
my %direct_children = ();
my %all_parents = ();
my %root_entries = ();

%properties = ();

%tags_images = ();
%tags_texts = ();

my $logo_height = 90;

=head1 FUNCTIONS

=cut

sub get_property ($tagtype, $canon_tagid, $property) {

	if ((exists $properties{$tagtype}{$canon_tagid}) and (exists $properties{$tagtype}{$canon_tagid}{$property})) {
		return $properties{$tagtype}{$canon_tagid}{$property};
	}
	else {
		return;
	}
}

sub get_property_with_fallbacks ($tagtype, $tagid, $property, $fallback_lcs = ["xx", "en"]) {

	my $property_value = get_property($tagtype, $tagid, $property);
	if (!defined $property_value) {
		# is it language dependent ?
		if ($property =~ /:..$/) {
			my $bare_name = $`;
			# try fallbacks
			foreach my $lc (@$fallback_lcs) {
				$property_value = get_property($tagtype, $tagid, "$bare_name:$lc");
				last if defined $property_value;
			}
		}
	}
	return $property_value;
}

sub get_inherited_property ($tagtype, $canon_tagid, $property) {

	my @parents = ($canon_tagid);
	my %seen = ();

	foreach my $tagid (@parents) {
		if (not defined $tagid) {
			$log->warn("undefined parent for tag", {parent_tagid => $tagid, canon_tagid => $canon_tagid})
				if $log->is_warn();
		}
		else {
			defined $seen{$tagid} and next;
			$seen{$tagid} = 1;
			my $property_value = deep_get(\%properties, $tagtype, $tagid, $property);
			if (defined $property_value) {

				if ($property_value eq "undef") {
					# stop the propagation to parents of this tag, but continue with other parents
				}
				else {
					#Return only one occurence of the property if several are defined in ingredients.txt
					return $property_value;
				}
			}
			elsif (exists $direct_parents{$tagtype}{$tagid}) {
				# check if one of the parents has the property
				push @parents, sort keys %{$direct_parents{$tagtype}{$tagid}};
			}
		}
	}
	return;
}

=head2 get_property_from_tags ($tagtype, $tags_ref, $property)

Return the value of a property for the first tag of a list that has this property.

=head3 Parameters

=head4 $tagtype

=head4 $tags_ref Reference to a list of tags

=head4 $property

=cut

sub get_property_from_tags ($tagtype, $tags_ref, $property) {

	my $value;
	if (defined $tags_ref) {
		foreach my $tagid (@$tags_ref) {
			$value = get_property($tagtype, $tagid, $property);
			last if $value;
		}
	}
	return $value;
}

=head2 get_inherited_property_from_tags ($tagtype, $tags_ref, $property)

Return the value of an inherited property for the first tag of a list that has this property.

=head3 Parameters

=head4 $tagtype

=head4 $tags_ref Reference to a list of tags

=head4 $property

=cut

sub get_inherited_property_from_tags ($tagtype, $tags_ref, $property) {

	my $value;
	if (defined $tags_ref) {
		foreach my $tagid (@$tags_ref) {
			$value = get_inherited_property($tagtype, $tagid, $property);
			last if $value;
		}
	}
	return $value;
}

=head2 get_matching_regexp_property_from_tags ($tagtype, $tags_ref, $property, $regexp)

Return the value of a property for the first tag of a list that has this property that matches the regexp.

=head3 Parameters

=head4 $tagtype

=head4 $tags_ref Reference to a list of tags

=head4 $property

=head4 $regexp

=cut

sub get_matching_regexp_property_from_tags ($tagtype, $tags_ref, $property, $regexp) {

	my $matching_value;
	if (defined $tags_ref) {
		foreach my $tagid (@$tags_ref) {
			my $value = get_property($tagtype, $tagid, $property);
			if ((defined $value) and ($value =~ /$regexp/)) {
				$matching_value = $value;
				last;
			}
		}
	}
	return $matching_value;
}

=head2 get_inherited_property_from_categories_tags ($product_ref, $property) {

Iterating from the most specific category, try to get a property for a tag by exploring the taxonomy (using parents).

=head3 Parameters

=head4 $product_ref - the product reference
=head4 $property - the property - string

=head3 Return

The property if found.

=cut

sub get_inherited_property_from_categories_tags ($product_ref, $property) {

	if (defined $product_ref->{categories_tags}) {
		# We reverse the list of categories in order to have the most specific categories first
		return get_inherited_property_from_tags("categories", [reverse @{$product_ref->{categories_tags}}], $property);
	}

	return;
}

=head2 get_inherited_properties ($tagtype, $canon_tagid, $properties_names_ref, $fallback_lcs = ["xx", "en"]) {

Try to get a set of properties for a tag by exploring the taxonomy (using parents).

This methods take into account if a property is defined as "undef"
(but it cuts value only for the considered branch
and might still lead to a value if there are multiple parents branches).

B<Warning:> The algorithm is a bit rough and my not work as you would expect on a DAG.
It does not (currently) respect exploration of nodes that joins from multiple parent
(in those case you would expect to first explore children from both branches).
If we want to change the algorithm for this to work we should first explore parents,
and then decide the order, but this methods is more eager to save time.

=head3 Parameters

=head4 $tagtype - str, name of taxonomy
=head4 $canon_tagid - tag id for which we want properties
=head4 $properties_names - ref to a list of property name
=head4 $fallback_lcs - fallback language code to try
If may search a description:fr but if fallback is ['xx', 'en']
and we find a description:xx or description:en property we will use this value.

=head3 Return

A ref to a hashmap where keys are property names and values are found value.
If a property name is not present it means it was not found.

=cut

sub get_inherited_properties ($tagtype, $canon_tagid, $properties_names_ref, $fallback_lcs = ["xx", "en"]) {

	my @parents = ([0, $canon_tagid]);
	my @fallback_langs = @$fallback_lcs;
	my %seen = ($canon_tagid => 1);
	my %found_properties = ();
	# we have to handle properties that explicitely have "undef" as value
	# we will do it by retaining and propagating this undef value for each target tagid
	my %undef_properties = ();
	my %unfound_properties = ();
	foreach my $property (@{$properties_names_ref}) {
		$unfound_properties{$property} = 1;
	}

	while (scalar @parents) {
		my ($depth, $tagid) = @{shift @parents};
		if (not defined $tagid) {
			$log->warn("undefined parent for tag", {parent_tagid => $tagid, canon_tagid => $canon_tagid})
				if $log->is_warn();
		}
		else {
			# harvest properties
			foreach my $property (keys %unfound_properties) {
				my $property_value = deep_get(\%properties, $tagtype, $tagid, $property);
				if (!defined $property_value) {
					# is it language dependent ?
					if ($property =~ /:..$/) {
						my $bare_name = $`;
						# try fallbacks
						foreach my $lang (@fallback_langs) {
							$property_value = deep_get(\%properties, $tagtype, $tagid, "$bare_name:$lang");
							last if defined $property_value;
						}
					}
				}
				if (defined $property_value) {
					# skip if propagation by a previous children with "undef" value
					next if defined $undef_properties{$tagid} && defined $undef_properties{$tagid}{$property};
					if ($property_value eq "undef") {
						# stop the propagation to parents of this tag, but continue with other parents
						defined $undef_properties{$tagid} or $undef_properties{$tagid} = {};
						$undef_properties{$tagid}{$property} = 1;
					}
					else {
						#Return only one occurence of the property if several are defined in ingredients.txt
						$found_properties{$property} = $property_value;
						delete $unfound_properties{$property};
					}
				}
			}
			# add parents to the search ?
			my $propagate = 0;
			if (exists $direct_parents{$tagtype}{$tagid}) {
				if (!defined $unfound_properties{$tagid}) {
					$propagate = scalar %unfound_properties;
				}
				else {
					# check if we have at least one unfonud property which not "undef"
					for my $property (keys %unfound_properties) {
						if (!defined $unfound_properties{$tagid}{$property}) {
							$propagate = 1;
							last;
						}
					}
				}
			}

			if ($propagate) {
				# propagate search to parents
				foreach my $parent (keys %{$direct_parents{$tagtype}{$tagid}}) {
					if (!defined $seen{$parent}) {
						$seen{$parent} = 1;
						push @parents, [$depth + 1, $parent];
					}
					# propagate undef, we merge with maybe existing items
					if (defined $undef_properties{$tagid}) {
						defined $undef_properties{$parent} or $undef_properties{$parent} = {};
						foreach my $property (keys %{$undef_properties{$tagid}}) {
							$undef_properties{$parent}{$property} = 1;
						}
					}
				}

				# sort parents, lower depth first, name second
				@parents = sort {(@$a[0] <=> @$b[0]) || (@$a[1] cmp @$b[1])} @parents;
			}

			# no need to keep undef_properties for $tagid
			delete $undef_properties{$tagid} if defined $undef_properties{$tagid};
		}
	}
	return \%found_properties;
}

=head2 get_tags_grouped_by_property ($tagtype, $tagids_ref, $prop_name, $props_ref, $inherited_props_ref, $fallback_lcs = ["xx", "en"])
Retrieve properties of a series of tags given in C<$tagids_ref>
and return them, but grouped by C<$prop_name>,
also fetching C<$props_ref> and C<$inherited_props_ref>

=head3 Return
A ref to a hashmap, where keys are property C<$prop_name> values,
and values are in turn hashmaps where keys are tag ids,
and values are a hashmap with of properties and their values.

Tags with undefined property are with group under "undef" value.

=head4 Example
we asks for quality tags, grouped by fix_action, while getting descriptions
{
	"add_nutrition_facts" => {
		"en:kcal-does-not-match-other-nutrients" => {
			"description:en" => "Kcal is not matching value computed from other nutriments"
		},
		"en:kcal-does-not-match-kj" => {
			"description:en" => "Kcal is not matching kJ value"
		},
	},
	"add_categories" =>
	{
		"en:detected-category-baby-milk" {
			"description:en" => "Detected category … may be missing baby milks"
		}
	}
}
=cut

sub get_tags_grouped_by_property ($tagtype, $tagids_ref, $prop_name, $props_ref, $inherited_props_ref,
	$fallback_lcs = ["xx", "en"])
{
	my @tagids = @{$tagids_ref};
	my @props_to_fetch = (@{$inherited_props_ref});
	push @props_to_fetch, $prop_name;

	my $grouped_tags = {};

	foreach my $tagid (@tagids) {
		my $found_ref = get_inherited_properties($tagtype, $tagid, \@props_to_fetch);
		my $prop_value = $found_ref->{$prop_name} // "undef";
		delete $found_ref->{$prop_name} if defined $found_ref->{$prop_name};
		defined $grouped_tags->{$prop_value} or $grouped_tags->{$prop_value} = {};
		# properties only on first level
		foreach my $property (@$props_ref) {
			my $value = get_property_with_fallbacks($tagtype, $tagid, $property, $fallback_lcs);
			if (defined $value) {
				$found_ref->{$property} = $value;
			}
		}
		$grouped_tags->{$prop_value}{$tagid} = $found_ref;
	}

	return $grouped_tags;
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

# Determine if a tag is a child of another tag (or the same tag)
# assume tags are already canonicalized
sub is_a ($tagtype, $child, $parent) {

	if (not defined $tagtype) {
		$log->error("is_a() function called with undefined $tagtype: should not happen",
			{child => $child, parent => $parent})
			if $log->is_error();
		return 0;
	}

	#$log->debug("is_a", { tagtype => $tagtype, child => $child, parent => $parent }) if $log->is_debug();

	my $found = 0;

	if ($child eq $parent) {
		$found = 1;
	}
	elsif ( (defined $all_parents{$tagtype})
		and (defined $all_parents{$tagtype}{$child}))
	{

		#$log->debug("is_a - parents found") if $log->is_debug();

		foreach my $tagid (@{$all_parents{$tagtype}{$child}}) {
			#$log->debug("is_a - comparing parents", {tagid => $tagid}) if $log->is_debug();
			if ($tagid eq $parent) {
				$found = 1;
				last;
			}
		}
	}

	return $found;
}

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

sub load_tags_images ($lc, $tagtype) {

	defined $tags_images{$lc} or $tags_images{$lc} = {};
	defined $tags_images{$lc}{$tagtype} or $tags_images{$lc}{$tagtype} = {};

	if (opendir(DH2, "$www_root/images/lang/$lc/$tagtype")) {
		foreach my $file (sort readdir(DH2)) {
			# Note: readdir returns bytes, which may be utf8 on some systems
			# see https://perldoc.perl.org/perlunicode#When-Unicode-Does-Not-Happen
			$file = decode('utf8', $file);
			if ($file =~ /^((.*)\.\d+x${logo_height}.(png|svg))$/) {
				if ((not defined $tags_images{$lc}{$tagtype}{$2}) or ($3 eq 'svg')) {
					$tags_images{$lc}{$tagtype}{$2} = $1;
				}
			}
		}
		closedir DH2;
	}

	return;
}

# Cache the stopwords regexps to remove stopwords from strings and tagids
my %stopwords_regexps = ();

=head2 remove_stopwords_from_start_or_end_of_string ( $tagtype, $lc, $string )

Remove stopwords (that are specific to each category) from the start or end of a string that has not been normalized.
This function differs from remove_stopwords() that works on normalized tags instead of strings and that also removes stopwords in the middle.

=head3 Arguments

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $lc - Language code

The language the string is in.

=head4 $string - string

The string to remove stopwords from.

=cut

sub remove_stopwords_from_start_or_end_of_string ($tagtype, $lc, $string) {

	if (defined $stopwords{$tagtype}{$lc . ".strings"}) {

		if (not defined $stopwords_regexps{$tagtype . '.' . $lc . '.strings'}) {
			$stopwords_regexps{$tagtype . '.' . $lc . '.strings'}
				= join('|', uniq(@{$stopwords{$tagtype}{$lc . '.strings'}}));
		}

		my $regexp = $stopwords_regexps{$tagtype . '.' . $lc . '.strings'};

		$string =~ s/^(\b($regexp)\s)+//ig;
		$string =~ s/(\s($regexp)\b)+$//ig;
	}
	return $string;
}

=head2 remove_stopwords ( $tagtype, $lc, $tagid )

Remove stopwords (that are specific to each category) from a normalized tag.

=head3 Arguments

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $lc - Language code

The language the tagid is in.

=head4 $tagid - normalized tag

Lowercased, unaccented depending on language, non-alphanumeric chars turned to dash.

=cut

sub remove_stopwords ($tagtype, $lc, $tagid) {

	if (defined $stopwords{$tagtype}{$lc}) {

		my $uppercased_stopwords_overrides = 0;

		if ($lc eq 'fr') {
			# "Dés de tomates" -> "des-de-tomates" --> "dés" should not be a stopword
			$tagid =~ s/\bdes-de\b/DES-DE/g;
			$tagid =~ s/\ben-des\b/EN-DES/g;
			$uppercased_stopwords_overrides = 1;
		}

		if (not defined $stopwords_regexps{$tagtype . '.' . $lc}) {
			$stopwords_regexps{$tagtype . '.' . $lc} = join('|', uniq(@{$stopwords{$tagtype}{$lc}}));
		}

		my $regexp = $stopwords_regexps{$tagtype . '.' . $lc};

		# In Japanese, do not require a word boundary, and do not introduce a hyphen
		if ($lc eq 'ja') {
			$tagid =~ s/$regexp//g;
		}
		# In other languages, require a word boundary, and replace stopwords with a hyphen
		else {
			$tagid =~ s/(^|-)($regexp)(-($regexp))*(-|$)/-/g;
		}

		$tagid =~ tr/-/-/s;
		$tagid =~ s/^-//;
		$tagid =~ s/-$//;

		if ($uppercased_stopwords_overrides) {
			$tagid = lc($tagid);
		}
	}
	return $tagid;
}

sub remove_plurals ($lc, $tagid) {

	if ($lc eq 'en') {
		$tagid =~ s/s$//;
		$tagid =~ s/(s)-/-/g;
	}
	if ($lc eq 'fr') {
		$tagid =~ s/(s|x)$//;
		$tagid =~ s/(s|x)-/-/g;
	}
	if ($lc eq 'es') {
		$tagid =~ s/s$//;
		$tagid =~ s/(s)-/-/g;
	}

	return $tagid;

}

=head2 sanitize_taxonomy_line( $line )

Sanitize a taxonomy line before processing

=head3 Arguments

=head4 str $line - the line read from the file

=cut

sub sanitize_taxonomy_line ($line) {

	chomp($line);

	$line =~ s/’/'/g;    # normalize quotes

	# assume commas between numbers are part of the name
	# e.g. en:2-Bromo-2-Nitropropane-1,3-Diol, Bronopol
	# replace by a lower comma ‚

	$line =~ s/(\d),(\d)/$1‚$2/g;

	# replace escaped comma \, by a lower comma ‚
	$line =~ s/\\,/‚/g;

	# remove parenthesis for roman numerals
	# fr:E333(iii), Citrate tricalcique
	# -> E333iii

	$line =~ s/\(((i|v|x)+)\)/$1/i;

	# strip spaces at end of line
	$line =~ s/\s+$//;

	return $line;
}

=head2 get_lc_tagid( $synonyms_ref, $lc, $tagtype, $tag, $warning )

Search for "current tag" (tag at start of line) for a given tag

=head3 Arguments

=head4 str $tag - tag string for which we search

=head4 reference to hash map $synonyms_ref - ref to %synonyms for $tagtype

=head4 str $tagtype - tag type

=head4 str $lc - language

=head4 str $warning

An optional prefix to display errors if we had to use stopwords / plurals.

If empty, no warning will be displayed.

=head3 return str - found current tagid or undef

=cut

sub get_lc_tagid ($synonyms_ref, $lc, $tagtype, $tag, $warning) {
	$tag =~ s/^\s+//;    # normalize spaces
	$tag = normalize_percentages($tag, $lc);
	my $tagid = get_string_id_for_lang($lc, $tag);
	# search if this tag is associated to a canonical tag id
	my $lc_tagid = $synonyms_ref->{$lc}{$tagid};
	if (not defined $lc_tagid) {
		# try to remove stop words and plurals
		my $stopped_tagid = remove_stopwords($tagtype, $lc, $tagid);
		$stopped_tagid = remove_plurals($lc, $stopped_tagid);
		# and try again to see if it is associated to a canonical tag id
		$lc_tagid = $synonyms_ref->{$lc}{$stopped_tagid};
		if ($warning) {
			print STDERR "$warning tagid $tagid, trying stopped_tagid $stopped_tagid - result canon_tagid: "
				. ($lc_tagid // "") . "\n";
		}

	}
	return $lc_tagid;
}

sub get_file_from_cache ($source, $target) {
	my $cache_root = "$data_root/build-cache/taxonomies";
	my $local_cache_source = "$cache_root/$source";

	# first, try to get it localy
	if (-e $local_cache_source) {
		copy($local_cache_source, $target);
		return 1;
	}

	# Else try to get it from the github project acting as cache
	my $ua = LWP::UserAgent->new();
	my $response = $ua->mirror("https://raw.githubusercontent.com/$build_cache_repo/main/taxonomies/$source",
		$local_cache_source);

	if (($response->is_success) and (-e $local_cache_source)) {
		copy($local_cache_source, $target);
		return 2;
	}

	return 0;
}

sub get_from_cache ($tagtype, @files) {
	# If the full set of cached files can't be found then returns the hash to be used
	# when saving the new cached files.
	my $tag_data_root = "$data_root/taxonomies/$tagtype";
	my $tag_www_root = "$www_root/data/taxonomies/$tagtype";

	my $sha1 = Digest::SHA1->new;

	# Add a version string to the taxonomy data
	# Change this version string if you want to force the taxonomies to be rebuilt
	# e.g. if the taxonomy building algorithm or configuration has changed
	# This needs to be done also when the unaccenting parameters for languages set in Config.pm are changed

	$sha1->add("20230316 - made xx: unaccented");

	foreach my $source_file (@files) {
		open(my $IN, "<", "$data_root/taxonomies/$source_file.txt")
			or die("Cannot open $data_root/taxonomies/$source_file.txt : $!\n");

		binmode($IN);
		$sha1->addfile($IN);
		close($IN);
	}

	my $hash = $sha1->hexdigest;
	my $cache_prefix = "$tagtype.$hash";
	my $got_from_cache = get_file_from_cache("$cache_prefix.result.sto", "$tag_data_root.result.sto");
	if ($got_from_cache) {
		$got_from_cache = get_file_from_cache("$cache_prefix.result.txt", "$tag_data_root.result.txt");
	}
	if ($got_from_cache) {
		$got_from_cache = get_file_from_cache("$cache_prefix.json", "$tag_www_root.json");
	}
	if ($got_from_cache) {
		$got_from_cache = get_file_from_cache("$cache_prefix.full.json", "$tag_www_root.full.json");
	}
	if ($got_from_cache) {
		print "obtained taxonomy for $tagtype from " . ('', 'local', 'GitHub')[$got_from_cache] . " cache.\n";
		$cache_prefix = '';
	}

	return $cache_prefix;
}

sub put_file_to_cache ($source, $target) {
	my $local_target_path = "$data_root/build-cache/taxonomies/$target";
	copy($source, $local_target_path);

	# Upload to github
	my $token = $ENV{GITHUB_TOKEN};
	if ($token) {
		open my $source_file, '<', $source;
		binmode $source_file;
		my $content = '{"message":"put_to_cache ' . strftime('%Y-%m-%d %H:%M:%S', gmtime) . '","content":"';
		my $buf;
		while (read($source_file, $buf, 60 * 57)) {
			$content .= encode_base64($buf, '');
		}
		$content .= '"}';
		close $source_file;

		my $ua = LWP::UserAgent->new(timeout => 300);
		my $url = "https://api.github.com/repos/$build_cache_repo/contents/taxonomies/$target";
		my $response = $ua->put(
			$url,
			Accept => 'application/vnd.github+json',
			Authorization => "Bearer $token",
			'X-GitHub-Api-Version' => '2022-11-28',
			Content => $content
		);
		if (!$response->is_success()) {
			print "Error uploading to GitHub cache for $target: ${\$response->message()}\n";
		}
	}

	return;
}

sub put_to_cache ($tagtype, $cache_prefix) {
	my $tag_data_root = "$data_root/taxonomies/$tagtype";
	my $tag_www_root = "$www_root/data/taxonomies/$tagtype";

	put_file_to_cache("$tag_www_root.json", "$cache_prefix.json");
	put_file_to_cache("$tag_www_root.full.json", "$cache_prefix.full.json");
	put_file_to_cache("$tag_data_root.result.txt", "$cache_prefix.result.txt");
	put_file_to_cache("$tag_data_root.result.sto", "$cache_prefix.result.sto");

	return;
}

=head2 build_tags_taxonomy( $tagtype, $file, $publish )

Build taxonomy from the taxonomy file

Taxonomy will be stored in global hash maps under the entry $tagtype

=head3 Arguments

=head4 str $tagtype - the tagtype

Like "categories", "ingredients"

=head3 $file - name of the file to read in taxonomies folder

=head3 $publish - if 1, store the result in sto

=cut

sub build_tags_taxonomy ($tagtype, $publish) {
	binmode STDERR, ":encoding(UTF-8)";
	binmode STDIN, ":encoding(UTF-8)";
	binmode STDOUT, ":encoding(UTF-8)";

	my @files = ($tagtype);

	# For the origins taxonomy, include the countries taxonomy
	if ($tagtype eq "origins") {
		@files = ("countries", "origins");
	}

	# For the Open Food Facts ingredients taxonomy, concatenate additives, minerals, vitamins, nucleotides and other nutritional substances taxonomies
	elsif (($tagtype eq "ingredients") and (defined $options{product_type}) and ($options{product_type} eq "food")) {
		@files = (
			"additives_classes", "additives", "minerals", "vitamins",
			"nucleotides", "other_nutritional_substances", "ingredients"
		);
	}

	# Packaging
	elsif (($tagtype eq "packaging")) {
		@files = ("packaging_materials", "packaging_shapes", "packaging_recycling", "preservation");
	}

	# Traces - just a copy of allergens
	elsif ($tagtype eq "traces") {
		@files = ("allergens");
	}

	my $cache_prefix = get_from_cache($tagtype, @files);
	if (!$cache_prefix) {
		return;
	}

	print "building taxonomy for $tagtype - publish: $publish\n";

	# Concatenate taxonomy files if needed
	my $file = "$tagtype.txt";
	if ((scalar @files) > 1) {
		$file = "$tagtype.all.txt";

		open(my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/$file")
			or die("Cannot write $data_root/taxonomies/$file : $!\n");

		foreach my $taxonomy (@files) {
			open(my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$taxonomy.txt")
				or die("Missing $data_root/taxonomies/$taxonomy.txt\n");

			print $OUT "# $taxonomy.txt\n\n";

			while (<$IN>) {
				print $OUT $_;
			}

			print $OUT "\n\n";
			close($IN);
		}

		close($OUT);
	}

	# we ofen use the term *tag* in the code to indicate a single entry between commas
	# that is most lines, are tags separated by commas.

	# when we speak about normalized entry, or tagid,
	# it's the tag value where we lowercased, replace separators by dash etc.,
	# see get_string_id_for_lang

	# language code tagid, aka lc_tagid in particular is the first entry in a line
	# that is the id for this tag in a particular language

	# when we speak about canonical tagid (or canon_tagid),
	# this is the lc_tagid for the first line of a definition block,
	# This is the id for the tag among languages,
	# we keep the language code as prefix, as it may be in any language

	# Need to be initialized as a taxonomy is probably already loaded by Tags.pm
	# stopwords contains three entry per language
	# * <lc> contains an array of normalized stop words
	# * <lc>.strings contains an array of stop words
	# * <lc>.orig the original lines as a string
	$stopwords{$tagtype} = {};
	# synonyms track know synonyms and associate to their tagid, by language
	# Note that it contains synonyms and extended synonyms
	# tagtype -> lc -> tagid stores the lc tagid for this tagid
	# Note: it could have been named synonym_of
	$synonyms{$tagtype} = {};
	# synonyms by language for each tagid (this is the reverse lookup of synonyms)
	# but only for direct synonyms (not extended one)
	# tagtype -> lc -> line_tagid stores synonyms tag strings
	$synonyms_for{$tagtype} = {};
	# this is a close parent to synonyms_for,
	# but this contains synonyms generated by substitutions
	# tagtype -> lc -> line_tagid -> tagid contains 1 if tagid in a synonym of line_tagid
	$synonyms_for_extended{$tagtype} = {};
	# given a tagid, with language prefix, gives the corresponding canonical tag id
	# tagtype -> lc:tagid gives you canon_tagid
	$translations_from{$tagtype} = {};
	# associtate each canonical tag id, to a hash where key is language code and value the tag text
	# eg: tagtype -> canon_tagid -> lc gives you text tag
	$translations_to{$tagtype} = {};
	$level{$tagtype} = {};
	# list of parents for every tag as a hashmap (only canonical tagid)
	# $tagtype -> $canon_tagid -> $parentid contains 1
	$direct_parents{$tagtype} = {};
	# list of children for every tag as a hashmap
	# $tagtype -> $canon_tagid -> $childid contains 1
	$direct_children{$tagtype} = {};
	$all_parents{$tagtype} = {};
	$root_entries{$tagtype} = {};
	# a list of all canon_tagid as a hashmap
	# $tagtype -> $canon_tagid contains 1 for every canonical tagid
	$just_tags{$tagtype} = {};
	# synonyms that are not real entries, but only enrich existing tags
	# they correspond to synonyms: entries
	# this is a hashmap where keys are canonical tagid, and value is 1
	$just_synonyms{$tagtype} = {};
	# this stores properties for each canonical tagid
	# $tagtype -> $canon_tagid -> "$property:$lc" stores the value for property
	$properties{$tagtype} = {};

	my $errors = '';

	if (open(my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$file")) {

		# Main name of a tag in a specific language (display form) - e.g. "Café au lait"
		my $lc_tag;
		# Main id of a tag in a specific language (normalized form) - e.g. "cafe-au-lait"
		my $lc_tagid;
		# Canonical id of the tag (main language prefix + normalized form in the main language)
		# e.g. "en:coffee-with-milk"
		my $canon_tagid;

		# print STDERR "Tags.pm - load_tags_taxonomy - tagtype: $tagtype \n";

		# 1st phase: read translations and synonyms

		my $line_number = 0;

		while (<$IN>) {

			my $line = sanitize_taxonomy_line($_);

			$line_number++;

			# empty line, means we change tag block
			if ($line =~ /^(\s*)$/) {
				$canon_tagid = undef;
				next;
			}

			# handle lines of comments
			next if ($line =~ /^\#/);

			#print "new_line: $line\n";
			if ($line =~ /^</) {
				# Parent
				# Ignore in first pass as it may be a synonym, or a translation, for the canonical parent
			}
			elsif ($line =~ /^stopwords:(\w\w):(\s*)/) {
				# stop words definition
				my $lc = $1;
				# store an orig version as is (but spaces)
				$stopwords{$tagtype}{$lc . ".orig"} .= "stopwords:$lc:$'\n";
				$line = $';
				$line =~ s/^\s+//;    # normalize spaces
				my @tags = split(/\s*,\s*/, $line);    # split on comma
				foreach my $tag (@tags) {
					my $tagid = get_string_id_for_lang($lc, $tag);
					next if $tagid eq '';
					defined $stopwords{$tagtype}{$lc} or $stopwords{$tagtype}{$lc} = [];
					defined $stopwords{$tagtype}{$lc . ".strings"} or $stopwords{$tagtype}{$lc . ".strings"} = [];
					# normalized version
					push @{$stopwords{$tagtype}{$lc}}, $tagid;
					# full text version
					push @{$stopwords{$tagtype}{$lc . ".strings"}}, $tag;
				}
			}
			elsif ($line =~ /^(synonyms:)?(\w\w):/) {
				# line with regular entry or a synonyms entry
				my $qualifier = $1;    # eventual synonyms prefix
				my $lc = $2;
				$line = $';
				$line =~ s/^\s+//;

				# Make sure we don't have empty entries
				if ($line eq "") {
					die("Empty entry at line $line_number in $data_root/taxonomies/$file\n");
				}
				# split on comma
				my @tags = split(/\s*,\s*/, $line);

				# first entry gives id of tag
				$lc_tag = $tags[0];
				$lc_tag = ucfirst($lc_tag);
				$lc_tagid = get_string_id_for_lang($lc, $lc_tag);

				# check if we already have an entry listed for one of the synonyms
				# this is useful for taxonomies that need to be merged, and that are concatenated
				# In this case we want to use same canon_tagid and current_tag

				# should only be applied to ingredients (and not to additives)

				if ($tagtype eq 'ingredients') {
					# the other taxonomy may not have chosen the same tag as canonical tag
					# so we try them all until we eventually find
					foreach my $tag2 (@tags) {

						my $tag = $tag2;
						my $possible_canon_tagid = get_lc_tagid($synonyms{$tagtype}, $lc, $tagtype, $tag, "");
						if ((not defined $canon_tagid) and (defined $possible_canon_tagid)) {
							$canon_tagid = "$lc:" . $possible_canon_tagid;
							$lc_tagid = $possible_canon_tagid;
							# we already have a canon_tagid $canon_tagid for the tag
							last;
						}
					}

					# do we already have a translation from a previous definition?
					if ((defined $canon_tagid) and (defined $translations_to{$tagtype}{$canon_tagid}{$lc})) {
						# in this case change current_tag
						$lc_tag = $translations_to{$tagtype}{$canon_tagid}{$lc};
						$lc_tagid = get_string_id_for_lang($lc, $lc_tag);
					}

				}

				if (not defined $canon_tagid) {
					# this is the first entry for the block, so it defines the canonical tagid
					$canon_tagid = "$lc:$lc_tagid";
					# print STDERR "new canon_tagid: $canon_tagid\n";
					if ((defined $qualifier) and ($qualifier eq 'synonyms:')) {
						# register that it's just a synonym
						$just_synonyms{$tagtype}{$canon_tagid} = 1;
					}
				}
				# update translations_from
				if (not defined $translations_from{$tagtype}{"$lc:$lc_tagid"}) {
					$translations_from{$tagtype}{"$lc:$lc_tagid"} = $canon_tagid;
					# print STDERR "taxonomy - translation_from{$tagtype}{$lc:$lc_tagid} = $canon_tagid \n";
				}
				# check that we have same canon_tagid as before
				elsif ($translations_from{$tagtype}{"$lc:$lc_tagid"} ne $canon_tagid) {
					# issue an error message and continue
					my $msg
						= "$lc:$lc_tagid already is associated to "
						. $translations_from{$tagtype}{"$lc:$lc_tagid"} . " ("
						. $tagtype . ")"
						. " - $lc:$lc_tagid cannot be mapped to entry $canon_tagid\n";
					$errors .= "ERROR - " . $msg;
					next;
				}

				defined $translations_to{$tagtype}{$canon_tagid} or $translations_to{$tagtype}{$canon_tagid} = {};
				# update translations_to
				if (not defined $translations_to{$tagtype}{$canon_tagid}{$lc}) {
					$translations_to{$tagtype}{$canon_tagid}{$lc} = $lc_tag;
					# print STDERR "taxonomy - translations_to{$tagtype}{$canon_tagid}{$lc} = $lc_tag \n";
				}

				# Initialize the synonyms list
				(defined $synonyms_for{$tagtype}{$lc}) or $synonyms_for{$tagtype}{$lc} = {};
				defined $synonyms_for{$tagtype}{$lc}{$lc_tagid} or $synonyms_for{$tagtype}{$lc}{$lc_tagid} = [];

				# note: Include the main tag as a synonym of itself,
				# useful later to compute other synonyms
				foreach my $tag (@tags) {
					my $tagid = get_string_id_for_lang($lc, $tag);
					next if $tagid eq '';

					# Check if the synonym is already associated with another tag
					if (
							(defined $synonyms{$tagtype}{$lc}{$tagid})
						and ($synonyms{$tagtype}{$lc}{$tagid} ne $lc_tagid)
						# for additives, E101 contains synonyms that corresponds to E101(i) etc.   Make E101(i) override E101.
						and (not($tagtype =~ /^additives(|_prev|_next|_debug)$/))
						# we have some exception when we merge packaging shapes and materials
						# in packaging
						and (not($tagtype =~ /^packaging(|_prev|_next|_debug)$/))
						)
					{
						# issue an error
						my $msg
							= "$lc:$tagid already is a synonym of $lc:"
							. $synonyms{$tagtype}{$lc}{$tagid}
							. " for entry "
							. $translations_from{$tagtype}{$lc . ":" . $synonyms{$tagtype}{$lc}{$tagid}}
							. " ($tagtype)"
							. " - $lc:$tagid cannot be mapped to entry $canon_tagid / $lc:$lc_tagid\n";
						$errors .= "ERROR - " . $msg;
						next;
					}
					# add synonym to both tracking lists
					push @{$synonyms_for{$tagtype}{$lc}{$lc_tagid}}, $tag;
					$synonyms{$tagtype}{$lc}{$tagid} = $lc_tagid;
					# print STDERR "taxonomy - synonyms - synonyms{$tagtype}{$lc}{$tagid} = $lc_tagid \n";
				}

			}
			elsif ($line =~ /^expected_nutriscore_grade:en:/) {
				# the line should be the nutriscore grade: a, b, c, d or e
				my $nutriscore_grade = $';    # everything after the matched string

				if (not($nutriscore_grade =~ /^([a-e]){1}$/i)) {
					my $msg
						= "expected_nutriscore_grade:en: in "
						. $tagtype
						. " should be followed by a single letter between a and e. expected_nutriscore_grade:en: "
						. $nutriscore_grade
						. " is incorrect\n";

					$errors .= "ERROR - " . $msg;
				}
			}
			elsif ($line =~ /^expected_ingredients:en:/) {
				# the line should contain a single ingredient
				my $expected_ingredients = $';    # everything after the matched string

				if ($expected_ingredients =~ /,/i) {
					my $msg
						= "expected_ingredients:en: in "
						. $tagtype
						. " should contain a single letter "
						. $expected_ingredients
						. " is incorrect\n";

					$errors .= "ERROR - " . $msg;
				}
			}
			else {
				$log->info("unrecognized line in taxonomy", {tagtype => $tagtype, line => $line}) if $log->is_info();
			}

		}

		close($IN);

		if ($errors ne "") {

			print STDERR "Errors in the $tagtype taxonomy definition:\n";
			print STDERR $errors;
			# Disable die for the ingredients taxonomy that is merged with additives, minerals etc.
			# Disable die for the packaging taxonomy as some legit material and shape might have same name
			unless (($tagtype eq "ingredients")
				or ($tagtype eq "packaging")
				or ($tagtype eq "packaging"))
			{
				die("Errors in the $tagtype taxonomy definition");
			}
		}

		# 2nd phase: compute synonyms
		# e.g.
		# en:yogurts, yoghurts
		# ..
		# en:banana yogurts
		#
		# --> also compute banana yoghurts
		# Note that this does not happen on tag string but on tagid (banana-yoghurts)

		#print "synonyms: initializing synonyms_for_extended - tagtype: $tagtype - lc keys: " . scalar(keys %{$synonyms_for{$tagtype}{$lc}}) . "\n";

		# synonym_contains_synonyms is the memory of substitutions that where done
		# $lc -> $tagid -> $canon_tagid2 stores 1
		# if $tagid had a substitution of a tag which canonical tag is $canon_tagid2
		my %synonym_contains_synonyms = ();

		# first pass to build synonyms_for_extended without any reccursion yet
		foreach my $lc (sort keys %{$synonyms_for{$tagtype}}) {
			# initialize synonym_contains_synonyms that we will use later on
			# synonym_contains_synonyms tracks already made substitutions
			# lc -> tagid -> synonym_canonical_tagid
			$synonym_contains_synonyms{$lc} = {};
			# for each list of synonyms
			foreach my $lc_tagid (sort keys %{$synonyms_for{$tagtype}{$lc}}) {
				# print STDERR "synonyms_for{$tagtype}{$lc} - $lc_tagid - " . scalar(@{$synonyms_for{$tagtype}{$lc}{$lc_tagid}}) . "\n";

				(defined $synonyms_for_extended{$tagtype}{$lc}) or $synonyms_for_extended{$tagtype}{$lc} = {};
				# iterate over synonyms to register in synonyms_for_extended
				foreach my $tag (@{$synonyms_for{$tagtype}{$lc}{$lc_tagid}}) {
					my $tagid = get_string_id_for_lang($lc, $tag);
					(defined $synonyms_for_extended{$tagtype}{$lc}{$lc_tagid})
						or $synonyms_for_extended{$tagtype}{$lc}{$lc_tagid} = {};
					$synonyms_for_extended{$tagtype}{$lc}{$lc_tagid}{$tagid} = 1;
					# print STDERR "synonyms_for_extended{$tagtype}{$lc}{$lc_tagid}{$tagid} = 1 \n";
				}
			}
		}

		# Limit the number of passes for big taxonomies to avoid generating tons of useless synonyms
		my $max_pass = 2;
		if (($tagtype =~ /^additives(|_prev|_next|_debug)$/) or ($tagtype =~ /^ingredients/)) {
			$max_pass = 2;
		}

		for (my $pass = 1; $pass <= $max_pass; $pass++) {

			print STDERR "computing synonyms - $tagtype - pass $pass\n";

			foreach my $lc (sort keys %{$synonyms{$tagtype}}) {

				# this list will contain all tags that are possible synonyms
				# that are smaller than current tag and that we may substitute in it
				my @smaller_synonyms = ();

				# synonyms don't support non roman languages at this point
				next if ($lc eq 'ar');
				next if ($lc eq 'he');

				# iterate over synonyms for this tagtype
				# sort from shorter to longuest string and then in lexical order
				# the size sort, enables us to only loop once,
				# as we already harvested all smaller tagsid when we loop over a tag
				foreach my $tagid (sort {length($a) <=> length($b) || ($a cmp $b)} keys %{$synonyms{$tagtype}{$lc}}) {

					my $max_length = length($tagid) - 3;
					# don't lengthen already long synonyms
					# but for the first pass, allow longer synonyms
					$max_length > (60 / $pass) and next;

					# check if the synonym contains another small synonym

					# the canonical tagid this tag is a synonym for
					my $lc_tagid1 = $synonyms{$tagtype}{$lc}{$tagid};

					#print "computing synonyms for $tagid (canon: $lc_tagid1)\n";

					# Does $tagid have other synonyms?
					if (scalar @{$synonyms_for{$tagtype}{$lc}{$lc_tagid1}} > 1) {
						# limit length of synonyms for performance
						if (length($tagid) < (30 / $pass)) {
							push @smaller_synonyms, $tagid;
							#print "$tagid (canon: $lc_tagid1) has other synonyms\n";
						}
					}

					# try each candidate synonyms
					foreach my $tagid2 (@smaller_synonyms) {

						last if length($tagid2) > $max_length;    # avoid generating long strings

						# try to avoid looping:
						# e.g. bio, agriculture biologique, biologique -> agriculture bio -> agriculture agriculture biologique etc.

						# canonical tagid for tagid2
						my $lc_tagid2 = $synonyms{$tagtype}{$lc}{$tagid2};

						# tag is not candidate to its own sustitution !
						next if $lc_tagid2 eq $lc_tagid1;

						# do not apply same synonym twice
						next
							if ((defined $synonym_contains_synonyms{$lc}{$tagid})
							and (defined $synonym_contains_synonyms{$lc}{$tagid}{$lc_tagid2}));

						my $replace;
						my $before = '';
						my $after = '';

						# replace whole words/phrases only

						# String comparisons are many times faster than the regexps, as long as tags only ever need simple string matching.
						# despite how convoluted it is, this is still faster than the regexp.
						# looks in the middle of $tagid
						#if ($tagid =~ /-${tagid2}-/) {
						if (index($tagid, "-${tagid2}-") >= 0) {
							$replace = "-${tagid2}-";
							$before = '-';
							$after = '-';
						}
						# looks at the end of $tagid
						#elsif ($tagid =~ /-${tagid2}$/) {
						elsif (rindex($tagid, "-${tagid2}") + length("-${tagid2}") == length($tagid)) {
							$replace = "-${tagid2}\$";
							$before = '-';
						}
						# looks at the start of $tagid
						#elsif ($tagid =~ /^${tagid2}-/) {
						elsif (index($tagid, "${tagid2}-") == 0) {
							$replace = "^${tagid2}-";
							$after = '-';
						}
						# note that exact match is not a case here (eliminated earlier)

						if (defined $replace) {

							#print "computing synonyms for $tagid ($lc_tagid1): replace: $replace \n";

							# now that we know we have a candidate, we will substitute with all its synonyms
							foreach my $tagid2_s (sort keys %{$synonyms_for_extended{$tagtype}{$lc}{$lc_tagid2}}) {

								# don't replace a synonym by itself
								next if $tagid2_s eq $tagid2;

								# oeufs, oeufs frais -> oeufs frais frais -> oeufs frais frais frais
								# synonym already contained? skip if we are not shortening
								next if ((length($tagid2_s) > length($tagid2)) and ($tagid =~ /${tagid2_s}/));
								next if ($tagid2_s =~ /$tagid/);

								# generate the tag with substitution
								my $tagid_new = $tagid;
								my $replaceby = "${before}${tagid2_s}${after}";
								# TODO: why do we need /e here ?
								$tagid_new =~ s/$replace/$replaceby/e;

								#print "computing synonyms for $tagid ($tagid0): replaceby: $replaceby - tagid4: $tagid4\n";

								if (not defined $synonyms_for_extended{$tagtype}{$lc}{$lc_tagid1}{$tagid_new}) {
									# register substitution as a new synonym
									$synonyms_for_extended{$tagtype}{$lc}{$lc_tagid1}{$tagid_new} = 1;
									# register in synonyms
									$synonyms{$tagtype}{$lc}{$tagid_new} = $lc_tagid1;
									# and register the supstitution happened
									if (defined $synonym_contains_synonyms{$lc}{$tagid_new}) {
										# we inherit substitutions already made on original tagid
										$synonym_contains_synonyms{$lc}{$tagid_new}
											= clone($synonym_contains_synonyms{$lc}{$tagid});
									}
									else {
										$synonym_contains_synonyms{$lc}{$tagid_new} = {};
									}
									$synonym_contains_synonyms{$lc}{$tagid_new}{$lc_tagid2} = 1;
									# print STDERR "synonyms_extended : synonyms{$tagtype}{$lc}{$tagid_new} = $lc_tagid1 (tagid: $tagid - tagid2: $tagid2 - tagid2_c: $lc_tagid2 - tagid2_s: $tagid2_s - replace: $replace - replaceby: $replaceby)\n";
								}
							}
						}

					}

				}    # end of substitutions on a tagid

			}    # end of language code $lc loop

		}    # on of pass loop

		# add more synonyms: remove stopwords and deal with simple plurals
		# -> should not be done on some taxonomies that contain only proper names
		# TODO we could mark this kind of thing in a header for taxonomy
		if (($tagtype ne "countries") and ($tagtype ne "origins")) {

			# Remember: synonyms also contains extended synonyms
			foreach my $lc (sort keys %{$synonyms{$tagtype}}) {

				foreach my $tagid (sort keys %{$synonyms{$tagtype}{$lc}}) {

					my $tagid2 = $tagid;

					# remove stopwords if have at least 3 words in the tag name
					# for this check that we have at least 2 word separators (dashes)
					if ($tagid2 =~ /-.+-/) {
						$tagid2 = remove_stopwords($tagtype, $lc, $tagid);
					}

					$tagid2 = remove_plurals($lc, $tagid2);

					if (not defined $synonyms{$tagtype}{$lc}{$tagid2}) {
						# this is a new synonym, add it using same canonical tagid
						$synonyms{$tagtype}{$lc}{$tagid2} = $synonyms{$tagtype}{$lc}{$tagid};
						#print STDERR "taxonomy - more synonyms - tagid2: $tagid2 - tagid: $tagid\n";
					}
				}
			}
		}

		# 3rd phase: compute the hierarchy
		# there we will associate each tags with its parent
		# the complexity arise by the fact we let taxonomy contains parents written using synonyms
		# or in a different language than the canonical language for this tag

		# we will also collect properties

		# Nectars de fruits, nectar de fruits, nectars, nectar
		# < Jus et nectars de fruits, jus et nectar de fruits
		# > Nectars de goyave, nectar de goyave, nectar goyave
		# > Nectars d'abricot, nectar d'abricot, nectars d'abricots, nectar

		open(my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$file") or die;

		# print STDERR "Tags.pm - load_tags_taxonomy - tagtype: $tagtype - phase 3, computing hierarchy\n";

		# counts for children for each parent
		my %parents = ();

		$canon_tagid = undef;

		while (<$IN>) {

			my $line = sanitize_taxonomy_line($_);

			# consider parenthesis as spaces
			$line =~ s/\(|\)/-/g;

			if ($line =~ /^(\s*)$/) {
				# empty line, this is the end of current block
				$canon_tagid = undef;
				%parents = ();
				#print STDERR "taxonomy: next tag\n";
				next;
			}
			# skip comments lines
			next if ($line =~ /^\#/);

			if ($line =~ /^<(\s*)(\w\w):/) {
				# Parent lines, starting with "<".

				my $lc = $2;
				my $parent = $';
				my $canon_parentid = get_lc_tagid($synonyms{$tagtype}, $lc, $tagtype, $parent,
					"taxonomy : $tagtype : did not find parent");
				my $main_parentid = $translations_from{$tagtype}{"$lc:" . $canon_parentid};
				$parents{$main_parentid}++;
				# display a warning if the same parent is specified twice?
			}
			elsif ($line =~ /^(\w\w):/) {
				# Synonym/translation lines, starting with a language code.

				my $lc = $1;
				$line = $';
				$line =~ s/^\s+//;
				my @tags = split(/\s*,\s*/, $line);
				$lc_tag = normalize_percentages($tags[0], $lc);
				$lc_tagid = get_string_id_for_lang($lc, $lc_tag);

				# we are only interested with the line that defines the canonical tagid
				if (not defined $canon_tagid) {

					$canon_tagid = "$lc:$lc_tagid";

					# check if we already have an entry listed for one of the synonyms
					# this is useful for taxonomies that need to be merged, and that are concatenated

					# should only be applied to ingredients (and not to additives)

					if ($tagtype eq 'ingredients') {

						foreach my $tag2 (@tags) {

							my $tag = $tag2;
							my $possible_canon_tagid = get_lc_tagid($synonyms{$tagtype}, $lc, $tagtype, $tag, "");

							if ((not defined $canon_tagid) and (defined $possible_canon_tagid)) {
								# this is the first line of a block
								$canon_tagid = "$lc:" . $possible_canon_tagid;
								print STDERR
									"taxonomy : $tagtype : we already have a canon_tagid $canon_tagid for the tag $tag\n";
								last;
							}
						}

					}
					# register as canonical tag
					$just_tags{$tagtype}{$canon_tagid} = 1;
					# register direct parents and direct children
					foreach my $parentid (sort keys %parents) {
						# Make sure the parent is not equal to the child
						if ($parentid eq $canon_tagid) {
							$errors .= "ERROR - $canon_tagid is a parent of itself\n";
							next;
						}
						defined $direct_parents{$tagtype}{$canon_tagid} or $direct_parents{$tagtype}{$canon_tagid} = {};
						$direct_parents{$tagtype}{$canon_tagid}{$parentid} = 1;
						defined $direct_children{$tagtype}{$parentid} or $direct_children{$tagtype}{$parentid} = {};
						$direct_children{$tagtype}{$parentid}{$canon_tagid} = 1;
					}
				}
			}
			elsif ($line =~ /^([a-z0-9_\-\.]+):(\w\w):(\s*)/) {
				# property lines - wikidata:en:, description:fr:, etc.

				my $property = $1;
				my $lc = $2;
				$line = $';
				$line =~ s/^\s+//;
				next if $property eq 'synonyms';
				next if $property eq 'stopwords';

				if (defined $canon_tagid) {
					defined $properties{$tagtype}{$canon_tagid} or $properties{$tagtype}{$canon_tagid} = {};

					# If the property name matches the name of an already loaded taxonomy,
					# canonicalize the property values for the corresponding synonym
					# e.g. if an additive has a class additives_classes:en: en:stabilizer (a synonym),
					# we can map it to en:stabiliser (the canonical name in the additives_classes taxonomy)
					if (exists $translations_from{$property}) {
						$properties{$tagtype}{$canon_tagid}{"$property:$lc"}
							= join(",", map({canonicalize_taxonomy_tag($lc, $property, $_)} split(/\s*,\s*/, $line)));
					}
					else {
						# TODO print a warning if the property is already defined
						# add property value
						$properties{$tagtype}{$canon_tagid}{"$property:$lc"} = $line;
					}
				}
				else {
					print STDERR "taxonomy : $tagtype : discarding orphan line : $property : "
						. substr($line, 0, 50) . "...\n";
				}
			}
		}

		close $IN;

		# allow a second file for wikipedia abstracts -> too big, so don't include it in the main file
		# only process properties

		if (-e "$data_root/taxonomies/${tagtype}.properties.txt") {

			open(my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/${tagtype}.properties.txt");

			# print STDERR "Tags.pm - load_tags_taxonomy - tagtype: $tagtype - phase 3, computing hierarchy\n";

			$canon_tagid = undef;

			while (<$IN>) {

				my $line = sanitize_taxonomy_line($_);

				# consider parenthesis as spaces
				$line =~ s/\(|\)/-/g;

				# blank line, is the start of a new block
				if ($line =~ /^(\s*)$/) {
					$canon_tagid = undef;
					next;
				}
				# ignore comments lines
				next if ($line =~ /^\#/);

				if ($line =~ /^(\w\w):/) {
					my $lc = $1;
					$line = $';
					# TODO: why not use get_lc_tagid here ?
					$line =~ s/^\s+//;
					my @tags = split(/\s*,\s*/, $line);
					$lc_tag = normalize_percentages($tags[0], $lc);
					$lc_tagid = get_string_id_for_lang($lc, $lc_tag);

					# this is the first line of the block
					if (not defined $canon_tagid) {
						$canon_tagid = "$lc:$lc_tagid";
					}
				}
				elsif ($line =~ /^([a-z0-9_\-\.]+):(\w\w):(\s*)/) {
					my $property = $1;
					my $lc = $2;
					$line = $';
					$line =~ s/^\s+//;
					next if $property eq 'synonyms';
					next if $property eq 'stopwords';

					# register property value
					#print STDERR "taxonomy - property - tagtype: $tagtype - canon_tagid: $canon_tagid - lc: $lc - property: $property\n";
					defined $properties{$tagtype}{$canon_tagid} or $properties{$tagtype}{$canon_tagid} = {};
					$properties{$tagtype}{$canon_tagid}{"$property:$lc"} = $line;
				}
			}

			close $IN;
		}    # wikipedia file

		# Compute all parents, breadth first

		# print STDERR "Tags.pm - load_tags_hierarchy - lc: $lc - tagtype: $tagtype - compute all parents breadth first\n";

		my %longest_parent = ();

		# foreach my $tagid (keys %{$direct_parents{$tagtype}}) {
		foreach my $tagid (sort keys %{$translations_to{$tagtype}}) {

			# print STDERR "Tags.pm - load_tags_hierarchy - lc: $lc - tagtype: $tagtype - compute all parents breadth first - tagid: $tagid\n";

			my @queue = ();

			if (defined $direct_parents{$tagtype}{$tagid}) {
				@queue = sort keys %{$direct_parents{$tagtype}{$tagid}};
			}
			elsif (not defined $just_synonyms{$tagtype}{$tagid}) {
				# Keep track of entries that are at the root level
				$root_entries{$tagtype}{$tagid} = 1;
			}

			if (not defined $level{$tagtype}{$tagid}) {
				$level{$tagtype}{$tagid} = 1;
				if (defined $direct_parents{$tagtype}{$tagid}) {
					$longest_parent{$tagid} = (sort keys %{$direct_parents{$tagtype}{$tagid}})[0];
				}
			}

			my %seen = ();

			while ($#queue > -1) {
				my $parentid = shift @queue;
				#print "- $parentid\n";

				if ($parentid eq $tagid) {
					$errors .= "ERROR - $tagid is a parent of itself\n";
				}
				elsif (not defined $seen{$parentid}) {
					defined $all_parents{$tagtype}{$tagid} or $all_parents{$tagtype}{$tagid} = [];
					push @{$all_parents{$tagtype}{$tagid}}, $parentid;
					$seen{$parentid} = 1;

					if (not defined $level{$tagtype}{$parentid}) {
						$level{$tagtype}{$parentid} = 2;
						$longest_parent{$tagid} = $parentid;
					}

					if (defined $direct_parents{$tagtype}{$parentid}) {
						foreach my $grandparentid (sort keys %{$direct_parents{$tagtype}{$parentid}}) {
							push @queue, $grandparentid;
							if (   (not defined $level{$tagtype}{$grandparentid})
								or ($level{$tagtype}{$grandparentid} <= $level{$tagtype}{$parentid}))
							{
								$level{$tagtype}{$grandparentid} = $level{$tagtype}{$parentid} + 1;
								$longest_parent{$parentid} = $grandparentid;
							}
						}
					}
				}
			}
		}

		# Compute all children, breadth first

		my %sort_key_parents = ();
		foreach my $tagid (sort keys %{$level{$tagtype}}) {
			my $key = '';
			if (defined $just_synonyms{$tagtype}{$tagid}) {
				$key = '! synonyms ';    # synonyms first
			}
			if (defined $all_parents{$tagtype}{$tagid}) {
				# sort parents according to level
				@{$all_parents{$tagtype}{$tagid}} = sort {
					(((defined $level{$tagtype}{$b}) ? $level{$tagtype}{$b} : 0)
						<=> ((defined $level{$tagtype}{$a}) ? $level{$tagtype}{$a} : 0))
						|| ($a cmp $b)
				} @{$all_parents{$tagtype}{$tagid}};
				$key .= '> ' . join((' > ', reverse @{$all_parents{$tagtype}{$tagid}})) . ' ';
			}
			$key .= '> ' . $tagid;
			$sort_key_parents{$tagid} = $key;
		}

		open(my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/$tagtype.result.txt");

		print $OUT
			"# The [taxonomy name].results.txt files are generated by build_tags_taxonomy.pl.\n# Do not edit this file manually. Edit instead the [taxonomy name].txt source.\n\n";

		# data structure to export the taxonomy to json format
		my %taxonomy_json = ();
		my %taxonomy_full_json = ();    # including wikipedia abstracts

		foreach my $lc (sort keys %{$stopwords{$tagtype}}) {
			next if $lc =~ /\./;    # .orig or .strings
			print $OUT $stopwords{$tagtype}{$lc . ".orig"};
		}
		print $OUT "\n\n";

		foreach my $tagid (
			sort {($sort_key_parents{$a} cmp $sort_key_parents{$b}) || ($a cmp $b)}
			keys %{$level{$tagtype}}
			)
		{

			$taxonomy_json{$tagid} = {name => {}};
			$taxonomy_full_json{$tagid} = {name => {}};

			# print "taxonomy - compute all children - $tagid - level: $level{$tagtype}{$tagid} - longest: $longest_parent{$tagid} - syn: $just_synonyms{$tagtype}{$tagid} - sort_key: $sort_key_parents{$tagid} \n";
			if (defined $direct_parents{$tagtype}{$tagid}) {
				$taxonomy_json{$tagid}{parents} = [];
				$taxonomy_full_json{$tagid}{parents} = [];
				foreach my $parentid (sort keys %{$direct_parents{$tagtype}{$tagid}}) {
					my $lc = $parentid;
					$lc =~ s/^(\w\w):.*/$1/;
					if (not exists $translations_to{$tagtype}{$parentid}{$lc}) {
						$errors .= "ERROR - $tagid has an undefined parent $parentid\n";
					}
					else {
						print $OUT "< $lc:" . $translations_to{$tagtype}{$parentid}{$lc} . "\n";
						push @{$taxonomy_json{$tagid}{parents}}, $parentid;
						push @{$taxonomy_full_json{$tagid}{parents}}, $parentid;
					}
				}
			}

			if (defined $direct_children{$tagtype}{$tagid}) {
				$taxonomy_json{$tagid}{children} = [];
				$taxonomy_full_json{$tagid}{children} = [];
				foreach my $childid (sort keys %{$direct_children{$tagtype}{$tagid}}) {
					my $lc = $childid;
					push @{$taxonomy_json{$tagid}{children}}, $childid;
					push @{$taxonomy_full_json{$tagid}{children}}, $childid;
				}
			}

			my $main_lc = $tagid;
			$main_lc =~ s/^(\w\w):.*/$1/;

			my $i = 0;

			# print "taxonomy - compute all children - $tagid - translations \n";

			my $qualifier = '';
			if (defined $just_synonyms{$tagtype}{$tagid}) {
				$qualifier = "synonyms:";

				# remove synonyms that are also tags from just_synonyms
				if (defined $just_tags{$tagtype}{$tagid}) {
					delete $just_synonyms{$tagtype}{$tagid};
				}
			}

			foreach my $lc ($main_lc, sort keys %{$translations_to{$tagtype}{$tagid}}) {
				$i++;

				$taxonomy_json{$tagid}{name}{$lc} = $translations_to{$tagtype}{$tagid}{$lc};
				$taxonomy_full_json{$tagid}{name}{$lc} = $translations_to{$tagtype}{$tagid}{$lc};

				my $lc_tagid = get_string_id_for_lang($lc, $translations_to{$tagtype}{$tagid}{$lc});

				# print "taxonomy - lc: $lc - tagid: $tagid - lc_tagid: $lc_tagid\n";
				if (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}) {
					if (not(($lc eq $main_lc) and ($i > 1))) {
						print $OUT "$qualifier$lc:" . join(", ", @{$synonyms_for{$tagtype}{$lc}{$lc_tagid}}) . "\n";
					}

					# additives has e-number as their name, and the first synonym is the additive name
					if (    ($tagtype =~ /^additives(|_prev|_next|_debug)$/)
						and (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}[1]))
					{
						$taxonomy_json{$tagid}{name}{$lc} .= " - " . $synonyms_for{$tagtype}{$lc}{$lc_tagid}[1];
						$taxonomy_full_json{$tagid}{name}{$lc} .= " - " . $synonyms_for{$tagtype}{$lc}{$lc_tagid}[1];
					}

					# add synonyms to the full taxonomy
					if (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}) {
						(defined $taxonomy_full_json{$tagid}{synonyms}) or $taxonomy_full_json{$tagid}{synonyms} = {};
						$taxonomy_full_json{$tagid}{synonyms}{$lc} = $synonyms_for{$tagtype}{$lc}{$lc_tagid};
					}
				}
			}

			if (defined $properties{$tagtype}{$tagid}) {

				foreach my $prop_lc (sort keys %{$properties{$tagtype}{$tagid}}) {
					print $OUT "$prop_lc: " . $properties{$tagtype}{$tagid}{$prop_lc} . "\n";
					if ($prop_lc =~ /^(.*):(\w\w)$/) {
						my $prop = $1;
						my $lc = $2;

						(defined $taxonomy_full_json{$tagid}{$prop}) or $taxonomy_full_json{$tagid}{$prop} = {};
						$taxonomy_full_json{$tagid}{$prop}{$lc} = $properties{$tagtype}{$tagid}{$prop_lc};

						if ($prop_lc !~ /^wikipedia/) {
							(defined $taxonomy_json{$tagid}{$prop}) or $taxonomy_json{$tagid}{$prop} = {};
							$taxonomy_json{$tagid}{$prop}{$lc} = $properties{$tagtype}{$tagid}{$prop_lc};
						}

					}
					else {
						$taxonomy_json{$tagid}{$prop_lc} = $properties{$tagtype}{$tagid}{$prop_lc};
						$taxonomy_full_json{$tagid}{$prop_lc} = $properties{$tagtype}{$tagid}{$prop_lc};
					}
				}
			}

			print $OUT "\n";

		}

		close $OUT;

		if ($errors ne "") {

			print STDERR "Errors in the $tagtype taxonomy definition:\n";
			print STDERR $errors;
			# Disable die for the ingredients taxonomy that is merged with additives, minerals etc.
			# Disable also for packaging taxonomy for some shapes and materials shares same names
			unless (($tagtype eq "ingredients") or ($tagtype eq "packaging")) {
				die("Errors in the $tagtype taxonomy definition");
			}
		}

		(-e "$www_root/data/taxonomies") or mkdir("$www_root/data/taxonomies", 0755);

		{
			binmode STDOUT, ":encoding(UTF-8)";
			if (open(my $OUT_JSON, ">", "$www_root/data/taxonomies/$tagtype.json")) {
				print $OUT_JSON encode_json(\%taxonomy_json);
				close($OUT_JSON);
			}
			else {
				print "Cannot open $www_root/data/taxonomies/$tagtype.json, skipping writing taxonomy to file.\n";
			}

			if (open(my $OUT_JSON_FULL, ">", "$www_root/data/taxonomies/$tagtype.full.json")) {
				print $OUT_JSON_FULL encode_json(\%taxonomy_full_json);
				close($OUT_JSON_FULL);
			}
			else {
				print "Cannot open $www_root/data/taxonomies/$tagtype.full.json, skipping writing taxonomy to file.\n";
			}
			# to serve pre-compressed files from Apache
			# nginx : needs nginx_static module
			# system("cp $www_root/data/taxonomies/$tagtype.json $www_root/data/taxonomies/$tagtype.json.json");
			# system("gzip $www_root/data/taxonomies/$tagtype.json");
		}

		$log->error("taxonomy errors", {errors => $errors}) if $log->is_error();

		my $taxonomy_ref = {
			stopwords => $stopwords{$tagtype},
			synonyms => $synonyms{$tagtype},
			just_synonyms => $just_synonyms{$tagtype},
			synonyms_for => $synonyms_for{$tagtype},
			synonyms_for_extended => $synonyms_for_extended{$tagtype},
			translations_from => $translations_from{$tagtype},
			translations_to => $translations_to{$tagtype},
			level => $level{$tagtype},
			direct_parents => $direct_parents{$tagtype},
			direct_children => $direct_children{$tagtype},
			all_parents => $all_parents{$tagtype},
			root_entries => $root_entries{$tagtype},
			properties => $properties{$tagtype},
		};

		if ($publish) {
			store("$data_root/taxonomies/$tagtype.result.sto", $taxonomy_ref);
			put_to_cache($tagtype, $cache_prefix);
		}
	}

	return;
}

=head2 build_all_taxonomies ( $pubish)

Build all taxonomies, including the test taxonomy

=head3 Parameters

=head4 Publish STO file $publish

=cut

sub build_all_taxonomies ($publish) {
	foreach my $taxonomy (@taxonomy_fields, "test") {
		# traces and data_quality_xxx are not real taxonomy per se
		# (but built from allergens and data_quality)
		if ($taxonomy ne "traces" and rindex($taxonomy, 'data_quality_', 0) != 0) {
			build_tags_taxonomy($taxonomy, $publish);
		}
	}

	return;
}

=head2 generate_tags_taxonomy_extract ( $tagtype, $tags_ref, $options_ref, $lcs_ref)

Generate an extract of the taxonomy for a specific set of tags.

=head3 Parameters

=head4 tag type $tagtype

=head4 reference to a list of tags ids $tags_ref

=head4 reference to a hash of key/value options

Options:
- fields: comma separated lists of fields (e.g. "name,description,vegan:en,inherited:vegetarian:en" )

Properties can be requested with their name (e.g."description") or name + a specific language (e.g. "vegan:en").
Only properties directly defined for the entry are returned.
To include inherited properties from parents, prefix the property with "inherited:" (e.g. "inherited:vegan:en").

- include_parents: include entries for all direct parents of the requested tags
- include_children: include entries for all direct children of the requested tags

=head4 reference to an array of language codes

Languages for which we want to extract names, synonyms, properties.

=cut

sub generate_tags_taxonomy_extract ($tagtype, $tags_ref, $options_ref, $lcs_ref) {

	$log->debug("generate_tags_taxonomy_extract",
		{tagtype => $tagtype, tags_ref => $tags_ref, options_ref => $options_ref, lcs_ref => $lcs_ref})
		if $log->is_debug();

	# Return empty hash if the taxonomy does not exist
	if (not defined $translations_to{$tagtype}) {
		$log->debug("taxonomy not found", {tagtype => $tagtype}) if $log->is_debug();
		return {};
	}

	# For the options include_children or include_parents,
	# we will need to include data for more tags than requested.
	# @tags will hold the tags to include

	my @tags = ();
	my %requested_tags = ();
	my %included_tags = ();

	# Requested tags
	foreach my $tagid (@$tags_ref) {
		push @tags, $tagid;
		$requested_tags{$tagid} = 1;
		$included_tags{$tagid} = 1;
	}

	# Root entries
	if ((defined $options_ref) and ($options_ref->{include_root_entries})) {
		if (defined $root_entries{$tagtype}) {
			foreach my $tagid (sort keys %{$root_entries{$tagtype}}) {
				push @tags, $tagid;
				$requested_tags{$tagid} = 1;
				$included_tags{$tagid} = 1;
			}
		}
	}

	my $include_all_fields = 0;
	my $fields_ref = {};
	my @inherited_properties = ();
	if ((defined $options_ref) and (defined $options_ref->{fields})) {
		foreach my $field (split(/,/, $options_ref->{fields})) {
			# Compute a list of the requested inherited properties,
			# as we will populate them directly
			if ($field =~ /^inherited:(.*):(\w\w)$/) {
				my $prop = $1;
				my $lc = $2;
				push @inherited_properties, [$prop, $lc];
			}
			# Compute a hash of the other requested fields
			# as we will go through all existing properties
			else {
				$fields_ref->{$field} = 1;
			}
		}
	}
	else {
		$include_all_fields = 1;
	}

	my $taxonomy_ref = {};

	while (my $tagid = shift @tags) {

		$taxonomy_ref->{$tagid} = {};

		# Handle parent fields

		if (defined $direct_parents{$tagtype}{$tagid}) {

			$taxonomy_ref->{$tagid}{parents} = [];
			foreach my $parentid (sort keys %{$direct_parents{$tagtype}{$tagid}}) {
				if (($include_all_fields) or (defined $fields_ref->{parents})) {
					exists $taxonomy_ref->{$tagid}{parents} or $taxonomy_ref->{$tagid}{parents} = [];
					push @{$taxonomy_ref->{$tagid}{parents}}, $parentid;
				}
				# Include parents if the tag is one of the initially requested tags
				# so that we don't also add parents of parents.
				# Also check that the parent has not been already included.
				if (    (defined $options_ref)
					and ($options_ref->{include_parents})
					and ($requested_tags{$tagid})
					and (not exists $included_tags{$parentid}))
				{
					# Add parent to list of tags to process and included_tags, while leaving it outside of requested_tags
					push @tags, $parentid;
					$included_tags{$parentid} = 1;
				}
			}
		}

		# Handle children fields

		if (defined $direct_children{$tagtype}{$tagid}) {

			foreach my $childid (sort keys %{$direct_children{$tagtype}{$tagid}}) {
				if (($include_all_fields) or (defined $fields_ref->{children})) {
					exists $taxonomy_ref->{$tagid}{children} or $taxonomy_ref->{$tagid}{children} = [];
					push @{$taxonomy_ref->{$tagid}{children}}, $childid;
				}
				# Include children if the tag is one of the initially requested tags
				# so that we don't also add children of children.
				# Also check that the child has not been already included.
				if (    (defined $options_ref)
					and ($options_ref->{include_children})
					and ($requested_tags{$tagid})
					and (not exists $included_tags{$childid}))
				{
					# Add child to list of tags to process and included_tags, while leaving it outside of requested_tags
					push @tags, $childid;
					$included_tags{$childid} = 1;
				}
			}
		}

		# Handle name and synonyms fields

		if (    (($include_all_fields) or (defined $fields_ref->{name}))
			and (defined $translations_to{$tagtype}{$tagid}))
		{

			$taxonomy_ref->{$tagid}{name} = {};

			foreach my $lc (@{$lcs_ref}) {

				if (defined $translations_to{$tagtype}{$tagid}{$lc}) {
					$taxonomy_ref->{$tagid}{name}{$lc} = $translations_to{$tagtype}{$tagid}{$lc};
				}

				my $lc_tagid = get_string_id_for_lang($lc, $translations_to{$tagtype}{$tagid}{$lc});

				if (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}) {

					# additives has e-number as their name, and the first synonym is the additive name
					if (    ($tagtype =~ /^additives(|_prev|_next|_debug)$/)
						and (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}[1]))
					{
						$taxonomy_ref->{$tagid}{name}{$lc} .= " - " . $synonyms_for{$tagtype}{$lc}{$lc_tagid}[1];
					}

					# add synonyms to the full taxonomy
					if (    (($include_all_fields) or (defined $fields_ref->{synonyms}))
						and (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}))
					{
						(defined $taxonomy_ref->{$tagid}{synonyms}) or $taxonomy_ref->{$tagid}{synonyms} = {};
						$taxonomy_ref->{$tagid}{synonyms}{$lc} = $synonyms_for{$tagtype}{$lc}{$lc_tagid};
					}
				}
			}
		}

		# Handle properties that are directly defined for the tags

		if (defined $properties{$tagtype}{$tagid}) {

			foreach my $prop_lc (keys %{$properties{$tagtype}{$tagid}}) {

				# properties are of the form [property_name]:[2 letter language code]
				my ($prop, $lc) = split(/:/, $prop_lc);

				if (
					# Include the property in all requested languages if the property
					# is specified without a language in the fields parameter
					# or if the fields parameter is not specified.

					((($include_all_fields) or (defined $fields_ref->{$prop})) and (grep({/^$lc$/} @$lcs_ref)))

					# Also include the property if it was requested in a specific language
					# e.g. fields=vegan:en
					# as some properties are defined only for English

					or ((defined $fields_ref) and (defined $fields_ref->{$prop_lc}))

					)
				{

					(defined $taxonomy_ref->{$tagid}{$prop}) or $taxonomy_ref->{$tagid}{$prop} = {};
					$taxonomy_ref->{$tagid}{$prop}{$lc} = $properties{$tagtype}{$tagid}{$prop_lc};
				}
			}
		}

		# Handle inherited properties
		foreach my $property_ref (@inherited_properties) {

			my $prop = $property_ref->[0];
			my $lc = $property_ref->[1];
			my $property_value = get_inherited_property($tagtype, $tagid, "$prop:$lc");
			if (defined $property_value) {
				(defined $taxonomy_ref->{$tagid}{$prop}) or $taxonomy_ref->{$tagid}{$prop} = {};
				# If we already have a value for the property (because it's a direct property of the tag)
				# then the inherited value is the same.
				# For simplicity we return the value for both direct and inherited properties in the same field.
				$taxonomy_ref->{$tagid}{$prop}{$lc} = $property_value;
			}
		}
	}

	return $taxonomy_ref;
}

sub retrieve_tags_taxonomy ($tagtype) {

	$taxonomy_fields{$tagtype} = 1;
	$tags_fields{$tagtype} = 1;

	my $file = $tagtype;
	if ($tagtype eq "traces") {
		$file = "allergens";
	}
	elsif (rindex($tagtype, 'data_quality_', 0) == 0) {
		$file = "data_quality";
	}

	# Check if we have a taxonomy for the previous or the next version
	if ($tagtype !~ /_(next|prev)/) {
		if (-e "$data_root/taxonomies/${file}_prev.result.sto") {
			retrieve_tags_taxonomy("${tagtype}_prev");
		}
		if (-e "$data_root/taxonomies/${file}_next.result.sto") {
			retrieve_tags_taxonomy("${tagtype}_next");
		}
	}

	if (!-e "$data_root/taxonomies/$file.result.sto") {
		print "Building $file on the fly\n";
		build_tags_taxonomy($file, 1);
	}

	my $taxonomy_ref = retrieve("$data_root/taxonomies/$file.result.sto")
		or die("Could not load taxonomy: $data_root/taxonomies/$file.result.sto");
	if (defined $taxonomy_ref) {

		$loaded_taxonomies{$tagtype} = 1;
		$stopwords{$tagtype} = $taxonomy_ref->{stopwords};
		$synonyms{$tagtype} = $taxonomy_ref->{synonyms};
		$synonyms_for{$tagtype} = $taxonomy_ref->{synonyms_for};
		$synonyms_for_extended{$tagtype} = $taxonomy_ref->{synonyms_for_extended};
		$just_synonyms{$tagtype} = $taxonomy_ref->{just_synonyms};
		# %just_synonyms was not included in taxonomies previously
		if (not exists $just_synonyms{$tagtype}) {
			$just_synonyms{$tagtype} = {};
		}
		$translations_from{$tagtype} = $taxonomy_ref->{translations_from};
		$translations_to{$tagtype} = $taxonomy_ref->{translations_to};
		$level{$tagtype} = $taxonomy_ref->{level};
		$direct_parents{$tagtype} = $taxonomy_ref->{direct_parents};
		$direct_children{$tagtype} = $taxonomy_ref->{direct_children};
		$all_parents{$tagtype} = $taxonomy_ref->{all_parents};
		$root_entries{$tagtype} = $taxonomy_ref->{root_entries};
		$properties{$tagtype} = $taxonomy_ref->{properties};
	}

	$special_tags{$tagtype} = [];
	if (open(my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/special_$file.txt")) {

		while (<$IN>) {

			my $line = $_;
			chomp($line);
			$line =~ s/\s+$//s;

			next if (($line =~ /^#/) or ($line eq ""));
			my $type = "with";
			if ($line =~ /^-/) {
				$type = "without";
				$line = $';
			}
			my $tag = canonicalize_taxonomy_tag("en", $tagtype, $line);
			my $tagid = get_taxonomyid("en", $tag);

			print "special_tag - line:<$line> - tag:<$tag> - tagid:<$tagid>\n";

			if ($tagid ne "") {
				push @{$special_tags{$tagtype}},
					{
					tagid => $tagid,
					type => $type,
					};
			}
		}

		close($IN);
	}

	return;
}

sub country_to_cc ($country) {

	if ($country eq 'en:world') {
		return 'world';
	}
	elsif (defined $properties{countries}{$country}{"country_code_2:en"}) {
		return lc($properties{countries}{$country}{"country_code_2:en"});
	}

	return;
}

# load all tags images

# print STDERR "Tags.pm - loading tags images\n";
if (opendir my $DH2, "$www_root/images/lang") {
	foreach my $langid (sort readdir($DH2)) {
		next if $langid eq '.';
		next if $langid eq '..';
		next if ((length($langid) ne 2) and not($langid eq 'other'));

		if (-e "$www_root/images/lang/$langid") {
			opendir my $DH, "$www_root/images/lang/$langid" or die "Couldn't open the current directory: $!";
			foreach my $tagtype (sort readdir($DH)) {
				next if $tagtype =~ /\./;
				#print STDERR "Tags: loading tagtype images $langid/$tagtype\n";
				load_tags_images($langid, $tagtype);
			}
			closedir($DH);
		}

	}
	closedir($DH2);
}
else {
	$log->warn("The $lang_dir directory could not be opened.") if $log->is_warn();
	$log->warn("Tags images could not be loaded.") if $log->is_warn();
}

# It would be nice to move this from BEGIN to INIT, as it's slow, but other BEGIN code depends on it.
foreach my $taxonomyid (@ProductOpener::Config::taxonomy_fields) {
	$log->info("loading taxonomy $taxonomyid");
	retrieve_tags_taxonomy($taxonomyid);
}

# Build map of language codes and names

%language_codes = ();
%language_codes_reverse = ();

%Languages = ();    # Hash of language codes, will be used to initialize %Lang::Langs

foreach my $language (keys %{$properties{languages}}) {

	my $lc = lc($properties{languages}{$language}{"language_code_2:en"});

	$language_codes{$lc} = $language;
	$language_codes_reverse{$language} = $lc;

	# %Languages will be passed to Lang::build_lang() to populate language names and
	# to initialize to the English value all missing values for all the languages
	$Languages{$lc} = $translations_to{languages}{$language};
}

# Build map of local country names in official languages to (country, language)

$log->info("Building a map of local country names in official languages to (country, language)") if $log->is_info();

%country_names = ();
%country_codes = ();
%country_codes_reverse = ();
%country_languages = ();

foreach my $country (keys %{$properties{countries}}) {

	my $cc = country_to_cc($country);
	if (not(defined $cc)) {
		next;
	}

	$country_codes{$cc} = $country;
	$country_codes_reverse{$country} = $cc;

	$country_languages{$cc} = ['en'];
	if (defined $properties{countries}{$country}{"language_codes:en"}) {
		$country_languages{$cc} = [];
		foreach my $language (split(",", $properties{countries}{$country}{"language_codes:en"})) {
			$language = get_string_id_for_lang("no_language", $language);
			$language =~ s/-/_/;
			push @{$country_languages{$cc}}, $language;
			my $name = $translations_to{countries}{$country}{$language};
			my $nameid = get_string_id_for_lang("no_language", $name);
			if (not defined $country_names{$nameid}) {
				$country_names{$nameid} = [$cc, $country, $language];
				# print STDERR "country_names{$nameid} = [$cc, $country, $language]\n";
			}
		}
	}
}

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

sub gen_tags_hierarchy_taxonomy ($tag_lc, $tagtype, $tags_list) {

	# $tags_list  ->  comma-separated list of tags, not in a specific order

	if ((not defined $tags_list) or ($tags_list =~ /^\s*$/)) {
		return ();
	}

	if (not defined $all_parents{$tagtype}) {
		$log->warning("all_parents{\$tagtype} not defined", {tagtype => $tagtype}) if $log->is_warning();
		return (split(/\s*,\s*/, $tags_list));
	}

	my %tags = ();

	my $and = $and{$tag_lc} || " and ";

	foreach my $tag2 (split(/\s*,\s*/, $tags_list)) {
		my $tag = $tag2;
		my $l = $tag_lc;
		if ($tag =~ /^(\w\w):/) {
			$l = $1;
			$tag = $';
		}
		next if $tag eq '';
		my $canon_tag = canonicalize_taxonomy_tag($l, $tagtype, $tag);
		my @canon_tags = ($canon_tag);

		# Try to split unrecognized tags (e.g. "known tag and other known tag" -> "known tag, other known tag"

		if (($tag =~ /$and/i) and (not exists_taxonomy_tag($tagtype, $canon_tag))) {

			my $tag1 = $`;
			my $tag2 = $';

			my $canon_tag1 = canonicalize_taxonomy_tag($l, $tagtype, $tag1);
			my $canon_tag2 = canonicalize_taxonomy_tag($l, $tagtype, $tag2);

			if (    (exists_taxonomy_tag($tagtype, $canon_tag1))
				and (exists_taxonomy_tag($tagtype, $canon_tag2)))
			{
				@canon_tags = ($canon_tag1, $canon_tag2);
			}
		}

		foreach my $canon_tag_i (@canon_tags) {

			my $tagid = get_taxonomyid($l, $canon_tag_i);
			next if $tagid eq '';
			if ($tagid =~ /:$/) {
				#print STDERR "taxonomy - empty tag: $tag - l: $l - tagid: $tagid - tag_lc: >$tags_list< \n";
				next;
			}
			$tags{$canon_tag_i} = 1;
			if (defined $all_parents{$tagtype}{$tagid}) {
				foreach my $parentid (@{$all_parents{$tagtype}{$tagid}}) {
					$tags{$parentid} = 1;
				}
			}
		}
	}

	my @sorted_list = sort {
		(((defined $level{$tagtype}{$b}) ? $level{$tagtype}{$b} : 0)
			<=> ((defined $level{$tagtype}{$a}) ? $level{$tagtype}{$a} : 0))
			|| ($a cmp $b)
	} keys %tags;

	return @sorted_list;
}

sub gen_ingredients_tags_hierarchy_taxonomy ($tag_lc, $tags_list) {
	# $tags_list  ->  comma-separated list of tags, not in a specific order

	# for ingredients, we should keep the order
	# question: what do do with parents?
	# put the parents after the ingredient
	# do not put parents that have already been added after another ingredient

	my $tagtype = "ingredients";

	if (not defined $all_parents{$tagtype}) {
		$log->warning("all_parents{\$tagtype} not defined", {tagtype => $tagtype}) if $log->is_warning();
		return (split(/\s*,\s*/, $tags_list));
	}

	my @tags = ();
	my %seen = ();

	foreach my $tag2 (split(/\s*,\s*/, $tags_list)) {
		my $tag = $tag2;
		my $l = $tag_lc;
		if ($tag =~ /^(\w\w):/) {
			$l = $1;
			$tag = $';
		}
		next if $tag eq '';
		$tag = canonicalize_taxonomy_tag($l, $tagtype, $tag);
		my $tagid = get_taxonomyid($l, $tag);
		next if $tagid eq '';
		if ($tagid =~ /:$/) {
			#print STDERR "taxonomy - empty tag: $tag - l: $l - tagid: $tagid - tag_lc: >$tags_list< \n";
			next;
		}

		if (not exists $seen{$tag}) {
			push @tags, $tag;
			$seen{$tag} = 1;
		}

		if (defined $all_parents{$tagtype}{$tagid}) {
			foreach my $parentid (@{$all_parents{$tagtype}{$tagid}}) {
				if (not exists $seen{$parentid}) {
					push @tags, $parentid;
					$seen{$parentid} = 1;
				}
			}
		}
	}

	return @tags;
}

sub get_city_code ($tag) {

	my $city_code = uc(get_string_id_for_lang("no_language", $tag));
	$city_code =~ s/^(EMB|FR)/FREMB/i;
	$city_code =~ s/CE$//i;
	$city_code =~ s/-//g;
	$city_code =~ s/(\d{5})\d+/$1/;
	$city_code =~ s/[A-Z]+$//i;
	# print STDERR "get_city_code : tag: $tag - city_code: $city_code \n";
	return $city_code;
}

# This function is not efficient (calls too many other functions) and should be removed
sub get_tag_css_class ($target_lc, $tagtype, $tag) {

	$target_lc =~ s/_.*//;
	$tag = display_taxonomy_tag($target_lc, $tagtype, $tag);

	my $canon_tagid = canonicalize_taxonomy_tag($target_lc, $tagtype, $tag);

	# Don't treat users as tags.
	if (   ($tagtype eq 'photographers')
		or ($tagtype eq 'editors')
		or ($tagtype eq 'informers')
		or ($tagtype eq 'correctors')
		or ($tagtype eq 'checkers'))
	{
		return "";
	}

	my $css_class = "tag ";
	if (not exists_taxonomy_tag($tagtype, $canon_tagid)) {
		$css_class .= "user_defined";
	}
	else {
		$css_class .= "well_known";
	}

	return $css_class;
}

sub display_tag_name ($tagtype, $tag) {

	# do not display UUIDs yuka-UnY4RExZOGpoTVVWb01aajN4eUY2UHRJNDY2cWZFVzhCL1U0SVE9PQ
	# but just yuka - user
	if ($tagtype =~ /^(users|correctors|editors|informers|correctors|photographers|checkers)$/) {
		$tag =~ s/\.(.*)/ - user/;
	}
	return $tag;
}

sub display_tag_link ($tagtype, $tag) {

	$tag = canonicalize_tag2($tagtype, $tag);

	my $path = $tag_type_singular{$tagtype}{$lc};

	my $tag_lc = $lc;
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}

	if ($tagtype =~ /^(users|correctors|editors|informers|correctors|photographers|checkers|team)$/) {
		$tag_lc = "no_language";
	}

	my $tagid = get_string_id_for_lang($tag_lc, $tag);
	my $tagurl = get_urlid($tagid, 0, $tag_lc);

	my $display_tag = display_tag_name($tagtype, $tag);

	my $html;
	if ((defined $tag_lc) and ($tag_lc ne $lc)) {
		$html = "<a href=\"/$path/$tagurl\" lang=\"$tag_lc\">$display_tag</a>";
	}
	else {
		$html = "<a href=\"/$path/$tagurl\">$display_tag</a>";
	}

	if ($tagtype eq 'emb_codes') {
		my $city_code = get_city_code($tagid);

		init_emb_codes() unless %emb_codes_cities;
		if (defined $emb_codes_cities{$city_code}) {
			$html .= " - " . display_tag_link('cities', $emb_codes_cities{$city_code});
		}
	}

	return $html;
}

sub canonicalize_taxonomy_tag_link ($target_lc, $tagtype, $tag) {

	$target_lc =~ s/_.*//;
	$tag = display_taxonomy_tag($target_lc, $tagtype, $tag);
	my $tagurl = get_taxonomyurl($target_lc, $tag);

	my $path = $tag_type_singular{$tagtype}{$target_lc};
	$log->info("tax tag 1 /$path/$tagurl") if $log->is_info();
	return "/$path/$tagurl";
}

# The display_taxonomy_tag_link function makes many calls to other functions, in particular it calls twice display_taxonomy_tag_link
# Will be replaced by display_taxonomy_tag_link_new function

sub display_taxonomy_tag_link ($target_lc, $tagtype, $tag) {

	$target_lc =~ s/_.*//;
	$tag = display_taxonomy_tag($target_lc, $tagtype, $tag);
	my $tagid = get_taxonomyid($target_lc, $tag);
	my $tagurl = get_taxonomyurl($target_lc, $tagid);

	my $tag_lc;
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}

	my $path = $tag_type_singular{$tagtype}{$target_lc} // '';

	my $css_class = get_tag_css_class($target_lc, $tagtype, $tag);

	my $html;
	if ((defined $tag_lc) and ($tag_lc ne $target_lc)) {
		$html = "<a href=\"/$path/$tagurl\" class=\"$css_class\" lang=\"$tag_lc\">$tag_lc:$tag</a>";
	}
	else {
		$html = "<a href=\"/$path/$tagurl\" class=\"$css_class\">$tag</a>";
	}

	if ($tagtype eq 'emb_codes') {
		my $city_code = get_city_code($tagid);

		init_emb_codes() unless %emb_codes_cities;
		if (defined $emb_codes_cities{$city_code}) {
			$html .= " - " . display_tag_link('cities', $emb_codes_cities{$city_code});
		}
	}

	return $html;
}

# get_taxonomy_tag_and_link_for_lang computes the display text and link
# in a target language for a canonical tagid
# It returns a hash ref with:
# - display : text of the link in the target language, or English
# - display_lc : language code of the language returned in display
# - known : 0 or 1, indicates if the input tagid exists in the taxonomy
# - tagurl : escaped link to the tag, without the tag type path component

sub get_taxonomy_tag_and_link_for_lang ($target_lc, $tagtype, $tagid) {

	my $tag_lc;

	if ($tagid =~ /^(\w\w):/) {
		$tag_lc = $1;
	}

	my $display = '';
	my $display_lc = "en";    # Default to English
	my $exists_in_taxonomy = 0;

	if (    (defined $translations_to{$tagtype})
		and (defined $translations_to{$tagtype}{$tagid})
		and (defined $translations_to{$tagtype}{$tagid}{$target_lc}))
	{
		# we have a translation for the target language
		# print STDERR "display_taxonomy_tag - translation for the target language - translations_to{$tagtype}{$tagid}{$target_lc} : $translations_to{$tagtype}{$tagid}{$target_lc}\n";
		$display = $translations_to{$tagtype}{$tagid}{$target_lc};
		$display_lc = $target_lc;
		$exists_in_taxonomy = 1;
	}
	else {
		# use tag language
		if (    (defined $translations_to{$tagtype})
			and (defined $translations_to{$tagtype}{$tagid})
			and (defined $tag_lc)
			and (defined $translations_to{$tagtype}{$tagid}{$tag_lc}))
		{
			# we have a translation for the tag language
			# print STDERR "display_taxonomy_tag - translation for the tag language - translations_to{$tagtype}{$tagid}{$tag_lc} : $translations_to{$tagtype}{$tagid}{$tag_lc}\n";

			$display = "$tag_lc:" . $translations_to{$tagtype}{$tagid}{$tag_lc};

			$exists_in_taxonomy = 1;
		}
		else {
			$display = $tagid;
			if (defined $tag_lc) {
				$display_lc = $tag_lc;
			}

			if ($target_lc eq $tag_lc) {
				$display =~ s/^(\w\w)://;
			}
			# print STDERR "display_taxonomy_tag - no translation available for $tagtype $tagid in target language $lc or tag language $tag_lc - result: $display\n";
		}
	}

	# for additives, add the first synonym
	if ($tagtype =~ /^additives(|_prev|_next|_debug)$/) {
		$tagid =~ s/.*://;
		if (    (defined $synonyms_for{$tagtype}{$target_lc})
			and (defined $synonyms_for{$tagtype}{$target_lc}{$tagid})
			and (defined $synonyms_for{$tagtype}{$target_lc}{$tagid}[1]))
		{
			$display .= " - " . ucfirst($synonyms_for{$tagtype}{$target_lc}{$tagid}[1]);
		}
	}

	my $display_lc_prefix = "";
	my $display_tag = $display;

	if ($display =~ /^((\w\w):)/) {
		$display_lc_prefix = $1;
		$display_lc = $2;
		$display_tag = $';
	}

	my $tagurlid = get_string_id_for_lang($display_lc, $display_tag);
	if ($tagurlid =~ /[^a-zA-Z0-9-]/) {
		$tagurlid = URI::Escape::XS::encodeURIComponent($display_tag);
	}

	my $tagurl = $display_lc_prefix . $tagurlid;

	my $css_class = "";
	my $html_lang = "";

	# Don't treat users as tags.
	if (
		not(   ($tagtype eq 'photographers')
			or ($tagtype eq 'editors')
			or ($tagtype eq 'informers')
			or ($tagtype eq 'correctors')
			or ($tagtype eq 'checkers'))
		)
	{
		$css_class = "tag ";

		if ($exists_in_taxonomy) {
			$css_class .= "known ";
		}
		else {
			$css_class .= "user_defined ";
		}

		if ($display_lc ne $lc) {
			$html_lang = ' lang="' . $display_lc . '"';
		}

	}

	my $tag_ref = {
		tagid => $tagid,
		display => $display,
		display_lc => $display_lc,
		tagurl => $tagurl,
		known => $exists_in_taxonomy,
		css_class => $css_class,
		html_lang => $html_lang,
	};

	return $tag_ref;
}

sub display_tags_list ($tagtype, $tags_list) {

	my $html = '';
	my $images = '';
	if (not defined $tags_list) {
		return '';
	}
	foreach my $tag (split(/,/, $tags_list)) {
		$html .= display_tag_link($tagtype, $tag) . ", ";

		my $tagid = get_string_id_for_lang($lc, $tag);
		if (defined $tags_images{$lc}{$tagtype}{$tagid}) {
			my $img = $tags_images{$lc}{$tagtype}{$tagid};
			my $size = '';
			if ($img =~ /\.(\d+)x(\d+)/) {
				$size = " width=\"$1\" height=\"$2\"";
			}
			$images .= <<HTML
<img src="/images/lang/$lc/$tagtype/$img"$size/ style="display:inline">
HTML
				;
		}
	}
	$html =~ s/, $//;
	if ($images ne '') {
		$html .= "<br />$images";
	}

	return $html;
}

sub display_tag_and_parents ($tagtype, $tagid) {

	my $html = '';

	if (    (defined $tags_all_parents{$lc})
		and (defined $tags_all_parents{$lc}{$tagtype})
		and (defined $tags_all_parents{$lc}{$tagtype}{$tagid}))
	{
		foreach my $parentid (@{$tags_all_parents{$lc}{$tagtype}{$tagid}}) {
			$html = display_tag_link($tagtype, $parentid) . ', ' . $html;
		}
	}

	$html =~ s/, $//;

	return $html;
}

sub display_tag_and_parents_taxonomy ($tagtype, $tagid) {

	my $target_lc = $lc;
	my $html = '';

	if ((defined $all_parents{$tagtype}) and (defined $all_parents{$tagtype}{$tagid})) {
		foreach my $parentid (@{$all_parents{$tagtype}{$tagid}}) {
			$html = display_taxonomy_tag_link($target_lc, $tagtype, $parentid) . ', ' . $html;
		}
	}

	$html =~ s/, $//;

	return $html;
}

sub display_parents_and_children ($target_lc, $tagtype, $tagid) {

	$target_lc =~ s/_.*//;
	my $html = '';

	if (defined $taxonomy_fields{$tagtype}) {

		# print STDERR "family - $target_lc - tagtype: $tagtype - tagid: $tagid - all_parents{$tagtype}{$tagid}: $all_parents{$tagtype}{$tagid} - direct_children{$tagtype}{$tagid}: $direct_children{$tagtype}{$tagid}\n";

		if ((defined $all_parents{$tagtype}) and (defined $all_parents{$tagtype}{$tagid})) {
			$html .= "<p>" . lang("tag_belongs_to") . "</p>\n";
			$html .= "<p>" . display_tag_and_parents_taxonomy($tagtype, $tagid) . "</p>\n";
		}

		if ((defined $direct_children{$tagtype}) and (defined $direct_children{$tagtype}{$tagid})) {
			$html .= "<p>" . lang("tag_contains") . "</p><ul>\n";
			foreach my $childid (sort keys %{$direct_children{$tagtype}{$tagid}}) {
				$html .= "<li>" . display_taxonomy_tag_link($target_lc, $tagtype, $childid) . "</li>\n";
			}
			$html .= "</ul>\n";
		}
	}
	else {

		if (    (defined $tags_all_parents{$lc})
			and (defined $tags_all_parents{$lc}{$tagtype})
			and (defined $tags_all_parents{$lc}{$tagtype}{$tagid}))
		{
			$html .= "<p>" . lang("tag_belongs_to") . "</p>\n";
			$html .= "<p>" . display_tag_and_parents($tagtype, $tagid) . "</p>\n";
		}

		if (    (defined $tags_direct_children{$lc})
			and (defined $tags_direct_children{$lc}{$tagtype})
			and (defined $tags_direct_children{$lc}{$tagtype}{$tagid}))
		{
			$html .= "<p>" . lang("tag_contains") . "</p><ul>\n";
			foreach my $childid (sort keys %{$tags_direct_children{$lc}{$tagtype}{$tagid}}) {
				$html .= "<li>" . display_tag_link($tagtype, $childid) . "</li>\n";
			}
			$html .= "</ul>\n";
		}

	}

	return $html;
}

sub display_tags_hierarchy ($tagtype, $tags_ref) {

	my $html = '';
	my $images = '';
	if (defined $tags_ref) {
		foreach my $tag (@{$tags_ref}) {
			$html .= display_tag_link($tagtype, $tag) . ", ";

			#			print STDERR "abbio - lc: $lc - tagtype: $tagtype - tag: $tag\n";

			my $tagid = get_string_id_for_lang($lc, $tag);
			if (defined $tags_images{$lc}{$tagtype}{$tagid}) {
				my $img = $tags_images{$lc}{$tagtype}{$tagid};
				my $size = '';
				if ($img =~ /\.(\d+)x(\d+)/) {
					$size = " width=\"$1\" height=\"$2\"";
				}
				# print STDERR "abbio - lc: $lc - tagtype: $tagtype - tag: $tag - img: $img\n";

				$images .= <<HTML
<img src="/images/lang/$lc/$tagtype/$img"$size/ style="display:inline">
HTML
					;
			}
		}
		$html =~ s/, $//;
		if ($images ne '') {
			$html .= "<br />$images";
		}
	}
	return $html;
}

=head2 get_tag_image ( $target_lc, $tagtype, $canon_tagid )

If an image is associated to a tag, return its relative url, otherwise return undef.

=head3 Arguments

=head4 $target_lc

The desired language for the image. If an image is not available in the target language,
it can be returned in English or in the tag language.

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $canon_tagid

=cut

sub get_tag_image ($target_lc, $tagtype, $canon_tagid) {

	# Build an ordered list of languages that the image can be in
	my @languages = ($target_lc, "xx", "en");
	if ($canon_tagid =~ /^(\w\w):/) {
		push @languages, $1;
	}

	# Record which language we tested, as the list can contain the same language multiple times
	my %seen_lc = ();

	foreach my $l (@languages) {
		next if defined $seen_lc{$l};
		$seen_lc{$l} = 1;
		my $translation = display_taxonomy_tag($l, $tagtype, $canon_tagid);
		# Support both unaccented and possibly deaccented image file name
		foreach
			my $imgid (get_string_id_for_lang("no_language", $translation), get_string_id_for_lang($l, $translation))
		{
			if (defined $tags_images{$l}{$tagtype}{$imgid}) {
				return "/images/lang/$l/$tagtype/" . $tags_images{$l}{$tagtype}{$imgid};
			}
		}
	}

	return;
}

=head2 display_tags_hierarchy_taxonomy ( $target_lc, $tagtype, $tags_ref )

Generates a comma separated list of tags in the target language, with links and images.

=head3 Arguments

=head4 $target_lc

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $tags_ref

Reference to a list of tags. (usually the *_tags field corresponding to the tag type)

=cut

sub display_tags_hierarchy_taxonomy ($target_lc, $tagtype, $tags_ref) {

	# $target_lc =~ s/_.*//;
	my $tag_lc = undef;

	my $html = '';
	my $images = '';
	if (defined $tags_ref) {
		foreach my $tag (@{$tags_ref}) {
			$html .= display_taxonomy_tag_link($target_lc, $tagtype, $tag) . ", ";

			my $canon_tagid = canonicalize_taxonomy_tag($target_lc, $tagtype, $tag);
			my $img = get_tag_image($target_lc, $tagtype, $canon_tagid);

			if ($img) {
				my $size = '';
				if ($img =~ /\.(\d+)x(\d+)/) {
					$size = " width=\"$1\" height=\"$2\"";
				}
				$images .= <<HTML
<img src="$img"$size/ style="display:inline">
HTML
					;
			}
		}
		$html =~ s/, $//;
		if ($images ne '') {
			$html .= "<br />$images";
		}
	}
	return $html;
}

=head2 list_taxonomy_tags_in_language ( $target_lc, $tagtype, $tags_ref )

Generates a comma separated (with a space after the comma) list of tags in the target language.

=head3 Arguments

=head4 $target_lc

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $tags_ref

Reference to a list of tags. (usually the *_tags field corresponding to the tag type)

The tags are expected to be in their canonical format.

=cut

sub list_taxonomy_tags_in_language ($target_lc, $tagtype, $tags_ref) {

	# $target_lc =~ s/_.*//;

	if (defined $tags_ref) {
		return join(', ', map({display_taxonomy_tag($target_lc, $tagtype, $_)} @{$tags_ref}));
	}
	else {
		return "";
	}
}

sub canonicalize_tag2 ($tagtype, $tag) {
	#$tag = lc($tag);
	my $canon_tag = $tag;
	$canon_tag =~ s/^ //g;
	$canon_tag =~ s/ $//g;

	my $tagid = get_string_id_for_lang($lc, $tag);

	if ($tagtype =~ /^(users|correctors|editors|informers|correctors|photographers|checkers)$/) {
		return $tagid;
	}

	if (    (defined $canon_tags{$lc})
		and (defined $canon_tags{$lc}{$tagtype})
		and (defined $canon_tags{$lc}{$tagtype}{$tagid}))
	{
		$canon_tag = $canon_tags{$lc}{$tagtype}{$tagid};
	}
	elsif ($canon_tag eq $tagid) {
		$canon_tag =~ s/-/ /g;
		$canon_tag = ucfirst($tag);
	}

	#$canon_tag =~ s/(-|\'|_|\n)/ /g;	# - and ' might be added back

	$tag = $canon_tag;

	if (($tagtype ne "additives_debug") and ($tagtype =~ /^additives(|_prev|_next|_debug)$/)) {

		# e322-lecithines -> e322
		my $tagid = get_string_id_for_lang($lc, $tag);
		$tagid =~ s/-.*//;
		my $other_name = $ingredients_classes{$tagtype}{$tagid}{other_names};
		$other_name =~ s/,.*//;
		if ($other_name ne '') {
			$other_name = " - " . $other_name;
		}
		$tag = ucfirst($tagid) . $other_name;
	}

	elsif (($tagtype eq 'ingredients_from_palm_oil') or ($tagtype eq 'ingredients_that_may_be_from_palm_oil')) {
		my $tagid = get_string_id_for_lang($lc, $tag);
		$tag = $ingredients_classes{$tagtype}{$tagid}{name};
	}

	elsif ($tagtype eq 'emb_codes') {

		$tag = uc($tag);

		$tag = normalize_packager_codes($tag);
		$tag = localize_packager_code($tag);
	}

	elsif ($tagtype eq 'cities') {
		if (defined $cities{$tagid}) {
			$tag = $cities{$tagid};
		}
	}

	return $tag;

}

sub get_taxonomyid ($tag_lc, $tagid) {

	# $tag_lc  ->  Default tag language if tagid is not prefixed by a language code
	if ($tagid =~ /^(\w\w):/) {
		return lc($1) . ':' . get_string_id_for_lang(lc($1), $');
	}
	else {
		return get_string_id_for_lang($tag_lc, $tagid);
	}
}

sub get_taxonomyurl ($tag_lc, $tagid) {

	# $tag_lc  ->  Default tag language if tagid is not prefixed by a language code
	if ($tagid =~ /^(\w\w):/) {
		return lc($1) . ':' . get_url_id_for_lang(lc($1), $');
	}
	else {
		return get_url_id_for_lang($tag_lc, $tagid);
	}
}

=head2 canonicalize_taxonomy_tag_or_die ($tag_lc, $tagtype, $tag)

Canonicalize a string to check if matches an entry in a taxonomy, and die otherwise.

This function is used during initialization, to check that some initialization data has matching entries in taxonomies.

=head3 Arguments

=head4 $tag_lc

The language of the string.

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $tag

The string that we want to match to a tag.

=head4 $exists_in_taxonomy_ref

A reference to a variable that will be assigned 1 if we found a matching taxonomy entry, or 0 otherwise.

=head3 Return value

If the string could be matched to an existing taxonomy entry, the canonical id for the entry is returned.

Otherwise, the function dies.

=cut

sub canonicalize_taxonomy_tag_or_die ($tag_lc, $tagtype, $tag) {

	my $exists_in_taxonomy;
	my $tagid = canonicalize_taxonomy_tag($tag_lc, $tagtype, $tag, \$exists_in_taxonomy);
	if (not $exists_in_taxonomy) {
		die("$tag ($tag_lc) could not be matched to an entry in the $tagtype taxonomy");
	}
	return $tagid;
}

=head2 canonicalize_taxonomy_tag ($tag_lc, $tagtype, $tag, $exists_in_taxonomy_ref = undef)

Canonicalize a string to check if matches an entry in a taxonomy

=head3 Arguments

=head4 $tag_lc

The language of the string.

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $tag

The string that we want to match to a tag.

=head4 $exists_in_taxonomy_ref

A reference to a variable that will be assigned 1 if we found a matching taxonomy entry, or 0 otherwise.

=head3 Return value

If the string could be matched to an existing taxonomy entry, the canonical id for the entry is returned.

Otherwise, we return the string prefixed with the language code (e.g. en:An unknown entry)

=cut

sub canonicalize_taxonomy_tag ($tag_lc, $tagtype, $tag, $exists_in_taxonomy_ref = undef) {

	if (not defined $tag) {
		if (defined $exists_in_taxonomy_ref) {
			$$exists_in_taxonomy_ref = 0;
		}
		return "";
	}

	#$tag = lc($tag);
	$tag =~ s/^ //g;
	$tag =~ s/ $//g;

	my $linked_data_tag = canonicalize_taxonomy_tag_linkeddata($tagtype, $tag);
	if ($linked_data_tag) {
		return $linked_data_tag;
	}

	my $weblink_tag = canonicalize_taxonomy_tag_weblink($tagtype, $tag);
	if ($weblink_tag) {
		return $weblink_tag;
	}

	# If we are passed a tag string that starts with a language code (e.g. fr:café)
	# override the input language
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}

	$tag = normalize_percentages($tag, $tag_lc);
	my $tagid = get_string_id_for_lang($tag_lc, $tag);

	if ($tagtype =~ /^additives/) {
		# convert the E-number + name into just E-number (we get those in urls like /additives/e330-citric-acid)
		# check E + 1 digit in order to not convert Erythorbate-de-sodium to Erythorbate
		$tagid =~ s/^e(\d.*?)-(.*)$/e$1/i;
	}

	if (($tagtype eq "ingredients") or ($tagtype eq "packaging") or ($tagtype =~ /^additives/)) {
		# convert E-number + name to E-number only if the number match the name
		my $additive_tagid;
		my $name;
		if ($tagid =~ /^(e\d.*?)-(.*)$/i) {
			$additive_tagid = $1;
			$name = $2;
		}
		elsif ($tagid =~ /^(.*)-(e\d.*?)$/i) {
			$name = $1;
			$additive_tagid = $2;
		}
		if (defined $name) {
			my $name_id = canonicalize_taxonomy_tag($tag_lc, "additives", $name, $exists_in_taxonomy_ref);
			# caramelo e150c -> name_id is e150
			if (("en:" . $additive_tagid) =~ /^$name_id/) {
				return "en:" . $additive_tagid;
			}
		}
	}

	my $found = 0;

	if (    (defined $synonyms{$tagtype})
		and (defined $synonyms{$tagtype}{$tag_lc})
		and (defined $synonyms{$tagtype}{$tag_lc}{$tagid}))
	{
		$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid};
		$found = 1;
	}
	else {
		# try removing stopwords and plurals
		my $tagid2 = remove_stopwords($tagtype, $tag_lc, $tagid);
		$tagid2 = remove_plurals($tag_lc, $tagid2);

		# try to add / remove hyphens (e.g. antioxydant / anti-oxydant)
		my $tagid3 = $tagid2;
		my $tagid4 = $tagid2;
		$tagid3 =~ s/(anti)(-| )/$1/;
		$tagid4 =~ s/(anti)([a-z])/$1-$2/;

		if (    (defined $synonyms{$tagtype})
			and (defined $synonyms{$tagtype}{$tag_lc})
			and (defined $synonyms{$tagtype}{$tag_lc}{$tagid2}))
		{
			$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid2};
			$found = 1;
		}
		elsif ( (defined $synonyms{$tagtype})
			and (defined $synonyms{$tagtype}{$tag_lc})
			and (defined $synonyms{$tagtype}{$tag_lc}{$tagid3}))
		{
			$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid3};
			$found = 1;
		}
		elsif ( (defined $synonyms{$tagtype})
			and (defined $synonyms{$tagtype}{$tag_lc})
			and (defined $synonyms{$tagtype}{$tag_lc}{$tagid4}))
		{
			$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid4};
			$found = 1;
		}
		else {

			# try matching in other languages (by default, in the "language-less" language xx, and in English)
			# note that there may be conflicts where a non-English word matches an English entry,
			# so this should be disabled in taxonomies with many small entries such as ingredients
			my @test_languages = ("xx", "en");

			if (defined $options{product_type}) {

				if ($options{product_type} eq "food") {

					# Latin animal species (e.g. for fish)
					if ($tagtype eq "ingredients") {
						@test_languages = ("xx", "la");
					}
				}
				elsif ($options{product_type} eq "beauty") {

					# Beauty products ingredients are often in English or Latin
					if ($tagtype eq "ingredients") {
						@test_languages = ("xx", "en", "la");
					}
				}
			}

			foreach my $test_lc (@test_languages) {

				next if ($test_lc eq $tag_lc);

				# get a tagid with the unaccenting rules for the language we are trying to match
				my $test_lc_tagid = get_string_id_for_lang($test_lc, $tag);

				if (    (defined $synonyms{$tagtype})
					and (defined $synonyms{$tagtype}{$test_lc})
					and (defined $synonyms{$tagtype}{$test_lc}{$test_lc_tagid}))
				{
					$tagid = $synonyms{$tagtype}{$test_lc}{$test_lc_tagid};
					$tag_lc = $test_lc;
					$found = 1;
				}
				else {

					# try removing stopwords and plurals
					my $tagid2 = remove_stopwords($tagtype, $test_lc, $test_lc_tagid);
					$tagid2 = remove_plurals($test_lc, $tagid2);
					if (    (defined $synonyms{$tagtype})
						and (defined $synonyms{$tagtype}{$test_lc})
						and (defined $synonyms{$tagtype}{$test_lc}{$tagid2}))
					{
						$tagid = $synonyms{$tagtype}{$test_lc}{$tagid2};
						$tag_lc = $test_lc;
						$found = 1;
						last;
					}
				}
			}
		}
	}

	# If we have not found the tag in the taxonomy, try to see if it is of the form
	# "Parent / Children" or "Synonym 1 / Synonym 2", "Synonym 1 (Synonym 2)"
	if (not $found) {
		if ($tag =~ /\/|\(/) {    # Match / or the ( opening parenthesis
			my $tag1 = $`;
			# we might get closing parenthesis, but canonicalize will get rid of it
			my $tag2 = $';
			my $exists_tag1;
			my $exists_tag2;
			my $tagid1 = canonicalize_taxonomy_tag($tag_lc, $tagtype, $tag1, \$exists_tag1);
			my $tagid2 = canonicalize_taxonomy_tag($tag_lc, $tagtype, $tag2, \$exists_tag2);

			$log->debug(
				"Checking for multiple tags separated by a slash",
				{
					tagtype => $tagtype,
					tag => $tag,
					tag1 => $tag1,
					tag2 => $tag2,
					tagid1 => $tagid1,
					tagid2 => $tagid2,
					exists_tag1 => $exists_tag1,
					exists_tag2 => $exists_tag2
				}
			) if $log->is_debug();

			if ($exists_tag1 and $exists_tag2) {
				# "Synonym 1 / Synonym 2"
				if ($tagid1 eq $tagid2) {
					$tagid = $tagid1;
				}
				# "Parent / Child"
				elsif (is_a($tagtype, $tagid2, $tagid1)) {
					$tagid = $tagid2;
				}
				# "Child / Parent"
				elsif (is_a($tagtype, $tagid1, $tagid2)) {
					$tagid = $tagid1;
				}
			}
		}
	}

	# $tagid may already be a canon tagid with a language prefix, in which case do not add the language prefix
	if ($tagid !~ /^\w\w:/) {
		$tagid = $tag_lc . ':' . $tagid;
	}

	my $exists_in_taxonomy = 0;

	if (    (defined $translations_from{$tagtype})
		and (defined $translations_from{$tagtype}{$tagid})
		and not((exists $just_synonyms{$tagtype}) and (exists $just_synonyms{$tagtype}{$tagid})))
	{
		$tagid = $translations_from{$tagtype}{$tagid};
		$exists_in_taxonomy = 1;
	}
	elsif (defined $tag) {
		# no translation available, tag is not in known taxonomy
		$tagid = $tag_lc . ':' . $tag;
	}
	else {
		# If $tag is not defined, we don't want to return "$tag_lc:", but we also cannot return undef, because consumers assume an assigned value.
		$tagid = "";
	}

	if (defined $exists_in_taxonomy_ref) {
		$$exists_in_taxonomy_ref = $exists_in_taxonomy;
	}

	return $tagid;
}

sub canonicalize_taxonomy_tag_linkeddata ($tagtype, $tag) {

	if (   (not defined $tagtype)
		or (not defined $tag)
		or (not($tag =~ /^(\w+:\w\w):(.+)/))
		or (not defined $properties{$tagtype}))
	{
		return;
	}

	# Test for linked data, ie. wikidata:en:Q1234
	my $property_key = $1;
	my $property_value = $2;
	my $matched_tagid;
	foreach my $canon_tagid (keys %{$properties{$tagtype}}) {
		if (    (defined $properties{$tagtype}{$canon_tagid}{$property_key})
			and ($properties{$tagtype}{$canon_tagid}{$property_key} eq $property_value))
		{
			if (defined $matched_tagid) {
				# Bail out on multiple matches for a single tag.
				undef $matched_tagid;
				last;
			}

			$matched_tagid = $canon_tagid;
		}
	}

	return $matched_tagid;
}

sub canonicalize_taxonomy_tag_weblink ($tagtype, $tag) {

	if (   (not defined $tagtype)
		or (not defined $tag)
		or (not($tag =~ /^https?:\/\/.+/)))
	{
		return;
	}

	# Test for linked data URLs, ie. https://www.wikidata.org/wiki/Q1234
	my $matched_tagid;
	foreach my $property_key (keys %weblink_templates) {
		next if not defined $weblink_templates{$property_key}{parse};
		my $property_value = $weblink_templates{$property_key}{parse}->($tag);
		if (defined $property_value) {
			foreach my $canon_tagid (keys %{$properties{$tagtype}}) {
				if (    (defined $properties{$tagtype}{$canon_tagid}{$property_key})
					and ($properties{$tagtype}{$canon_tagid}{$property_key} eq $property_value))
				{
					if (defined $matched_tagid) {
						# Bail out on multiple matches for a single tag.
						undef $matched_tagid;
						last;
					}

					$matched_tagid = $canon_tagid;
				}
			}
		}
	}

	return $matched_tagid;
}

sub generate_spellcheck_candidates ($tagid, $candidates_ref) {

	# https://norvig.com/spell-correct.html
	# "All edits that are one edit away from `word`."
	# letters    = 'abcdefghijklmnopqrstuvwxyz'
	# splits     = [(word[:i], word[i:])    for i in range(len(word) + 1)]
	# deletes    = [L + R[1:]               for L, R in splits if R]
	# transposes = [L + R[1] + R[0] + R[2:] for L, R in splits if len(R)>1]
	# replaces   = [L + c + R[1:]           for L, R in splits if R for c in letters]
	# inserts    = [L + c + R               for L, R in splits for c in letters]

	my $l = length($tagid);

	for (my $i = 0; $i <= $l; $i++) {

		my $left = substr($tagid, 0, $i);
		my $right = substr($tagid, $i);

		# delete
		if ($i < $l) {
			push @{$candidates_ref}, $left . substr($right, 1);
		}

		foreach my $c ("a" .. "z") {

			# insert
			push @{$candidates_ref}, $left . $c . $right;

			# replace
			if ($i < $l) {
				push @{$candidates_ref}, $left . $c . substr($right, 1);
			}
		}

		if (($i > 0) and ($i < $l)) {
			push @{$candidates_ref}, $left . "-" . $right;
			if ($i < ($l - 1)) {
				push @{$candidates_ref}, $left . "-" . substr($right, 1);
			}
		}
	}

	return;
}

sub spellcheck_taxonomy_tag ($tag_lc, $tagtype, $tag) {
	#$tag = lc($tag);
	$tag =~ s/^ //g;
	$tag =~ s/ $//g;

	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}

	$tag = normalize_percentages($tag, $tag_lc);

	my @candidates = ($tag);

	if (length($tag) > 6) {
		generate_spellcheck_candidates($tag, \@candidates);
	}

	my $result;
	my $resultid;
	my $canon_resultid;
	my $correction;
	my $last_candidate;

	if ((exists $synonyms{$tagtype}) and (exists $synonyms{$tagtype}{$tag_lc})) {

		foreach my $candidate (@candidates) {

			$last_candidate = $candidate;
			my $tagid = get_string_id_for_lang($tag_lc, $candidate);

			if (exists $synonyms{$tagtype}{$tag_lc}{$tagid}) {
				$result = $synonyms{$tagtype}{$tag_lc}{$tagid};
				last;
			}
			else {
				# try removing stopwords and plurals
				# my $tagid2 = remove_stopwords($tagtype,$tag_lc,$tagid);
				# $tagid2 = remove_plurals($tag_lc,$tagid2);
				my $tagid2 = remove_plurals($tag_lc, $tagid);

				# try to add / remove hyphens (e.g. antioxydant / anti-oxydant)
				my $tagid3 = $tagid2;
				my $tagid4 = $tagid2;
				$tagid3 =~ s/(anti)(-| )/$1/;
				$tagid4 =~ s/(anti)([a-z])/$1-$2/;

				if (exists $synonyms{$tagtype}{$tag_lc}{$tagid2}) {
					$result = $synonyms{$tagtype}{$tag_lc}{$tagid2};
					last;
				}
				elsif (exists $synonyms{$tagtype}{$tag_lc}{$tagid3}) {
					$result = $synonyms{$tagtype}{$tag_lc}{$tagid3};
					last;
				}
				elsif (exists $synonyms{$tagtype}{$tag_lc}{$tagid4}) {
					$result = $synonyms{$tagtype}{$tag_lc}{$tagid4};
					last;
				}
			}
		}
	}

	if (defined $result) {

		$correction = $last_candidate;
		my $tagid = $tag_lc . ':' . $result;
		$resultid = $tagid;

		if ((defined $translations_from{$tagtype}) and (defined $translations_from{$tagtype}{$tagid})) {
			$canon_resultid = $translations_from{$tagtype}{$tagid};
		}
	}

	return ($canon_resultid, $resultid, $correction);

}

=head2 get_taxonomy_tag_synonyms ( $tagtype )

Return all entries in a taxonomy.

=head3 Arguments

=head4 $tagtype

=head4 $canon_tagid

=head3 Return values

- undef is the taxonomy does not exist or is not loaded
- or a list of all tags

=cut

sub get_all_taxonomy_entries ($tagtype) {

	if (defined $translations_to{$tagtype}) {

		my @list = ();
		foreach my $tagid (keys %{$translations_to{$tagtype}}) {
			# Skip entries that are just synonyms
			next if (defined $just_synonyms{$tagtype}{$tagid});
			push @list, $tagid;
		}
		return @list;
	}
	else {
		return;
	}
}

=head2 get_taxonomy_tag_synonyms ( $target_lc, $tagtype, $canon_tagid )

Return all synonyms (including extended synonyms) in a specific language for a taxonomy entry.

=head3 Arguments

=head4 $target_lc

=head4 $tagtype

=head4 $canon_tagid

=head3 Return values

- undef is the taxonomy does not exist or is not loaded, or if the tag does not exist
- or a list of all synonyms

=cut

sub get_taxonomy_tag_synonyms ($target_lc, $tagtype, $tagid) {

	if ((defined $translations_to{$tagtype}) and (defined $translations_to{$tagtype}{$tagid})) {

		my $target_lc_tagid = get_string_id_for_lang($target_lc, $translations_to{$tagtype}{$tagid}{$target_lc});

		if (defined $synonyms_for_extended{$tagtype}{$target_lc}{$target_lc_tagid}) {
			return (@{$synonyms_for{$tagtype}{$target_lc}{$target_lc_tagid}},
				sort keys %{$synonyms_for_extended{$tagtype}{$target_lc}{$target_lc_tagid}});
		}
		elsif (defined $synonyms_for{$tagtype}{$target_lc}{$target_lc_tagid}) {
			return @{$synonyms_for{$tagtype}{$target_lc}{$target_lc_tagid}};
		}
		else {
			return;
		}
	}
	else {
		return;
	}
}

sub exists_taxonomy_tag ($tagtype, $tagid) {

	return (    (exists $translations_from{$tagtype})
			and (exists $translations_from{$tagtype}{$tagid})
			and not((exists $just_synonyms{$tagtype}) and (exists $just_synonyms{$tagtype}{$tagid})));
}

=head2 cached_display_taxonomy_tag ( $target_lc, $tagtype, $canon_tagid )

Return the name of a tag for displaying it to the user.
This function builds a cache of the resulting names, in order to reduce execution time.
The cache is an ever-growing hash of input parameters.
This function should only be used in batch scripts, and not in code called from the Apache mod_perl processes.

=head3 Arguments

=head4 $target_lc - target language code

=head4 $tagtype

=head4 $canon_tagid

=head3 Return values

The tag translation if it exists in target language,
otherwise, the tag id.

=cut

my %cached_display_taxonomy_tags = ();
$cached_display_taxonomy_tag_calls = 0;
$cached_display_taxonomy_tag_misses = 0;

sub cached_display_taxonomy_tag ($target_lc, $tagtype, $tag) {
	$cached_display_taxonomy_tag_calls++;
	my $key = $target_lc . ':' . $tagtype . ':' . $tag;
	return $cached_display_taxonomy_tags{$key} if exists $cached_display_taxonomy_tags{$key};

	$cached_display_taxonomy_tag_misses++;
	my $value = display_taxonomy_tag($target_lc, $tagtype, $tag);
	$cached_display_taxonomy_tags{$key} = $value;
	return $value;
}

=head2 display_taxonomy_tag ( $target_lc, $tagtype, $canon_tagid )

Return the name of a tag for displaying it to the user

=head3 Arguments

=head4 $target_lc - target language code

=head4 $tagtype

=head4 $canon_tagid

=head3 Return values

The tag translation if it exists in target language,
otherwise, the tag id.

=cut

sub display_taxonomy_tag ($target_lc, $tagtype, $tag) {
	$target_lc =~ s/_.*//;

	if (not defined $tag) {
		$log->warn("display_taxonomy_tag() called for undefined \$tag") if $log->is_warn();
		return "";
	}

	$tag =~ s/^ //g;
	$tag =~ s/ $//g;

	if (not defined $taxonomy_fields{$tagtype}) {

		return canonicalize_tag2($tagtype, $tag);
	}

	my $tag_lc;

	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}
	else {
		# print STDERR "WARNING - display_taxonomy_tag - $tag has no language code, assuming target_lc: $lc\n";
		$tag_lc = $target_lc;
	}

	my $tagid_no_lc = get_string_id_for_lang($tag_lc, $tag);
	my $tagid = $tag_lc . ':' . $tagid_no_lc;

	my $display = '';

	if (    (defined $translations_to{$tagtype})
		and (defined $translations_to{$tagtype}{$tagid})
		and (defined $translations_to{$tagtype}{$tagid}{$target_lc}))
	{
		# we have a translation for the target language
		$display = $translations_to{$tagtype}{$tagid}{$target_lc};
	}
	elsif ( (defined $translations_to{$tagtype})
		and (defined $translations_to{$tagtype}{$tagid})
		and (defined $translations_to{$tagtype}{$tagid}{xx}))
	{
		# we have a translation for the default xx language
		$display = $translations_to{$tagtype}{$tagid}{xx};
	}
	else {
		# We may have changed a canonical en: entry into an language-less xx: entry,
		# or removed a canonical en: entry to replace it to a language-specific entry
		# (e.g. we used to have en:label-rouge, we now have fr:label-rouge + xx:label-rouge)

		my $xx_tagid = 'xx:' . $tagid_no_lc;

		# if we didn't find a language specific entry but there is a corresponding xx: synonym for it,
		# assume the language specific entry was changed to a language-less xx: entry
		if (    (defined $synonyms{$tagtype})
			and (defined $synonyms{$tagtype}{xx})
			and (defined $synonyms{$tagtype}{xx}{$tagid_no_lc}))
		{
			$tagid = "xx:" . $synonyms{$tagtype}{xx}{$tagid_no_lc};
			$tagid = $translations_from{$tagtype}{$tagid};
		}

		if (    (defined $translations_to{$tagtype})
			and (defined $translations_to{$tagtype}{$tagid})
			and (defined $translations_to{$tagtype}{$tagid}{$target_lc}))
		{
			# we have a translation for the target language
			$display = $translations_to{$tagtype}{$tagid}{$target_lc};
		}
		elsif ( (defined $translations_to{$tagtype})
			and (defined $translations_to{$tagtype}{$tagid})
			and (defined $translations_to{$tagtype}{$tagid}{xx}))
		{
			# we have a translation for the default xx language
			$display = $translations_to{$tagtype}{$tagid}{xx};
		}

		elsif ( (defined $translations_to{$tagtype})
			and (defined $translations_to{$tagtype}{$xx_tagid})
			and (defined $translations_to{$tagtype}{$xx_tagid}{xx}))
		{
			# we have a translation for the default xx language
			$display = $translations_to{$tagtype}{$xx_tagid}{xx};
		}

		# use tag language
		elsif ( (defined $translations_to{$tagtype})
			and (defined $translations_to{$tagtype}{$tagid})
			and (defined $translations_to{$tagtype}{$tagid}{$tag_lc}))
		{
			# we have a translation for the tag language
			# print STDERR "display_taxonomy_tag - translation for the tag language - translations_to{$tagtype}{$tagid}{$tag_lc} : $translations_to{$tagtype}{$tagid}{$tag_lc}\n";

			$display = "$tag_lc:" . $translations_to{$tagtype}{$tagid}{$tag_lc};
		}
		else {
			$display = $tag;

			if ($target_lc ne $tag_lc) {
				$display = "$tag_lc:$display";
			}
			else {
				$display = ucfirst($display);
			}
			# print STDERR "display_taxonomy_tag - no translation available for $tagtype $tagid in target language $lc or tag language $tag_lc - result: $display\n";
		}
	}

	# for additives, add the first synonym
	if ($tagtype =~ /^additives(|_prev|_next|_debug)$/) {
		$tagid =~ s/.*://;
		if (    (defined $synonyms_for{$tagtype}{$target_lc})
			and (defined $synonyms_for{$tagtype}{$target_lc}{$tagid})
			and (defined $synonyms_for{$tagtype}{$target_lc}{$tagid}[1]))
		{
			$display .= " - " . ucfirst($synonyms_for{$tagtype}{$target_lc}{$tagid}[1]);
		}
	}

	return $display;

}

=head2 display_taxonomy_tag_name ( $target_lc, $tagtype, $canon_tagid )

A version of display_taxonomy_tag that removes eventual language prefix

=head3 Arguments

=head4 $target_lc - target language code

=head4 $tagtype

=head4 $canon_tagid

=head3 Return values

The tag translation if it exists in target language,
otherwise, the tag in its primary language

=cut

sub display_taxonomy_tag_name ($target_lc, $tagtype, $canon_tagid) {
	my $display_value = display_taxonomy_tag($target_lc, $tagtype, $canon_tagid);
	# remove eventual leading language code
	$display_value =~ s/^\w\w://;
	return $display_value;
}

sub canonicalize_tag_link ($tagtype, $tagid) {

	if (defined $taxonomy_fields{$tagtype}) {
		die "ERROR: canonicalize_tag_link called for a taxonomy tagtype: $tagtype - tagid: $tagid - $!";
	}

	if ($tagtype eq 'missions') {
		if ($tagid =~ /\./) {
			$tagid = $';
		}
	}

	my $path = $tag_type_singular{$tagtype}{$lang};
	if (not defined $path) {
		$path = $tag_type_singular{$tagtype}{en};
	}

	my $link = "/$path/" . URI::Escape::XS::encodeURIComponent($tagid);

	$log->info("canonicalize_tag_link $tagtype $tagid $path $link") if $log->is_info();

	return $link;
}

sub export_tags_hierarchy ($lc, $tagtype) {

	# GEXF graph file (gephi, sigma.js etc.)
	# GraphViz dot file / png / svg

	my $gexf_example = <<GEXF
<?xml version="1.0" encoding="UTF-8"?>
<gexf xmlns="http://www.gexf.net/1.2draft" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.2draft/gexf.xsd" version="1.2">
    <graph>
        <nodes>
            <node id="a" label="cheese"/>
            <node id="b" label="cherry"/>
            <node id="c" label="cake">
                <parents>
                    <parent for="a"/>
                    <parent for="b"/>
                </parents>
            </node>
        </nodes>

		<edges>
            <edge id="0" source="0" target="1" />
        </edges>

    </graph>
</gexf>
GEXF
		;

	my $gexf = <<GEXF
<?xml version="1.0" encoding="UTF-8"?>
<gexf xmlns="http://www.gexf.net/1.2draft" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.2draft/gexf.xsd" version="1.2">
    <graph>
        <nodes>
GEXF
		;
	my $edges = '';

	my $graph = GraphViz2->new(
		edge => {color => 'grey'},
		global => {directed => 1},
		node => {shape => 'oval'},
	);

	if ((defined $tags_level{$lc}) and (defined $tags_level{$lc}{$tagtype})) {

		foreach my $tagid (keys %{$tags_level{$lc}{$tagtype}}) {

			$gexf .= "\t\t\t" . "<node id=\"$tagid\" label=\"" . canonicalize_tag2($tagtype, $tagid) . "\" ";

			$graph->add_node(
				name => $tagid,
				label => canonicalize_tag2($tagtype, $tagid),
				URL => "http://$lc.openfoodfacts.org/" . $tag_type_singular{$tagtype}{$lc} . "/" . $tagid
			);

			if (defined $tags_direct_parents{$lc}{$tagtype}{$tagid}) {
				$gexf .= ">\n";
				$gexf .= "\t\t\t\t<parents>\n";
				foreach my $parentid (sort keys %{$tags_direct_parents{$lc}{$tagtype}{$tagid}}) {
					$gexf .= "\t\t\t\t\t<parent for=\"$parentid\"/>\n";
					$edges .= "\t\t\t<edge id=\"${parentid}_$tagid\" source=\"$parentid\" target=\"$tagid\" />\n";

					$graph->add_edge(from => $parentid, to => $tagid);
				}
				$gexf .= "\t\t\t\t<\/parents>\n" . "\t\t\t<\/node>\n";
			}
			else {
				$gexf .= "\/>\n";
			}
		}
	}

	$gexf .= <<GEXF
        </nodes>
		<edges>
			$edges
		</edges>
    </graph>
</gexf>
GEXF
		;

	open(my $OUT, ">:encoding(UTF-8)",
		"$www_root/data/$lc." . get_string_id_for_lang("no_language", lang($tagtype . "_p"), 1) . ".gexf")
		or die("write error: $!\n");
	print $OUT $gexf;
	close $OUT;

	eval {
		$graph->run(
			format => 'svg',
			output_file => "$www_root/data/$lc."
				. get_string_id_for_lang("no_language", lang($tagtype . "_p"), 1) . ".svg"
		);
	};
	eval {
		$graph->run(
			format => 'png',
			output_file => "$www_root/data/$lc."
				. get_string_id_for_lang("no_language", lang($tagtype . "_p"), 1) . ".png"
		);
	};

	return;
}

sub init_emb_codes {
	return if ((%emb_codes_geo) and (%emb_codes_cities));
	# Load cities for emb codes
	$log->info("Loading cities for packaging codes") if $log->is_info();

	# French departements
	my %departements = ();
	open(my $IN, "<:encoding(windows-1252)", "$data_root/emb_codes/france_departements.txt");
	while (<$IN>) {
		chomp();
		my ($code, $dep) = split(/\t/);
		$departements{$code} = $dep;
	}
	close($IN);

	# France
	# http://www.insee.fr/fr/methodes/nomenclatures/cog/telechargement/2012/txt/france2012.zip
	open($IN, "<:encoding(windows-1252)", "$data_root/emb_codes/france2012.txt");

	my @th = split(/\t/, <$IN>);
	my %th = ();
	my $i = 0;
	foreach my $h (@th) {
		$th{$h} = $i;
		$i++;
	}

	while (<$IN>) {
		chomp();
		my @td = split(/\t/);

		my $dep = $td[$th{DEP}];
		if (length($dep) == 1) {
			$dep = '0' . $dep;
		}
		my $com = $td[$th{COM}];
		if (length($com) == 1) {
			$com = '0' . $com;
		}
		if ((length($dep) == 2) and (length($com) == 2)) {
			$com = '0' . $com;
		}

		$emb_codes_cities{'FREMB' . $dep . $com} = $td[$th{NCCENR}] . " ($departements{$dep}, France)";
		#print STDERR 'FR' . $dep . $com. ' =  ' . $td[$th{NCCENR}] . " ($departements{$dep}, France)\n";

		$cities{get_string_id_for_lang("no_language", $td[$th{NCCENR}] . " ($departements{$dep}, France)")}
			= $td[$th{NCCENR}] . " ($departements{$dep}, France)";
	}
	close($IN);

	open($IN, "<:encoding(windows-1252)", "$data_root/emb_codes/insee.csv");
	while (<$IN>) {
		chomp();
		my @td = split(/;/);
		my $postal_code = $td[1];
		my $insee = $td[3];
		$insee =~ s/(\r|\n)+$//;
		if (length($insee) == 4) {
			$insee = '0' . $insee;
		}
		if (defined $emb_codes_cities{'FREMB' . $insee}) {
			$emb_codes_cities{'FR' . $postal_code} = $emb_codes_cities{'FREMB' . $insee};    # not used...
		}
	}
	close($IN);

	# geo coordinates

	my @geofiles = ("villes-geo-france-galichon-20130208.csv", "villes-geo-france-complement.csv");
	foreach my $geofile (@geofiles) {
		local $log->context->{geofile} = $geofile;
		$log->info("loading geofile $geofile") if $log->is_info();
		open(my $IN, "<:encoding(UTF-8)", "$data_root/emb_codes/$geofile");

		my @th = split(/\t/, <$IN>);
		my %th = ();

		my $i = 0;

		foreach my $h (@th) {
			$h =~ s/^\s+//;
			$h =~ s/\s+$//;
			$th{$h} = $i;
			$i++;
		}

		my $j = 0;
		while (<$IN>) {
			chomp();
			my @td = split(/\t/);

			my $insee = $td[$th{"Code INSEE"}];
			if (length($insee) == 4) {
				$insee = '0' . $insee;
			}

			($td[$th{"Latitude"}] == 0) and $td[$th{"Latitude"}] = 0;    # - => 0
			($td[$th{"Longitude"}] == 0) and $td[$th{"Longitude"}] = 0;
			$emb_codes_geo{'FREMB' . $insee} = [$td[$th{"Latitude"}], $td[$th{"Longitude"}]];

			$j++;
			# ($j < 10) and print STDERR "Tags.pm - geo - map - emb_codes_geo: FREMB$insee =  " . $td[$th{"Latitude"}] . " , " . $td[$th{"Longitude"}]. " \n";
		}

		close($IN);
	}

	$log->debug("Cities for packaging codes loaded") if $log->is_debug();

	return;
}

# load all tags texts
sub init_tags_texts {
	return if (%tags_texts);

	$log->info("loading tags texts") if $log->is_info();
	if (opendir DH2, $lang_dir) {
		foreach my $langid (readdir(DH2)) {
			next if $langid eq '.';
			next if $langid eq '..';

			# print STDERR "Tags.pm - reading texts for lang $langid\n";
			next if ((length($langid) ne 2) and not($langid eq 'other'));

			my $lc = $langid;

			defined $tags_texts{$lc} or $tags_texts{$lc} = {};

			if (-e "$lang_dir/$langid") {
				foreach my $tagtype (sort keys %tag_type_singular) {

					defined $tags_texts{$lc}{$tagtype} or $tags_texts{$lc}{$tagtype} = {};

					# this runs number-of-languages * number-of-tag-types times.
					if (-e "$lang_dir/$langid/$tagtype") {
						opendir DH, "$lang_dir/$langid/$tagtype" or die "Couldn't open the current directory: $!";
						foreach my $file (readdir(DH)) {
							next if $file !~ /(.*)\.html/;
							my $tagid = $1;
							open(my $IN, "<:encoding(UTF-8)", "$lang_dir/$langid/$tagtype/$file")
								or $log->error("cannot open file",
								{path => "$lang_dir/$langid/$tagtype/$file", error => $!});

							my $text = join("", (<$IN>));
							close $IN;

							$tags_texts{$lc}{$tagtype}{$tagid} = $text;
						}
						closedir(DH);
					}
				}
			}
		}
		closedir(DH2);
		$log->debug("tags texts loaded") if $log->is_debug();
	}
	else {
		$log->warn("The $lang_dir could not be opened.") if $log->is_warn();
		$log->warn("Tags texts could not be loaded.") if $log->is_warn();
	}

	return;
}

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
			$tagid = get_taxonomyid($tag_lc, canonicalize_taxonomy_tag($tag_lc, $field, $tag));
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

sub compute_field_tags ($product_ref, $tag_lc, $field) {
	# generate the tags hierarchy from the comma separated list of $field with default language $tag_lc

	# fields that should not have a different normalization (accentuation etc.) based on language
	if ($field eq "teams") {
		$tag_lc = "no_language";
	}

	init_emb_codes() unless %emb_codes_cities;
	# generate the hierarchy of tags from the field values

	if (defined $taxonomy_fields{$field}) {
		$product_ref->{$field . "_lc"} = $tag_lc;    # save the language for the field, useful for debugging
		$product_ref->{$field . "_hierarchy"} = [gen_tags_hierarchy_taxonomy($tag_lc, $field, $product_ref->{$field})];
		$product_ref->{$field . "_tags"} = [];
		foreach my $tag (@{$product_ref->{$field . "_hierarchy"}}) {
			push @{$product_ref->{$field . "_tags"}}, get_taxonomyid($tag_lc, $tag);
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

	# check if we have a previous or a next version and compute differences

	my $debug_tags = 0;

	$product_ref->{$field . "_debug_tags"} = [];

	# previous version

	if (exists $loaded_taxonomies{$field . "_prev"}) {

		$product_ref->{$field . "_prev_hierarchy"}
			= [gen_tags_hierarchy_taxonomy($tag_lc, $field . "_prev", $product_ref->{$field})];
		$product_ref->{$field . "_prev_tags"} = [];
		foreach my $tag (@{$product_ref->{$field . "_prev_hierarchy"}}) {
			push @{$product_ref->{$field . "_prev_tags"}}, get_taxonomyid($tag_lc, $tag);
		}

		# compute differences
		foreach my $tag (@{$product_ref->{$field . "_tags"}}) {
			if (not has_tag($product_ref, $field . "_prev", $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "added-$tagid";
				$debug_tags++;
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_prev_tags"}}) {
			if (not has_tag($product_ref, $field, $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "removed-$tagid";
				$debug_tags++;
			}
		}
	}
	else {
		delete $product_ref->{$field . "_prev_hierarchy"};
		delete $product_ref->{$field . "_prev_tags"};
	}

	# next version

	if (exists $loaded_taxonomies{$field . "_next"}) {

		$product_ref->{$field . "_next_hierarchy"}
			= [gen_tags_hierarchy_taxonomy($tag_lc, $field . "_next", $product_ref->{$field})];
		$product_ref->{$field . "_next_tags"} = [];
		foreach my $tag (@{$product_ref->{$field . "_next_hierarchy"}}) {
			push @{$product_ref->{$field . "_next_tags"}}, get_taxonomyid($tag_lc, $tag);
		}

		# compute differences
		foreach my $tag (@{$product_ref->{$field . "_tags"}}) {
			if (not has_tag($product_ref, $field . "_next", $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "will-remove-$tagid";
				$debug_tags++;
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_next_tags"}}) {
			if (not has_tag($product_ref, $field, $tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "will-add-$tagid";
				$debug_tags++;
			}
		}
	}
	else {
		delete $product_ref->{$field . "_next_hierarchy"};
		delete $product_ref->{$field . "_next_tags"};
	}

	if ($debug_tags == 0) {
		delete $product_ref->{$field . "_debug_tags"};
	}

	return;
}

sub add_user_translation ($tag_lc, $tagtype, $user, $from, $to) {

	(-e "$data_root/translate") or mkdir("$data_root/translate", 0755);

	open(my $LOG, ">>:encoding(UTF-8)", "$data_root/translate/$tagtype.$tag_lc.txt");
	print $LOG join("\t", (time(), $user, $from, $to)) . "\n";
	close $LOG;

	return;
}

sub load_users_translations_for_lc ($users_translations_ref, $tagtype, $tag_lc) {

	if (not defined $users_translations_ref->{$tag_lc}) {
		$users_translations_ref->{$tag_lc} = {};
	}

	my $file = "$data_root/translate/$tagtype.$tag_lc.txt";

	$log->debug("load_users_translations_for_lc", {file => $file}) if $log->is_debug();

	if (-e $file) {
		$log->debug("load_users_translations_for_lc, file exists", {file => $file}) if $log->is_debug();
		open(my $LOG, "<:encoding(UTF-8)", "$data_root/translate/$tagtype.$tag_lc.txt");
		while (<$LOG>) {
			chomp();
			my ($time, $userid, $from, $to) = split(/\t/, $_);
			$users_translations_ref->{$tag_lc}{$from} = {t => $time, userid => $userid, to => $to};
			$log->debug("load_users_translations_for_lc, new translation $tagtype $userid $from $to",
				{userid => $userid, from => $from, to => $to})
				if $log->is_debug();
		}
		close($LOG);

		return 1;
	}
	else {
		$log->debug("load_users_translations_for_lc, file does not exist", {file => $file}) if $log->is_debug();
		return 0;
	}
}

sub load_users_translations ($users_translations_ref, $tagtype) {

	if (opendir(my $DH, "$data_root/translate")) {
		foreach my $file (readdir($DH)) {
			if ($file =~ /^$tagtype.(\w\w).txt$/) {
				load_users_translations_for_lc($users_translations_ref, $tagtype, $1);
			}
		}
		closedir $DH;
	}

	return;
}

sub add_users_translations_to_taxonomy ($tagtype) {

	my $users_translations_ref = {};

	load_users_translations($users_translations_ref, $tagtype);

	if (open(my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$tagtype.txt")) {

		binmode(STDIN, ":encoding(UTF-8)");
		binmode(STDOUT, ":encoding(UTF-8)");
		binmode(STDERR, ":encoding(UTF-8)");

		my $first_lc = "";
		my $first_language_tag = "";
		my $others = "";
		my $tagid;

		my %translations = ();

		while (<$IN>) {

			my $line = $_;
			chomp($line);

			if ($line =~ /^(<|stopwords|synonyms)/) {
				print $line . "\n";
			}
			elsif (($first_lc eq '') and (($line =~ /^#/) or ($line =~ /^\s*$/))) {
				# comments above the English definition
				print $line . "\n";
			}
			elsif (($line =~ /^(\w\w):(.*)$/) or ($line =~ /^(\w\w_\w\w):(.*)$/)) {
				my $l = $1;
				my $tag = $2;

				if ($first_lc eq "") {
					$first_language_tag = $tag;
					$first_lc = $l;
					$tag =~ s/,.*//;
					$tagid = $first_lc . ":" . get_string_id_for_lang($first_lc, $tag);
				}
				else {
					$translations{$l} = $tag;
				}
			}
			elsif ($line =~ /^#/) {
				$others .= $line . "\n";
			}
			elsif (($first_language_tag ne "") and ($line =~ /^\s*$/)) {

				foreach my $l (keys %{$users_translations_ref}) {
					if (defined $users_translations_ref->{$l}{$tagid}) {

						if (not defined $translations{$l}) {
							$translations{$l} = $users_translations_ref->{$l}{$tagid}{to};
						}
						elsif (defined $users_translations_ref->{$l}{$tagid}) {
							print STDERR "ignoring translation for already existing translation:\n";
							print STDERR "existing: " . $translations{$l} . "\n";
							print STDERR "new: " . $users_translations_ref->{$l}{$tagid}{to} . "\n";
						}
					}
				}

				print "$first_lc:$first_language_tag\n";
				foreach my $l (sort keys %translations) {
					print "$l:$translations{$l}\n";
				}
				print $others;
				print "\n";

				%translations = ();
				$first_lc = "";
				$first_language_tag = "";
				$others = "";
				$tagid = undef;

			}
			else {
				$others .= $line . "\n";
			}
		}

		if ($first_language_tag) {

			foreach my $l (keys %{$users_translations_ref}) {
				if (defined $users_translations_ref->{$l}{$tagid}) {
					if (not defined $translations{$l}) {
						$translations{$l} = $users_translations_ref->{$l}{$tagid}{to};
					}
					else {
						print STDERR "ignoring translation for already existing translation:\n";
						print STDERR "existing: " . $translations{$l} . "\n";
						print STDERR "new: " . $users_translations_ref->{$l}{$tagid}{to} . "\n";
					}
				}
			}

			print "$first_lc:$first_language_tag\n";
			foreach my $l (sort keys %translations) {
				print "$l:$translations{$l}\n";
			}
			print $others;
			print "\n";

		}
	}

	return;
}

=head2 generate_regexps_matching_taxonomy_entries($taxonomy, $return_type, $options_ref)

Create regular expressions that will match entries of a taxonomy.

=head3 Arguments

=head4 $taxonomy

The type of the tag (e.g. categories, labels, allergens)

=head4 $return_type - string

Either "unique_regexp" to get one single regexp for all entries of one language.

Or "list_of_regexps" to get a list of regexps (1 per entry) for each language.
For each entry, we return an array with the entry id, and the the regexp for that entry.
e.g. ['en:coffee',"coffee|coffees"]

=head4 $options_ref

A reference to a hash to enable options to indicate how to match:

- add_simple_plurals : in some languages, like French, we will allow an extra "s" at the end of entries
- add_simple_singulars: same with removing the "s" at the end of entries
- match_space_with_dash: spaces or dashes in entries will match either a space or a dash (e.g. "South America" will match "South-America")

=cut

sub generate_regexps_matching_taxonomy_entries ($taxonomy, $return_type, $options_ref) {

	# We will return for each language an unique regexp or a list of regexps
	my $result_ref = {};

	# Lists of synonyms regular expressions per language
	my %synonyms_regexps = ();

	foreach my $tagid (get_all_taxonomy_entries($taxonomy)) {

		foreach my $language (sort keys %{$translations_to{$taxonomy}{$tagid}}) {

			defined $synonyms_regexps{$language} or $synonyms_regexps{$language} = [];

			# the synonyms below also contain the main translation as the first entry

			foreach my $synonym (get_taxonomy_tag_synonyms($language, $taxonomy, $tagid)) {

				# Escape some characters
				$synonym = regexp_escape($synonym);

				if ($options_ref->{add_simple_singulars}) {
					if ($synonym =~ /s$/) {
						# match entry without final s
						$synonym =~ s/s$/\(\?:s\?\)/;
					}
				}

				if ($options_ref->{add_simple_plurals}) {
					if ($synonym !~ /s$/) {
						# match entry with additional final s
						$synonym =~ s/$/\(\?:s\?\)/;
					}
				}

				if ($options_ref->{match_space_with_dash}) {
					# Make spaces match dashes and the reverse
					$synonym =~ s/( |-)/\(\?: \|-\)/g;
				}

				push @{$synonyms_regexps{$language}}, [$tagid, $synonym];

				if ((my $unaccented_synonym = unac_string_perl($synonym)) ne $synonym) {
					push @{$synonyms_regexps{$language}}, [$tagid, $unaccented_synonym];
				}
			}
		}
	}

	# We want to match the longest strings first

	if ($return_type eq 'unique_regexp') {
		foreach my $language (keys %synonyms_regexps) {
			$result_ref->{$language} = join('|',
				map {$_->[1]}
					sort {(length $b->[1] <=> length $a->[1]) || ($a->[1] cmp $b->[1])}
					@{$synonyms_regexps{$language}});
		}
	}
	elsif ($return_type eq 'list_of_regexps') {
		foreach my $language (keys %synonyms_regexps) {
			@{$result_ref->{$language}}
				= sort {(length $b->[1] <=> length $a->[1]) || ($a->[1] cmp $b->[1])} @{$synonyms_regexps{$language}};
		}
	}
	else {
		die(
			"unknown return type for generate_regexps_matching_taxonomy_entries: $return_type - must be unique_regexp or list_of_regexps"
		);
	}

	return $result_ref;
}

=head2 cmp_taxonomy_tags_alphabetically($tagtype, $target_lc, $a, $b)

Comparison function for canonical tags entries in a taxonomy.

To be used as a sort function in a sort() call.

Each tag is converted to a string, by priority:
1 - the tag name in the target language
2 - the tag name in the xx language
3 - the tag id

=head3 Arguments

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $target_lc

=head4 $a

=head4 $b

=cut

sub cmp_taxonomy_tags_alphabetically ($tagtype, $target_lc, $a, $b) {

	return ($translations_to{$tagtype}{$a}{$target_lc} || $translations_to{$tagtype}{$a}{"xx"} || $a)
		cmp($translations_to{$tagtype}{$b}{$target_lc} || $translations_to{$tagtype}{$b}{"xx"} || $b);
}

=head2 get_knowledge_content ($tagtype, $tagid, $target_lc, $target_cc)

Fetch knowledge content as HTML about additive, categories,...

This content is used in knowledge panels.

Content is stored as HTML files in `${lang_dir}/${target_lc}/knowledge_panels/${tagtype}`.
We first check the existence of a file specific to the country specified by `${target_cc}`,
with a fallback on `world` otherwise. This is useful to have a more specific description for some
countries compared to the `world` base content.

=head3 Arguments

=head4 $tagtype

The type of the tag (e.g. categories, labels, allergens)

=head4 $tagid

The tag we want to match, with language prefix (ex: `en:e255`).

=head4 $target_lc

The user language as a 2-letters code (fr, it,...)

=head4 $target_cc

The user country as a 2-letters code (fr, it, ch) or `world`

=head3 Return value

If a content exists for the tag type, tag value, language code and country code, return the HTML text,
return undef otherwise. 

=cut

sub get_knowledge_content ($tagtype, $tagid, $target_lc, $target_cc) {
	# tag value is normalized:
	# en:250 -> en_250
	$tagid =~ s/:/_/g;

	my $base_dir = "$lang_dir/$target_lc/knowledge_panels/$tagtype";

	foreach my $cc ($target_cc, "world") {
		my $file_path = "$base_dir/$tagid" . "_" . "$cc.html";
		$log->debug("get_knowledge_content - checking $file_path") if $log->is_debug();
		if (-e $file_path) {
			$log->debug("get_knowledge_content - Match on $file_path!") if $log->is_debug();
			open(my $IN, "<:encoding(UTF-8)", $file_path) or $log->error("cannot open file", {path => $file_path});
			my $text = join("", (<$IN>));
			close $IN;
			return $text;
		}
	}
	return;
}

$log->info("Tags.pm loaded") if $log->is_info();

1;
