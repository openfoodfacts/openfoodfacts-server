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
			
			if ($product_ref->{countries} =~ /:/) {
				my $country = $product_ref->{countries};
				$country =~ s/.*://;
				my $countryid = canonicalize_taxonomy_tag('en', "countries", $country);
				print $product_ref->{countries} . " --> id: " . $countryid . " --> " .display_taxonomy_tag($lc, "countries", $countryid) . "\n";
			
				$product_ref->{countries} = display_taxonomy_tag($lc, "countries", $countryid);
		if ($code ne '993605347529') {
			store("$data_root/products/$path/product.sto", $product_ref);		
			$products_collection->save($product_ref);
			}
			}
		}
		
	}

	
exit(0);

