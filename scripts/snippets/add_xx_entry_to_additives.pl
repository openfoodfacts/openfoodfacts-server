#!/usr/bin/perl -w

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

# This scripts adds a xx: entry to additives in the additives taxonomy
# with the e-number of the additive

# Usage: ./add_xx_entry_to_additives.pl < additives.txt > additives.xx.txt

use ProductOpener::PerlStandards;

my $e_number;

while (my $line = <STDIN>) {

	if ($line =~ /^\w\w:(E(?:[^,]+))/) {
		$e_number = $1;
		chomp($e_number);
	}
	if ((defined $e_number) and (($line =~ /^\s*$/) or ($line =~ /^(#|e_number:|wikidata|efsa)/))) {
		print "xx:$e_number\n";
		$e_number = undef;
	}

	print $line;
}
