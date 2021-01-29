#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::ImportConvert qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use XML::Rules;

use Log::Any::Adapter ('Stderr');

# default language (needed for cleaning fields)

%global_params = (
	lc => 'fr',
	countries => "France",
	brands => "Ferrero",
	# stores => "Casino",
);





my @csv_fields_mapping_ingredients = (

["GTIN de l'article déclaré", "code"],
["Libellé court", "product_name_fr_if_not_existing"],
["Marque", "brands"],
["Nombre de portions exact", "number_of_servings"],
["Nombre de portions approximatif", "number_of_servings_estimate"],
["Les allergènes", "allergens"],
["Ingrédients","ingredients_text_fr"],
["Conditions particulières de conservation", "conservation_fr"],
["Format du Produit", "packaging"],

);

my @csv_fields_mapping_nutrition = (

["GTIN", "code"],
["Libellé court", "product_name_fr_if_not_existing"],
["Marque", "brands"],
["Quantité", "nutriments.energy_kJ", ["Nutriment", "Energie"], ["Taille de la portion", "100.0000"], ["Unité", "Kilojoules (kj)"] ],
["Quantité", "nutriments.fat_g", ["Nutriment", "Matières grasses"], ["Taille de la portion", "100.0000"] ],
["Quantité", "nutriments.saturated-fat_g", ["Nutriment", "Acides gras saturés"], ["Taille de la portion", "100.0000"] ],
["Quantité", "nutriments.carbohydrates_g", ["Nutriment", "Glucides"], ["Taille de la portion", "100.0000"] ],
["Quantité", "nutriments.sugars_g", ["Nutriment", "Sucres"], ["Taille de la portion", "100.0000"] ],
["Quantité", "nutriments.proteins_g", ["Nutriment", "Proteines"], ["Taille de la portion", "100.0000"] ],
["Quantité", "nutriments.salt_g", ["Nutriment", "Sel"], ["Taille de la portion", "100.0000"] ],
["Quantité", "nutriments.polyols_g", ["Nutriment", "Polyols"], ["Taille de la portion", "100.0000"] ],


);

#			["nutrients.ENERKJ.[0].RoundValue", "nutriments.energy_kJ"],
#			["nutrients.FAT.[0].RoundValue", "nutriments.fat_g"],
#			["nutrients.FASAT.[0].RoundValue", "nutriments.saturated-fat_g"],
#			["nutrients.CHOAVL.[0].RoundValue", "nutriments.carbohydrates_g"],
#			["nutrients.SUGAR.[0].RoundValue", "nutriments.sugars_g"],
#			["nutrients.FIBTG.[0].RoundValue", "nutriments.fiber_g"],
#			["nutrients.PRO.[0].RoundValue", "nutriments.proteins_g"],
#			["nutrients.SALTEQ.[0].RoundValue", "nutriments.salt_g"],


my @csv_fields_mapping_photos = (

["GTIN", "code"],
["URL", "download_to:/srv/off/imports/ferrero/images/"],

);

my @files = get_list_of_files(@ARGV);

# first load the CSV file, then get the product name from the images

foreach my $file (@files) {

	if ($file =~ /ingredients.*\.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines=> 0, skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping_ingredients});
	}
	elsif ($file =~ /nutrition.*\.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines=> 0, skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping_nutrition});
	}
	elsif ($file =~ /photos.*\.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines=> 0, skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping_photos});
	}
}

# Fix specific issues that are not likely to be present in other sources
# -> otherwise fix them in Import::clean_fields_for_all_products

foreach my $code (sort keys %products) {
	
	my $product_ref = $products{$code};
	
	# number of servings in product name:
	# TIC TAC MENTHE BOX T200
	if ((defined $product_ref->{product_name_fr_if_not_existing}) and ($product_ref->{product_name_fr_if_not_existing} =~ /\bT(\d+)\b/)) {
		$product_ref->{number_of_servings} = $1;
		$product_ref->{product_name_fr_if_not_existing} =~ s/\bT(\d+)\b//g;
	}
	
	if (defined $product_ref->{product_name_fr_if_not_existing}) {
		$product_ref->{product_name_fr_if_not_existing} =~ s/K( |\.)*(SURPRISE|BUENO|COUNTRY|PINGUI)/KINDER $2/ig;
		$product_ref->{product_name_fr_if_not_existing} =~ s/\bDEL /DELACRE/g;
		$product_ref->{product_name_fr_if_not_existing} =~ s/SAV. JAMB. FUME/saveur jambon fumé/g;
		$product_ref->{product_name_fr_if_not_existing} =~ s/^F( |\.)+/FERRERO /g;
		$product_ref->{product_name_fr_if_not_existing} =~ s/^K( |\.)+/KINDER /g;
		
		# Uppercase the first letter of every word
		$product_ref->{product_name_fr_if_not_existing} =~ s/([\w']+)/\u\L$1/g
	}
	
	# change case of brands, remove "MIXTE"
	if (defined $product_ref->{brands}) {
	
		# MON CHERI / F ROCHER / RAFFAELLO
	
		$product_ref->{brands} =~ s/\//,/g;
		$product_ref->{brands} =~ s/\bF( |\.)+/FERRERO/g;
		remove_value($product_ref, "brands", "MIXTE");
		
		# Uppercase the first letter of every word
		$product_ref->{brands} =~ s/([\w']+)/\u\L$1/g
	}
	
	if (defined $product_ref->{ingredients_text_fr}) {
		# TIC TAC MENTHE : Sucre, maltodextrine, fructose, épaississant: gomme arabique; amidon de riz, arômes, huile essentielle de menthe, agent d'enrobage: cire de carnauba. TIC TAC MENTHE EXTRA FRAICHE : sucre, maltodextrine, arômes, fructose, épaississant: gomme arabique; amidon de riz, huile essentielle de menthe, agent d'enrobage: cire de carnauba.  TIC TAC PECHE CITRON : sucre, maltodextrine, acidifiants (acide tartrique, acide citrique),  épaississant : gomme arabique, amidon de riz, arômes, jus de citron en poudre, colorants (E 162, E 160a), agent d'enrobage : cire de carnauba. TIC TAC CERISE COLA :sucre, acidifiants (acide tartrique, acide malique, acide citrique), maltodextrine, épaississant : gomme arabique ; amidon de riz, arômes, colorants (E 120, E 160a), agent d'enrobage : cire de carnauba.
		
		# remove everything before the first : if it doesn't look like an ingredient
		$product_ref->{ingredients_text_fr} =~ s/^([^,-;:]|\/)*:\s*//i;
	}

	assign_quantity_from_field($product_ref, "product_name_fr_if_not_existing");
}

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

