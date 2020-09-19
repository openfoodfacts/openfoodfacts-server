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

my $usage = <<TXT
extract_images.pl is a script that copies uploaded images from a specific set of products
in a target directory. The subset of product is specified in the code.

Usage:

update_all_products.pl --dir [target directory to copy images]

TXT
;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Data qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use JSON::PP;


use Getopt::Long;


my $target_dir;

my $query_ref = {};    # filters for mongodb query

GetOptions (
	"dir=s"   => \$target_dir,      # string
	"lc=s" => \$lc,
	"query=s%" => $query_ref,
)
  or die("Error in command line arguments:\n\n$usage");

(defined $target_dir) or die("Please specify --dir target directory:\n\n$usage");

if (! -e $target_dir) {
	mkdir($target_dir, 0755) or die("Could not create target directory $target_dir : $!\n");
}

use boolean;

foreach my $field (sort keys %{$query_ref}) {
	if ($query_ref->{$field} eq 'null') {
		# $query_ref->{$field} = { '$exists' => false };
		$query_ref->{$field} = undef;
	}
	if ($query_ref->{$field} eq 'exists') {
		$query_ref->{$field} = { '$exists' => true };
	}
}

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);
print STDERR "lc: $lc - target dir: $target_dir\n";

my $products_collection = get_products_collection();

my $count = $products_collection->count_documents($query_ref);

print STDERR "$count products to extract\n";

sleep(2);

my $cursor = $products_collection->query($query_ref)->fields({ code => 1 });
$cursor->immortal(1);

my $i = 0;

my $n = 0;

open (my $csv, ">", $target_dir . "/products.csv") or die("Cannot create products.csv: $!\n");

print $csv join("\t", qw(code angle x1 y1 x2 y2)) . "\n";

my $imageid = "nutrition";
my $imageid_lc = "nutrition_" . $lc;

while (my $product_ref = $cursor->next) {

	my $code = $product_ref->{code};
	my $path = product_path($code);

	$i++;

	$product_ref = retrieve_product($code);

	if (defined $product_ref) {

		my $dir = "$www_root/images/products/$path";

		next if ! -e $dir;

		# Keep only products with a selected nutrition image
		next if not defined $product_ref->{images};
		next if not defined $product_ref->{images}{$imageid_lc};

		# Keep only products that have nutrition data
		next if not defined $product_ref->{nutriments};
		next if not defined $product_ref->{nutriments}{energy_100g};

		my $imgid = $product_ref->{images}{$imageid_lc}{imgid};
		my $rev = $product_ref->{images}{$imageid_lc}{rev};

		my $angle = $product_ref->{images}{$imageid_lc}{angle};
		not defined $angle and $angle = 0;

		my $x1 = $product_ref->{images}{$imageid_lc}{x1};
		my $y1 = $product_ref->{images}{$imageid_lc}{y1};
		my $x2 = $product_ref->{images}{$imageid_lc}{x2};
		my $y2 = $product_ref->{images}{$imageid_lc}{y2};

		not defined $x1 and $x1 = 0;
		not defined $y1 and $y1 = 0;
		not defined $x2 and $x2 = 0;
		not defined $y2 and $y2 = 0;


		# Crop coordinates

		my $ow = $product_ref->{images}{$imgid}{sizes}{full}{w};
		my $oh = $product_ref->{images}{$imgid}{sizes}{full}{h};

		my $w = $product_ref->{images}{$imgid}{sizes}{$crop_size}{w};
		my $h = $product_ref->{images}{$imgid}{sizes}{$crop_size}{h};

		if ((defined $angle) and (($angle % 180) == 90)) {
			my $z = $w;
			$w = $h;
			$h = $z;

			my $oz = $ow;
			$ow = $oh;
			$oh = $oz;
		}

		next if not defined $w or $w == 0;
		next if not defined $h or $h == 0;

		my $ox1;
		my $oy1;
		my $ox2;
		my $oy2;

		# image not cropped?

		if ((not defined $x1) or ($x2 == $x1))  {
			$ox1 = 0;
			$oy1 = 0;
			$ox2 = $ow;
			$oy2 = $oh;
		}
		else {
			$ox1 = int($x1 * $ow / $w);
			$oy1 = int($y1 * $oh / $h);
			$ox2 = int($x2 * $ow / $w);
			$oy2 = int($y2 * $oh / $h);
		}

		require File::Copy;
		File::Copy->import( qw( copy ) );
		copy("$dir/$imgid.jpg","$target_dir/$code" . '.' . $imageid . ".jpg") or print STDERR ("could not copy $dir/$imgid.jpg : $!\n");
		copy("$dir/$imageid_lc.$rev.full.jpg","$target_dir/$code" . '.' . $imageid . ".cropped.jpg") or print STDERR ("could not copy $dir/$imageid_lc.$rev.full.jpg : $!\n");
		copy("$dir/$imageid_lc.$rev.json","$target_dir/$code" . '.' . $imageid . ".cropped.json") or print STDERR ("could not copy $dir/$imageid_lc.$rev.json : $!\n");

		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			$product_ref->{nutriments}{$nid} =~ /nutrition/ and delete $product_ref->{nutriments}{$nid};
			$product_ref->{nutriments}{$nid} eq "nova" and delete $product_ref->{nutriments}{$nid};
		}

		my $json_file = "$target_dir/$code" . ".nutriments.json";
		open (my $OUT, ">:encoding(UTF-8)", "$json_file");
		print $OUT encode_json($product_ref->{nutriments});
		close $OUT;

		print $csv join("\t", $code, $angle, $ox1, $oy1, $ox2, $oy2) . "\n";


		$n++;
#		($n > 10) and last;
	}
}

print STDERR "$i products - $n selected products\n";

exit(0);
