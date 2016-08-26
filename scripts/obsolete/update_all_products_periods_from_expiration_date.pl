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


my $cursor = $products_collection->query({})->fields({ code => 1 });;
my $count = $cursor->count();

my $periods = 0;
	
	print STDERR "$count products to update\n";
	
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

