#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::TaxonomySuggestions qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::HTTP qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use JSON::PP;
use Encode;

my $request_ref = ProductOpener::Display::init_request();

my $search_lc = $request_ref->{lc};

# We need a taxonomy name to provide suggestions for
my $tagtype = request_param($request_ref, "tagtype");

# The API accepts a string input in the "string" field or "term" field.
# - term is used by the jquery Autocomplete widget: https://api.jqueryui.com/autocomplete/
# Use "string" only if both are present.
my $string = decode("utf8", (request_param($request_ref, 'string') || request_param($request_ref, 'term')));

# /cgi/suggest.pl supports only limited context (use /api/v3/taxonomy_suggestions to use richer context)
my $context_ref = {country => $request_ref->{country},};

# Options define how many suggestions should be returned, in which format etc.
my $options_ref = {limit => request_param($request_ref, 'limit')};

my @suggestions = get_taxonomy_suggestions($tagtype, $search_lc, $string, $context_ref, $options_ref);

my $data = encode_json(\@suggestions);

# send response
write_cors_headers();

print header(
	-type => 'application/json',
	-charset => 'utf-8',
	-cache_control => 'public, max-age=' . 60,    # 1 minute cache
);

print $data;
