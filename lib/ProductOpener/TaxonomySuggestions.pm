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

ProductOpener::TaxonomySuggestions - suggests taxonomy entries for dropdown, autocomplete etc.

=head1 DESCRIPTION

=cut

package ProductOpener::TaxonomySuggestions;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_taxonomy_suggestions_with_synonyms
		&get_taxonomy_suggestions
		&generate_sorted_list_of_taxonomy_entries
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/get_string_id_for_lang retrieve_json/;
use ProductOpener::Display qw/$country/;
use ProductOpener::Lang qw/lang/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::PackagerCodes qw/@sorted_packager_codes normalize_packager_codes/;
use ProductOpener::Cache qw/$memd generate_cache_key/;

use List::Util qw/min/;
use Data::DeepAccess qw(deep_exists deep_get);

# We use a global variable in order to load the packaging stats only once
my $categories_packagings_stats_for_suggestions_ref;

sub load_categories_packagings_stats_for_suggestions() {
	if (not defined $categories_packagings_stats_for_suggestions_ref) {
		my $file = "$BASE_DIRS{PRIVATE_DATA}/categories_stats/categories_packagings_stats.all.popular.json";
		# In dev environments, we provide a sample stats file in the data-default directory
		# so that we can run tests with meaningful and unchanging data
		if (!-e $file) {
			my $default_file
				= "$BASE_DIRS{PRIVATE_DATA}-default/categories_stats/categories_packagings_stats.all.popular.json";
			$log->debug("local packaging stats file does not exist, will use default",
				{file => $file, default_file => $default_file})
				if $log->is_debug();
			$file = $default_file;
		}
		$log->debug("loading packaging stats", {file => $file}) if $log->is_debug();
		$categories_packagings_stats_for_suggestions_ref = retrieve_json($file);
		if (not defined $categories_packagings_stats_for_suggestions_ref) {
			$log->debug("unable to load packaging stats", {file => $file}) if $log->is_debug();
		}
	}
	return $categories_packagings_stats_for_suggestions_ref;
}

=head2 get_taxonomy_suggestions_with_synonyms ($tagtype, $search_lc, $string, $context_ref, $options_ref )

Generate taxonomy suggestions with matched synonyms information.

=head2 get_taxonomy_suggestions ($tagtype, $search_lc, $string, $context_ref, $options_ref )

Generate taxonomy suggestions (without matched synonyms information).

=head3 Parameters

=head4 $tagtype		id of the taxonomy (required)

=head4 $search_lc	language of parameters (categories, shape, material etc.) and of the returned suggestions (required)

=head4 $string 		string to query (e.g. for autocompletion) (optional)

=head4 $context_ref context object

Hash of fields that can be taken into account to generate relevant suggestions

- country: derived from the cc parameter
- categories: comma separated list of categories (tags ids or strings in the $search_lc language)
- shape: packaging shape (tag id or string in the $search_lc language)

=head3 Note

The results of this function are cached for 1 day using memcached.
Restart memcached if you want fresh results (e.g. when taxonomy are category stats change).

=cut

sub get_taxonomy_suggestions_with_synonyms ($tagtype, $search_lc, $string, $context_ref, $options_ref) {

	$log->debug(
		"get_taxonomy_suggestions - start",
		{
			tagtype => $tagtype,
			search_lc => $search_lc,
			string => $string,
			context_ref => $context_ref,
			options_ref => $options_ref
		}
	) if $log->is_debug();

	# Check if we have cached suggestions
	my $key = generate_cache_key(
		"get_taxonomy_suggestions",
		{
			tagtype => $tagtype,
			search_lc => $search_lc,
			string => $string,
			context_ref => $context_ref,
			options_ref => $options_ref
		}
	);

	my $results_ref = $memd->get($key);

	if (not defined $results_ref) {
		$log->debug("suggestions are not cached", {key => $key}) if $log->is_debug();

		my @tags = generate_sorted_list_of_taxonomy_entries($tagtype, $search_lc, $context_ref);

		my @filtered_tags
			= filter_suggestions_matching_string_with_synonyms(\@tags, $tagtype, $search_lc, $string, $options_ref);
		$results_ref = \@filtered_tags;

		$log->debug("storing suggestions in cache", {key => $key}) if $log->is_debug();
		$memd->set($key, $results_ref, 24 * 3600);    # Cache suggestions for 1 day
	}
	else {
		$log->debug("got suggestions from cache", {key => $key}) if $log->is_debug();
	}

	return @$results_ref;
}

sub get_taxonomy_suggestions ($tagtype, $search_lc, $string, $context_ref, $options_ref) {
	return
		map {$_->{tag}}
		get_taxonomy_suggestions_with_synonyms($tagtype, $search_lc, $string, $context_ref, $options_ref);
}

=head2 generate_sorted_list_of_taxonomy_entries($tagtype, $search_lc, $context_ref)

Generate a sorted list of canonicalized taxonomy entries from which we will generate suggestions

=cut

sub generate_sorted_list_of_taxonomy_entries ($tagtype, $search_lc, $context_ref) {

	my @tags;
	my %seen_tags = ();    # Used to not add the same tag several times

	# search for emb codes
	if ($tagtype eq 'emb_codes') {
		return @sorted_packager_codes;
	}
	# search for entries in a taxonomy
	else {
		# Generate popular suggestions
		@tags = generate_popular_suggestions_according_to_context($tagtype, $search_lc, $context_ref, \%seen_tags);

		# add all remaining entries in alphabetical order
		foreach my $tag (
			sort({cmp_taxonomy_tags_alphabetically($tagtype, $search_lc, $a, $b)}
				keys %{$translations_to{$tagtype}})
			)
		{
			next if defined $seen_tags{$tag};
			push @tags, $tag;
		}
	}

	return @tags;
}

=head2 generate_popular_suggestions_according_to_context($tagtype, $search_lc, $context_ref, $seen_tags_ref)

Given a specific context (e.g. the product's country, categories, or the packaging component shape),
we can generate popular suggestions sorted by popularity in this context.

Currently supports packaging_shapes and packaging_materials

For other taxonomy types, an empty list is returned.

=cut

sub generate_popular_suggestions_according_to_context ($tagtype, $search_lc, $context_ref, $seen_tags_ref) {

	my @tags = ();

	# For packaging shapes and materials, we will generate the most popular suggestions
	# for the country, product categories, and shape
	if (($tagtype eq "packaging_shapes") or ($tagtype eq "packaging_materials")) {
		load_categories_packagings_stats_for_suggestions();

		# We will try to provide popular suggestions for the product categories
		my @categories = ("all");    # popular suggestions for all categories
									 # If categories are provided, add them (most generic categories first)
		if (defined $context_ref->{categories}) {
			push @categories, gen_tags_hierarchy_taxonomy($search_lc, "categories", $context_ref->{categories});
		}

		# Start with the most specific category
		foreach my $category (reverse @categories) {

			if ($tagtype eq "packaging_shapes") {
				my $shapes_ref = deep_get(
					$categories_packagings_stats_for_suggestions_ref,
					("countries", $country, "categories", $category, "shapes")
				);

				add_sorted_entries_to_tags(\@tags, $seen_tags_ref, $shapes_ref, $tagtype, $search_lc);
			}
			elsif ($tagtype eq "packaging_materials") {
				# Add materials specific to the shape if we have one
				my $shape;
				if (defined $context_ref->{shape}) {
					$shape = canonicalize_taxonomy_tag($search_lc, "packaging_shapes", $context_ref->{shape});
				}
				else {
					$shape = "all";
				}
				my $materials_ref = deep_get($categories_packagings_stats_for_suggestions_ref,
					("countries", $country, "categories", $category, "shapes", $shape, "materials"));

				add_sorted_entries_to_tags(\@tags, $seen_tags_ref, $materials_ref, $tagtype, $search_lc);
			}
		}

		$log->debug("resulting tags from categories", {categories => \@categories, tags => \@tags})
			if $log->is_debug();
	}

	return @tags;
}

=head2 add_sorted_entries_to_tags($tags_ref, $seen_tags_ref, $entries_ref, $tagtype, $search_lc)

Add packaging entries (shapes or materials) sorted by frequency for a specific country, category and shape (for materials)

=head3 Parameters

=head4 $tags_ref points to the list we want to appends tags to

=head4 $seen_tags_ref point to a hashmap of entries already in $tags_ref

=head4 $entries_ref point to a hashmap where keys are tags and values represent tag priority

=head4 $tagtype - type of tag necessary to use right translations for alphabetical sort (see Tags.pm)

=head4 $search_lc - is the target language for translations

=cut

sub add_sorted_entries_to_tags ($tags_ref, $seen_tags_ref, $entries_ref, $tagtype, $search_lc) {

	if (defined $entries_ref) {
		foreach my $entry (
			sort({
					($entries_ref->{$b}{n} <=> $entries_ref->{$a}{n})    # Sort first by descending order of popularity
						or cmp_taxonomy_tags_alphabetically($tagtype, $search_lc, $a,
						$b)    # And then by ascending alphabetical order
				}
				keys %$entries_ref)
			)
		{
			next if (($entry eq "all") or ($entry eq "en:unknown"));
			next if defined $seen_tags_ref->{$entry};
			push @$tags_ref, $entry;
			$seen_tags_ref->{$entry} = 1;
		}
	}

	return;
}

# Match the normalized form of a tag synonym to the normalized input of an user

sub match_stringids ($stringid, $fuzzystringid, $synonymid) {

	$log->debug("match string ids", {stringid => $stringid, fuzzystringid => $fuzzystringid, synonymid => $synonymid})
		if $log->is_debug();

	# matching at start, best matches
	if ($synonymid =~ /^$stringid/) {
		return "start";
	}
	# matching inside
	elsif ($synonymid =~ /$stringid/) {
		return "inside";
	}
	# fuzzy match
	elsif ($synonymid =~ /$fuzzystringid/) {
		return "fuzzy";
	}

	return "none";
}

# best_match is used to see how well matches the best matching synonym

sub best_match ($search_lc, $stringid, $fuzzystringid, $synonyms_ref) {

	my $best_type = "none";
	my $best_match = 0;

	foreach my $synonym (@$synonyms_ref) {
		my $synonymid = get_string_id_for_lang($search_lc, $synonym);
		my $match = match_stringids($stringid, $fuzzystringid, $synonymid);
		# Prefer to use the earlier ones from the list for when the canonical name has the same match type as a synonym
		next if $match eq "none" or $match eq $best_type;
		if ($match eq "start") {
			# Best match, we can return without looking at the other synonyms
			$best_type = $match;
			$best_match = $synonym;
			last;
		}
		elsif (($match eq "inside")
			or (($match eq "fuzzy") and ($best_type eq "none")))
		{
			$best_type = $match;
			$best_match = $synonym;
		}
	}
	return {type => $best_type, match => $best_match};
}

=head2 filter_suggestions_matching_string_with_synonyms ($tags_ref, $tagtype, $search_lc, $string, $options_ref)

Filter a list of potential taxonomy suggestions matching a string with matched synonyms information.

=head2 filter_suggestions_matching_string ($tags_ref, $tagtype, $search_lc, $string, $options_ref)

Filter a list of potential taxonomy suggestions matching a string (without matched synonyms information).

By priority, the function returns:
- taxonomy entries that match the input string at the beginning
- taxonomy entries that contain the input string
- taxonomy entries that contain words contained in the input string (with other words between)

=head3 Parameters

=head4 $tags_ref	reference to an array of tags that needs to be filtered

=head4 $tagtype		the type of tag

=head4 $search_lc	language code of taxonomy suggestions to return

=head4 $string		string to search

=head4 $options_ref	hash of options

- limit: limit of number of results
- format (not yet defined and implemented)

=head3 Return value

An array of suggestions hashes with the following fields:
- tag: the tag to suggest
- matched_synonym: the synonym that matched the input string

=cut

sub filter_suggestions_matching_string_with_synonyms ($tags_ref, $tagtype, $search_lc, $string, $options_ref) {

	my $original_lc = $search_lc;

	# Limit the maximum number of results
	my $limit = $options_ref->{limit} || 25;
	# Set a hard limit of 400
	$limit = min(int($limit), 400);

	$log->debug(
		"filter_suggestions_matching_string",
		{
			number_of_input_suggestions => scalar(@$tags_ref),
			tagtype => $tagtype,
			search_lc => $search_lc,
			string => $string,
			options_ref => $options_ref,
			limit => $limit
		}
	) if $log->is_debug();

	# undefined string
	if (not defined $string) {
		$string = "";
	}

	# if search string begins with a language code, use it for search
	if ($string =~ /^(\w\w):/) {
		$search_lc = $1;
		$string = $';
	}

	my @suggestions = ();    # Suggestions starting with the string
	my @suggestions_c = ();    # Suggestions containing the string
	my @suggestions_f = ();    # fuzzy suggestions

	my $suggestions_count = 0;

	# search for emb codes
	if ($tagtype eq 'emb_codes') {
		my $stringid = get_string_id_for_lang("no_language", normalize_packager_codes($string));
		foreach my $canon_tagid (@$tags_ref) {
			next if $canon_tagid !~ /^$stringid/;
			my $normalized_tag = normalize_packager_codes($canon_tagid);
			my $suggestion_ref = {
				tag => $normalized_tag,
				matched_synonym => $normalized_tag
			};
			push @suggestions, $suggestion_ref;
			last if ++$suggestions_count >= $limit;
		}
	}
	else {
		# search for string in a taxonomy

		# normalize string
		my $stringid = get_string_id_for_lang($search_lc, $string);
		# remove eventual leading or ending "-"
		$stringid =~ s/^-//;
		$stringid =~ s/^-$//;
		# fuzzy match whole words with other words between them
		my $fuzzystringid = join(".*", split("-", $stringid));

		foreach my $canon_tagid (@$tags_ref) {
			# just_synonyms are not real entries
			next if defined $just_synonyms{$tagtype}{$canon_tagid};

			# We will match synonyms in the search language, and in the wildcard xx: language
			my $tag = display_taxonomy_tag($search_lc, $tagtype, $canon_tagid);
			my $tag_xx = display_taxonomy_tag("xx", $tagtype, $canon_tagid);

			# Build a list of normalized synonyms in the search language and the wildcard xx: language
			my @synonyms = (
				@{deep_get(\%synonyms_for, $tagtype, $search_lc, get_string_id_for_lang($search_lc, $tag)) || []},
				@{deep_get(\%synonyms_for, $tagtype, "xx", get_string_id_for_lang("xx", $tag_xx)) || []}
			);

			# check how well the synonyms match the input string
			my $best_match = best_match($search_lc, $stringid, $fuzzystringid, \@synonyms);

			$log->debug(
				"synonyms for canon_tagid",
				{
					tagtype => $tagtype,
					canon_tagid => $canon_tagid,
					tag => $tag,
					synonyms => \@synonyms,
					best_match => $best_match
				}
			) if $log->is_debug();

			my $suggestion_ref = {
				tag => $tag,
				matched_synonym => $best_match->{match}
			};
			# matching at start, best matches
			if ($best_match->{type} eq "start") {
				push @suggestions, $suggestion_ref;
				# count matches at start so that we can return only if we have enough matches
				$suggestions_count++;
				last if $suggestions_count >= $limit;
			}
			# matching inside
			elsif ($best_match->{type} eq "inside") {
				push @suggestions_c, $suggestion_ref;
			}
			# fuzzy match
			elsif ($best_match->{type} eq "fuzzy") {
				push @suggestions_f, $suggestion_ref;
			}
		}
	}

	# suggestions containing string
	my $contains_to_add = min($limit - (scalar @suggestions), scalar @suggestions_c) - 1;
	if ($contains_to_add >= 0) {
		push @suggestions, @suggestions_c[0 .. $contains_to_add];
	}
	# Suggestions as fuzzy match
	my $fuzzy_to_add = min($limit - (scalar @suggestions), scalar @suggestions_f) - 1;
	if ($fuzzy_to_add >= 0) {
		push @suggestions, @suggestions_f[0 .. $fuzzy_to_add];
	}

	return @suggestions;
}

sub filter_suggestions_matching_string ($tags_ref, $tagtype, $search_lc, $string, $options_ref) {
	return
		map {$_->{tag}}
		filter_suggestions_matching_string_with_synonyms($tags_ref, $tagtype, $search_lc, $string, $options_ref);
}

1;
