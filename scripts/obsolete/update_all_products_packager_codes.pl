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


my $cursor = $products_collection->query({})->fields({ code => 1 });;
my $count = $cursor->count();
	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		if (defined $product_ref->{emb_codes_orig}) {
			$product_ref->{emb_codes} = $product_ref->{emb_codes_orig};
		}
		
		if (not defined $product_ref->{emb_codes_20141016}) {
			$product_ref->{emb_codes_20141016} = $product_ref->{emb_codes};
		}
		$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});
		
		my $field = 'emb_codes';
		
			if (defined $tags_fields{$field}) {

				$product_ref->{$field . "_tags" } = [];
				if ($field eq 'emb_codes') {
					$product_ref->{"cities_tags" } = [];
				}
				foreach my $tag (split(',', $product_ref->{$field} )) {
					if (get_fileid($tag) ne '') {
						push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
						if ($field eq 'emb_codes') {
							my $city_code = get_city_code($tag);
							if (defined $emb_codes_cities{$city_code}) {
								push @{$product_ref->{"cities_tags" }}, get_fileid($emb_codes_cities{$city_code}) ;
							}
						}
					}
				}			
			}		
		# Store

		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
		
		}
	}

exit(0);

