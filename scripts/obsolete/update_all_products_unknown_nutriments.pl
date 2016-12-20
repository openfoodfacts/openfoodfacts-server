#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2015';
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

