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

use Getopt::Long;

my @products = ();


GetOptions ( 'products=s' => \@products);
@products = split(/,/,join(',',@products));


sub find_products($$) {

	my $dir = shift;
	my $code = shift;

	opendir DH, "$dir" or die "could not open $dir directory: $!\n";
	foreach my $file (readdir(DH)) {
		chomp($file);
		#print "file: $file\n";
		if ($file eq 'product.sto') {
			push @products, $code;
			#print "code: $code\n";
		}
		else {
			$file =~ /\./ and next;
			if (-d "$dir/$file") {
				find_products("$dir/$file","$code$file");
			}
		}
	}
	closedir DH;
}


if (scalar $#products < 0) {
	find_products("$data_root/products",'');
}





my $count = $#products;
	
	print STDERR "$count products to update\n";
	
	foreach my $code (@products) {
        
		
		my $path = product_path($code);
		
		# print STDERR "updating product $code\n";
		
		#my $product_ref = retrieve_product($code);
		my $product_ref = retrieve("$data_root/products/$path/product.sto");
		
		if ((defined $product_ref) and ($code ne '')) {
				
		$lc = $product_ref->{lc};
		$lang = $lc;
		
		my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
		if (not defined $changes_ref) {
			$changes_ref = [];
		}
		else {
			my $last = pop(@$changes_ref);
			if ($last->{comment} =~ /automatic removal/) {
				print "* automatically deleted: $code  - empty: $product_ref->{empty} - complete: $product_ref->{complete} \n";
			}
		}

		if (($product_ref->{empty} != 1) and ($product_ref->{deleted} eq 'on')) {
			print "! deleted non empty product: $code\n";
		}
		
		if ($product_ref->{empty} == 1) {
			compute_product_history_and_completeness($product_ref, $changes_ref);
			if ($product_ref->{empty} != 1) {
				print "product was empty but is not - code: $code\n";
				
				#if ($product_ref->{code} eq '3596710313266') {
				delete $product_ref->{deleted};
				store("$data_root/products/$path/product.sto", $product_ref);		
				$products_collection->save($product_ref);
				store("$data_root/products/$path/changes.sto", $changes_ref);				
				#}
			}
		}
		
	
			
		# compute_product_history_and_completeness($product_ref, $changes_ref);

		if (($product_ref->{empty} != 1) and ($product_ref->{deleted} eq 'on')) {
			print "!!! deleted non empty product: $code\n";
		}		

		#store("$data_root/products/$path/product.sto", $product_ref);		
		#$products_collection->save($product_ref);
		#store("$data_root/products/$path/changes.sto", $changes_ref);
		}
	}

exit(0);

