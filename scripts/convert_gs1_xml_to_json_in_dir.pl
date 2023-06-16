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

use JSON;
use XML::XML2JSON;

my $dir = $ARGV[0];

if (not defined $dir) {
	die("Missing directory parameter.");
}

opendir(my $dh, $dir) or die("Could not open the $dir directory: $!\n");

my $xml2json = XML::XML2JSON->new(module => 'JSON', pretty => 1, force_array => 0, attribute_prefix => "");

foreach my $file (sort(readdir($dh))) {

	next if $file !~ /\.xml$/;

	open(my $in, "<:encoding(UTF-8)", "$dir/$file") or die("Could not read $dir/$file: $!");
	my $xml = join('', (<$in>));
	close($in);

	my $json = $xml2json->convert($xml);

	# XML2JSON changes the namespace concatenation character from : to $
	# e.g. "allergen_information$allergenInformationModule":
	# it is unwanted, turn it back to : so that we can match the expected input of ProductOpener::GS1
	$json =~ s/([a-z])\$([a-z])/$1:$2/ig;

	# Note: XML2JSON also creates a hash for simple text values. Text values of tags are converted to $t properties.
	# e.g. <gtin>03449862093657</gtin>
	#
	# becomes:
	#
	# gtin: {
	#    $t: "03449865355608"
	# },
	#
	# This is taken care of later by the ProductOpener::GS1::convert_single_text_property_to_direct_value() function

	$file =~ s/\.xml$/.json/;

	open(my $out, ">:encoding(UTF-8)", "$dir/$file") or die("Could not read $dir/$file: $!");
	print $out $json;
	close($out);
}
