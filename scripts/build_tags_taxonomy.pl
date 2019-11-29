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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

my $tagtype = $ARGV[0];
my $publish = $ARGV[1];

print "building taxonomy for $tagtype - publish: $publish\n";

binmode STDERR, ":encoding(UTF-8)";
binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";


my $file = $tagtype . ".txt";

# For the Open Food Facts ingredients taxonomy, concatenate additives, minerals, vitamins, nucleotides and other nutritional substances taxonomies

# For automated tests, the domain is off.travis-ci.org

if (($tagtype eq "ingredients") and ($server_domain =~ /openfoodfacts|off.travis/)) {

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
			print STDERR "Missing $data_root/taxonomies/$tagtype.txt\n";
		}
	}

	close ($OUT);
}

build_tags_taxonomy($tagtype, $file, $publish);


exit(0);

