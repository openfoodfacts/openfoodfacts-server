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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

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
use ProductOpener::Lang qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
# load all tags hierarchies

print STDERR "Tags.pm - exporting tags hierarchies\n";
opendir DH2, "$data_root/lang" or die "Couldn't open $data_root/lang : $!";
foreach my $langid (readdir(DH2)) {
	next if $langid eq '.';
	next if $langid eq '..';
	print STDERR "Tags.pm - reading tagtypes for lang $langid\n";
	next if ((length($langid) ne 2) and not ($langid eq 'other'));

	if (-e "$data_root/lang/$langid/tags") {
		opendir DH, "$data_root/lang/$langid/tags" or die "Couldn't open the current directory: $!";
		foreach my $tagtype (readdir(DH)) {
			next if $tagtype !~ /(.*)\.txt/;
			$tagtype = $1;
			print STDERR "Tags: exporting tagtype $langid/$tagtype\n";	
			$lc = $langid;			
			export_tags_hierarchy($langid, $tagtype);
		}
		closedir(DH);
	}

	
}
closedir(DH2);

exit(0);

