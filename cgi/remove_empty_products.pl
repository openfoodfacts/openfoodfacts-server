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

my $total = 0;
my $l = 'en';

	$lc = $l;
	$lang = $l;


my $cursor = $products_collection->query({empty => 1})->fields({ code => 1, empty => 1 });;
my $count = $cursor->count();
my $removed = 0;
	
	print STDERR "$count products to check\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		#print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
				
			$lc = $product_ref->{lc};
			$lang = $lc;
			
			if (($product_ref->{empty} == 1) and (time() > $product_ref->{last_modified_t} + 86400)) {
				$product_ref->{deleted} = 'on';
				my $comment = "automatic removal of product without information or images";

				# print STDERR "removing product code $code\n";
				$removed++;
				if ($lc ne 'xx') {
					store_product($product_ref, $comment);
				}
			}
		}
		else {
			print "product $code : file not found\n";
		}

	}
	
print STDERR "$lc - removed $removed products\n";
$total += $removed;


print STDERR "total - removed $total products\n";


exit(0);

