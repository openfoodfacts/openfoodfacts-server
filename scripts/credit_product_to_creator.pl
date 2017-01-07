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

