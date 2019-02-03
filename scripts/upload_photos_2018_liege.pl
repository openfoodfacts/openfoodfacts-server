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
use JSON::PP;
use Time::Local;

$User_id = 'uliege';

my $editor_user_id = 'uliege';

my $dir = $ARGV[0];
$dir =~ s/\/$//;

my $photo_user_id = $ARGV[1];

$User_id = 'uliege';
$photo_user_id = "uliege";
$editor_user_id = "uliege";

not defined $photo_user_id and die;

print "uploading photos from dir $dir\n";

my $i = 0;
my $j = 0;
my %codes = ();
my $current_code = undef;
my $previous_code = undef;
my $last_imgid = undef;

my $current_product_ref = undef;

my @fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );


my %params = (
#	lc => 'sv',
#	countries => "Sverige",
	lc => 'fr',
	countries => "Belgique",
	stores => "Colruyt",
);

$lc = 'fr';


my $comment = "Photos de l'Université de Liège";

my $time = time();

if (opendir (DH, "$dir")) {
	foreach my $file (sort readdir(DH)) {
	
		#next if $file gt "2013-07-13 11.02.07";
		#next if $file le "DSC_1783.JPG";
	
		if ($file =~ /jpg/i) {
			my $code = scan_code("$dir/$file");
			print $file . "\tcode: " . $code . "\n";
			
			if ((defined $code) and (not defined $codes{$code})) {	# in some pictures we detect the wrong code, for a product we already scanned..
			# see http://world.openfoodfacts.org/cgi/product.pl?type=edit&code=5010663251270 -> a barely there code is still detected
						
				$codes{$code}++;
				
				if ((defined $current_code) and ($code ne $current_code)) {
				
					$j++;
				
					if ((defined $last_imgid) and (defined $current_product_ref)) {
						if ((not defined $current_product_ref->{images}) or (not defined $current_product_ref->{images}{'front'})) {
							print STDERR "cropping for code $current_code - front_$lc - , last_imgid: $last_imgid\n";
							$User_id = $photo_user_id;
							process_image_crop($current_code, "front_$lc", $last_imgid, 0, undef, undef, -1, -1, -1, -1);
						}
					}
				
					$previous_code = $current_code;
					$last_imgid = undef;
					if ($j > 10000) {
						print STDERR "stopping - j = $j\n";
						exit;
					}
				}				
				
				$current_code = $code;
				

				
				my $product_ref = product_exists($code); # returns 0 if not
				

		
				if (1 and (not $product_ref)) {
					print STDERR "product code $code does not exist yet, creating product\n";
					$User_id = $photo_user_id;
					$product_ref = init_product($code);
					$product_ref->{interface_version_created} = "upload_photos.pl - version 2017/09/11";
					$product_ref->{lc} = $params{lc};
					#store_product($product_ref, "Creating product (upload_photos.pl bulk upload) - " . $comment );
										
					
				}
				
				else { 
					# do not update products that have already been uploaded
					if (join(" ", $product_ref->{editors_tags} =~ /$editor_user_id/)) {
						#print STDERR "product $code already has $product_ref->{editors_tags} in editors\n";
						#next;
					}
				}
				
				# Create or update fields
				
				foreach my $field (@fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang') {
						
					if (defined $params{$field}) {				

						add_tags_to_field($product_ref, $lc, $field, $params{$field});
				
						print STDERR "product.pl - code: $code - field: $field = $product_ref->{$field}\n";
						
						compute_field_tags($product_ref, $lc, $field);						

					}
				}
				
				$User_id = $editor_user_id;
				store_product($product_ref, "Editing product (upload_photos.pl bulk upload) - " . $comment );
				
				$current_product_ref = $product_ref;
			} # code found
			
			if (defined $current_code) {
			
				my $filetime = $time;
				
				# 2013-07-13 11.02.07
				if ($file =~ /(20\d\d).(\d\d).(\d\d).(\d\d).(\d\d).(\d\d)/) {
					$filetime = timelocal( $6, $5, $4, $3, $2 - 1, $1 );
				}				
				# 20150712_173454.jpg
				elsif ($file =~ /(20\d\d)(\d\d)(\d\d)(-|_|\.)/) {
					$filetime = timelocal( 0 ,0 , 0, $3, $2 - 1, $1 );
				}					
				elsif ($file =~ /(20\d\d).(\d\d).(\d\d)./) {
					$filetime = timelocal( 0 ,0 , 0, $3, $2 - 1, $1 );
				}				
			
				$User_id = $photo_user_id;
				my $imgid;
				my $return_code = process_image_upload($current_code, "$dir/$file", $User_id, $filetime, $comment, \$imgid);
				
				print "process_image_upload - file: $file - filetime: $filetime - result: $imgid\n";
				if (($imgid > 0) and ($imgid <= 2)) { # assume the 1st image is the barcode, and 2nd the product front (or 1st if there's only one image)
					$last_imgid = $imgid;
				}
			}				
			
			$i++;
			
		} #jpg
		
	}
	closedir DH;
}
else {
	print STDERR "Could not open dir $dir: $!\n";
}

print "$i images\n";
print (scalar (keys %codes)) . " codes\n";

