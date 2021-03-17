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

use Data::Dumper;


# Get a list of all products

use Getopt::Long;

my @products = ();


GetOptions ( 'products=s' => \@products);
@products = split(/,/,join(',',@products));

my $d = 0;

if (scalar $#products < 0) {
	# Look for products with EAN8 codes directly in the product root

	my $dh;

	opendir $dh, "$data_root/products" or die "could not open $data_root/products directory: $!\n";
	foreach my $dir (sort readdir($dh)) {
		chomp($dir);
		
		next if ($dir =~ /^\d\d\d$/);
		
		if (-e "$data_root/products/$dir/product.sto") {
			push @products, $dir;
			$d++;
			(($d % 1000) == 1 ) and print STDERR "$d products - $dir\n";
		}
	}
	closedir $dh;	
}



my $count = $#products;
my $i = 0;

my %codes = ();

print STDERR "$count products to update\n";

my $products_collection = get_products_collection();

my $invalid = 0;
my $moved = 0;
my $not_moved = 0;

foreach my $code (@products) {

	my $product_id = product_id_for_owner(undef, $code);
	
	my $path_old = $code;
	my $path_new = product_path_from_id($product_id);
	
	if ($path_new eq "invalid") {
		$invalid++;
		print STDERR "invalid path: $invalid\n";
	}
	elsif ($path_new ne $path_old) {
	
		if (not -e "$data_root/products/$path_new") {
			print STDERR "$path_new does not exist, moving $path_old\n";
			$moved++;
		}
		else {
			print STDERR "$path_new exist, not moving $path_old\n";
			$not_moved++;
		}
		
		if (0) {
			my $product_ref = retrieve("$data_root/products/$path_new/product.sto") or print "not defined $data_root/products/$path_new/product.sto\n";

			if ((defined $product_ref)) {

				if ((defined $product_ref) and ($code ne '')) {
										
					next if ((defined $product_ref->{empty}) and ($product_ref->{empty} == 1));
					next if ((defined $product_ref->{deleted}) and ($product_ref->{deleted} eq 'on'));
					print STDERR "updating product $code -- " . $product_ref->{code} . " \n";
					my $return = $products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, { upsert => 1 });
					print STDERR "return $return\n";
					$i++;
					$codes{$code} = 1;
				}
			}
		}
	}
}

print STDERR "$count products to update - $i products not empty or deleted\n";
print STDERR "scalar keys codes : " . (scalar keys %codes) . "\n";

print STDERR "invalid: $invalid\n";
print STDERR "moved: $moved\n";
print STDERR "not moved: $not_moved\n";

exit(0);

