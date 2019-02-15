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

use strict;
use utf8;


binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::Import qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use XML::Rules;

use Log::Any::Adapter ('Stderr');

# default language (needed for cleaning fields)

$lc = "fr";

%global_params = (
	lc => 'fr',
	countries => "France",
	# brands => "LDC",
	# stores => "Casino",
);

# several entries with same code for products with several sub-products
# 3230890758539	COQ EN BOX DE POULET CROUSTILLANT 585G MAITRE COQ	Coq en Box Croustillant (épicé) SANS SAUCE 585g
# 3230890758539	COQ EN BOX DE POULET CROUSTILLANT 585G MAITRE COQ	Sauce miel MOUTARDE
# 3230890758539	COQ EN BOX DE POULET CROUSTILLANT 585G MAITRE COQ	Sauce Barbecue

# the actual product name is in the image file name...
# Coq en box poulet croustillant lÃ©gÃ¨rement Ã©picÃ© - 3230890758539.jpg



my @csv_fields_mapping = (

["Code EAN", "code"],
["Nom du Produit", "ldc_nom_du_produit"],
["Dénomination générique du produit", "ldc_denomination"],
["Dénomination générique du produit", "product_name_fr"],	# we can overwrite it with the image file name
["Quantité", "quantity"],
["Conditionnement (Frais/Surgelé)", "labels"],
["Marques", "brands"],
["Catégorie du produit", "categories"],
["Labels", "labels"],
["Site", "producer_fr"],
["Origine Viande", "origins"],
["Code emballeur", "ldc_emb_codes"],
["Estampille Sanitaire", "ldc_emb_codes"],
["Pays de vente", "countries"],
["Liste Ingrédients", "ingredients_text_fr"],
["Allergènes", "allergens"],
["traces allergènes", "traces"],
["Poids d'une portion (g)", "serving_size_g"],
["Energie (kJ)", "nutriments.energy_kJ"],
["Energie (kcal)", "nutriments.energy_kcal"],
["MG", "nutriments.fat_g"],
["Dont AGS", "nutriments.saturated-fat_g"],
["Glucides", "nutriments.carbohydrates_g"],
["Dont sucres", "nutriments.sugars_g"],
["Fibres alimentaires", "nutriments.fiber_g"],
["Protéines", "nutriments.proteins_g"],
["Sel", "nutriments.salt_g"],
#[" Sodium", "nutriments.sodium_g"],	# keep only salt
["F&L frais", "nutriments.fruits-vegetables-nuts_100g"], 
["F&L sec", "nutriments.fruits-vegetables-nuts-dried_100g"],
["Nutri-Score", "nutrition_grade_fr_producer"],


);



my @files = get_list_of_files(@ARGV);

# first load the CSV file, then get the product name from the images

foreach my $file (@files) {

	if ($file =~ /\.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines=> 1, skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping});
	}
	elsif ($file =~ /^(.*)(\d{13})(.*)\./) {
		my $code = $2;
		my $prefix = $1;
		my $suffix = $3;
		$suffix =~ s/^(-|_|\s)\d+$//;
		my $name = $prefix . $suffix;
		$name =~ s/^(.*)\///;	# remove path
		use Encode qw( from_to decode encode decode_utf8 );
		my $data2 = $name;
		from_to($data2, "utf8", "iso-8859-1");
		my $name2 = decode_utf8($data2);
		# Ailes de poulet \xC3  la provençale
		$name2 =~ s/\\xC3/à/g;
		
		$name = $name2;
		
		$name =~ s/ +/ /g;
		$name =~ s/_/ /g;
		$name =~ s/^(\s|-)*//;
		$name =~ s/(\s|-)*$//;
		
		# 6 ppa extra frais gros le gaulois profil
		
		# skip some entries
		
		next if ($name =~ /\b(ppa|3 4|profil)\b/i);
		
		$name =~ s/tartetatin/Tarte Tatin/i;
		
		# keep the names for Traditions d'Asie
		
		next if ($products{$code}{brands} =~ /Traditions d'Asie/);
		
		if (defined $products{$code}) {
			$products{$code}{product_name_fr} = $name;
		}

	}
}

# Fix specific issues that are not likely to be present in other sources
# -> otherwise fix them in Import::clean_fields_for_all_products

foreach my $code (sort keys %products) {
	
	my $product_ref = $products{$code};
	
	# The CSV export from the XLS file seems to convert 46,125 to 46125
	# 41029   1098
	
	foreach my $field ("fruits-vegetables-nuts_value", "fruits-vegetables-nuts-dried_value") {
	
		if (defined $product_ref->{$field}) {
			$product_ref->{$field} =~ s/(\d)(\d\d\d)$/$1,$2/g;
		}
	}
		
	# Date '04.04.2017 instead of quantity
		
	if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} =~ /^'?\d\d\.\d\d\.\d\d\d\d$/)) {
		print STDERR "product code $code: deleting date in quantity $product_ref->{quantity}\n";
		delete $product_ref->{quantity};
	}
	
	if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} =~ /^(\d+)$/)) {
		$product_ref->{quantity} .= " g";
	}
	
	foreach my $field ("labels", "categories") {
	
		if (defined $product_ref->{$field}) {
			if ($product_ref->{$field} =~ /(Frais|Surgelés|Surgelé|Surgelée|Surgelées)/) {
				assign_value($product_ref, "packaging", $1);
				$product_ref->{$field} =~ s/Frais|Surgelés|Surgelé//i;
				$product_ref->{categories} =~ s/, ,/,/g;
				$product_ref->{categories} =~ s/^, ?//g;
				$product_ref->{categories} =~ s/, ?$//g;
			}
		}	
	}
	
	# 0, aucun, aucune in allergens / traces
	foreach my $field ("allergens", "traces") {
		if ((defined $product_ref->{$field}) and ($product_ref->{$field} =~ /^(0|aucun|aucune)(s?)$/i)) {
			delete $product_ref->{$field};
		}
	}
	
	match_taxonomy_tags($product_ref, "ldc_emb_codes", "emb_codes",
	{
		split => ',|( \/ )|\r|\n|\+|:|;|=|\(|\)|\b(et|par|pour|ou)\b',
		# stopwords =>
	}
	);
	# EMB 85065B ou EMB 85233, FR 85.065.001 CE FR 85.233.001 CE
	if (defined $products{$code}{emb_codes}) {
		$products{$code}{emb_codes} =~ s/CE FR/CE, FR/g;
	}
	
	$product_ref->{brands} =~ s/le gaulois/Le Gaulois/ig;
	$product_ref->{brands} =~ s/marie/Marie/ig;
}

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

