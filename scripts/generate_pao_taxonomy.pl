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

open (my $IN, q{<}, "periods_after_opening_logo.svg") or die ;
my $svg = join ("",(<$IN>));
close($IN);

my $entry_format = <<TXT
en:<i> months, <i>months, <i> M, <i>M, <i>
fr:<i> mois, <i>mois
numeric_number_of_months_after_opening:en:<i>
TXT
;

my $image_path = "/home/obf/html/images/lang/en/periods_after_opening";

for (my $i = 1; $i <= 4 * 12; $i++) {

	my $entry = $entry_format;
	$entry =~ s/<i>/$i/g;
	print $entry . "\n";
	
	# generate SVG logo
	my $isvg = $svg;
	$isvg =~ s/49 M/$i M/;
	
	my $file = "$image_path/$i-months.90x90.svg";
	$file =~ s/^1-months/1-month/;
	
	open (my $OUT, q{>}, "$file") or die;
	print $OUT $isvg;
	close $OUT;
	
}
