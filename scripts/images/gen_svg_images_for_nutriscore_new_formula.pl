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

gen_svg_images_for_nutriscore_new_formula.pl - Add a "New formula" banner to Nutri-Score logos.

=head1 DESCRIPTION



=cut

use ProductOpener::PerlStandards;
use ProductOpener::Config qw/:all/;

# We will add a white rectangle below the Nutri-Score logo, and a blue banner with the "New formula" text
# We can have a different text for several languages

my $new_formula_below = <<SVG
<rect
     style="fill:#ffffff;fill-opacity:1;stroke:none;stroke-width:2.65346;stroke-linecap:round;stroke-linejoin:round;paint-order:stroke fill markers"
     id="rect18499"
     width="239.17799"
     height="30"
     x="0"
     y="98" />
SVG
	;

my $new_formula_banner = <<SVG
<path
     id="path16330"
     clip-path="url(#clipPath1593)"
     style="fill:#093c6b;fill-opacity:1;fill-rule:nonzero;stroke:none"
     d="M 0 33.997 L 0 27.407156 C 2.3684734e-15 12.296171 12.298124 -0.003 27.412109 -0.003 L 211.76953 -0.003 L 211.76953 -0.001046875 C 226.88152 -0.001046875 239.17773 12.295171 239.17773 27.407156 L 239.17773 33.997 L 0 33.997 z "
     transform="matrix(1,0,0,-1,0,161.997)" />
SVG
	;

my %new_formula_text = (
	en => <<SVG
<g
     aria-label="NEW FORMULA"
     id="text18503"
     style="font-size:21.2243px;line-height:1.25;font-family:'Open Sans';-inkscape-font-specification:'Open Sans';stroke-width:0.530607"><path
       d="m 44.677833,143.89633 v 8.61707 h -3.480785 v -15.06926 h 2.71671 l 7.025244,8.85054 v -8.85054 h 3.480785 V 152.5134 H 51.61818 Z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19002" /><path
       d="m 67.897194,149.4571 v 3.0563 H 57.306269 v -15.06926 h 10.399907 v 3.0563 h -6.919122 v 2.92896 h 5.942804 v 2.82283 h -5.942804 v 3.20487 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19004" /><path
       d="m 75.028538,137.46537 h 3.20487 l 1.528149,4.81791 1.52815,-4.81791 h 3.226094 l -2.525692,7.00402 1.52815,4.05384 3.777925,-11.07909 h 3.79915 l -6.027701,15.06926 h -2.90773 l -2.398346,-5.90036 -2.377121,5.90036 h -2.928954 l -6.006477,-15.06926 h 3.777926 l 3.79915,11.07909 1.485701,-4.05384 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19006" /><path
       d="m 96.63483,152.5134 v -15.06926 h 10.23011 v 3.0563 h -6.74932 v 3.24732 h 5.56076 v 2.82283 h -5.56076 v 5.94281 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19008" /><path
       d="m 114.97257,152.64074 q -1.67672,0 -3.0563,-0.65795 -1.37958,-0.65795 -2.35589,-1.71917 -0.97632,-1.08244 -1.52815,-2.46202 -0.53061,-1.37958 -0.53061,-2.84405 0,-1.4857 0.55183,-2.86528 0.57306,-1.37958 1.5706,-2.41957 1.01876,-1.06122 2.39834,-1.67672 1.37958,-0.63673 3.01385,-0.63673 1.67672,0 3.0563,0.65795 1.37958,0.65795 2.3559,1.74039 0.97632,1.08244 1.50693,2.46202 0.5306,1.37958 0.5306,2.80161 0,1.4857 -0.57305,2.86528 -0.55183,1.37958 -1.54938,2.44079 -0.99754,1.03999 -2.37712,1.67672 -1.37958,0.63673 -3.01385,0.63673 z m -3.92649,-7.64075 q 0,0.8702 0.25469,1.69795 0.25469,0.80652 0.74285,1.44325 0.50938,0.63673 1.25223,1.01877 0.74285,0.38204 1.69795,0.38204 0.99754,0 1.74039,-0.40327 0.74285,-0.40326 1.23101,-1.03999 0.48816,-0.65795 0.72162,-1.46447 0.2547,-0.82775 0.2547,-1.67672 0,-0.8702 -0.2547,-1.67672 -0.25469,-0.82775 -0.76407,-1.44326 -0.50938,-0.63672 -1.25223,-0.99754 -0.72163,-0.38204 -1.67672,-0.38204 -0.99755,0 -1.7404,0.40327 -0.72162,0.38203 -1.23101,1.01876 -0.48815,0.63673 -0.74285,1.46448 -0.23346,0.80652 -0.23346,1.65549 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19010" /><path
       d="m 124.50225,152.5134 v -15.06926 h 6.79177 q 1.06122,0 1.95264,0.44571 0.91264,0.44571 1.5706,1.16734 0.65795,0.72163 1.01876,1.63427 0.38204,0.91265 0.38204,1.84652 0,0.7004 -0.16979,1.35835 -0.1698,0.63673 -0.48816,1.20979 -0.31837,0.57305 -0.7853,1.03999 -0.44571,0.44571 -1.01877,0.76407 l 3.31099,5.60322 h -3.92649 l -2.88651,-4.86037 h -2.271 v 4.86037 z m 3.48078,-7.89544 h 3.18365 q 0.6155,0 1.06121,-0.57306 0.44571,-0.59428 0.44571,-1.50692 0,-0.93387 -0.50938,-1.4857 -0.50938,-0.55184 -1.10366,-0.55184 h -3.07753 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19012" /><path
       d="m 150.6081,152.5134 v -9.02033 l -3.26854,6.55831 h -1.86774 l -3.26854,-6.55831 v 9.02033 h -3.48079 v -15.06926 h 3.77793 l 3.90527,7.87422 3.92649,-7.87422 h 3.75671 v 15.06926 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19014" /><path
       d="m 163.44877,149.542 q 0.89142,0 1.50693,-0.36082 0.6155,-0.38204 0.99754,-0.99754 0.38204,-0.6155 0.53061,-1.4008 0.16979,-0.80653 0.16979,-1.63428 v -7.70442 h 3.48079 v 7.70442 q 0,1.5706 -0.40326,2.92896 -0.38204,1.35835 -1.20979,2.37712 -0.80652,1.01877 -2.07998,1.61305 -1.25224,0.57305 -2.99263,0.57305 -1.80406,0 -3.07752,-0.6155 -1.27346,-0.61551 -2.07998,-1.63427 -0.7853,-1.03999 -1.16734,-2.39835 -0.36081,-1.35835 -0.36081,-2.84406 v -7.70442 h 3.48078 v 7.70442 q 0,0.8702 0.1698,1.6555 0.16979,0.7853 0.55183,1.4008 0.38204,0.61551 0.97632,0.97632 0.6155,0.36082 1.50692,0.36082 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19016" /><path
       d="m 172.82991,152.5134 v -15.06926 h 3.48078 v 12.01296 h 7.30116 v 3.0563 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19018" /><path
       d="m 189.3424,137.44414 h 3.14119 l 5.4971,15.06926 H 194.415 l -1.16733,-3.37467 h -4.69057 l -1.14612,3.37467 h -3.56568 z m 3.33221,9.29625 -1.76162,-5.3273 -1.80406,5.3273 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path19020" /></g>

SVG
	,
	fr => <<SVG
<g
     aria-label="NOUVEAU CALCUL"
     id="text18503"
     style="font-size:21.2243px;line-height:1.25;font-family:'Open Sans';-inkscape-font-specification:'Open Sans';stroke-width:0.530607"><path
       d="m 27.677145,143.89633 v 8.61707 h -3.480786 v -15.06926 h 2.716711 l 7.025243,8.85054 v -8.85054 h 3.480786 v 15.06926 h -2.801608 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18799" /><path
       d="m 46.906337,152.64074 q -1.676719,0 -3.056299,-0.65795 -1.379579,-0.65795 -2.355897,-1.71917 -0.976318,-1.08244 -1.52815,-2.46202 -0.530607,-1.37958 -0.530607,-2.84405 0,-1.4857 0.551831,-2.86528 0.573057,-1.37958 1.570599,-2.41957 1.018766,-1.06122 2.398346,-1.67672 1.379579,-0.63673 3.01385,-0.63673 1.67672,0 3.0563,0.65795 1.379579,0.65795 2.355897,1.74039 0.976318,1.08244 1.506925,2.46202 0.530608,1.37958 0.530608,2.80161 0,1.4857 -0.573056,2.86528 -0.551832,1.37958 -1.549374,2.44079 -0.997542,1.03999 -2.377122,1.67672 -1.379579,0.63673 -3.013851,0.63673 z m -3.926495,-7.64075 q 0,0.8702 0.254691,1.69795 0.254692,0.80652 0.742851,1.44325 0.509383,0.63673 1.252234,1.01877 0.74285,0.38204 1.697944,0.38204 0.997542,0 1.740392,-0.40327 0.742851,-0.40326 1.23101,-1.03999 0.488159,-0.65795 0.721626,-1.46447 0.254692,-0.82775 0.254692,-1.67672 0,-0.8702 -0.254692,-1.67672 -0.254692,-0.82775 -0.764075,-1.44326 -0.509383,-0.63672 -1.252234,-0.99754 -0.721626,-0.38204 -1.676719,-0.38204 -0.997542,0 -1.740393,0.40327 -0.721626,0.38203 -1.231009,1.01876 -0.488159,0.63673 -0.742851,1.46448 -0.233467,0.80652 -0.233467,1.65549 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18801" /><path
       d="m 62.909426,149.542 q 0.89142,0 1.506925,-0.36082 0.615505,-0.38204 0.997542,-0.99754 0.382038,-0.6155 0.530608,-1.4008 0.169794,-0.80653 0.169794,-1.63428 v -7.70442 h 3.480785 v 7.70442 q 0,1.5706 -0.403261,2.92896 -0.382038,1.35835 -1.209786,2.37712 -0.806523,1.01877 -2.079981,1.61305 -1.252234,0.57305 -2.992626,0.57305 -1.804066,0 -3.077524,-0.6155 -1.273458,-0.61551 -2.079981,-1.63427 -0.785299,-1.03999 -1.167337,-2.39835 -0.360813,-1.35835 -0.360813,-2.84406 v -7.70442 h 3.480785 v 7.70442 q 0,0.8702 0.169795,1.6555 0.169794,0.7853 0.551832,1.4008 0.382037,0.61551 0.976317,0.97632 0.615505,0.36082 1.506926,0.36082 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18803" /><path
       d="m 74.476663,137.44414 3.544458,10.69705 3.502009,-10.69705 h 3.671804 l -5.709337,15.06926 h -2.928953 l -5.77301,-15.06926 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18805" /><path
       d="m 97.186657,149.4571 v 3.0563 H 86.595732 v -15.06926 h 10.399907 v 3.0563 h -6.919122 v 2.92896 h 5.942804 v 2.82283 h -5.942804 v 3.20487 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18807" /><path
       d="m 103.40536,137.44414 h 3.14119 l 5.4971,15.06926 h -3.56568 l -1.16734,-3.37467 h -4.69057 l -1.14611,3.37467 h -3.565685 z m 3.33221,9.29625 -1.76161,-5.3273 -1.80407,5.3273 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18809" /><path
       d="m 119.34477,149.542 q 0.89142,0 1.50692,-0.36082 0.61551,-0.38204 0.99754,-0.99754 0.38204,-0.6155 0.53061,-1.4008 0.1698,-0.80653 0.1698,-1.63428 v -7.70442 h 3.48078 v 7.70442 q 0,1.5706 -0.40326,2.92896 -0.38204,1.35835 -1.20979,2.37712 -0.80652,1.01877 -2.07998,1.61305 -1.25223,0.57305 -2.99262,0.57305 -1.80407,0 -3.07753,-0.6155 -1.27346,-0.61551 -2.07998,-1.63427 -0.7853,-1.03999 -1.16733,-2.39835 -0.36082,-1.35835 -0.36082,-2.84406 v -7.70442 h 3.48079 v 7.70442 q 0,0.8702 0.16979,1.6555 0.1698,0.7853 0.55183,1.4008 0.38204,0.61551 0.97632,0.97632 0.61551,0.36082 1.50693,0.36082 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18811" /><path
       d="m 132.80096,144.85142 q 0,-1.35835 0.50939,-2.69548 0.50938,-1.35836 1.4857,-2.41957 0.97632,-1.06122 2.37712,-1.71917 1.4008,-0.65795 3.18364,-0.65795 2.12243,0 3.67181,0.91264 1.5706,0.91265 2.33467,2.37712 l -2.67426,1.86774 q -0.25469,-0.59428 -0.65795,-0.97632 -0.38204,-0.40326 -0.84898,-0.63673 -0.46693,-0.25469 -0.95509,-0.33958 -0.48816,-0.10613 -0.95509,-0.10613 -0.99755,0 -1.7404,0.40327 -0.74285,0.40326 -1.23101,1.03999 -0.48815,0.63673 -0.72162,1.44325 -0.23347,0.80652 -0.23347,1.63427 0,0.89142 0.27592,1.71917 0.27591,0.82775 0.7853,1.46448 0.5306,0.63672 1.25223,1.01876 0.74285,0.36082 1.6555,0.36082 0.46693,0 0.95509,-0.10613 0.50938,-0.12734 0.95509,-0.36081 0.46694,-0.25469 0.84897,-0.63673 0.38204,-0.40326 0.61551,-0.97632 l 2.84406,1.67672 q -0.33959,0.82775 -1.01877,1.4857 -0.65795,0.65796 -1.52815,1.10367 -0.8702,0.44571 -1.84651,0.67918 -0.97632,0.23346 -1.91019,0.23346 -1.63427,0 -3.01385,-0.65795 -1.35836,-0.67918 -2.3559,-1.78284 -0.97632,-1.10367 -1.52815,-2.50447 -0.53061,-1.4008 -0.53061,-2.84406 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18813" /><path
       d="m 152.15751,137.44414 h 3.1412 l 5.49709,15.06926 h -3.56568 l -1.16734,-3.37467 h -4.69057 l -1.14611,3.37467 h -3.56568 z m 3.33222,9.29625 -1.76162,-5.3273 -1.80407,5.3273 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18815" /><path
       d="m 162.28147,152.5134 v -15.06926 h 3.48079 v 12.01296 h 7.30116 v 3.0563 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18817" /><path
       d="m 172.87237,144.85142 q 0,-1.35835 0.50938,-2.69548 0.50938,-1.35836 1.4857,-2.41957 0.97632,-1.06122 2.37712,-1.71917 1.40081,-0.65795 3.18365,-0.65795 2.12243,0 3.6718,0.91264 1.5706,0.91265 2.33467,2.37712 l -2.67426,1.86774 q -0.25469,-0.59428 -0.65795,-0.97632 -0.38204,-0.40326 -0.84897,-0.63673 -0.46694,-0.25469 -0.9551,-0.33958 -0.48815,-0.10613 -0.95509,-0.10613 -0.99754,0 -1.74039,0.40327 -0.74285,0.40326 -1.23101,1.03999 -0.48816,0.63673 -0.72163,1.44325 -0.23347,0.80652 -0.23347,1.63427 0,0.89142 0.27592,1.71917 0.27592,0.82775 0.7853,1.46448 0.53061,0.63672 1.25223,1.01876 0.74285,0.36082 1.6555,0.36082 0.46693,0 0.95509,-0.10613 0.50939,-0.12734 0.9551,-0.36081 0.46693,-0.25469 0.84897,-0.63673 0.38204,-0.40326 0.6155,-0.97632 l 2.84406,1.67672 q -0.33959,0.82775 -1.01877,1.4857 -0.65795,0.65796 -1.52815,1.10367 -0.87019,0.44571 -1.84651,0.67918 -0.97632,0.23346 -1.91019,0.23346 -1.63427,0 -3.01385,-0.65795 -1.35835,-0.67918 -2.3559,-1.78284 -0.97631,-1.10367 -1.52815,-2.50447 -0.5306,-1.4008 -0.5306,-2.84406 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18819" /><path
       d="m 194.81828,149.542 q 0.89143,0 1.50693,-0.36082 0.6155,-0.38204 0.99754,-0.99754 0.38204,-0.6155 0.53061,-1.4008 0.16979,-0.80653 0.16979,-1.63428 v -7.70442 h 3.48079 v 7.70442 q 0,1.5706 -0.40326,2.92896 -0.38204,1.35835 -1.20979,2.37712 -0.80652,1.01877 -2.07998,1.61305 -1.25223,0.57305 -2.99263,0.57305 -1.80406,0 -3.07752,-0.6155 -1.27346,-0.61551 -2.07998,-1.63427 -0.7853,-1.03999 -1.16734,-2.39835 -0.36081,-1.35835 -0.36081,-2.84406 v -7.70442 h 3.48079 v 7.70442 q 0,0.8702 0.16979,1.6555 0.16979,0.7853 0.55183,1.4008 0.38204,0.61551 0.97632,0.97632 0.6155,0.36082 1.50692,0.36082 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18821" /><path
       d="m 204.19943,152.5134 v -15.06926 h 3.48078 v 12.01296 h 7.30116 v 3.0563 z"
       style="font-weight:800;font-family:Raleway;-inkscape-font-specification:'Raleway Ultra-Bold';fill:#ffffff"
       id="path18823" /></g>    
SVG
	,
);

# Read the Nutri-Score SVG images in the html/images/attributes/src directory
# and add a "New formula" banner to the Nutri-Score logos.

my $dir = "$www_root/images/attributes/src";

my @files = glob "$dir/nutriscore-*.svg";

foreach my $lc ("en", "fr") {

	foreach my $file (@files) {

		# skip the Nutri-Score logo with the new formula banner
		next if ($file =~ /new-formula/);

		my $new_file = $file;
		$new_file =~ s/\.svg$/-new-formula-$lc.svg/;

		open(my $fh, "<", $file) or die "Could not open file $file: $!\n";
		open(my $fh2, ">", $new_file) or die "Could not open file $new_file: $!\n";

		while (my $line = <$fh>) {

			if ($line =~ /<svg/) {
				# Change the height of the SVG image
				# <svg xmlns="http://www.w3.org/2000/svg" id="svg2032" width="240" height="130" version="1.1" viewBox="0 0 240 130">
				$line =~ s/height="130"/height="162"/;
				$line =~ s/viewBox="0 0 240 130"/viewBox="0 0 240 162"/;
				print $fh2 $line;
				if ($file !~ /unknown|not-applicable/) {
					print $fh2 $new_formula_below;
				}
			}
			elsif ($line =~ /<\/svg>/) {
				# No banner for not-applicable / unknown
				if ($file !~ /unknown|not-applicable/) {
					print $fh2 $new_formula_banner;
					print $fh2 $new_formula_text{$lc};
				}
				print $fh2 $line;
			}
			else {
				print $fh2 $line;
			}
		}

		close $fh;
		close $fh2;
	}
}

exit(0);
