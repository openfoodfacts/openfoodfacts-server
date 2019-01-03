#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;


use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use LWP::Simple;
use CGI qw/:cgi :form escapeHTML/;


print header ( -expires=>'-1d', -charset=>'UTF-8');

foreach my $text (sort keys %wiki_texts) {

	print STDERR "update_texts_from_wiki - text: $text\n";

	if ($text =~ /^(.*?)\/(.*)$/) {
		my ($lang, $textid) = ($1, $2);
		
		print "Updating $textid ($lang) from $wiki_texts{$text} - ";
		
		my $content = get($wiki_texts{$text});
		
		if ((defined $content) and ($content =~ /<pre>(.*)<\/pre>/is)) {
			$content = $1;
			$textid = get_fileid($textid);
			$textid =~ s/-foundation/\.foundation/;
			open (my $OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/texts/" . $textid . ".html") or die("could not write $data_root/lang/$lang/texts/ : $!\n");
			print $OUT $content . "\n\n" . "<!-- retrieved from $wiki_texts{$text} on " . display_date(time()) . " -->\n\n";
			close $OUT;			
			print " OK<br/>";
		}
		else {
			print " ERROR\n";
		}
	}

}
