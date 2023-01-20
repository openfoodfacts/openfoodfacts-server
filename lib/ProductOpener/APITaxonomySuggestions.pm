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

ProductOpener::APITaxonomySuggestions - suggests taxonomy entries for dropdown, autocomplete etc.

=head1 DESCRIPTION

=cut

package ProductOpener::APITaxonomySuggestions;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&taxonomy_suggestions_api
		&get_taxonomy_suggestions
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;

use List::Util qw/min/;
use Data::DeepAccess qw(deep_exists deep_get);
use Encode;

=head2 taxonomy_suggestions_api ( $request_ref )

Process API V3 taxonomy suggestions requests.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub taxonomy_suggestions_api ($request_ref) {

	$log->debug("taxonomy_suggestions_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# We need a taxonomy name to provide suggestions for
	my $tagtype = request_param($request_ref, "tagtype");

	if (not defined $tagtype) {
		$log->info("missing tagtype", {tagtype => $tagtype}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "missing_tagtype"},
				field => {id => "tagtype", value => $tagtype},
				impact => {id => "failure"},
			}
		);
		$response_ref->{result} = {id => "unable_to_provide_suggestions"};
	}
	# Check that the taxonomy exists
	# we also provide suggestions for emb-codes (packaging codes)
	elsif ((not defined $taxonomy_fields{$tagtype}) and ($tagtype ne "emb_codes")) {
		$log->info("tagtype is not a taxonomy", {tagtype => $tagtype}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "invalid_tagtype"},
				field => {id => "tagtype", value => $tagtype},
				impact => {id => "failure"},
			}
		);
		$response_ref->{result} = {id => "unable_to_provide_suggestions"};
	}
	# Generate suggestions
	else {
		$response_ref->{suggestions}
			= [get_taxonomy_suggestions($request_ref)];
	}

	$log->debug("taxonomy_suggestions_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

my $categories_packagings_stats_for_suggestions_ref;

sub load_categories_packagings_stats_for_suggestions() {
	if (not defined $categories_packagings_stats_for_suggestions_ref) {
		my $file = "$data_root/data/categories_stats/categories_packagings_stats.all.popular.sto";
		if (!-e $file) {
			my $default_file = "$data_root/data-default/categories_stats/categories_packagings_stats.all.popular.sto";
			$log->debug("local packaging stats file does not exist, will use default",
				{file => $file, default_file => $default_file})
				if $log->is_debug();
			$file = $default_file;
		}
		$log->debug("loading packaging stats", {file => $file}) if $log->is_debug();
		$categories_packagings_stats_for_suggestions_ref = retrieve($file);
		if (not defined $categories_packagings_stats_for_suggestions_ref) {
			$log->debug("unable to load packaging stats", {file => $file}) if $log->is_debug();
		}
	}
	return;
}

=head2 get_taxonomy_suggestions ($request_ref)

Generate taxonomy suggestions.

=head3 Parameters

=head4 $request_ref

The suggestions will depend on parameters passed in $request_ref:

- lc: language of parameters (categories, shape, material etc.) and of the returned suggestions
- country: derived from the cc parameter
- tagtype: the taxonomy id
- string or term: the string to query ("term" is used by default by jquery autocomplete and select2)
- categories: comma separated list of categories

=cut

sub get_taxonomy_suggestions ($request_ref) {

	# Search language
	my $search_lc = $request_ref->{lc};

	# Taxonomy
	my $tagtype = request_param($request_ref, "tagtype");

	# The API accepts a string input in the "string" field or "term" field.
	# - term is used by the jquery Autocomplete widget: https://api.jqueryui.com/autocomplete/
	# Use "string" only if both are present.
	my $string = decode("utf8", (request_param($request_ref, 'string') || request_param($request_ref, 'term')));

	# max results
	my $limit = 25;
	# superseed by request parameter
	if (defined request_param($request_ref, 'limit')) {
		# we put a hard limit however
		$limit = min(int(request_param($request_ref, 'limit')), 400);
	}

	my @tags = generate_sorted_list_of_taxonomy_entries($request_ref, $tagtype, $limit);

	return filter_suggestions_matching_string($search_lc, $tagtype, $string, $limit, \@tags);
}

=head2 generate_sorted_list_of_taxonomy_entries($request_ref, $tagtype, $limit)

Generate a sorted list of canonicalized taxonomy entries from which we will generate suggestions

=cut

sub generate_sorted_list_of_taxonomy_entries ($request_ref, $tagtype, $limit) {

	my $search_lc = $request_ref->{lc};
	my @tags = ();
	my %seen_tags = ();    # Used to not add the same tag several times

	# search for emb codes
	if ($tagtype eq 'emb_codes') {
		@tags = sort keys %packager_codes;
	}
	# search for string in a taxonomy
	else {
		# For packaging shapes and materials, we will generate the most popular suggestions
		# for the country, product categories, and shape
		if (($tagtype eq "packaging_shapes") or ($tagtype eq "packaging_materials")) {
			load_categories_packagings_stats_for_suggestions();

			# Country for the request (set with the cc field or the subdomain)
			my $country = $request_ref->{country};

			# We will try to provide popular suggestions for the product categories
			my @categories = ("all");    # popular suggestions for all categories

			# If categories are provided, add them (most generic categories first)
			if (defined request_param($request_ref, "categories")) {
				push @categories,
					gen_tags_hierarchy_taxonomy($search_lc, "categories",
					decode("utf8", request_param($request_ref, "categories")));
			}

			# Start with the most specific category
			foreach my $category (reverse @categories) {

				if ($tagtype eq "packaging_shapes") {
					my $shapes_ref = deep_get(
						$categories_packagings_stats_for_suggestions_ref,
						("countries", $country, "categories", $category, "shapes")
					);

					add_sorted_entries_to_tags(\@tags, \%seen_tags, $shapes_ref, $tagtype, $search_lc);
				}
				elsif ($tagtype eq "packaging_materials") {
					# Add materials specific to the shape if we have one
					my $shape = decode("utf8", request_param($request_ref, "shape"));
					if (defined $shape) {
						$shape = canonicalize_taxonomy_tag($request_ref->{lc}, "packaging_shapes", $shape);
					}
					else {
						$shape = "all";
					}
					my $materials_ref = deep_get($categories_packagings_stats_for_suggestions_ref,
						("countries", $country, "categories", $category, "shapes", $shape, "materials"));

					add_sorted_entries_to_tags(\@tags, \%seen_tags, $materials_ref, $tagtype, $search_lc);
				}
			}

			$log->debug("resulting tags from categories", {categories => \@categories, tags => \@tags})
				if $log->is_debug();
		}

		# add all remaining entries in alphabetical order
		foreach my $tag (
			sort(
				{($translations_to{$tagtype}{$a}{$search_lc} || $translations_to{$tagtype}{$a}{"xx"} || $a)
						cmp($translations_to{$tagtype}{$b}{$search_lc} || $translations_to{$tagtype}{$b}{"xx"} || $b)}
				keys %{$translations_to{$tagtype}})
			)
		{
			next if defined $seen_tags{$tag};
			push @tags, $tag;
		}
	}

	return @tags;
}

=head2 add_sorted_entries_to_tags($tags_ref, $seen_tags_ref, $entries_ref, $tagtype, $search_lc)

Add packaging entries (shapes or materials) sorted by frequency for a specific country, category and shape (for materials)

=cut

sub add_sorted_entries_to_tags ($tags_ref, $seen_tags_ref, $entries_ref, $tagtype, $search_lc) {

	if (defined $entries_ref) {
		foreach my $entry (
			sort(
				{$entries_ref->{$b}{n} <=> $entries_ref->{$a}{n}
						|| (
						($translations_to{$tagtype}{$a}{$search_lc} || $translations_to{$tagtype}{$a}{"xx"} || $a)
						cmp($translations_to{$tagtype}{$b}{$search_lc} || $translations_to{$tagtype}{$b}{"xx"} || $b))}
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

=head2 filter_suggestions_matching_string ($search_lc, $tagtype, $string, $limit, $tags_ref)

Filter a list of potential taxonomy suggestions matching a string.

By priority, the function returns:
- taxonomy entries that match the input string at the beginning
- taxonomy entries that contain the input string
- taxonomy entries that contain words contained in the input string

=head3 Parameters

=head4 $search_lc - language code of taxonomy suggestions to return

=head4 $tagtype - the type of tag

=head4 $string - string to search

=head4 $limit - limit of number of results

=head4 $tags_ref - reference to an array of tags that needs to be filtered

=cut

sub filter_suggestions_matching_string ($search_lc, $tagtype, $string, $limit, $tags_ref) {

	my $original_lc = $search_lc;

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
			push @suggestions, normalize_packager_codes($canon_tagid);
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
		# fuzzy match whole words with eventual inter-words
		my $fuzzystringid = join(".*", split("-", $stringid));

		foreach my $canon_tagid (@$tags_ref) {
			# just_synonyms are not real entries
			next if defined $just_synonyms{$tagtype}{$canon_tagid};

			my $tag;    # this is the content string
			my $tagid;    # this is the tag

			# search if the tag exists in target language
			if (defined $translations_to{$tagtype}{$canon_tagid}{$search_lc}) {

				$tag = $translations_to{$tagtype}{$canon_tagid}{$search_lc};
				# TODO: explain why $tagid can be different from $canon_tagid
				$tagid = get_string_id_for_lang($search_lc, $tag);

				# add language prefix if we are not searching current interface language
				if (not($search_lc eq $original_lc)) {
					$tag = $search_lc . ":" . $tag;
				}
			}
			# also search for special language code "xx" which is universal
			elsif (defined $translations_to{$tagtype}{$canon_tagid}{xx}) {
				$tag = $translations_to{$tagtype}{$canon_tagid}{xx};
				$tagid = get_string_id_for_lang("xx", $tag);
			}

			if (defined $tag) {
				# matching at start, best matches
				if ($tagid =~ /^$stringid/) {
					push @suggestions, $tag;
					# only matches at start are considered
					$suggestions_count++;
				}
				# matching inside
				elsif ($tagid =~ /$stringid/) {
					push @suggestions_c, $tag;
				}
				# fuzzy match
				elsif ($tagid =~ /$fuzzystringid/) {
					push @suggestions_f, $tag;
				}
				# end as soon as we got enough
				last if $suggestions_count >= $limit;
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

=head2 get_taxonomy_suggestions_matching_string ($request_ref, $tagtype, $string)

Generate taxonomy suggestions matching a string.

The generation uses a brute force approach to match the input string to taxonomies.

By priority, the function returns:
- taxonomy entries that match the input string at the beginning
- taxonomy entries that contain the input string
- taxonomy entries that contain words contained in the input string

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head4 tagtype - the type of tag

=head4 tags_ref - reference of an array of tags to match

[
	countries_tags => ["en:france", "en:belgium"],
	categories_tags => ..

]

=head4 string - string to search

=cut

sub get_popular_taxonomy_suggestions_matching_tags_and_string ($request_ref, $tagtype, $tags_ref, $string) {

	# search language code
	my $search_lc = single_param('lc') || $request_ref->{lc};

	# superseed by request parameter
	if (defined single_param('lc')) {
		$search_lc = single_param('lc');
	}

	my $original_lc = $search_lc;

	# if search string begins with a language code, use it for search
	if ($string =~ /^(\w\w):/) {
		$search_lc = $1;
		$string = $';
	}

	# max results
	my $limit = 25;
	# superseed by request parameter
	if (defined single_param('limit')) {
		# we put a hard limit however
		$limit = min(int(single_param('limit')), 400);
	}

	my @suggestions = ();    # Suggestions starting with the string
	my @suggestions_c = ();    # Suggestions containing the string
	my @suggestions_f = ();    # fuzzy suggestions

	my $suggestions_count = 0;

	# search for emb codes
	if ($tagtype eq 'emb_codes') {
		my $stringid = get_string_id_for_lang("no_language", normalize_packager_codes($string));
		my @tags = sort keys %packager_codes;
		foreach my $canon_tagid (@tags) {
			next if $canon_tagid !~ /^$stringid/;
			push @suggestions, normalize_packager_codes($canon_tagid);
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
		# fuzzy match whole words with eventual inter-words
		my $fuzzystringid = join(".*", split("-", $stringid));
		# all tags can be retrieve from the $translations_to hash
		my @tags = sort keys %{$translations_to{$tagtype}};
		foreach my $canon_tagid (@tags) {
			# just_synonyms are not real entries
			next if defined $just_synonyms{$tagtype}{$canon_tagid};

			my $tag;    # this is the content string
			my $tagid;    # this is the tag

			# search if the tag exists in target language
			if (defined $translations_to{$tagtype}{$canon_tagid}{$search_lc}) {

				$tag = $translations_to{$tagtype}{$canon_tagid}{$search_lc};
				# TODO: explain why $tagid can be different from $canon_tagid
				$tagid = get_string_id_for_lang($search_lc, $tag);

				# add language prefix if we are not searching current interface language
				if (not($search_lc eq $original_lc)) {
					$tag = $search_lc . ":" . $tag;
				}
			}
			# also search for special language code "xx" which is universal
			elsif (defined $translations_to{$tagtype}{$canon_tagid}{xx}) {
				$tag = $translations_to{$tagtype}{$canon_tagid}{xx};
				$tagid = get_string_id_for_lang("xx", $tag);
			}

			if (defined $tag) {
				# matching at start, best matches
				if ($tagid =~ /^$stringid/) {
					push @suggestions, $tag;
					# only matches at start are considered
					$suggestions_count++;
				}
				# matching inside
				elsif ($tagid =~ /$stringid/) {
					push @suggestions_c, $tag;
				}
				# fuzzy match
				elsif ($tagid =~ /$fuzzystringid/) {
					push @suggestions_f, $tag;
				}
				# end as soon as we got enough
				last if $suggestions_count >= $limit;
			}
		}
	}
	# sort best suggestions
	@suggestions = sort @suggestions;
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

1;
