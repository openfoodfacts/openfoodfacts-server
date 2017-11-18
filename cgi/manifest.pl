#!/usr/bin/perl -w

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
use ProductOpener::URL qw/:all/;
use ProductOpener::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();

my $short_name = lang("site_name");
my $long_name = $short_name;

# http://stackoverflow.com/a/16533563/11963
$short_name =~ s/\b([A-Z])[a-z]+(?=\s+[A-Z][a-z])|\G(?!^)\s+([A-Z])[a-z]+/$1$2/g;

if ($cc eq 'world') {
	$long_name .= " " . uc($lc);
	$short_name .= " " . uc($lc);
}
else {
	$long_name .= " " . uc($cc) . "/" . uc($lc);
	$short_name .= " " . uc($cc) . "/" . uc($lc);
}

my %manifest;
$manifest{lang} = $lc;
$manifest{name} = $long_name;
$manifest{short_name} = $short_name;
$manifest{description} = lang('site_description');
$manifest{start_url} = format_subdomain($subdomain);
$manifest{scope} = '/';
$manifest{display} = 'standalone';

my @keys = qw(theme_color icons related_applications background_color);
foreach my $key (@keys) {
	$manifest{$key} = $options{manifest}{$key} if $options{manifest}{$key};
}

my $data = encode_json(\%manifest);
	
print "Content-Type: application/manifest+json; charset=UTF-8\r\nCache-Control: max-age=86400\r\n\r\n" . $data;

