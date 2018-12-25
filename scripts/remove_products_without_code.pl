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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;


# Get a list of all products


my $cursor = get_products_collection()->query({})->fields( {'code' => 1, '_id'=>1, 'lc'=>1});

my $count = $cursor->count();

my $i = 0;
my $j = 0;
	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		$i++;
		
		my $code = $product_ref->{code};
		my $id = $product_ref->{id};
		
		if (not defined $lc) {
			print STDERR "lc does not exist - updating product _id: $id - hcode $code\n";		
		}
		
		if (not defined $code) {
		
		$j++;
		
		print STDERR "code does not exist - updating product _id: $id - hcode $code\n";
		
		#get_products_collection()->delete_one({"code" => $code});
		
		# index_product($product_ref);

		# Store

		# store("$data_root/products/$path/product.sto", $product_ref);		
		# get_products_collection()->save($product_ref);
		}
	}

print "$i products, removed $j\n";	
	
exit(0);

