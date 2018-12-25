#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use Modern::Perl '2012';
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
use ProductOpener::SiteQuality qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use JSON::PP;


use Getopt::Long;


my $target_dir;


GetOptions ("dir=s"   => \$target_dir,      # string
			)
  or die("Error in command line arguments:\n\n$usage");
  
(defined $target_dir) or die("Please specify --dir target directory:\n\n$usage");

if (! -e $target_dir) {
	mkdir($target_dir, 0755) or die("Could not create target directory $target_dir : $!\n");
}

#my $query_ref = {entry_dates_tags => "2018-03-02"};
my $query_ref = {states_tags => "en:complete", lc => "en"};

#my $cursor = $products_collection->query($query_ref)->fields({ code => 1 , images => 1, lc => 1 });;
my $cursor = $products_collection->query($query_ref);;
$cursor->immortal(1);
my $count = $cursor->count();

my $i = 0;
my $images_copied = 0;
	
print STDERR "$count products to update\n";

my $n = 0;
	
while (my $product_ref = $cursor->next) {
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
	
	$i++;


	$product_ref = retrieve_product($code);

	if (defined $product_ref) {

		my $dir = "$www_root/images/products/$path";
		
		next if ! -e $dir;

		next if not defined $product_ref->{images};

		my $ingredients_imgid;
		my $nutrition_imgid;

		my $plc = $product_ref->{lc};

		if (defined $product_ref->{images}{"ingredients_" . $plc}) {
			$ingredients_imgid = "ingredients_" . $plc;
		}
		elsif (defined $product_ref->{images}{"ingredients"}) {
                        $ingredients_imgid = "ingredients";
                }

		if (defined $product_ref->{images}{"nutrition_" . $plc}) {
                        $nutrition_imgid = "nutrition_" . $plc;
                }
                elsif (defined $product_ref->{images}{"nutrition"}) {
                        $nutrition_imgid = "nutrition";
                }

		next if not defined $ingredients_imgid;
		next if not defined $nutrition_imgid;
		
		print STDERR "\nproduct code: $code - path: $path\n";

		$product_ref->{ingredients_imgid} = $ingredients_imgid;
		$product_ref->{nutrition_imgid} = $nutrition_imgid;

		my %imgids = ();
		$imgids{$product_ref->{images}{$ingredients_imgid}{imgid}} = 1;
		$imgids{$product_ref->{images}{$nutrition_imgid}{imgid}} = 1;
		
		foreach my $imgid (sort keys %imgids) {
			
				print STDERR "copying imgid: $imgid\n";

				use File::Copy;
				copy("$dir/$imgid.jpg","$target_dir/$code" . '_' . $imgid . ".jpg") or print STDERR ("could not copy: $!\n");
				
				$images_copied++;
		}

		my $json_file = "$target_dir/$code" . ".json";
		open (my $OUT, ">:encoding(UTF-8)", "$json_file");
		print $OUT encode_json($product_ref);
		close $OUT;

		$n++;
#		($n > 10) and last;
	}
}

print STDERR "$i products - $n selected products\n";

exit(0);
