#!/usr/bin/perl
# This file is used to upload images to the Moodstocks API for offline image recognition

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
use JSON::PP;
use MIME::Base64;




use Getopt::Long;

my $agemin;
my $agemax;
my $pretend;

GetOptions ( 'agemin=s' => \$agemin, 'agemax=s' => \$agemax, 'pretend'=>\$pretend);

# Get a list of all products

# my $cursor = $products_collection->query({  complete=>1, categories_tags=>'chocolats', creator => 'stephane' })->fields({ code => 1, images=>1 } );;

my $query_ref = {  complete=>1} ;

if (defined $agemin) {
#	defined $query_ref->{ last_modified_t } or $query_ref->{ last_modified_t } = {};
#	$query_ref->{ last_modified_t }{'$lt' => (time() - $agemin * 86400)};
}

if (defined $agemax) {
	#defined $query_ref->{ last_modified_t } or $query_ref->{ last_modified_t } = {};
#	$query_ref->{ last_modified_t }{'$gt' => (time() - $agemax * 86400)};
}

my $cursor = $products_collection->query($query_ref )->fields({ code => 1, images=>1, last_modified_t=>1 } )->sort({"unique_scans_n" => -1})->limit(10000);



my $count = $cursor->count();
my $i = 0;
my $j = 0;

	
	print STDERR "$count products to update\n";
	
	
	while (my $product_ref = $cursor->next) {
        
if (defined $agemin) {
#	defined $query_ref->{ last_modified_t } or $query_ref->{ last_modified_t } = {};
#	$query_ref->{ last_modified_t }{'$lt' => (time() - $agemin * 86400)};
	next if ($product_ref->{last_modified_t} > time() - $agemin * 86400);
}

if (defined $agemax) {
	#defined $query_ref->{ last_modified_t } or $query_ref->{ last_modified_t } = {};
#	$query_ref->{ last_modified_t }{'$gt' => (time() - $agemax * 86400)};
	next if ($product_ref->{last_modified_t} < time() - $agemax * 86400);

}		
		
		$i++;
		$pretend and next;

		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		print "$code\t$product_ref->{product_name}\t$product_ref->{brands}\n";

		
		my $id = 'front';
		my $size = "full";
		
		if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
			and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
			
			$j++;
			
			my $productid = "$code - $product_ref->{product_name} - $product_ref->{brands}";
			#my $encodedid = encode_base64($productid);	
			my $encodedid = get_fileid($productid);
			$encodedid =~ s/(=|\n)*$//;

			print "uploading - $productid\n-> id: $encodedid";
			
			my $path = product_path($product_ref->{code});
		
			my $image_filename = $www_root . '/images/products/' . $path . '/' . $id . '.' . $product_ref->{images}{$id}{rev} . '.' . $size . '.jpg';

	

			system( "cp $image_filename /home/off/html/images/popular-products/$encodedid.jpg");
	
		}

	$i > 10000 and last;
		
	}
	
print "$j products uploaded out of $i products\n";

exit(0);

