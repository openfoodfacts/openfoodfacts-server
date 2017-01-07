#!/usr/bin/perl

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
		
		# Update
		#extract_ingredients_classes_from_text($product_ref);
		
		my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
		
		if (not defined $changes_ref) {
			$changes_ref = [{}];
		}		
		
		compute_product_history_and_completeness($product_ref, $changes_ref);		
		
		my $change_ref = $changes_ref->[0];
		if ((not defined $change_ref->{userid}) or ($change_ref->{userid} eq '')) {
			$product_ref->{creator} = "openfoodfacts-contributors";
		}

		# Store

		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
	}

exit(0);

