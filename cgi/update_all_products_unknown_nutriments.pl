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
		
		
		$product_ref = retrieve_product($code);
		
		# Update
		#extract_ingredients_classes_from_text($product_ref);
		
		if (defined $product_ref->{nutriments}) {

	fix_salt_equivalent($product_ref);
	
	compute_serving_size_data($product_ref);
		
	compute_nutrient_levels($product_ref);
	
	compute_unknown_nutrients($product_ref);
				

				# Store

				store("$data_root/products/$path/product.sto", $product_ref);		
				$products_collection->save($product_ref);				
				
				print STDERR "updated product $code\n";

				
			
			
		}
		

	}

exit(0);

