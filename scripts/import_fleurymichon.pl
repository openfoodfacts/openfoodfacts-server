#!/usr/bin/perl

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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Time::Local;
use XML::Rules;

$lc = "fr";

my %fleurymichon_nutrients = (

);


my %nutrients_names = ();

$User_id = 'fleury-michon';

my $editor_user_id = 'fleury-michon';

my $xmlfile = $ARGV[0];

my $dir = $ARGV[1];
$dir =~ s/\/$//;

my $photo_user_id = $ARGV[1];

$User_id = $editor_user_id;
$photo_user_id = $editor_user_id;
$editor_user_id = $editor_user_id;

not defined $photo_user_id and die;

print "uploading xmlfile $xmlfile, image_dir $dir\n";

#<?xml version="1.0" encoding="ISO-8859-1"?>
#<genfi id="SITE_INTERNET_1491384067145" >
#<table catalogue="SITE_INTERNET" destinataire="SITE_INTERNET" id="PRODUIT">
#<envir id="CH">
#<record action="M">
#<cdonne nom="BOO_DIF_SIT_INT">O</cdonne>

my @rules = (
genfi => "no content",
table => "no content array",
envir => "no content array",
record => "no content array",
cdonne => sub { '%fields' => [$_[1]->{nom} => $_[1]->{_content}]},

);

my $parser = XML::Rules->new(rules => \@rules);
my $fleurymichon_xml_ref = $parser->parse_file( $xmlfile);

#use Data::Dumper;
#print STDERR Dumper($fleurymichon_xml_ref);
#exit;

# Merge the information corresponding to each product

my $fleury_michon_products_ref = ();


foreach my $table_ref (@{$fleurymichon_xml_ref->{genfi}{table}}) {

	foreach my $envir_ref (@{$table_ref->{envir}}) {
		# COD_FIC_GFI

			my $id = $envir_ref->{id};
			
			foreach my $record_ref (@{$envir_ref->{record}}) {
			
				my $action = $record_ref->{action};			
				my $COD_FIC_GFI = $record_ref->{fields}{COD_FIC_GFI};
				print STDERR "record COD_FIC_GFI: $COD_FIC_GFI - id: $id - action: $action\n";
				
				if ($action ne 'A') {
					defined $fleury_michon_products_ref->{$COD_FIC_GFI} or $fleury_michon_products_ref->{$COD_FIC_GFI} = {};
					foreach my $field (keys %{$record_ref->{fields}}) {
						$fleury_michon_products_ref->{$COD_FIC_GFI}{$field} = $record_ref->{fields}{$field};
					}
				}
			}
	}
	
}


use Data::Dumper;
#print STDERR Dumper($fleury_michon_products_ref);
#exit;


# Images

# in alphabetical order, the first image A1C1 seems to be the front of the product
# 3095757123109-03095757123109_A1C1_s02.jpg
# 3095757123109-03095757123109_A7C1_s01.jpg
# 3302740168109-03302740168109_A1C1_s06.jpg
# 3302740168109-03302740168109_A1R1_s05.jpg
# 3302740168109-03302740168109_A7C1_s01.jpg
# 3302740168109-03302740168109_A8C1_s02.jpg
# 3302741714107-03302741714107_A1C1_s02.jpg
# 3302741714107-03302741714107_A1R1_s01.jpg
# 3302741714107-03302741714107_A7C1_s03.jpg

# new filenames:

# 03302749357023_A7C1_s02.png
# 03302740447020_A1R1_s08.png
# 03302749358020_A1C1_s01.png
# 03302740447020_A7C1_s02.png
# 03302749358020_A7C1_s02.png

my $fleury_michon_images_ref = {};

print "Opening image dir $dir\n";

if (opendir (DH, "$dir")) {
	foreach my $file (sort { $a cmp $b } readdir(DH)) {

		#if ($file =~ /^(\d+)-(\d+)_(.*)\.jpg/) {
		if ($file =~ /0(\d+)_(.*)\.png/) {
		
			my $code = $1;
			
			print STDERR "found image $file for product code $code\n";

			defined $fleury_michon_images_ref->{$code} or $fleury_michon_images_ref->{$code} = [];
			push @{$fleury_michon_images_ref->{$code}}, $file;
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

my @param_sorted_langs = qw(fr en nl);

my %global_params = (
	lc => 'fr',
	countries => "France",
	brands => "Fleury Michon",
);

$lc = 'fr';

my $comment = "Fleury Michon direct data import";

my $time = time();

my $i = 0;
my $existing = 0;
my $new = 0;
my $differing = 0;
my %differing_fields = ();
my @edited = ();
my %edited = ();

my $testing = 0;

print STDERR "importing products\n";

 
	foreach my $fleurymichon_id (sort keys %{$fleury_michon_products_ref}) {
	
			$i++;
		
			
			#print $json;
			
			my @modified_fields;
			my @images_ids;
			
			my $fleurymichon_product_ref = $fleury_michon_products_ref->{$fleurymichon_id};
			my $code = $fleurymichon_product_ref->{GTIN_UC};
			
			print "product $i - fleurymichon_id: $fleurymichon_id - code: $code\n";
			
			if ($code eq '') {
				print STDERR "empty code\n";
				use Data::Dumper;
				print STDERR Dumper($fleurymichon_product_ref);
				exit;
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
					$product_ref->{interface_version_created} = "import_fleurymichon_ch.pl - version 2017/09/04";
					$product_ref->{lc} = $global_params{lc};
					delete $product_ref->{countries};
					delete $product_ref->{countries_tags};
					delete $product_ref->{countries_hierarchy};					
					store_product($product_ref, "Creating product (import_fleurymichon_ch.pl bulk upload) - " . $comment );					
				}				
				
			}
			else {
				print "- already exists in OFF\n";
				$existing++;
			}
			
			# images: uploads_production/image/data/15937/xlarge_7610807072198.jpg\?v\=1468391266
			
#images: [
#{
#categories: [
#"Ingredients list"
#],
#thumb: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/thumb_myImage.jpg?v=1468842503",
#medium: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/medium_myImage.jpg?v=1468842503",
#large: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/large_myImage.jpg?v=1468842503",
#xlarge: "https://d2v5oodgkvnw88.cloudfront.net/uploads_production/image/data/4036/xlarge_myImage.jpg?v=1468842503"
#},			
			
			print STDERR "uploading images for product code $code\n";

			if (defined $fleury_michon_images_ref->{$code}) {
				my $fleury_michon_images_ref = $fleury_michon_images_ref->{$code};
				my $images_n = scalar @{$fleury_michon_images_ref};
				print "- $images_n images\n";
				
				my $images = 0;
				
				foreach my $fleury_michon_image_file (@{$fleury_michon_images_ref}) {
				
					# upload the image
					my $file = $fleury_michon_image_file;
					$file =~ s/(.*)cloudfront.net\///;
					if (-e "$dir/$file") {
						print "found image file $dir/$file\n";
						
						# upload a photo
						my $imgid;
						my $return_code = process_image_upload($code, "$dir/$file", $User_id, undef, $comment, \$imgid);
						print "process_image_upload - file: $file - return code: $return_code - imgid: $imgid\n";	
						
						
						if ($imgid > 0) {
							$images++;
							push @images_ids, $imgid;
							if ($images == 1) {
								# first image: assign to front
								print STDERR "assigning image $imgid to front-fr\n";
								process_image_crop($code, "front_fr", $imgid, 0, undef, undef, -1, -1, -1, -1);
							}
				
						}
					}
					else {
						print "did not find image file $dir/$file\n";
					}
				
				}

			}
			
			# reload the product (changed by image upload)
			$product_ref = retrieve_product($code);
			
			
			# First load the global params, then apply the product params on top
			my %params = %global_params;			
			
my $boo = <<XML			
<cdonne nom="BOO_AFDIAG">N</cdonne>
<cdonne nom="BOO_ALI_VEG_MIN_VIT">N</cdonne>
<cdonne nom="BOO_AROM_NAT">O</cdonne>
<cdonne nom="BOO_BIO"></cdonne>
<cdonne nom="BOO_BLE_BLA_COE">N</cdonne>
<cdonne nom="BOO_BOE_FRA">N</cdonne>
<cdonne nom="BOO_HAL">N</cdonne>
<cdonne nom="BOO_LBL_RGE">N</cdonne>
<cdonne nom="BOO_POR_FRA">N</cdonne>
<cdonne nom="BOO_ARO_ART">A</cdonne>
<cdonne nom="BOO_SAN_ARO"></cdonne>
<cdonne nom="BOO_COLORANT"></cdonne>
<cdonne nom="BOO_DIPHOSPHATE">A</cdonne>
<cdonne nom="BOO_EXA_GOU"></cdonne>
<cdonne nom="BOO_GLUTAMATE">A</cdonne>
<cdonne nom="BOO_GLUTEN"></cdonne>
<cdonne nom="BOO_HUILE_HYDRO">A</cdonne>
<cdonne nom="BOO_ING_OGM">A</cdonne>
<cdonne nom="BOO_HUILE_PALME">A</cdonne>
<cdonne nom="BOO_POLYPHOSPHATE">A</cdonne>
<cdonne nom="BOO_SORBITOL">A</cdonne>
<cdonne nom="BOO_TRIPHOSPHATE">A</cdonne>
<cdonne nom="BOO_VOL_FRA">N</cdonne>			
XML
;

			my %labels = (
BOO_AFDIAG => "AFDIAG",
BOO_ALI_VEG_MIN_VIT => "Alimentation végétale minérale et vitamines",
BOO_AROM_NAT => "Arômes naturels",
BOO_BIO => "Bio",
BOO_BIO_EUR=> "Agriculture Biologique",
BOO_BLE_BLA_COE => "Bleu Blanc Coeur",
BOO_BOE_FRA => "Boeuf Français",
BOO_HAL => "Halal",
BOO_LBL_RGE => "Label Rouge",
BOO_POR_FRA => "Porc Français",
BOO_ARO_ART => "Arômes artificiels",
BOO_SAN_ARO => "Sans arômes",
BOO_SAN_ARA => "Sans arômes artificiels",
BOO_SAN_COL => "Sans colorant",
BOO_SAN_DIP => "Sans disphosphates",
BOO_SAN_EDG => "Sans exhausteur de goût",
BOO_SAN_GLM => "Sans glutamate monosodique",
BOO_SAN_GLU => "Sans gluten",
BOO_SAN_OGM => "Sans OGM",
BOO_SAN_POL => "Sans polyphosphates",
BOO_SAN_TRI => "Sans triphosphate",
BOO_SAN_SOR => "Sans sorbitol",
BOO_COLORANT => "",
BOO_DIPHOSPHATE => "",
BOO_EXA_GOU => "",
BOO_GLUTAMATE => "",
BOO_GLUTEN => "",
BOO_HUILE_HYDRO => "",
BOO_ING_OGM => "",
BOO_HUILE_PALME => "",
BOO_POLYPHOSPHATE => "",
BOO_SORBITOL => "",
BOO_TRIPHOSPHATE => "",
BOO_VOL_FRA => "Volaille Française",
BOO_JOE_ROB => "Joël Robuchon"
			);

			foreach my $label (sort keys %labels) {
				if ((defined $fleurymichon_product_ref->{$label})
					and ($fleurymichon_product_ref->{$label} eq 'O')) {
					defined $params{labels} or $params{labels} eq '';
					$params{labels} .= ", $labels{$label}";
				}
			}
			$params{labels} =~ s/^, //;
			
			print STDERR "labels for product code $code : " . $params{labels} . "\n";
			
			# <cdonne nom="LIB_PAC">Filet de saumon purée aux brocolis</cdonne>
			# <cdonne nom="LIB_PAC_EN"></cdonne>
			# <cdonne nom="LIB_PAC_NL"></cdonne>

			
			if ((defined $fleurymichon_product_ref->{LIB_PAC}) and ($fleurymichon_product_ref->{LIB_PAC} ne '')) {
				$params{product_name} = $fleurymichon_product_ref->{LIB_PAC};
				$params{product_name} =~ s/(\d) tr /$1 tranches /; # 4 tr fines
				
				print "set product_name to $params{product_name}\n";
				
				# copy value to main language
				$params{"product_name_" . $global_params{lc}} = $params{product_name};				
			}		
			if ((defined $fleurymichon_product_ref->{LIB_PAC_EN}) and ($fleurymichon_product_ref->{LIB_PAC_EN} ne '')) {
				$params{product_name_en} = $fleurymichon_product_ref->{LIB_PAC_EN};			
			}		
			if ((defined $fleurymichon_product_ref->{LIB_PAC_NL}) and ($fleurymichon_product_ref->{LIB_PAC_NL} ne '')) {
				$params{product_name_nl} = $fleurymichon_product_ref->{LIB_PAC_NL};			
			}						
			
# <cdonne nom="LIB_FAM_MKT">-- Sans rapprochement --</cdonne>
# <cdonne nom="COD_PRD_AG2">0483</cdonne>
# <cdonne nom="LIB_FAM_MKT_4"></cdonne>
# <cdonne nom="LIB_FAM_MKT_3">-- Sans rapprochement --</cdonne>
# <cdonne nom="LIB_FAM_MKT_2">Plats cuisinés</cdonne>
# <cdonne nom="LIB_FAM_MKT_1">Traiteur</cdonne>

#<cdonne nom="LIB_FAM_MKT">Rôti de Dinde cuit 100% filet</cdonne>
#<cdonne nom="COD_PRD_AG2">7416</cdonne>
#<cdonne nom="LIB_FAM_MKT_4"></cdonne>
#<cdonne nom="LIB_FAM_MKT_3">Rôti de Dinde cuit 100% filet</cdonne>
#<cdonne nom="LIB_FAM_MKT_2">Viandes rôties et cuisinées</cdonne>
#<cdonne nom="LIB_FAM_MKT_1">Charcuterie</cdonne>

			# skip Fleury Michon categories
			if (0) {
			for (my $c = 1; $c <= 4; $c++) {
			
				if ((defined $fleurymichon_product_ref->{"LIB_FAM_MKT_$c"}) and ($fleurymichon_product_ref->{"LIB_FAM_MKT_$c"} ne '')) {
					next if $fleurymichon_product_ref->{"LIB_FAM_MKT_$c"} =~ /Sans rapprochement/;
					defined $params{categories} or $params{categories} = "";
					$params{categories} .= ", " . $fleurymichon_product_ref->{"LIB_FAM_MKT_$c"};
				}
			}	
			(defined $params{categories}) and $params{categories} =~ s/^, //;
			
			print STDERR "categories for product code $code : " . $params{categories} . "\n";
			}
			
			# <cdonne nom="PDS_NET">0,3</cdonne>
			
			if ((defined $fleurymichon_product_ref->{PDS_NET}) and ($fleurymichon_product_ref->{PDS_NET} ne '')) {
				$params{quantity} = $fleurymichon_product_ref->{PDS_NET};
				$params{quantity} =~ s/,/./;
				$params{quantity} *= 1000;
				$params{quantity} = $params{quantity} . " g";
				print "set quantity to $params{quantity}\n";
			}
			
			if ((defined $fleurymichon_product_ref->{PDS_POR}) and ($fleurymichon_product_ref->{PDS_POR} ne '')) {
				$params{serving_size} = $fleurymichon_product_ref->{PDS_POR};
				$params{serving_size} =~ s/,/./;
				$params{serving_size} = $params{serving_size} . " g";
				
				# TXT_DEF_POR
				#if ((defined $fleurymichon_product_ref->{PDS_POR}) and ($fleurymichon_product_ref->{PDS_POR} ne '')) {
				#	$params{serving_size} .= " (" . $fleurymichon_product_ref->{PDS_POR} . ")"
				#}
				
				
				print "set serving_size to $params{serving_size}\n";
			}			
			
#<cdonne nom="TXT_LST_ING"><![CDATA[<p>
# Filet de dinde (88%), bouillons (2%) (eau, os de poulet, sel, &eacute;pices, carotte, <strong><u>c&eacute;leri</u></strong>, oignon, poireau, plantes aromatiques), sel (1.7%), dextrose de ma&iuml;s, jus concentr&eacute; de <u><strong>c&eacute;leri</strong></u> et de betterave jaune, plantes aromatiques (0.2%),&nbsp;poivre, ferments, colorant : caramel ordinaire.</p>]]></cdonne>
#<cdonne nom="TXT_LST_ING_EN"></cdonne>
#<cdonne nom="TXT_LST_ING_NL"></cdonne>			

# Riz basmati cuit 39% (eau, riz), saumon Atlantique (<strong>saumon</strong> Atlantique 23.4%, sel), eau, <strong>crème </strong>fraîche (8.2%), huile de colza, oseille (1.8%), vin blanc, <strong>beurre</strong>, farine de <strong>blé</strong>, sel, échalote, jus de citron (0.5%), vinaigre de vin blanc, curcuma, piment.

			
			my %ingredients_fields = (
				'TXT_LST_ING' => 'ingredients_text_fr',
				'TXT_LST_ING_EN' => 'ingredients_text_en',
				'TXT_LST_ING_NL' => 'ingredients_text_nl',
			);
			
			foreach my $field (sort keys %ingredients_fields) {
			
				if ((defined $fleurymichon_product_ref->{$field}) and ($fleurymichon_product_ref->{$field} ne '')) {
					$params{$ingredients_fields{$field}} = $fleurymichon_product_ref->{$field};
					
					$debug and print STDERR "ingredients 1 : $params{$ingredients_fields{$field}} \n";
					
					#  <u><strong>soja</strong></u> (eau, <u><strong>soja</strong></u>,<strong> </strong>farine de<strong> <u>bl&eacute;</u></strong>
					
					$params{$ingredients_fields{$field}} =~ s/<u>/<strong>/ig;
					$params{$ingredients_fields{$field}} =~ s/<\/u>/<\/strong>/ig;
					$params{$ingredients_fields{$field}} =~ s/(<strong>)+/<strong>/ig;
					$params{$ingredients_fields{$field}} =~ s/(<\/strong>)+/<\/strong>/ig;
					
						# _lait, poisson_
					$params{$ingredients_fields{$field}} =~ s/<strong>(\w+), (\w+)<\/strong>/<strong>$1<\/strong>, <strong>$2<\/strong>/g;

					
					
					# gélatine de_ poisson_
					
					# <strong>cabillaud, </strong>sel
					

					
					$params{$ingredients_fields{$field}} =~ s/<strong> / _/ig;		
					$params{$ingredients_fields{$field}} =~ s/<strong>/_/ig;
					$params{$ingredients_fields{$field}} =~ s/,<\/strong>/_,/ig;					
					$params{$ingredients_fields{$field}} =~ s/, <\/strong>/_, /ig;					
					$params{$ingredients_fields{$field}} =~ s/ <\/strong>/_ /ig;
					$params{$ingredients_fields{$field}} =~ s/(<\/strong>)(s)/$2_/ig;					
					$params{$ingredients_fields{$field}} =~ s/<\/strong>/_/ig;

					
					$params{$ingredients_fields{$field}} =~ s/<p>//g;
					$params{$ingredients_fields{$field}} =~ s/<\/p>/\n\n/g;
					
					$params{$ingredients_fields{$field}} =~ s/_+/_/g;
					
					$params{$ingredients_fields{$field}} =~ s/_ _/ /g;
					$params{$ingredients_fields{$field}} =~ s/_,_ /, /g;
					
				
					$debug and print STDERR "ingredients 2 : $params{$ingredients_fields{$field}} \n";

					
					use HTML::Entities qw(decode_entities);
					$params{$ingredients_fields{$field}} = decode_entities($params{$ingredients_fields{$field}});
					
					$debug and print STDERR "ingredients 3 : $params{$ingredients_fields{$field}} \n";

					}
			}
			$params{ingredients_text} = $params{ingredients_text_fr};

			
			
			# Create or update fields
			
			my @param_fields = ();
			
			my @fields = @ProductOpener::Config::product_fields;
			foreach my $field ('product_name', 'generic_name', @fields, 'serving_size', 'traces', 'ingredients_text','lang') {
			
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

						my %existing = ();
						foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
							$existing{$tagid} = 1;
						}
						
						
						foreach my $tag (split(/,/, $params{$field})) {
		
							my $tagid;

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
							
						}
						
						# next if ($code ne '3017620401473');
						
						
						if ($product_ref->{$field} =~ /^, /) {
							$product_ref->{$field} = $';
						}	
						
						if ($field eq 'emb_codes') {
							# French emb codes
							$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
							$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
						}
						if ($current_field ne $product_ref->{$field}) {
							print "changed value for product code: $code - field: $field = $product_ref->{$field} - old: $current_field \n";
							compute_field_tags($product_ref, $field);
							push @modified_fields, $field;
						}
					
					}
					else {
						# non-tag field
						my $new_field_value = $params{$field};
						
						if (($field eq 'quantity') or ($field eq 'serving_size')) {
							
								# openfood.ch now seems to round values to the 1st decimal, e.g. 28.0 g
								$new_field_value =~ s/\.0 / /;					
						}

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
								$current_value =~ s/(\d)( )?cl/${1}0 ml/i;
								$current_value =~ s/(\d)( )?dl/${1}00 ml/i;
								$current_value =~ s/litre|litres|liter|liters/l/i;
								$current_value =~ s/(0)(,|\.)(\d)( )?(l)(\.)?/${3}00 ml/i;
								$current_value =~ s/(\d)(,|\.)(\d)( )?(l)(\.)?/${1}${3}00 ml/i;
								$current_value =~ s/(\d)( )?(l)(\.)?/${1}000 ml/i;
								$current_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
								$current_value =~ s/(0)(,|\.)(\d)( )?(kg)(\.)?/${3}00 g/i;
								$current_value =~ s/(\d)(,|\.)(\d)( )?(kg)(\.)?/${1}${3}00 g/i;
								$current_value =~ s/(\d)( )?(kg)(\.)?/${1}000 g/i;
							}
							
							if ($field =~ /\ingredients/) {
							
								#$current_value = get_fileid(lc($current_value));
								#$current_value =~ s/\W+//g;
								#$normalized_new_field_value = get_fileid(lc($normalized_new_field_value));
								#$normalized_new_field_value =~ s/\W+//g;
								
							}
							
							if (lc($current_value) ne lc($normalized_new_field_value)) {
								print "differing value for product code $code - field $field - existing value: $product_ref->{$field} (normalized: $current_value) - new value: $new_field_value - https://world.fleurymichonfacts.org/product/$code \n";
								$differing++;
								$differing_fields{$field}++;		

								print "setting changing previously existing value for product code $code - field $field - value: $new_field_value\n";
								$product_ref->{$field} = $new_field_value;
								push @modified_fields, $field;								
							}
							

						}
						else {
							print "setting previously unexisting value for product code $code - field $field - value: $new_field_value\n";
							$product_ref->{$field} = $new_field_value;
							push @modified_fields, $field;
						}
					}					
				}
			}
			
			
			# Nutrients
			# {
			# name: "Matières grasses",
			# name-translations: {
			# de: "Fett",
			# en: "Fat",
			# fr: "Matières grasses",
			# it: "Grassi"
			# },
			# unit: "kJ",
			# order: 1,
			# per-hundred: "1530.0",
			
			my $xml = <<XML
<cdonne nom="PDS_POR">40</cdonne>
<cdonne nom="QTE_AG_MONO_INSATU"></cdonne>
<cdonne nom="QTE_AG_OMEGA3"></cdonne>
<cdonne nom="QTE_AG_OMEGA6"></cdonne>
<cdonne nom="QTE_AG_POLY_INSATU"></cdonne>
<cdonne nom="QTE_AG_SATURE">0,5</cdonne>
<cdonne nom="QTE_AG_TRANS"></cdonne>
<cdonne nom="QTE_AMIDON"></cdonne>
<cdonne nom="QTE_FIBRES"></cdonne>
<cdonne nom="QTE_GLUCIDES">0,9</cdonne>
<cdonne nom="QTE_GLU_ASS">0,9</cdonne>
<cdonne nom="QTE_KCALORIES">105</cdonne>
<cdonne nom="QTE_KJOULES">443</cdonne>
<cdonne nom="QTE_LIPIDES">1,9</cdonne>
<cdonne nom="QTE_PROTEINES">21</cdonne>
<cdonne nom="QTE_P_AG_MONO_INSATU"></cdonne>
<cdonne nom="QTE_P_AG_OMEGA3"></cdonne>
<cdonne nom="QTE_P_AG_OMEGA6"></cdonne>
<cdonne nom="QTE_P_AG_POLY_INSATU"></cdonne>
<cdonne nom="QTE_P_AG_SATURE">0,2</cdonne>
<cdonne nom="QTE_P_AG_TRANS"></cdonne>
<cdonne nom="QTE_P_AMIDON"></cdonne>
<cdonne nom="QTE_P_FIBRES"></cdonne>
<cdonne nom="QTE_P_GLUCIDES">&lt;0,5</cdonne>
<cdonne nom="QTE_P_GLU_ASS">&lt;0,5</cdonne>
<cdonne nom="QTE_P_KCALORIES">42</cdonne>
<cdonne nom="QTE_P_KJOULES">177</cdonne>
<cdonne nom="QTE_P_LIPIDES">0,8</cdonne>
<cdonne nom="QTE_P_PROTEINES">8,4</cdonne>
<cdonne nom="QTE_P_SEL">0,56</cdonne>
<cdonne nom="QTE_P_SODIUM"></cdonne>
<cdonne nom="QTE_P_SUCRE">&lt;0,5</cdonne>
<cdonne nom="QTE_SEL">1,4</cdonne>
<cdonne nom="QTE_SODIUM"></cdonne>
<cdonne nom="QTE_SUCRE">0,9</cdonne>			
XML
;

			my %nutrients = (
QTE_AG_MONO_INSATU => "monounsaturated-fat",
QTE_AG_OMEGA3 => "omega-3-fat",
QTE_AG_OMEGA6 => "omega-6-fat",
QTE_AG_POLY_INSATU => "polyunsaturated-fat",
QTE_AG_SATURE => "saturated-fat",
QTE_AG_TRANS => "trans-fat",
QTE_AMIDON => "starch",
QTE_FIBRES => "fiber",
QTE_GLUCIDES => "carbohydrates",
QTE_GLU_ASS => "glucides assimilables",
QTE_KCALORIES => "",
QTE_KJOULES => "energy",
QTE_LIPIDES => "fat",
QTE_PROTEINES => "proteins",
QTE_SEL => "salt",
QTE_SODIUM => "",
QTE_SUCRE => "sugars",
);
			
			$product_ref->{nutrition_data_per} = "100g";
			
			foreach my $nutrient (sort keys %nutrients) {

				next if $nutrients{$nutrient} eq ""; # no corresponding nutrient in OFF
			
				if ((defined $fleurymichon_product_ref->{$nutrient}) and ($fleurymichon_product_ref->{$nutrient} ne '')) {
			
					my $nid = $nutrients{$nutrient};
					my $enid = encodeURIComponent($nid);
					my $value = $fleurymichon_product_ref->{$nutrient};
					
					# <cdonne nom="QTE_SUCRE">&lt;0,5</cdonne>
					my $modifier = "";
					if ($value =~ /^(\&lt;|<)/) {
						$value = $';
						$modifier = "<";
					}
					
					$value =~ s/,/./;
					$value += 0;
					
					if ((defined $modifier) and ($modifier ne '')) {
						$product_ref->{nutriments}{$nid . "_modifier"} = $modifier;
					}
					else {
						delete $product_ref->{nutriments}{$nid . "_modifier"};
					}					
					
					
					$product_ref->{nutriments}{$nid . "_unit"} = "g";	
					if ($nid eq 'energy') {
						$product_ref->{nutriments}{$nid . "_unit"} = "kJ";	
					}
					$product_ref->{nutriments}{$nid . "_value"} = $value;
					
					my $new_value = $modifier . unit_to_g($value, $product_ref->{nutriments}{$nid . "_unit"});
					
					if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{$nid})
						and ($new_value != $product_ref->{nutriments}{$nid}) ) {
						my $current_value = $product_ref->{nutriments}{$nid};
						print "differing nutrient value for product code $code - nid $nid - existing value: $current_value - new value: $new_value - https://world.openfoodfacts.org/product/$code \n";
					}
					
					$product_ref->{nutriments}{$nid} = $new_value;
					
					print STDERR "$nutrient - $nid - $value\n";
				}
			}

			
			
			# Process the fields

			# Food category rules for sweeetened/sugared beverages
			# French PNNS groups from categories
			
			if ($server_domain =~ /fleurymichonfacts/) {
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
							
			
			# Ingredients classes
			extract_ingredients_from_text($product_ref);
			extract_ingredients_classes_from_text($product_ref);

			compute_languages($product_ref); # need languages for allergens detection
			detect_allergens_from_text($product_ref);			

			
			
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
				id => "fleurymichon",
				name => "Fleury Michon",
				url => "https://www.fleurymichon.fr",
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
			
				#print STDERR "Storing product code $code\n";
				#				use Data::Dumper;
				#print STDERR Dumper($product_ref);
				#exit;
				
				
				
				store_product($product_ref, "Editing product (import_fleurymichon_ch.pl bulk import) - " . $comment );
				
				push @edited, $code;
				$edited{$code}++;
				
				$i > 10000000 and last;
			}
			
			#last;
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
