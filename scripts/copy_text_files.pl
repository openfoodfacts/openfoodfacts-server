#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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
use utf8;

#use ProductOpener::Config qw/:all/;
#use ProductOpener::Store qw/:all/;

my %files = (
"nova-groups-for-food-processing.html" => "nova.html",
"experimental-nutrition-score-france.html" => "nutriscore.html",
);

my $source = $ARGV[0];
my $target = $ARGV[1];

print STDERR "Copying selected text files from source dir $source to target dir $target\n";


opendir DH, "$source/lang" or die "Couldn't open the current directory: $!";
my @langs = sort(readdir(DH));
closedir(DH);

foreach my $lang (@langs)
{
	next if $lang eq "." or $lang eq "..";
	next if $lang eq "fr";

	if (-e "$source/lang/$lang/texts") {
		foreach my $file (sort keys %files) {
			if (-e "$source/lang/$lang/texts/$file") {

				(-e "$target/lang/$lang") or mkdir("$target/lang/$lang", 0755);
				(-e "$target/lang/$lang/texts") or mkdir("$target/lang/$lang/texts", 0755);
				my $cmd = "cp -a $source/lang/$lang/texts/$file $target/lang/$lang/texts/$files{$file}";
				system($cmd);
				print STDERR "$cmd\n";
			}
		}
	}
}
exit(0);

