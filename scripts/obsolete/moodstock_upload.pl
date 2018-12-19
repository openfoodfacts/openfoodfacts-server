#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
# 
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

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

my $cursor = $products_collection->query($query_ref )->fields({ code => 1, images=>1, last_modified_t=>1 } );;



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
		my $size = 400;
		
		if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
			and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
			
			$j++;
			
			my $productid = "$code - $product_ref->{product_name} - $product_ref->{brands}";
			#my $encodedid = encode_base64($productid);	
			my $encodedid = get_fileid($productid);
			$encodedid =~ s/(=|\n)*$//;

			print "uploading - $productid\n-> id: $encodedid";
			
			my $path = product_path($product_ref->{code});
		
			use HTTP::Request::Common;
			use LWP::UserAgent;
			use LWP::Authen::Digest;

			# Settings
			my $key = "6boshzcjfsqyxmnl9znd";
			my $secret = "ZunCQ56gcp53GhZb";
			my $image_filename = $www_root . '/images/products/' . $path . '/' . $id . '.' . $product_ref->{images}{$id}{rev} . '.' . $size . '.jpg';

			# Boilerplate
			my $browser = LWP::UserAgent->new();
			$browser->credentials("api.moodstocks.com:80","Moodstocks API",$key,$secret);
			my $ep = "http://api.moodstocks.com/v2";
			my $resource = $ep."/ref/".$encodedid;
			
			print "resource: $resource\n";
	 
			# Adding a reference image
			my $rq = POST(
			  $resource,
			  Content_Type => "form-data",
			  Content => [image_file => [$image_filename]]
			);
			$rq->method("PUT");
			my $response = $browser->request($rq);
			print "add -> " . $response->content . "\n";		
			
			#my $offline = $resource."/offline";
			#$response = $browser->request(HTTP::Request->new("POST",$offline));

			#print "offline url: $offline\n";
			#print "offline -> " . $response->content . "\n";		
		
		}
		
	}
	
print "$j products uploaded out of $i products\n";

exit(0);

