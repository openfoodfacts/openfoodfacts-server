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
	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		my $normalize_code = normalize_code($code);
		
		if ((length($code) == 12) and ($normalize_code ne $code)) {
		
			print STDERR "updating product upc $code\n";
			
			$product_ref = retrieve_product($code);
			
			if ((defined $product_ref) and ($code ne '')) {
				print STDERR "loaded product_ref $code\n";
				$product_ref->{old_code} = $code;
				$product_ref->{code} = "0" . $code;
				$User_id = 'upcbot';
				store_product($product_ref, "normalizing code from UPC-12 $code to EAN-13 0$code");
				#exit();
			}
		}
	}

exit(0);

