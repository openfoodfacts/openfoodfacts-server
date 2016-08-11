#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
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
use JSON;


# Get a list of all products


my $cursor = $products_collection->query({})->fields( {'code' => 1, '_id'=>1, 'lc'=>1});

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
		
		#$products_collection->remove({"code" => $code});
		
		# index_product($product_ref);

		# Store

		# store("$data_root/products/$path/product.sto", $product_ref);		
		# $products_collection->save($product_ref);
		}
	}

print "$i products, removed $j\n";	
	
exit(0);

