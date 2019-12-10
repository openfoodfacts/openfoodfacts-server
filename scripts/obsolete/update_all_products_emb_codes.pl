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
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		# print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		# Update
		my $field = 'emb_codes';
		$product_ref->{emb_codes} = $product_ref->{emb_code};
		next if $product_ref->{emb_codes} eq '';
		
			if ($field eq 'emb_codes') {
				# French emb codes
				$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
				$product_ref->{$field} = uc($product_ref->{$field});
				$product_ref->{$field} =~ s/(^|,|, )(emb|e)?(\s|-|_|\.)?(\d+)(\.|-|\s)?(\d+)(\.|_|\s|-)?([a-z]+)/$1EMB $4$6$8/ig;
				
				# FRANCE -> FR
				$product_ref->{$field} =~ s/(^|,|, )(france)/$1FR/ig;
				
				sub normalize_emb_ce_code($$) {
					my $country = shift;
					my $number = shift;
					$country = uc($country);
					$number =~ s/\D//g;
					$number =~ s/^(\d\d)(\d\d\d)(\d)/$1.$2.$3/;
					$number =~ s/^(\d\d)(\d\d)/$1.$2/;
					
					# put leading 0s at the end
					$number =~ s/\.(\d)$/\.00$1/;
					$number =~ s/\.(\d\d)$/\.0$1/;
					return "$country $number CE";
				}
				
				# CE codes -- FR 67.145.01 CE
				$product_ref->{$field} =~ s/(^|,|, )([a-z][a-z])(\s|-|_|\.)?((\d|\.|_|\s|-)+)(\.|_|\s|-)?(ce)\b/$1 . normalize_emb_ce_code($2,$4)/ieg;				
			}
			print "emb - code: $code - $product_ref->{emb_code} -> $product_ref->{$field}\n";
			if ($product_ref->{$field} =~/,/) {
				print "multiple codes - code: $code - field: $field = $product_ref->{$field}\n";
			}

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
	
		
		# Store

		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
		
		}
	}

exit(0);

