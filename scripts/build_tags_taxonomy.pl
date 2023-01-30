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
use utf8;

# Prevent taxonomies from being loaded in ProductOpener::Tags
BEGIN {
	$ENV{'SKIP_TAXONOMY_LOAD'} = 'Yes';
}

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;
use Digest::SHA1;
use File::Copy;
use File::Basename;

my $tagtype = $ARGV[0] // '*';
my $publish = $ARGV[1] // 1;

my @taxonomies = ($tagtype);
if ($tagtype eq '*') {
	@taxonomies = qw(
		additives
		additives_classes
		allergens
		amino_acids
		categories
		countries
		data_quality
		food_groups
		improvements
		ingredients
		ingredients_analysis
		ingredients_processing
		labels
		languages
		minerals
		misc
		nova_groups
		nucleotides
		nutrients
		nutrient_levels
		origins
		other_nutritional_substances
		packaging
		packaging_materials
		packaging_recycling
		packaging_shapes
		periods_after_opening
		preservation
		states
		vitamins
	)
}
foreach my $taxonomy (@taxonomies) {
	build_taxonomy($taxonomy,$publish);
}

exit(0);

sub build_taxonomy {
	my ($tagtype, $publish) = @_;

	print "building taxonomy for $tagtype - publish: $publish\n";

	binmode STDERR, ":encoding(UTF-8)";
	binmode STDIN, ":encoding(UTF-8)";
	binmode STDOUT, ":encoding(UTF-8)";

	my $file = $tagtype . ".txt";

	# The nutrients_taxonomy.txt source file is created from values in the .po files
	if ($tagtype eq "nutrient_levels") {
		create_nutrients_level_taxonomy();
	}

	my @files = ();

	# For the origins taxonomy, include the countries taxonomy

	if ($tagtype eq "origins") {

		@files = ("countries", "origins");
	}

	# For the Open Food Facts ingredients taxonomy, concatenate additives, minerals, vitamins, nucleotides and other nutritional substances taxonomies

	elsif (($tagtype eq "ingredients") and (defined $options{product_type}) and ($options{product_type} eq "food")) {

		@files = (
			"additives_classes", "additives", "minerals", "vitamins",
			"nucleotides", "other_nutritional_substances", "ingredients"
		);
	}

	# Packaging

	elsif (($tagtype eq "packaging")) {

		@files = ("packaging_materials", "packaging_shapes", "packaging_recycling", "preservation");
	}

	# Concatenate taxonomy files if needed

	if ((scalar @files) > 0) {

		$file = "$tagtype.all.txt";

		open(my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/$file")
			or die("Cannot write $data_root/taxonomies/$file : $!\n");

		foreach my $taxonomy (@files) {

			if (open(my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$taxonomy.txt")) {

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

		close($OUT);
	}

	my $sha1 = Digest::SHA1->new;
	if (open(my $IN, "<", "$data_root/taxonomies/$file")) {
		binmode($IN);
		$sha1->addfile($IN);
		close($IN);

		my $hash = $sha1->hexdigest;
		(-e "$data_root/cache") or mkdir("$data_root/cache", 0755);

		if (-e "$data_root/cache/$tagtype.result.$hash.sto") {
			copy("$data_root/cache/$tagtype.result.$hash.txt", "$data_root/taxonomies/$tagtype.result.txt");
			copy("$data_root/cache/$tagtype.result.$hash.sto", "$data_root/taxonomies/$tagtype.result.sto");
			copy("$data_root/cache/$tagtype.$hash.json", "$www_root/data/taxonomies/$tagtype.json");
			print "obtained taxonomy for $tagtype from cache.\n";
		}
		else {
			build_tags_taxonomy($tagtype, $file, $publish);

			copy("$data_root/taxonomies/$tagtype.result.txt", "$data_root/cache/$tagtype.result.$hash.txt");
			if ($publish) {
				copy("$data_root/taxonomies/$tagtype.result.sto", "$data_root/cache/$tagtype.result.$hash.sto");
			}
			copy("$www_root/data/taxonomies/$tagtype.json", "$data_root/cache/$tagtype.$hash.json");
		}
	}
	else {
		print STDERR "Missing $data_root/taxonomies/$file\n";
	}
}

