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

use Getopt::Long;


my $usage = <<TXT
upload_photos.pl imports product photos into the database of Product Opener.
The photos need to be taken in this order: picture of barcode first, then other pictures, last picture is the front of the product.

Usage:

upload_photos.pl --images_dir path_to_directory_containing_images --user_id user_id --comment "Scan-Party in Holland 2019"
 --define lc=nl --define stores="Ekoplazza"

--define	: allows to define field values that will be applied to all products.

TXT
;

# $User_id is a global variable from Display.pm
my %global_values = ();
my $only_import_products_with_images = 0;
my $images_dir;
my $comment = '';
my $source_id;
my $source_name;
my $source_url;
my $source_licence;
my $source_licence_url;


GetOptions (
	"images_dir=s" => \$images_dir,
	"user_id=s" => \$User_id,
	"comment=s" => \$comment,
	"define=s%" => \%global_values,
	"source_id=s" => \$source_id,
	"source_name=s" => \$source_name,
	"source_url=s" => \$source_url,
	"source_licence=s" => \$source_licence,
	"source_licence_url=s" => \$source_licence_url,
		)
  or die("Error in command line arguments:\n$\nusage");

print STDERR "import.pl
- images_dir: $images_dir
- user_id: $User_id
- comment: $comment
- global fields values:
";

foreach my $field (sort keys %global_values) {
	print STDERR "-- $field: $global_values{$field}\n";
}

my $missing_arg = 0;
if (not defined $images_dir) {
	print STDERR "missing --images_dir parameter\n";
	$missing_arg++;
}

if (not defined $User_id) {
	print STDERR "missing --user_id parameter\n";
	$missing_arg++;
}

if (not defined  $global_values{lc}) {
	print STDERR "missing --define lc= parameter\n";
	$missing_arg++;
}

$missing_arg and exit();

$images_dir =~ s/\/$//;
print "uploading photos from dir $images_dir\n";

sleep(5);

my $i = 0;
my $j = 0;
my %codes = ();
my $current_code = undef;
my $previous_code = undef;
my $last_imgid = undef;

my $current_product_ref = undef;

my @fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries misc data_sources );



$lc = $global_values{lc};


my $time = time();

if (opendir (DH, "$images_dir")) {
	foreach my $file (sort readdir(DH)) {
	
		#next if $file gt "2013-07-13 11.02.07";
		#next if $file le "DSC_1783.JPG";
	
		if ($file =~ /jpg/i) {
		
			my $code;
			
			# we can have the barcode in the image path or in the file name
			if ($images_dir =~ /\/(\d{8}\d*)(\/|$)/) {
				$code = $1;
			}
			if ($file =~ /^(\d{8}\d*)/) {
				$code = $1;
			}
			
			if (not defined $code) {
				$code = scan_code("$images_dir/$file");
			}
			
			print $file . "\tcode: " . $code . "\n";
			
			if ((defined $code) and (not defined $codes{$code})) {	# in some pictures we detect the wrong code, for a product we already scanned..
			# see http://world.openfoodfacts.org/cgi/product.pl?type=edit&code=5010663251270 -> a barely there code is still detected
						
				$codes{$code}++;
				
				if ((defined $current_code) and ($code ne $current_code)) {
				
					$j++;
				
					if ((defined $last_imgid) and (defined $current_product_ref)) {
						if ((not defined $current_product_ref->{images}) or (not defined $current_product_ref->{images}{'front'})) {
							print STDERR "cropping for code $current_code - front_$lc - , last_imgid: $last_imgid\n";
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
					$product_ref = init_product($code);
					$product_ref->{interface_version_created} = "upload_photos.pl - version 2019/04/22";
					$product_ref->{lc} = $global_values{lc};
					#store_product($product_ref, "Creating product (upload_photos.pl bulk upload) - " . $comment );
										
					
				}
				
				
				# Create or update fields
				
				foreach my $field (@fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang') {
						
					if (defined $global_values{$field}) {				

						add_tags_to_field($product_ref, $lc, $field, $global_values{$field});
				
						print STDERR "product.pl - code: $code - field: $field = $product_ref->{$field}\n";
						
						compute_field_tags($product_ref, $lc, $field);						

					}
				}
				
				if (defined $source_id) {
					if (not defined $product_ref->{sources}) {
						$product_ref->{sources} = [];
					}

					my $product_source_url = $source_url;

					my $source_ref = {
						id => $source_id,
						name => $source_name,
						url => $product_source_url,
						collaboration => 1,
						import_t => time(),
					};

					defined $source_licence and $source_ref->{source_licence} = $source_licence;
					defined $source_licence_url and $source_ref->{source_licence_url} = $source_licence_url;

					push @{$product_ref->{sources}}, $source_ref;				
				}
				
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
			
				my $imgid;
				my $return_code = process_image_upload($current_code, "$images_dir/$file", $User_id, $filetime, $comment, \$imgid);
				
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
	print STDERR "Could not open dir $images_dir: $!\n";
}

print "$i images\n";
print (scalar (keys %codes)) . " codes\n";

