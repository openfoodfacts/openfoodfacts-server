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

use Modern::Perl '2017';
use utf8;

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

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();

my $tagtype = param('tagtype');
my $string = decode utf8=>param('string');
my $term = decode utf8=>param('term');

my $search_lc = $lc;

if (defined param('lc')) {
	$search_lc = param('lc');
}

my $original_lc = $search_lc;

if ($term =~ /^(\w\w):/) {
	$search_lc = $1;
	$term = $';
}

my @suggestions = (); # Suggestions starting with the term
my @suggestions_c = (); # Suggestions containing the term

my $cache_max_age = 0;
my $limit = 25;
my $i = 0;
if ($tagtype eq 'emb_codes') {
	my $stringid = get_string_id_for_lang("no_language", normalize_packager_codes($term));
	my @tags = sort keys %packager_codes;
	foreach my $canon_tagid (@tags) {
		next if $canon_tagid !~ /^$stringid/;
		push @suggestions, normalize_packager_codes($canon_tagid);
		last if ++$i >= $limit;
	}
	$cache_max_age = 3600;
}
else {
	my $stringid = get_string_id_for_lang($search_lc, $string) . get_string_id_for_lang($search_lc, $term);
	my @tags = sort keys %{$translations_to{$tagtype}} ;
	foreach my $canon_tagid (@tags) {
		
		next if defined $just_synonyms{$tagtype}{$canon_tagid};
		
		my $tag;
		my $tagid;
		
		if (defined $translations_to{$tagtype}{$canon_tagid}{$search_lc}) {
		
			$tag = $translations_to{$tagtype}{$canon_tagid}{$search_lc};
			$tagid = get_string_id_for_lang($search_lc, $tag);
			
			if (not ($search_lc eq $original_lc)) {
				$tag = $search_lc . ":" . $tag;
			}
		}
		elsif (defined $translations_to{$tagtype}{$canon_tagid}{xx}) {
			$tag = $translations_to{$tagtype}{$canon_tagid}{xx};
			$tagid = get_string_id_for_lang("xx", $tag);
		}
		
		if (defined $tag) {
		
			next if $tagid !~ /$stringid/;
			
			if ($tag =~ /^$stringid/i) {
				push @suggestions, $tag;
			}
			else {
				push @suggestions_c, $tag;
			}
			last if ++$i >= $limit;
		}
	}
	$cache_max_age = 3600;
}
push @suggestions, @suggestions_c;
my $data =  encode_json(\@suggestions);

print header(
	-type => 'application/json',
	-charset => 'utf-8',
	-access_control_allow_origin => '*'
);
if ($cache_max_age) {
	print header(
		-cache_control => 'public, max-age=' . $cache_max_age,
	);
}
print $data;
