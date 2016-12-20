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

my $class = 'additives';

open (OLD, q{>}, "$www_root/images/$class.old.html");
open (NEW, q{>}, "$www_root/images/$class.new.html");


my $cursor = $products_collection->query({})->fields({ code => 1 })->sort({code =>1});
my $count = $cursor->count();
	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		# Update
		extract_ingredients_classes_from_text($product_ref);

		# Store
		
		next if $path =~ /invalid/;

		if (-e "$data_root/products/$path/product.sto") {
			store("$data_root/products/$path/product.sto", $product_ref);		
			$products_collection->save($product_ref);
		
			if (defined $product_ref->{old_additives_tags}) {
				print OLD "<a href=\"" . product_url($product_ref) . "\">$product_ref->{code} - $product_ref->{name}</a> : " . join (" ", sort @{$product_ref->{old_additives_tags}}) . "<br />\n";
			}
			if (defined $product_ref->{new_additives_tags}) {
				print NEW "<a href=\"" . product_url($product_ref) . "\">$product_ref->{code} - $product_ref->{name}</a> : " . join (" ", sort @{$product_ref->{new_additives_tags}}) . "<br />\n";
			}			
		}
	}
	
close OLD;	
close NEW;

exit(0);

