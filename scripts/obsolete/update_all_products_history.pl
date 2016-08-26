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
		$lang = $lc;
		
		my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
		if (not defined $changes_ref) {
			$changes_ref = [];
		}		
	
		#make sure we have numbers for dates
		$product_ref->{last_modified_t} += 0;
		$product_ref->{created_t} += 0;
		
		compute_product_history_and_completeness($product_ref, $changes_ref);
		
		# sort_key
		# add 0 just to make sure we have a number...  last_modified_t at some point contained strings like  "1431125369"
		$product_ref->{sortkey} = 0 + $product_ref->{last_modified_t} - ((1 - $product_ref->{complete}) * 1000000000);


		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
		store("$data_root/products/$path/changes.sto", $changes_ref);
		}
	}

exit(0);

