#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use List::Util qw/min/;

my $request_ref = ProductOpener::Display::init_request();

=head1 CGI script to auto-complete entries for tags

=head2 Request parameters

=head3 tagtype - the type of tag

=head3 string - string to search

=head3 term - term to search

If string and term are passed together, they are concatenated together as separate words

=head3 limit - max number of suggestions

Warning, we are currently doing a brute force search, so avoid setting it too high

=cut

my $tagtype = single_param('tagtype');
my $string = decode utf8 => single_param('string');
# searched term
my $term = decode utf8 => single_param('term');

# search language code
my $search_lc = $lc;
# superseed by request parameter
if (defined single_param('lc')) {
	$search_lc = single_param('lc');
}

my $original_lc = $search_lc;

# if search begins with a language code, use it for search
if ($term =~ /^(\w\w):/) {
	$search_lc = $1;
	$term = $';
}

# max results
my $limit = 25;
# superseed by request parameter
if (defined single_param('limit')) {
	# we put a hard limit however
	$limit = min(int(single_param('limit')), 400);
}

my @suggestions = ();    # Suggestions starting with the term
my @suggestions_c = ();    # Suggestions containing the term
my @suggestions_f = ();    # fuzzy suggestions

my $cache_max_age = 0;
my $suggestions_count = 0;

# search for emb codes
if ($tagtype eq 'emb_codes') {
	my $stringid = get_string_id_for_lang("no_language", normalize_packager_codes($term));
	my @tags = sort keys %packager_codes;
	foreach my $canon_tagid (@tags) {
		next if $canon_tagid !~ /^$stringid/;
		push @suggestions, normalize_packager_codes($canon_tagid);
		last if ++$suggestions_count >= $limit;
	}
	# add cache to request
	$cache_max_age = 3600;
}
else {
	# search for term in a taxonomy

	# normalize string and term
	my $stringid = get_string_id_for_lang($search_lc, $string) . "-" . get_string_id_for_lang($search_lc, $term);
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
	# add cache to request
	$cache_max_age = 3600;
}
# sort best suggestions
@suggestions = sort @suggestions;
# suggestions containing term
my $contains_to_add = min($limit - (scalar @suggestions), scalar @suggestions_c) - 1;
if ($contains_to_add >= 0) {
	push @suggestions, @suggestions_c[0 .. $contains_to_add];
}
# Suggestions as fuzzy match
my $fuzzy_to_add = min($limit - (scalar @suggestions), scalar @suggestions_f) - 1;
if ($fuzzy_to_add >= 0) {
	push @suggestions, @suggestions_f[0 .. $fuzzy_to_add];
}
my $data = encode_json(\@suggestions);

# send response
write_cors_headers();
print header(
	-type => 'application/json',
	-charset => 'utf-8',
);
if ($cache_max_age) {
	print header(-cache_control => 'public, max-age=' . $cache_max_age,);
}
print $data;
