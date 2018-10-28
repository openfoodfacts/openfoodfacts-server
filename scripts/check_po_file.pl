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

use strict;
use utf8;
use warnings;

my $file = $ARGV[0];

if (not defined $file) {
	print STDERR "Pass path to .po file to test as first argument.\n";
	exit(1);
}

print STDERR "Testing $file .po file";


open (my $IN, "<:encoding(UTF-8)", "$file") or die("Could not read $file: $!");
my @lines = (<$IN>);
close ($IN);

my %vars = ();
my $key;

my $errors = 0;

foreach my $line (@lines) {

	if ($line =~ /^(msgctxt|msgstr|msgid)\s+"(.*)"/) {
		$key = $1;
		my $value = $2;
		if ($key eq "msgctxt") {
		
			if (defined $vars{"msgctxt"}) {
			
				# check that we do not have an empty value for the previous msgctxt
				
				if ((not defined $vars{"msgstr"}) or ($vars{"msgstr"} eq "")) {
					print STDERR "Error: empty msgstr string for msgctxt " . $vars{"msgctxt"} . " - msgid " . $vars{"msgid"} . "\n";
					$errors++;
				}
			
			}
		
			%vars = ();
			
	
		}
		defined $vars{$key} or $vars{$key} = "";
		$vars{$key} .= $value;
	}

}

print STDERR "$errors errors\n";
exit($errors);
