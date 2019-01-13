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

my %global_params = (
	lc => 'fr',
	countries => "France",
	brands => "LDC",
	# stores => "Casino",
);

@fields_mapping = (

["Code EAN", "code"],
["Nom du Produit", "product_name_fr"],
["Dénomination générique du produit", "generic_name_fr"],
["Quantité", "quantity"],
["Conditionnement (Frais/Surgelé)", "labels"],
["Marques", "brands"],
["Catégorie du produit", "categories"],
["Labels", "labels"],
["Site", "manufacturing_places"],
["Origine Viande", "origins"],
["Code emballeur", "emb_codes"],
["Estampille Sanitaire", "emb_codes"],
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
["Sodium", "nutriments.sodium_g"],
["F&L frais", ""], 
["F&L sec", "fruits-vegetables-nuts_100g"],
["Nutri-Score", "nutriments.nutrition-score-fr-producer"],


);



my @files = get_list_of_files(@ARGV);


foreach my $file (@files) {

	load_csv_file($file, "UTF-8", "\t", 0);

}

# Fix specific issues that are not likely to be present in other sources
# -> otherwise fix them in Import::clean_fields_for_all_products

foreach my $code (sort keys %products) {
	
	# Date '04.04.2017 instead of quantity
	
	if ((defined $products{$code}{quantity}) and ($products{$code}{quantity} =~ /^'?\d\d\.\d\d\.\d\d\d\d$/)) {
		print STDERR "product code $code: deleting date in quantity $products{$code}{quantity}\n";
		delete $products{$code}{quantity};
	}
	
	# Casino sub-brand : add Casino
	
	# if (defined $products{$code}{brands}) {
	# 	$products{$code}{brands} =~ s/Casino Famili - Enfant/Casino Famili/;
	# 	$products{$code}{brands} =~ s/^Casino (\w.*)$/Casino $1, Casino/;
	# }	

}

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

