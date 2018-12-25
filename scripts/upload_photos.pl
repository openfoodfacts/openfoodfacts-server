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

$User_id = 'stephane';

my $dir = $ARGV[0];
$dir =~ s/\/$//;

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
	lc => 'en',
	countries => "UK",
	purchase_places => "London",
);

if (opendir (DH, "$dir")) {
	foreach my $file (sort readdir(DH)) {
	
		# next if $file lt "IMG_1110.JPG";
	
		if ($file =~ /jpg/i) {
			my $code = scan_code("$dir/$file");
			print $file . "\tcode: " . $code . "\n";
			
			if ((defined $code) and (not defined $codes{$code})) {	# in some pictures we detect the wrong code, for a product we already scanned..
			# see https://world.openfoodfacts.org/cgi/product.pl?type=edit&code=5010663251270 -> a barely there code is still detected
						
				$codes{$code}++;
				
				if ((defined $current_code) and ($code ne $current_code)) {
				
					$j++;
				
					if ((defined $last_imgid) and (defined $current_product_ref)) {
						if ((not defined $current_product_ref->{images}) or (not defined $current_product_ref->{images}{'front'})) {
							print STDERR "cropping for code $current_code , last_imgid: $last_imgid\n";
							process_image_crop($current_code, 'front', $last_imgid, 0, undef, undef, -1, -1, -1, -1);
						}
					}
				
					$previous_code = $current_code;
					$last_imgid = undef;
					if ($j > 2) {
						#exit;
					}
				}				
				
				$current_code = $code;
				

				
				my $product_ref = product_exists($code); # returns 0 if not
				

		
				if (1 and (not $product_ref)) {
					print STDERR "product code $code does not exist yet, creating product\n";
					$product_ref = init_product($code);
					$product_ref->{interface_version_created} = "upload_photos.pl - version 2014/11/11";
					$product_ref->{lc} = $params{lc};
					
					foreach my $field (@fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang') {
						if (defined $params{$field}) {
							$product_ref->{$field} = remove_tags_and_quote($params{$field});
							if ($field eq 'emb_codes') {
								# French emb codes
								$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
								$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
							}
							print STDERR "product.pl - code: $code - field: $field = $product_ref->{$field}\n";
							if (defined $tags_fields{$field}) {

								$product_ref->{$field . "_tags" } = [];
								if ($field eq 'emb_codes') {
									$product_ref->{"cities_tags" } = [];
								}
								foreach my $tag (split(',', $product_ref->{$field} )) {
									if (get_fileid($tag) ne '') {
										push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
										if ($field eq 'emb_codes') {
											my $city_code = get_city_code($tag);
											if (defined $emb_codes_cities{$city_code}) {
												push @{$product_ref->{"cities_tags" }}, get_fileid($emb_codes_cities{$city_code}) ;
											}
										}
									}
								}			
							}
						
							if (defined $taxonomy_fields{$field}) {
								$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
								$product_ref->{$field . "_tags" } = [];
								foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
									push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
								}
							}		
							elsif (defined $hierarchy_fields{$field}) {
								$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy($field, $product_ref->{$field}) ];
								$product_ref->{$field . "_tags" } = [];
								foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
									if (get_fileid($tag) ne '') {
										push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
									}
								}
							}			
						}
						else {
							print STDERR "product.pl - could not find field $field\n";
						}
					}					
					
					store_product($product_ref, "Creating product (upload_photos.pl bulk upload)");
				}
				
				$current_product_ref = $product_ref;
			} # code found
			
			if (defined $current_code) {
				my $imgid = process_image_upload($current_code, "$dir/$file");
				print "process_image_upload - result: $imgid\n";
				if ($imgid > 0) {
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

