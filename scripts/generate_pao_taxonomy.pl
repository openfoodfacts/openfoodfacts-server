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

use Modern::Perl '2017';

open(my $IN, q{<}, "periods_after_opening_logo.svg") or die;
my $svg = join("", (<$IN>));
close($IN);

my $entry_format_month = <<TXT
en:<i> months, <i>months
fr:<i> mois, <i>mois
xx:<i> M, <i>M, <i>, <i> months, <i> month, <i>months, <i>month
numeric_number_of_months_after_opening:en:<i>
TXT
	;

my $entry_format_day = <<TXT
en:<i> days, <i>days
fr:<i> jours, <i>jours, <i> jour, <i>jour
xx:<i> D, <i>D, <i> days, <i> day, <i>days, <i>day
numeric_number_of_days_after_opening:en:<i>
TXT
	;

my $image_path = "/home/off/openfoodfacts-server/html/images/lang/en/periods_after_opening";

for (my $i = 1; $i <= 4 * 12; $i++) {

	my $entry = $entry_format_month;
	$entry =~ s/<i>/$i/g;
	$entry =~ s/:1 months, 1months/:1 month, 1month/;
	print $entry . "\n";

	# generate SVG logo
	my $isvg = $svg;
	$isvg =~ s/49 M/$i M/;

	my $file = "$image_path/$i-months.90x90.svg";
	$file =~ s/^1-months/1-month/;

	open(my $OUT, q{>}, "$file") or die;
	print $OUT $isvg;
	close $OUT;
}

for (my $i = 1; $i <= 2 * 30; $i++) {

	my $entry = $entry_format_day;
	$entry =~ s/<i>/$i/g;
	$entry =~ s/:1 jours, 1jours/:1 jour, 1jour/;
	$entry =~ s/:1 days, 1days/:1 day, 1day/;
	print $entry . "\n";

	# generate SVG logo
	my $isvg = $svg;
	$isvg =~ s/49 M/$i D/;

	my $file = "$image_path/$i-days.90x90.svg";
	$file =~ s/^1-days/1-day/;

	open(my $OUT, q{>}, "$file") or die;
	print $OUT $isvg;
	close $OUT;
}
