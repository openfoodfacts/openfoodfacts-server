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
		
	#	next if $code ne "3564700022153";
		
		print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		# Update all fields
	

		foreach my $field (keys %language_fields) {

			print STDERR "field: $field\n";
				if ($field !~ /_image/) {
					if ((defined $product_ref->{$field} and (not defined $product_ref->{$field . "_$lc"}))) {
					
						$product_ref->{$field . "_$lc"} = $product_ref->{$field};
					}
				}
				else {
					$field =~ s/_image//;
					print STDERR "image_field: $field\n";
					if ((defined $product_ref->{images}{$field}) ) {
						if (not defined $product_ref->{images}{$field . "_$lc"}) {
							$product_ref->{images}{$field . "_$lc"} = $product_ref->{images}{$field};
							print STDERR "updated image_field $field\n";
						}
						
						my $rev = $product_ref->{images}{$field}{rev};
						
						foreach my $size ($thumb_size, $small_size, $display_size, 'full') {
							# copy images to new name with language
							
							(! -e "$www_root/images/products/$path/${field}_$lc.$rev.$size.jpg") and system("cp -a $www_root/images/products/$path/$field.$rev.$size.jpg $www_root/images/products/$path/${field}_$lc.$rev.$size.jpg");
						}
						(! -e "$www_root/images/products/$path/${field}_$lc.$rev.full.json") and system("cp -a $www_root/images/products/$path/$field.$rev.full.json $www_root/images/products/$path/${field}_$lc.$rev.full.json");
						
					}
				}
			
		}
			
		# Store

		#$User_id = 'fieldbot';
		#store_product($product_ref, "allow Unicode characters in normalized values of tag fields");
		
		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
		
		}
	}

exit(0);

