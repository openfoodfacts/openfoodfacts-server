#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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

=head1 NAME

gen_svg_images_for_points.pl - Generates SVG images for positive or negative points for Nutri-Score components

=head1 DESCRIPTION

Each image has a number of squares corresponding to the maximum number of points for the component.
The number of squares filled in green or red (for positive or negative points) corresponds to the number of points for the product.
The remaining squares are filled in grey.

=cut

use ProductOpener::PerlStandards;

# Each square is 6x6 pixels, squares are separated by 1 pixel
# Squares are displayed in one or two rows, with at most 10 squares per row
# The rows are centered vertically in the image
# There is extra padding on top and bottom, so that the image is high enough

sub generate_image ($dir, $type, $points, $max) {

	my $image = <<SVG
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   width="70"
   height="36"
   viewBox="0 0 70 36"
   version="1.1"
   id="svg6"
   sodipodi:docname="points-negative-1-20.svg"
   inkscape:version="1.2 (dc2aeda, 2022-05-15)"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:dc="http://purl.org/dc/elements/1.1/">
SVG
		;
	my $x = 0;
	my $y = 11;
	# If there is only one row, center it vertically
	if ($max <= 10) {
		$y += 3;
	}
	my $row = 0;

	for (my $i = 0; $i < $max; $i++) {

		my $color = "#BDBDBD";
		if ($i < $points) {
			if ($type eq "positive") {
				$color = "#219653";
			}
			elsif ($type eq "negative") {
				$color = "#EB5757";
			}
		}

		$image .= "<rect width=\"6\" height=\"6\" x=\"$x\" y=\"$y\" fill=\"$color\"></rect>";

		$x += 7;
		if ($x >= 69) {
			$x = 0;
			$y += 7;
			$row++;
		}
	}

	$image .= "</svg>";

	my $filename = "$dir/points-$type-$points-$max.svg";
	open(my $file, ">:encoding(UTF-8)", $filename);
	print $file $image;
	close($file);

	return;
}

# Different maximum points used for Nutri-Score components
my @max_negative_points = (4, 10, 15, 20);
my @max_positive_points = (5, 6, 7,);

# Usage: gen_svg_images_for_points.pl [path to directory to save the images]
my $dir = shift @ARGV;

# Generate images for negative points
foreach my $max (@max_negative_points) {
	for (my $points = 0; $points <= $max; $points++) {
		generate_image($dir, "negative", $points, $max);
	}
}

# Generate images for positive points
foreach my $max (@max_positive_points) {
	for (my $points = 0; $points <= $max; $points++) {
		generate_image($dir, "positive", $points, $max);
	}
}

exit(0);
