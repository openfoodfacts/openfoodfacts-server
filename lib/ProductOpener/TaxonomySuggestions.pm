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
		&clear_suggestions_index
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/get_string_id_for_lang retrieve_config/;
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
		my $file = "$BASE_DIRS{PRIVATE_DATA}/categories_stats/categories_packagings_stats.all.popular";
		# In dev environments, we provide a sample stats file in the data-default directory
		# so that we can run tests with meaningful and unchanging data
		if (!-e $file) {
			my $default_file
				= "$BASE_DIRS{PRIVATE_DATA}-default/categories_stats/categories_packagings_stats.all.popular";
			$log->debug("local packaging stats file does not exist, will use default",
				{file => $file, default_file => $default_file})
				if $log->is_debug();
			$file = $default_file;
		}
		$log->debug("loading packaging stats", {file => $file}) if $log->is_debug();
		$categories_packagings_stats_for_suggestions_ref = retrieve_config($file);
		if (not defined $categories_packagings_stats_for_suggestions_ref) {
			$log->debug("unable to load packaging stats", {file => $file}) if $log->is_debug();
		}
	}
	return $categories_packagings_stats_for_suggestions_ref;
}

=head2 get_taxonomy_suggestions_with_synonyms ($country, $tagtype, $search_lc, $string, $context_ref, $options_ref )

Generate taxonomy suggestions with matched synonyms information.

=head2 get_taxonomy_suggestions ($country, $tagtype, $search_lc, $string, $context_ref, $options_ref )

Generate taxonomy suggestions (without matched synonyms information).

=head3 Parameters

=head4 $country		country id (e.g. "en:world", "en:united-states")

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

sub get_taxonomy_suggestions_with_synonyms ($country, $tagtype, $search_lc, $string, $context_ref, $options_ref) {

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

		my @tags = generate_sorted_list_of_taxonomy_entries($country, $tagtype, $search_lc, $context_ref);
		my $tags_ref = \@tags;

		# The entry list is the process's own, so the index can be kept and reused between
		# requests; it is dropped by clear_suggestions_index() when the taxonomies are rebuilt
		my @filtered_tags = _filter_suggestions(_get_suggestions_index($tagtype, $search_lc, $tags_ref),
			$tags_ref, $tagtype, $search_lc, $string, $options_ref);
		$results_ref = \@filtered_tags;

		$log->debug("storing suggestions in cache", {key => $key}) if $log->is_debug();
		$memd->set($key, $results_ref, 24 * 3600);    # Cache suggestions for 1 day
	}
	else {
		$log->debug("got suggestions from cache", {key => $key}) if $log->is_debug();
	}

	return @$results_ref;
}

sub get_taxonomy_suggestions ($country, $tagtype, $search_lc, $string, $context_ref, $options_ref) {
	return
		map {$_->{tag}}
		get_taxonomy_suggestions_with_synonyms($country, $tagtype, $search_lc, $string, $context_ref, $options_ref);
}

=head2 generate_sorted_list_of_taxonomy_entries($couuntry, $tagtype, $search_lc, $context_ref)

Generate a sorted list of canonicalized taxonomy entries from which we will generate suggestions

=cut

# Note: the sorted list of entries is deliberately not cached in the process. It does not depend on
# the string being searched for, but it does depend on the translations, and a running worker picks
# up user contributed translations through add_users_translations_to_taxonomy(), so a list cached
# for the lifetime of the worker would go stale. Building it costs about 0.25s for the categories
# taxonomy, which is a small enough part of a request to leave alone.
sub generate_sorted_list_of_taxonomy_entries ($country, $tagtype, $search_lc, $context_ref) {

	my @tags;
	my %seen_tags = ();    # Used to not add the same tag several times

	# search for emb codes
	if ($tagtype eq 'emb_codes') {
		return @sorted_packager_codes;
	}
	# search for entries in a taxonomy
	else {
		# Generate popular suggestions
		@tags = generate_popular_suggestions_according_to_context($country, $tagtype, $search_lc, $context_ref,
			\%seen_tags);

		# Sort the remaining entries alphabetically before adding them.
		# The entries are decorated with the string they sort on first: cmp_taxonomy_tags_alphabetically()
		# looks the translation up on both sides of every comparison, and sorting the categories
		# taxonomy is about 200000 comparisons for 14736 entries, so doing that lookup once per entry
		# instead of once per side of every comparison is the difference between the sort taking a
		# large part of a request and taking a small one. Perl's sort is stable, so entries that
		# translate to the same string keep the order they have here, as they did before.
		my @decorated
			= map {[$_, $translations_to{$tagtype}{$_}{$search_lc} || $translations_to{$tagtype}{$_}{"xx"} || $_]}
			keys %{$translations_to{$tagtype}};
		my @all_tags = map {$_->[0]} sort({$a->[1] cmp $b->[1]} @decorated);

		# add all remaining entries in alphabetical order
		foreach my $tag (@all_tags) {
			next if defined $seen_tags{$tag};
			push @tags, $tag;
		}
	}

	return @tags;
}

=head2 generate_popular_suggestions_according_to_context($country, $tagtype, $search_lc, $context_ref, $seen_tags_ref)

Given a specific context (e.g. the product's country, categories, or the packaging component shape),
we can generate popular suggestions sorted by popularity in this context.

Currently supports packaging_shapes and packaging_materials

For other taxonomy types, an empty list is returned.

=cut

sub generate_popular_suggestions_according_to_context ($country, $tagtype, $search_lc, $context_ref, $seen_tags_ref) {

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

# Per-process index of what a suggestion request needs for every entry of a taxonomy.
#
# A request that misses the result cache used to sort every entry of the taxonomy and then, for
# each of them, normalize its display text and every one of its synonyms, which meant tens of
# thousands of Unicode NFC normalizations per request. None of that work depends on the string
# being searched for: the same entries are walked in the same order for every query.
#
# The index holds, per taxonomy and per search language, the display text of every entry and the
# normalized synonyms of every entry, so a request is a loop over strings that already exist.
#
# It is deliberately not shared through memcached or redis: the display map of the categories
# taxonomy alone is about 1.2 MB per language in Storable, which is larger than the default
# memcached item size, and a shared cache would turn a pointer dereference into a multi-megabyte
# read on every keystroke. Workers are long lived, so one copy per process is cheaper.
#
# It also holds no product data: the entries come from the taxonomy, and the only suggestions that
# depend on products - packaging shapes and materials - are read from a separate precomputed file.
# It therefore only goes stale if the taxonomies are rebuilt inside the same process, which is
# what build_all_taxonomies() does, and operators can drop it with clear_suggestions_index().

my %suggestions_index = ();
my @suggestions_index_order = ();

# How many (taxonomy, language) indexes to keep. A handful of languages are hot at a time, and
# the categories taxonomy is the largest at about 1.2 MB per language, so this bounds the memory
# a worker spends on this at roughly 10 MB.
my $suggestions_index_max = 8;

=head2 clear_suggestions_index()

Drop the per-process index of taxonomy entries used to answer suggestion requests. Call it after
rebuilding the taxonomies in a process that also serves suggestions, otherwise the process keeps
answering from the entries it had indexed before the rebuild.

=cut

sub clear_suggestions_index() {
	%suggestions_index = ();
	@suggestions_index_order = ();
	return;
}

sub _build_suggestions_index ($tagtype, $search_lc, $tags_ref) {

	my @entries = ();

	foreach my $canon_tagid (@$tags_ref) {

		my $tag = display_taxonomy_tag($search_lc, $tagtype, $canon_tagid);
		my $tag_xx = display_taxonomy_tag("xx", $tagtype, $canon_tagid);

		# Synonyms in the search language, and in the wildcard xx: language. Each one is
		# normalized in the search language, which is what best_match() matched before.
		my @synonyms = map {
			my $synonym = $_;
			[get_string_id_for_lang($search_lc, $synonym), $synonym]
		} (
			@{deep_get(\%synonyms_for, $tagtype, $search_lc, get_string_id_for_lang($search_lc, $tag)) || []},
			@{deep_get(\%synonyms_for, $tagtype, "xx", get_string_id_for_lang("xx", $tag_xx)) || []}
		);

		push @entries, {tagid => $canon_tagid, tag => $tag, synonyms => \@synonyms};
	}

	return \@entries;
}

sub _get_suggestions_index ($tagtype, $search_lc, $tags_ref) {

	my $key = join("\t", $tagtype, $search_lc);

	if (not exists $suggestions_index{$key}) {

		$suggestions_index{$key} = _build_suggestions_index($tagtype, $search_lc, $tags_ref);
		push @suggestions_index_order, $key;

		# keep the memory bounded: drop the index that was added first
		if (scalar(@suggestions_index_order) > $suggestions_index_max) {
			delete $suggestions_index{shift @suggestions_index_order};
		}

		$log->debug(
			"built the suggestions index",
			{
				tagtype => $tagtype,
				search_lc => $search_lc,
				entries => scalar(@{$suggestions_index{$key}})
			}
		) if $log->is_debug();
	}

	return $suggestions_index{$key};
}

# best_match is used to see how well matches the best matching synonym

sub best_match ($stringid, $fuzzystringid, $synonyms_ref) {

	my $best_type = "none";
	my $best_match = 0;

	# $synonyms_ref is a list of [$normalized_synonym, $synonym] pairs, as built by
	# _get_suggestions_index(): the normalized form of a synonym does not depend on the query
	foreach my $synonym_pair_ref (@$synonyms_ref) {
		my ($synonymid, $synonym) = @{$synonym_pair_ref};
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

	# Callers can pass any list of entries, so index exactly that list rather than a cached one
	return _filter_suggestions(_build_suggestions_index($tagtype, $search_lc, $tags_ref),
		$tags_ref, $tagtype, $search_lc, $string, $options_ref);
}

sub _filter_suggestions ($index_ref, $tags_ref, $tagtype, $search_lc, $string, $options_ref) {

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

		foreach my $entry_ref (@$index_ref) {
			my $canon_tagid = $entry_ref->{tagid};
			# just_synonyms are not real entries
			next if defined $just_synonyms{$tagtype}{$canon_tagid};

			my $tag = $entry_ref->{tag};
			my $synonyms = $entry_ref->{synonyms};

			# check how well the synonyms match the input string
			my $best_match = best_match($stringid, $fuzzystringid, $synonyms);

			$log->debug(
				"synonyms for canon_tagid",
				{
					tagtype => $tagtype,
					canon_tagid => $canon_tagid,
					tag => $tag,
					synonyms => $synonyms,
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
