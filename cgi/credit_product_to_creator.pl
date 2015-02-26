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

my $code = $ARGV[0];
my $creator = $ARGV[1];

print "assigning product code $code to $creator\n";

my	$product_ref = retrieve_product($code);
		
		if (not defined $product_ref) {
			print "product code $code not found\n";
		}
		else {
			my $path = product_path($code);
			$product_ref->{creator} = $creator;

			store("$data_root/products/$path/product.sto", $product_ref);		
			$products_collection->save($product_ref);
		}
	

exit(0);

