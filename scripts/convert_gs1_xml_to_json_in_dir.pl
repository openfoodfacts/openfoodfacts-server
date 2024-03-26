#!/usr/bin/perl -w

# Perl script to convert XML received from GS1 to JSON files, more easily processed

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

use strict;
use utf8;
use warnings;

use ProductOpener::GS1 qw/:all/;

my $dir = $ARGV[0];

if (not defined $dir) {
	die("Missing directory parameter.");
}

opendir(my $dh, $dir) or die("Could not open the $dir directory: $!\n");

foreach my $file (sort(readdir($dh))) {

	next if $file !~ /\.xml$/;
	$file = $`;    # remove xml extension

	convert_gs1_xml_file_to_json("$dir/$file.xml", "$dir/$file.json");
}
