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
	
my $i=0;	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
				
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
			$lc = $product_ref->{lc};
			
			if ($product_ref->{lc} eq 'xx') {
			
				if ( join(' ' , @{$product_ref->{informers_tags}}) =~ /tacite-mass-editor/) {
				
					print STDERR "Updating product $code\n";
					$i++;
					
					$User_id = "escarbot";
					$product_ref->{lc} = "fr";
					$product_ref->{lang} = "fr";
					
	# For fields that can have different values in different languages, copy the main language value to the non suffixed field
	
	foreach my $field (keys %language_fields) {
		if ($field !~ /_image/) {
		
			if ((defined $product_ref->{$field . "_xx"}) and not (defined $product_ref->{$field . "_$product_ref->{lc}"})) {
				$product_ref->{$field . "_$product_ref->{lc}"} = $product_ref->{$field . "_xx"};
				delete $product_ref->{$field . "_xx"};
			}
		
			if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
				$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
			}
		}
	}
					
	
	# Ingredients classes
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);

	compute_languages($product_ref); # need languages for allergens detection
	detect_allergens_from_text($product_ref);					
					
					store_product($product_ref, "Changing unknown main language xx to fr - scanparty-franprix-05-2016");
					
					#last;
				}
			
			}
			
			# Update

		}
	
	}

print "\n$i products modified\n\n";	
	
exit(0);

