#!/usr/bin/perl

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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


use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Tags qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

Blogs::Display::init();
use Blogs::Lang qw/:all/;


my $tagtype = param('tagtype');
my $string = decode utf8=>param('string');
my $term = decode utf8=>param('term');
my $stringid = get_fileid($string) . get_fileid($term);

if (defined param('lc')) {
	$lc = param('lc');
}

my @tags = sort keys %{$translations_to{$tagtype}} ;

my @suggestions = ();

my $i = 0;

foreach my $canon_tagid (@tags) {

	next if not defined $translations_to{$tagtype}{$canon_tagid}{$lc};
	next if defined $just_synonyms{$tagtype}{$canon_tagid};
	my $tag = $translations_to{$tagtype}{$canon_tagid}{$lc};
	my $tagid = get_fileid($tag);
	next if $tagid !~ /^$stringid/;

	push @suggestions, $tag;
}


my $data =  encode_json(\@suggestions);
	
print "Content-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\n\r\n" . $data;	


