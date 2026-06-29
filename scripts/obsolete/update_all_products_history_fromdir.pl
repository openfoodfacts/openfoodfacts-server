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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Texts qw/:all/;
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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;


# Get a list of all products

use Getopt::Long;

my @products = ();


GetOptions ( 'products=s' => \@products);
@products = split(/,/,join(',',@products));


sub find_products($) {

	my $dir = shift;

	my $next = product_iter($dir);
	while (my $file = $next->()) {
		push @products, product_id_from_path($file);
	}

	return;
}


if (scalar $#products < 0) {
	find_products($BASE_DIRS{PRODUCTS});
}

my $count = $#products;
	
	print STDERR "$count products to update\n";
	
	foreach my $code (@products) {
        
		
		my $path = product_path($code);
		
		# print STDERR "updating product $code\n";
		
		#my $product_ref = retrieve_product($code);
		my $product_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/product");
		
		if ((defined $product_ref) and ($code ne '')) {
				
		$lc = $product_ref->{lc};
		$lang = $lc;
		
		my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/$path/changes");
		if (not defined $changes_ref) {
			$changes_ref = [];
		}
		else {
			my $last = pop(@{$changes_ref});
			if ($last->{comment} =~ /automatic removal/) {
				print "* automatically deleted: $code  - empty: $product_ref->{empty} - complete: $product_ref->{complete} \n";
			}
		}

		if (($product_ref->{empty} != 1) and ($product_ref->{deleted} eq 'on')) {
			print "! deleted non empty product: $code\n";
		}
		
		if ($product_ref->{empty} == 1) {
			compute_product_history_and_completeness($product_ref, $changes_ref);
			if ($product_ref->{empty} != 1) {
				print "product was empty but is not - code: $code\n";

				#if ($product_ref->{code} eq '3596710313266') {
				delete $product_ref->{deleted};
				store_object("$BASE_DIRS{PRODUCTS}/$path/product", $product_ref);
				$products_collection->save($product_ref);
				store_object("$BASE_DIRS{PRODUCTS}/$path/changes", $changes_ref);
				#}
			}
		}



		# compute_product_history_and_completeness($product_ref, $changes_ref);

		if (($product_ref->{empty} != 1) and ($product_ref->{deleted} eq 'on')) {
			print "!!! deleted non empty product: $code\n";
		}

		#store_object("$BASE_DIRS{PRODUCTS}/$path/product", $product_ref);		
		#$products_collection->save($product_ref);
		#store_object("$BASE_DIRS{PRODUCTS}/$path/changes", $changes_ref);
		}
	}

exit(0);

