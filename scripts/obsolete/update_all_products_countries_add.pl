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

use Geo::IP;
my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);

my %places = ();
open (my $IN, q{<}, "places.txt");
while(<$IN>) {
	chomp;
	my ($place, $n, $cc) = split(/\t/, $_);
	my $placeid = get_fileid($place);
	$cc eq '' and next;
	$places{$placeid} = $cc;
}

# Get a list of all products

my %new_countries = ();

		my $products_with_country = 0;
		my $products_without_country = 0;
		
my $cursor = $products_collection->query({})->fields({ code => 1 });;
my $count = $cursor->count();
	
	print  "$count products to update\n";
	
	my $new = 0;
	my $existing = 0;
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		print  "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		# Update
		my $field = 'countries';
		
		my $current_countries = $product_ref->{$field};

		my %existing = ();
		foreach my $countryid (@{$product_ref->{countries_tags}}) {
			$existing{$countryid} = 1;
		}
		
		foreach my $place (split(/,/, $product_ref->{purchase_places})) {
			
			my $country = undef;
			
			my $placeid = get_fileid($place);
			if (exists $places{$placeid}) {
				$country = canonicalize_taxonomy_tag($lc, "countries", $places{$placeid});
				print "known place $place -> countryid $country\n";
			}
			else {
				$placeid = canonicalize_taxonomy_tag($lc, "countries", $place);
	
				if (exists_taxonomy_tag("countries", $placeid)) {
					print  "known country $place / lc: $lc - countryid: $placeid\n";
					$country = $placeid;
				}
			}
			
			if (defined $country) {
				if (exists $existing{$country}) {
					$existing++;
					print "existing $country\n";
				}
				else {
					$new++;
					$new_countries{$country}++;
					print  "new $country\n";
					$existing{$country} = 2;
					$product_ref->{$field} .= ", " . display_taxonomy_tag($lc, "countries", $country);
				}
			}
		}
		
		# use IP from the person who added the product

		
		# Check lock and previous version
		if ($product_ref->{$field} eq '') {
			my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
			if ((defined $changes_ref) and (defined $changes_ref->[0])) {
				my $ip = $changes_ref->[0]{ip};

				# look up IP address '24.24.24.24'
				# returns undef if country is unallocated, or not defined in our database
				my $countrycode = $gi->country_code_by_addr($ip);
				if (defined $countrycode) {
					$country = canonicalize_taxonomy_tag('en', "countries", $countrycode);
					$new++;
					$new_countries{$country}++;
					print  "new $country\n";
					$existing{$country} = 3;
					$product_ref->{countries} = "en:" . $country;
				
				}
			}
		}
		

		
		if ($product_ref->{$field} eq '') {
			$products_without_country++;
		}
		else {
			$products_with_country++;
		}
		
		
		if ($product_ref->{$field} ne $current_countries) {
			$product_ref->{"countries.20131227"} = $current_countries;
		}
		
		if ($product_ref->{$field} =~ /^, /) {
			$product_ref->{$field} = $';
		}
		
			if (defined $taxonomy_fields{$field}) {
				$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
				$product_ref->{$field . "_tags" } = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
					push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
				}
			}
			
			if (defined $hierarchy_fields{$field}) {		
				$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy($field, $product_ref->{$field}) ];
				$product_ref->{$field . "_tags" } = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
					if (get_fileid($tag) ne '') {
						push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
					}
				}
			}
			
		# Store
		#if ($code eq '!3033710076017') 
		{
		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
		}
		}
	}

print "\n\total existing: $existing\ntotal new: $new\n\n";	

foreach my $country (sort { $new_countries{$a} <=> $new_countries{$b}} keys %new_countries) {
	print "$country $new_countries{$country} - with: $products_with_country - without: $products_without_country\n";
}
	
exit(0);

