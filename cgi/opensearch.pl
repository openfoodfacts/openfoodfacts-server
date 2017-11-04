#!/usr/bin/perl

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2016 Association Open Food Facts
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

use Modern::Perl '2012';
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
use ProductOpener::URL qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;

# https://developer.mozilla.org/en-US/Add-ons/Creating_OpenSearch_plugins_for_Firefox
# Maximum of 16 characters
my $short_name = lang("site_name");
# Maximum of 48 characters
my $long_name = $short_name;
if ($cc eq 'world') {
	$long_name .= " " . uc($lc);
}
else {
	$long_name .= " " . uc($cc) . "/" . uc($lc);
}

my $description = lang("search_description_opensearch");
my $image_tag = $options{opensearch_image};

my $uri = format_subdomain($subdomain);

my $xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
<ShortName>$short_name</ShortName>
<LongName>$long_name</LongName>
<Description>$description</Description>
<Contact>$contact_email</Contact>
<SyndicationRight>open</SyndicationRight>
<AdultContent>false</AdultContent>
<Language>$lc</Language>
<OutputEncoding>UTF-8</OutputEncoding>
<InputEncoding>UTF-8</InputEncoding>
$image_tag
<Url type="text/html" method="GET" template="$uri/cgi/search.pl?search_terms={searchTerms}&amp;search_simple=1&amp;action=process" />
<Url type="application/rss+xml" method="GET" template="$uri/cgi/search.pl?search_terms={searchTerms}&amp;search_simple=1&amp;action=process&amp;page={startPage?}&amp;page_size={count?}&amp;rss=1" />
<Url type="application/opensearchdescription+xml" rel="self" template="$uri/cgi/opensearch.pl" />
</OpenSearchDescription>
XML
;

print header( -type => 'application/opensearchdescription+xml', -charset => 'utf-8', -access_control_allow_origin => '*', -cache_control => 'public, max-age: 10080' ) . $xml;
