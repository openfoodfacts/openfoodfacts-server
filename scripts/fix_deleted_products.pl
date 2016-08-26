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

foreach my $l (values %lang_lc) {

	$lc = $l;
	$lang = $l;


my $cursor = $products_collection->query({ lc => $lc })->fields({ _id=>1, id=>1, code => 1});;
my $count = $cursor->count();
my $removed = 0;
my $notfound = 0;
	
	print STDERR "$count products to check\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $id = $product_ref->{id};
		my $_id = $product_ref->{_id};
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
				if ($lc eq 'vi') {
					# store_product($product_ref, $comment);
				}
			}
		}
		else {
			print "product code $code -  _id: $_id - id $id : not found\n";
			$notfound++;
			
			# try to add 0
			$products_collection->remove({"_id" => $_id . '' });
			$products_collection->remove({"_id" => $_id + 0});

		}

	}
	
print STDERR "$lc - notfound $notfound products\n";
$total += $notfound;
}

print STDERR "total - notfound $total products\n";


exit(0);

