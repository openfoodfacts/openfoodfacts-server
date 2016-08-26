#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

use Geo::IP;
my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);

my %places = ();
open (IN, "<places.txt");
while(<IN>) {
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

