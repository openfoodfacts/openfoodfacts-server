#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;


use Encode;
use JSON;

use LWP::Simple;

my $json = get("https://world.openpetfoodfacts.org/categories.json");

my $categories_ref = from_json($json);

#tags: [
#{
#products: 63,
#url: "https://world.openpetfoodfacts.org/category/cat-food",
#name: "Cat food",
#id: "en:cat-food"
#},

my %categories_of_interest = (
	"en:cat-food" => "00d400",
	"en:dog-food" => "ff0000",
	"en:fish-food" => "0066ff",
	"en:bird-food" => "ffcc00",
	"en:rabbit-food" => "00ccff",
);

my $max;
my $i = 0;
my $width = 100;
my $max_height = 280;

my $bars = "";

if (defined $categories_ref) {

	$categories_ref = $categories_ref->{tags};
	
	foreach my $category_ref (@$categories_ref) {
	
	
		my $category = $category_ref->{id};
		my $id = $category;
		$id =~ s/:/-/g;
		my $animal = $id;
		$animal =~ s/^en-//;
		$animal =~ s/-food$//;
		
		next if not defined $categories_of_interest{$category};
	
		if (not defined $max) {
			$max = $category_ref->{products};
		}
		
		my $products = $category_ref->{products};
		
		my $x = 10 + ($width + 10) * $i;
		my $height = $max_height * ($products / $max);
		my $y = 100 + $max_height - $height;
		my $y_icon = $y - 80;
		my $icon_height = $width * 0.75;
		
		my $xtext = $x + 45;
		my $ytext = $max_height + 130;
		
		my $color = $categories_of_interest{$category};
		my $url = $category_ref->{url};
		
		$bars .= <<SVG
<a xlink:href="$url">
<svg:rect id="bar_$id" x="$x" y="$y" width="$width" height="$height" style="fill:#$color" />
<svg:image id="image_$id" x="$x" y="$y_icon" width="$width" height="$icon_height" xlink:href="opff_$animal.svg" />
<svg:text id="text_$id" x="$xtext" y="$ytext" style="font-style:normal;font-weight:bold;font-size:30px;line-height:200%;font-family:sans-serif;letter-spacing:0px;word-spacing:0px;fill:#000000;fill-opacity:1;stroke:none;stroke-width:1px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1;text-anchor:middle;text-align:center;">
$products
</svg:text>
</a>
SVG
;
		
			
		$i++;
	}

}




my $svg = <<SVG
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Created with Inkscape (http://www.inkscape.org/) -->

<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:xlink="http://www.w3.org/1999/xlink"
   width="640"
   height="480"
   viewBox="0 0 620 480"
   >

$bars   
   
</svg>

SVG
;

open (my $OUT, ">:encoding(UTF-8)", "$www_root/images/misc/opff-leaderboard.svg");
print $OUT $svg;
close $OUT;
