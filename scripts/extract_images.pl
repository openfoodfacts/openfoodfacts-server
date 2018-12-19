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

use Getopt::Long;


my $target_dir;


GetOptions ("dir=s"   => \$target_dir,      # string
			)
  or die("Error in command line arguments:\n\n$usage");
  
(defined $target_dir) or die("Please specify --dir target directory:\n\n$usage");

if (! -e $target_dir) {
	mkdir($target_dir, 0755) or die("Could not create target directory $target_dir : $!\n");
}

my $query_ref = {entry_dates_tags => "2018-03-02"};

my $cursor = $products_collection->query($query_ref)->fields({ code => 1 });;
$cursor->immortal(1);
my $count = $cursor->count();

my $i = 0;
my $images_copied = 0;
	
print STDERR "$count products to update\n";
	
while (my $product_ref = $cursor->next) {
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
	
	$i++;

	if (defined $product_ref) {

		my $dir = "$www_root/images/products/$path";
		
		# Store the highest version number for each imageid
		
		next if ! -e $dir;
		
		print STDERR "\nproduct code: $code - path: $path\n";
		
		opendir DH, "$dir" or die "could not open image dir: $dir directory: $!\n";
		foreach my $file (sort readdir(DH)) {
			chomp($file);
			next if ($file !~ /\.jpg$/);
			
			if ($file =~ /^(\d+)\.jpg$/) {
				my $imageid = $1;
				
				print STDERR "$file - id: $imageid\n";

				use File::Copy;
				copy("$dir/$file","$target_dir/$code" . '_' . $imageid . ".jpg") or die("could not copy: $!\n");
				
				$images_copied++;
			}
		}
		closedir DH;			
		#($images_deleted > 10) and last;
	}
}

print STDERR "$i products - $images_copied images copied\n";

exit(0);
