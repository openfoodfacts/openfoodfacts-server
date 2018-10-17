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

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;



binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $english = "";
my $others = "";

while (<STDIN>) {

	my $line = $_;
	
	if ($line =~ /^(\w\w):(.*)$/) {
		my $lc = $1;
		if ($lc eq "en") {
			$english = $line;
		}
		else {
			$others .= $line;
		}
	}
	else {
	
		print $english;
		print $others;
		print $line;
		$english = "";
		$others = "";
	}
	
}

print $english;
print $others;


