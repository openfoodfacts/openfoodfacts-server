#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

my $tagtype = $ARGV[0];
my $publish = $ARGV[1];

(defined $tagtype) or die '$tagtype not defined, exited';
(defined $publish) or die '$publish not defined, exited';

print "building taxonomy for $tagtype - publish: $publish\n";

binmode STDERR, ":encoding(UTF-8)";
binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";


my $file = $tagtype . ".txt";

# The nutrients_taxonomy.txt source file is created from values in the .po files
if ($tagtype eq "nutrient_levels") {
	create_nutrients_level_taxonomy();
}

# For the Open Food Facts ingredients taxonomy, concatenate additives, minerals, vitamins, nucleotides and other nutritional substances taxonomies

if (($tagtype eq "ingredients") and (defined $options{product_type}) and ($options{product_type} eq "food")) {

	$file = "ingredients.all.txt";

	open (my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/$file") or die("Cannot write $data_root/taxonomies/$file : $!\n");

	foreach my $taxonomy ("additives_classes", "additives", "minerals", "vitamins", "nucleotides", "other_nutritional_substances", "ingredients") {

		if (open (my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$taxonomy.txt")) {

			print $OUT "# $taxonomy.txt\n\n";

			while (<$IN>) {
				print $OUT $_;
			}

			print $OUT "\n\n";
			close($IN);
		}
		else {
			print STDERR "Missing $data_root/taxonomies/$taxonomy.txt\n";
		}
	}

	close ($OUT);
}

build_tags_taxonomy($tagtype, $file, $publish);


exit(0);

