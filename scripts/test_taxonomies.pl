#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;

use Getopt::Long;


my $tag;
my $tagtype = 'labels';
my $taglc = 'fr';
my $targetlc = 'fr';

GetOptions ('tags=s' => \$tag, 'type=s' => \$tagtype, 'taglc=s'=>\$taglc, 'targetlc=s'=>\$targetlc);

#ProductOpener::Display::init();

$lc = $targetlc;

print "canonicalize_taxonomy_tag($taglc,$tagtype,$tag)\n";

print canonicalize_taxonomy_tag($taglc,$tagtype,$tag) . "\n\n";

print "display_taxonomy_tag($targetlc,$taglc,$tagtype,$tag)\n";

print display_taxonomy_tag($targetlc,$tagtype,$tag) . "\n\n";

print "display_taxonomy_tag_link($targetlc,$taglc,$tagtype,$tag)\n";

print display_taxonomy_tag_link($targetlc,$tagtype,$tag) . "\n\n";

print "canonicalize_tag_link($tagtype,$tag)\n";

print canonicalize_tag_link($tagtype,$tag) . "\n\n";

print "gen_tags_hierarchy_taxonomy($taglc, $tagtype, $tag)\n";

my @tags = gen_tags_hierarchy_taxonomy($taglc,$tagtype, $tag);

foreach my $t (@tags) {

	print "> $t - " . canonicalize_taxonomy_tag($taglc,$tagtype, $t) . "\n";
}

print "\n";
print "display_tags_hierarchy_taxonomy\n";
print display_tags_hierarchy_taxonomy($targetlc,$tagtype, \@tags) . "\n";

print "\ndisplay_parents_and_children($targetlc,$tagtype,$tag)\n";

print display_parents_and_children($targetlc,$tagtype,$tag) . "\n";

exit(0);

