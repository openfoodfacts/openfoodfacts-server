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
	print "building taxonomy for $taxonomy - publish: $publish\n";
	build_tags_taxonomy($taxonomy, $publish);
}

exit(0);


