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
use ProductOpener::Index qw/:all/;
use Getopt::Long;

use XML::FeedPP;

use POSIX qw(locale_h);
use locale;
setlocale( LC_CTYPE, "fr_FR" );    # May need to be changed depending on system

my $rss;

GetOptions ('rss=s' => \$rss);

if (not defined $rss) {
	print STDERR "Specify the RSS url via --rss\n";
	exit;
}

open(my $OUT, ">:encoding(UTF-8)", "$data_root/texts/blog.html");
open(my $OUT2, ">:encoding(UTF-8)", "$data_root/texts/blog_foundation.html");



my $feed = XML::FeedPP->new($rss);

my $html = '';
my $html2 = '';

my $i = 5;

foreach my $entry ($feed->get_item()) {
		
	$html .= "&rarr; <a href=\"" . $entry->link . "\">" . decode_html_entities($entry->title) . "</a><br />";
	$html2 .= "<li><a href=\"" . $entry->link . "\">" . decode_html_entities($entry->title) . "</a></li>\n";
	$i--;
	$i == 0 and last;
}

print $OUT $html;
print $OUT $html2;

close($OUT);
close($OUT2);

exit(0);

