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

my $total = 0;
my $l = 'en';

	$lc = $l;
	$lang = $l;


my $cursor = get_products_collection()->query({empty => 1})->fields({ code => 1, empty => 1 });;
my $count = $cursor->count();
my $removed = 0;
	
	print STDERR "$count products to check\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		#print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
				
			$lc = $product_ref->{lc};
			$lang = $lc;
			
			if (($product_ref->{empty} == 1) and (time() > $product_ref->{last_modified_t} + 86400)) {
				$product_ref->{deleted} = 'on';
				my $comment = "automatic removal of product without information or images";

				# print STDERR "removing product code $code\n";
				$removed++;
				if ($lc ne 'xx') {
					store_product($product_ref, $comment);
				}
			}
		}
		else {
			print "product $code : file not found\n";
		}

	}
	
print STDERR "$lc - removed $removed products\n";
$total += $removed;


print STDERR "total - removed $total products\n";


exit(0);

