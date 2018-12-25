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

use strict;
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");

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
use ProductOpener::SiteQuality qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;

use Text::CSV;

my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

$lc = "fr";

$User_id = 'sodebo';

my $editor_user_id = 'sodebo';

$User_id = $editor_user_id;
my $photo_user_id = $editor_user_id;
$editor_user_id = $editor_user_id;

not defined $photo_user_id and die;

my $csv_file = "/data/off/sodebo/2018_09_05-PRODUITS_SODEBO_OFF.csv";
my $imagedir = "/data/off/sodebo/images_20180905";

#my $csv_file = "/home/sodebo/SUYQD_AKENEO_PU_04.csv";
#my $categories_csv_file = "/home/sodebo/sodebo-categories.csv";
#my $imagedir = "/home/sodebo/all_product_images"; 

print "uploading csv_file: $csv_file, image_dir: $imagedir\n";

# Images

# 3 242 278 203 753_TAK_SamPou.jpg



my $images_ref = {};


my %categories = ();

print "Opening image dir $imagedir\n";

if (opendir (DH, "$imagedir")) {
	foreach my $file (sort { $a cmp $b } readdir(DH)) {

		if ($file =~ /^((\d| )+)_(.*?)\.(jpg|jpeg|png)/i) {
		
			my $code = $1;
			$code =~ s/\s//g;

			my $imagefield = "front";

			
			print "FOUND IMAGE FOR PRODUCT CODE $code - file $file - imagefield: $imagefield\n";

			defined $images_ref->{$code} or $images_ref->{$code} = {};
			
			# push @{$images_ref->{$code}}, $file;
			# keep jpg if there is also a png
			if (not defined $images_ref->{$code}{$imagefield}) {
				$images_ref->{$code}{$imagefield} = $file;
			}
		}
	
	}
}

closedir (DH);


my $i = 0;
my $j = 0;
my %codes = ();
my $current_code = undef;
my $previous_code = undef;
my $last_imgid = undef;

my $current_product_ref = undef;

my @fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

my @param_sorted_langs = qw(fr);

my %global_params = (
	lc => 'fr',
	countries => "France",
	brands => "U",
);

$lc = 'fr';

my $comment = "Sodebo direct data import";

my $time = time();

my $existing = 0;
my $new = 0;
my $differing = 0;
my %differing_fields = ();
my @edited = ();
my %edited = ();

my $testing = 0;
# my $testing = 1;

print STDERR "importing products - csv file: $csv_file\n";

open (my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open $csv_file: $!");

# ignore first line
#$csv->getline ($io);

$csv->column_names ($csv->getline ($io));

# code	ingredients_text	allergens	image_url	url	product_name	generic_name	 quantity 	brand	brands	categories	origins	manufacturing_places	serving_size		energy_100g	 fat_100g 	 saturated-fat_100g 	 carbohydrates_100g 	 sugars_100g 	 fiber_100g 	 proteins_100g 	 salt_100g 	 fruits-vegetables-nuts_100g 	nutrition-score-fr_100g



while (my $imported_product_ref = $csv->getline_hr ($io)) {
  	
			$i++;

			print "$i\n";

			#print $json;
			
			my $modified = 0;
			
			my @modified_fields;
			my @images_ids;
			
			my $code = $imported_product_ref->{code};
			$code =~ s/\s//g;
			
			#next if ($code ne "3256226388720");
			
			# next if ($i < 2665);
			
			print "PRODUCT LINE NUMBER $i - CODE $code\n";
			
			if (not defined $images_ref->{$code}) {
				print "MISSING IMAGES ALL - PRODUCT CODE $code\n";
			}
			if (not defined $images_ref->{$code}{front}) {
				print "MISSING IMAGES FRONT - PRODUCT CODE $code\n";
				next;
			}
			#if (not defined $images_ref->{$code}{ingredients}) {
			#	print "MISSING IMAGES INGREDIENTS - PRODUCT CODE $code\n";
			#}			
			#if (not defined $images_ref->{$code}{nutrition}) {
			#	print "MISSING IMAGES NUTRITION - PRODUCT CODE $code\n";
			#}			
			#
			#if ((not defined $images_ref->{$code}) or (not defined $images_ref->{$code}{front}) or (not defined $images_ref->{$code}{ingredients})) {
			#	print "MISSING IMAGES SOME - PRODUCT CODE $code\n";
		    #		next;
			#}
			
			print "product $i - code: $code\n";
			
			if ($code eq '') {
				print STDERR "empty code\n";
				use Data::Dumper;
				print STDERR Dumper($imported_product_ref);
				print "EMPTY CODE\n";
				next;
			}			
	
			
			# next if $code ne "3302741714107";
			
			my $product_ref = product_exists($code); # returns 0 if not
			
			if (not $product_ref) {
				print "- does not exist in OFF yet\n";
				$new++;
				if (1 and (not $product_ref)) {
					print "product code $code does not exist yet, creating product\n";
					$User_id = $photo_user_id;
					$product_ref = init_product($code);
					$product_ref->{interface_version_created} = "import_sodebo.pl - version 2018/06/14";
					$product_ref->{lc} = $global_params{lc};
					delete $product_ref->{countries};
					delete $product_ref->{countries_tags};
					delete $product_ref->{countries_hierarchy};					
					store_product($product_ref, "Creating product (import_sodebo.pl bulk upload) - " . $comment );					
				}				
				
			}
			else {
				print "- already exists in OFF\n";
				$existing++;
			}
	
			# First load the global params, then apply the product params on top
			my %params = %global_params;		
	
	
			if (not $testing) {
				print STDERR "uploading images for product code $code\n";

				if (defined $images_ref->{$code}) {
					my $images_ref = $images_ref->{$code};
					
					foreach my $imagefield ('front','ingredients','nutrition') {
						
						next if not defined $images_ref->{$imagefield};
						
						my $current_max_imgid = -1;
						
						if (defined $product_ref->{images}) {
							foreach my $imgid (keys %{$product_ref->{images}}) {
								if (($imgid =~ /^\d/) and ($imgid > $current_max_imgid)) {
									$current_max_imgid = $imgid;
								}
							}
						}
					
						my $imported_image_file = $images_ref->{$imagefield};
					
						# upload the image
						my $file = $imported_image_file;
						$file =~ s/(.*)cloudfront.net\///;
						if (-e "$imagedir/$file") {
							print "found image file $imagedir/$file\n";
							
							# upload a photo
							my $imgid;
							my $return_code = process_image_upload($code, "$imagedir/$file", $User_id, undef, $comment, \$imgid);
							print "process_image_upload - file: $file - return code: $return_code - imgid: $imgid\n";	
							
							
							if (($imgid > 0) and ($imgid > $current_max_imgid)) {

								print STDERR "assigning image $imgid to $imagefield-fr\n";
								eval { process_image_crop($code, $imagefield . "_fr", $imgid, 0, undef, undef, -1, -1, -1, -1); };
					
							}
							else {
								print STDERR "returned imgid $imgid not greater than the previous max imgid: $current_max_imgid\n";
							}
						}
						else {
							print "did not find image file $imagedir/$file\n";
						}
					
					}

				}
				
				# reload the product (changed by image upload)
				$product_ref = retrieve_product($code);
			}
			
	
			
			
			if ((defined $imported_product_ref->{categories}) and ($imported_product_ref->{categories} ne "")) {
				my $category = ucfirst(lc($imported_product_ref->{categories}));
				#$category =~ s/^fr://;
				$params{categories} = $category;
				print "assigning category $category from categories $imported_product_ref->{categories}\n";
			}
			
			# allergens
			
# UGC_allergenStatement
# A conserver dans un endroit sec, à température ambiante et à l'abri de la lumière.
# Sulfites et SO2 > 10ppm
# Céréale contenant du gluten
# Céréale contenant du gluten
# Crustacés, Sulfites et SO2 > 10ppm, Mollusques, Lait, Produits laitiers et dérivées, Céréale contenant du gluten
# AMANDES, CREME, LACTOSE, LAIT, NOISETTES, OEUF, PISTACHES, SULFITES
# BEURRE, CREME, LAIT, NOISETTE, OEUF, OEUFS
# CREME, LAIT
			
			
			my $allergens_field = "allergens";
			
			$params{allergens} = "";
			$params{traces} = "";
			
			foreach my $allergen_value (split (/(,|;| et )/i, $imported_product_ref->{allergens})) {
			
				my $allergen = $allergen_value;
				next if not defined $allergen;
				
				
				$allergen =~ s/Ce produit contient//i;
				
				if ($allergen =~ /contenir des traces/i) {
					$allergens_field = "traces";
					$allergen = $';
				}
				
				$allergen =~ s/^\s*(du |de |des |d'|d’)\s*//;
				$allergen =~ s/^\s*?(la |l'|l’)\s*//;
			
				$allergen =~ s/^\s+//;
				$allergen =~ s/(\.|\s)+$//;

				

				if ($allergen !~ /^\s*(,|et)?\s*$/i ) {
					$params{$allergens_field} .= ", " . $allergen;
				}
				
			}
			
			
			
			$params{allergens} =~ s/^, //;
			$params{traces} =~ s/^, //;
			
			print STDERR "allergens for product code $code : " . $params{allergens} . "\n";
			print STDERR "traces for product code $code : " . $params{traces} . "\n";
			


				
				$params{product_name} = $imported_product_ref->{generic_name};
				$params{brands} = "Sodebo";
				if ($imported_product_ref->{brands} !~ /GALET.INDIVIDUELLE/i) {
					$params{brands} .= ", " . ucfirst(lc($imported_product_ref->{brands}));
				}
				$params{quantity} = $imported_product_ref->{quantity} . " g";
				
				$params{link} = $imported_product_ref->{link};
				
				
				print "set product_name to $params{product_name}\n";
				
				# copy value to main language
				$params{"product_name_" . $global_params{lc}} = $params{product_name};				
			

			
				$params{product_name} =~ s/\s+$//;
				$params{link} =~ s/\s+$//;
				$params{brands} =~ s/\s+$//;
				$params{brands} =~ s/\s+/ /;
				
				$params{quantity} =~ s/\s+$//;
				$params{quantity} =~ s/\s+/ /;
				$params{packaging} =~ s/\s+$//;	
				
				$params{product_name} =~ s/^\s+//;
				$params{brands} =~ s/^\s+//;
				$params{quantity} =~ s/^\s+//;
				$params{packaging} =~ s/^\s+//;					
			



			my %ingredients_fields = (
				'ingredients_text' => 'ingredients_text_fr',
			);
			
			foreach my $field (sort keys %ingredients_fields) {
			
				if ((defined $imported_product_ref->{$field}) and ($imported_product_ref->{$field} ne '')) {
					# cleaning
					$imported_product_ref->{$field} =~ s/(\s|\/|\/|_|-)+$//is;
					$imported_product_ref->{$field} =~  s/Informations en gras destinées aux personnes allergiques.//i;					
					$params{$ingredients_fields{$field}} = $imported_product_ref->{$field};
					print STDERR "setting ingredients, field $field -> $ingredients_fields{$field}, value: " . $imported_product_ref->{$field} . "\n";
				}
			}
			
			
			# $params{ingredients_text} = $params{ingredients_text_fr};

			
			$params{serving_size} = $imported_product_ref->{serving_size} . " g";
			$params{serving_size} =~ s/\s+/ /;
					
			
			
			# Create or update fields
			
			my @param_fields = ();
			
			my @fields = @ProductOpener::Config::product_fields;
			foreach my $field ('product_name', 'generic_name', @fields, 'serving_size', 'allergens', 'traces', 'ingredients_text','lang') {
			
				if (defined $language_fields{$field}) {
					foreach my $display_lc (@param_sorted_langs) {
						push @param_fields, $field . "_" . $display_lc;
					}
				}
				else {
					push @param_fields, $field;
				}
			}
	
				
					
			foreach my $field (@param_fields) {
			

				
				if (defined $params{$field}) {				

				
					print STDERR "defined value for field $field : " . $params{$field} . "\n";
				
					# for tag fields, only add entries to it, do not remove other entries
					
					if (defined $tags_fields{$field}) {
					
						my $current_field = $product_ref->{$field};
						
						# brands -> remove existing values;
						if ($field eq 'brands') {
							$product_ref->{$field} = "";
							delete $product_ref->{$field . "_tags"};
						}

						my %existing = ();
							if (defined $product_ref->{$field . "_tags"}) {
							foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
								$existing{$tagid} = 1;
							}
						}
						
						
						foreach my $tag (split(/,/, $params{$field})) {
		
							my $tagid;
							
							next if $tag =~ /^(\s|,|-|\%|;|_|°)*$/;
							
							$tag =~ s/^\s+//;
							$tag =~ s/\s+$//;

							if (defined $taxonomy_fields{$field}) {
								$tagid = get_taxonomyid(canonicalize_taxonomy_tag($params{lc}, $field, $tag));
							}
							else {
								$tagid = get_fileid($tag);
							}
							if (not exists $existing{$tagid}) {
								print "- adding $tagid to $field: $product_ref->{$field}\n";
								$product_ref->{$field} .= ", $tag";
							}
							else {
								#print "- $tagid already in $field\n";
							}
							
						}
						
						if ($product_ref->{$field} =~ /^, /) {
							$product_ref->{$field} = $';
						}	
						
						if ($field eq 'emb_codes') {
							# French emb codes
							$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
							$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
						}
						if ($current_field ne $product_ref->{$field}) {
							print "changed value for product code: $code - field: $field = $product_ref->{$field} - old: $current_field\n";
							compute_field_tags($product_ref, $field);
							push @modified_fields, $field;
							$modified++;
						}
						elsif ($field eq "brands") {	# we removed it earlier
							compute_field_tags($product_ref, $field);
						}
						
						if (($field eq 'categories') and ($product_ref->{$field} eq "")) {
							print "categories: " . $imported_product_ref->{categories} . " -  value for product code: $code - field: $field = $product_ref->{$field} - old: $current_field\n";
							print "params{categories} $params{categories}\n";
							#exit;
						}
					
					}
					else {
						# non-tag field
						my $new_field_value = $params{$field};
						
						$new_field_value =~ s/\s+$//;
						$new_field_value =~ s/^\s+//;
						
						if (($field eq 'quantity') or ($field eq 'serving_size')) {
							
								# openfood.ch now seems to round values to the 1st decimal, e.g. 28.0 g
								$new_field_value =~ s/\.0 / /;			
								
								# 6x90g
								$new_field_value =~ s/(\d)(\s*)x(\s*)(\d)/$1 x $4/i;

								$new_field_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
								$new_field_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
								#$new_field_value =~ s/(\d)( )?cl/${1}0 ml/i;
								#$new_field_value =~ s/(\d)( )?dl/${1}00 ml/i;
								$new_field_value =~ s/litre|litres|liter|liters/l/i;
								#$new_field_value =~ s/(0)(,|\.)(\d)( )?(l)(\.)?/${3}00 ml/i;
								#$new_field_value =~ s/(\d)(,|\.)(\d)( )?(l)(\.)?/${1}${3}00 ml/i;
								#$new_field_value =~ s/(\d)( )?(l)(\.)?/${1}000 ml/i;
								$new_field_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
								#$new_field_value =~ s/(0)(,|\.)(\d)( )?(kg)(\.)?/${3}00 g/i;
								#$new_field_value =~ s/(\d)(,|\.)(\d)( )?(kg)(\.)?/${1}${3}00 g/i;
								#$new_field_value =~ s/(\d)( )?(kg)(\.)?/${1}000 g/i;
						}
						
						$new_field_value =~ s/\s+$//g;
						$new_field_value =~ s/^\s+//g;							

						my $normalized_new_field_value = $new_field_value;

						
						# existing value?
						if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {
							my $current_value = $product_ref->{$field};
							$current_value =~ s/\s+$//g;
							$current_value =~ s/^\s+//g;							
							
							# normalize current value
							if (($field eq 'quantity') or ($field eq 'serving_size')) {								
							
								$current_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
								$current_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
								#$current_value =~ s/(\d)( )?cl/${1}0 ml/i;
								#$current_value =~ s/(\d)( )?dl/${1}00 ml/i;
								$current_value =~ s/litre|litres|liter|liters/l/i;
								#$current_value =~ s/(0)(,|\.)(\d)( )?(l)(\.)?/${3}00 ml/i;
								#$current_value =~ s/(\d)(,|\.)(\d)( )?(l)(\.)?/${1}${3}00 ml/i;
								#$current_value =~ s/(\d)( )?(l)(\.)?/${1}000 ml/i;
								$current_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
								#$current_value =~ s/(0)(,|\.)(\d)( )?(kg)(\.)?/${3}00 g/i;
								#$current_value =~ s/(\d)(,|\.)(\d)( )?(kg)(\.)?/${1}${3}00 g/i;
								#$current_value =~ s/(\d)( )?(kg)(\.)?/${1}000 g/i;
							}
							
							if ($field =~ /ingredients/) {
							
								#$current_value = get_fileid(lc($current_value));
								#$current_value =~ s/\W+//g;
								#$normalized_new_field_value = get_fileid(lc($normalized_new_field_value));
								#$normalized_new_field_value =~ s/\W+//g;
								
							}
							
							if (lc($current_value) ne lc($normalized_new_field_value)) {
								print "differing value for product code $code - field $field - existing value: $product_ref->{$field} (normalized: $current_value) - new value: $new_field_value - https://world.openfoodfacts.org/product/$code \n";
								$differing++;
								$differing_fields{$field}++;		

								print "changing previously existing value for product code $code - field $field - value: $new_field_value\n";
								$product_ref->{$field} = $new_field_value;
								push @modified_fields, $field;
								$modified++;								
							}
							elsif (($field eq 'quantity') and ($product_ref->{$field} ne $new_field_value)) {
								# normalize quantity
								$product_ref->{$field} = $new_field_value;
								push @modified_fields, $field;
								$modified++;
							}
							

						}
						else {
							print "setting previously unexisting value for product code $code - field $field - value: $new_field_value\n";
							$product_ref->{$field} = $new_field_value;
							push @modified_fields, $field;
							$modified++;
						}
					}					
				}
			}
			
			
			# Nutrients

			# energy_100g	 fat_100g 	 saturated-fat_100g 	 carbohydrates_100g 	 sugars_100g 	 fiber_100g 	 proteins_100g 	 salt_100g 	 fruits-vegetables-nuts_100g 

			
			foreach my $nid (sort keys %Nutriments) {
			
				if ((defined $imported_product_ref->{$nid . "_100g"}) and ($imported_product_ref->{$nid . "_100g"} =~ /\d/)) {
				
					my $value =  $imported_product_ref->{$nid . "_100g"};
					$value =~ s/\s//g;
					$value =~ s/,/\./;
					my $unit = 'g';
					if ($nid eq 'energy') {
						$unit = "kJ";
					}
					my $modifier = "";				

					my $new_value = $value;
					
					if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{$nid})
						and ($new_value ne $product_ref->{nutriments}{$nid})						) {
						my $current_value = $product_ref->{nutriments}{$nid};
						print "differing nutrient value for product code $code - nid $nid - existing value: $current_value - new value: $new_value - https://world.openfoodfacts.org/product/$code \n";
					}
					
					if ((not defined $product_ref->{nutriments}) or (not defined $product_ref->{nutriments}{$nid})
						or ($new_value ne $product_ref->{nutriments}{$nid}) ) {
					
						if ((defined $modifier) and ($modifier ne '')) {
							$product_ref->{nutriments}{$nid . "_modifier"} = $modifier;
						}
						else {
							delete $product_ref->{nutriments}{$nid . "_modifier"};
						}					
						
						$product_ref->{nutriments}{$nid . "_unit"} = $unit;
						
						$product_ref->{nutriments}{$nid . "_value"} = $value;

						$product_ref->{nutriments}{$nid} = $new_value;
						
						$product_ref->{nutrition_data_per} = "100g";
						
						print STDERR "Setting $nid to $value $unit\n";
						
						$modified++;
					}
							
				
				}
				
			}
			
			

			

			
			# Skip further processing if we have not modified any of the fields
			
			print STDERR "product code $code - number of modifications - $modified\n";
			if ($modified == 0) {
				print STDERR "skipping product code $code - no modifications\n";
				next;
			}
			#exit;
		

			
			
			# Process the fields

			# Food category rules for sweeetened/sugared beverages
			# French PNNS groups from categories
			
			if ($server_domain =~ /openfoodfacts/) {
				ProductOpener::Food::special_process_product($product_ref);
			}
			
			
			if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
				push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
				push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
			}	
			
			if ((defined $product_ref->{nutriments}{"glycemic-index"}) and ($product_ref->{nutriments}{"glycemic-index"} ne '')) {
				push @{$product_ref->{"labels_hierarchy" }}, "en:glycemic-index";
				push @{$product_ref->{"labels_tags" }}, "en:glycemic-index";
			}
			
			# Language and language code / subsite
			
			if (defined $product_ref->{lang}) {
				$product_ref->{lc} = $product_ref->{lang};
			}
			
			if (not defined $lang_lc{$product_ref->{lc}}) {
				$product_ref->{lc} = 'xx';
			}	
			
			
			# For fields that can have different values in different languages, copy the main language value to the non suffixed field
			
			foreach my $field (keys %language_fields) {
				if ($field !~ /_image/) {
					if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
						$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
					}
				}
			}
							
			if (not $testing) {
				# Ingredients classes
				extract_ingredients_from_text($product_ref);
				extract_ingredients_classes_from_text($product_ref);

				compute_languages($product_ref); # need languages for allergens detection
				detect_allergens_from_text($product_ref);			

			}
			
#"sources": [
#{
#"id", "usda-ndb",
#"url", "https://ndb.nal.usda.gov/ndb/foods/show/58513?format=Abridged&reportfmt=csv&Qv=1" (direct product url if available)
#"import_t", "423423" (timestamp of import date)
#"fields" : ["product_name","ingredients","nutrients"]
#"images" : [ "1", "2", "3" ] (images ids)
#},
#{
#"id", "usda-ndb",
#"url", "https://ndb.nal.usda.gov/ndb/foods/show/58513?format=Abridged&reportfmt=csv&Qv=1" (direct product url if available)
#"import_t", "523423" (timestamp of import date)
#"fields" : ["ingredients","nutrients"]
#"images" : [ "4", "5", "6" ] (images ids)
#},			

			if (not defined $product_ref->{sources}) {
				$product_ref->{sources} = [];
			}
			
			push @{$product_ref->{sources}}, {
				id => "sodebo",
				name => "Sodebo",
				url => "https://www.sodebo.com/",
				manufacturer => 1,
				import_t => time(),
				fields => \@modified_fields,
				images => \@images_ids,	
			};

			
				
			$User_id = $editor_user_id;
			
			if (not $testing) {
			
				fix_salt_equivalent($product_ref);
					
				compute_serving_size_data($product_ref);
				
				compute_nutrition_score($product_ref);
				
				compute_nutrient_levels($product_ref);
				
				compute_unknown_nutrients($product_ref);
				
				ProductOpener::SiteQuality::check_quality($product_ref);
			
			
				#print STDERR "Storing product code $code\n";
				#				use Data::Dumper;
				#print STDERR Dumper($product_ref);
				#exit;
				
				
				
				store_product($product_ref, "Editing product (import_sodebo.pl bulk import) - " . $comment );
				
				push @edited, $code;
				$edited{$code}++;
				
				$j++;
				# $j > 10 and last;
				#last;
			}
			
			# last;
		}  # if $file =~ json
			


print "$i products\n";
print "$new new products\n";
print "$existing existing products\n";
print "$differing differing values\n\n";

print ((scalar @edited) . " edited products\n");
print ((scalar keys %edited) . " editions\n");

foreach my $field (sort keys %differing_fields) {
	print "field $field - $differing_fields{$field} differing values\n";
}






#print "\n\nlist of nutrient names:\n\n";
#foreach my $name (sort keys %nutrients_names) {
#	print $name . "\n";
#}
