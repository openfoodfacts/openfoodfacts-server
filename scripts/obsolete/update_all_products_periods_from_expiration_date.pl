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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;


# Get a list of all products


my $cursor = $products_collection->query({})->fields({ code => 1 });

my $periods = 0;
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		# Update
		
		if ((defined $product_ref->{expiration_date}) and ($product_ref->{expiration_date} =~ /^\d+( )?m(ois|onth|onths)?$/i)
			and ((not defined $product_ref->{periods_after_opening}) or ($product_ref->{periods_after_opening} eq ""))) {
				$product_ref->{periods_after_opening} = $product_ref->{expiration_date};
				delete $product_ref->{expiration_date};
				print "updated period : code: $code -  " . $product_ref->{expiration_date}  . "\n";
				$periods++;
		}
		
		my $field = 'periods_after_opening';

		compute_field_tags($product_ref, $field);
		

			
		# Store

		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
		
		}
	}

print "\n\nperiods updated from expiration date: $periods\n";
	
exit(0);

