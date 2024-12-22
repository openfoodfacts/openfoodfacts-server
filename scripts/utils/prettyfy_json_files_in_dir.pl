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

# Script used to prettify a JSON file in the same way we use for expected outputs in tests.

# Used to convert JSON files from convert_gs1_xml_to_json.js (without spaces or line breaks)

use strict;
use utf8;
use warnings;

use JSON;

my $dir = $ARGV[0];

if (not defined $dir) {
	die("Missing directory parameter.");
}

opendir(my $dh, $dir) or die("Could not open the $dir directory: $!\n");

my $json = JSON->new->allow_nonref->canonical;

foreach my $file (sort(readdir($dh))) {

	next if $file !~ /\.json$/;

	if (open(my $json_in, "<:encoding(UTF-8)", "$dir/$file")) {

		local $/;    #Enable 'slurp' mode
		my $json_ref = $json->decode(<$json_in>);

		close($json_in);

		if (open(my $json_out, ">:encoding(UTF-8)", "$dir/$file")) {
			my $pretty_json = $json->pretty->encode($json_ref);
			print $json_out $pretty_json;
			close($json_out);
		}
		else {
			print STDERR "could not write $dir/$file: $!\n";
		}
	}
	else {
		print STDERR "could not read $dir/$file: $!\n";
	}
}

