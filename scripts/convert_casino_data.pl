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

use ProductOpener::Import qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use XML::Rules;

# default language (needed for cleaning fields)

$lc = "fr";

%global_params = (
	lc => 'fr',
	countries => "France",
	brands => "Casino",
	stores => "Casino",
);

my @csv_fields_mapping = (

["EAN", "code"],
["ID", "producer_version_id"],
["Denomination", "product_name_fr"],
["Déno légale", "generic_name_fr"],
["Format", "quantity"],
["Marque", "brands"],
["Liste ingrédients", "ingredients_text_fr"],
["Mentions obligatoires", "other_information_fr"],
["Conditions de conservation", "conservation_conditions_fr"],
["Poids net", "net_weight_value"],
["Unité
poids
net", "net_weight_unit"],
["Poids net égoutté", "drained_weight_value"],
["Unité
poids net 
égoutté", "drained_weight_unit"],
["Volume", "volume_value"],
["Unité volume", "volume_unit"],
["Consigne
A recycler", "recycling_instructions_to_recycle_fr"],
["Consigne
A jeter", "recycling_instructions_to_discard_fr"],
["Signe qualité", "labels"],
["Plus produit", "labels"],
["Score", "nutriments.nutrition-score-fr-producer"],
["Groupe", "nutrition_grade_fr_producer" ],
["Energie kJ", "nutriments.energy_kJ"],
["Matiere grasse g", "nutriments.fat_g"],
["dont acides gras saturés g", "nutriments.saturated-fat_g"],
["Glucides g", "nutriments.carbohydrates_g"],
["dont sucres g", "nutriments.sugars_g"],
["Fibres g", "nutriments.fiber_g"],
["Proteines g", "nutriments.proteins_g"],
["Sel g", "nutriments.salt_g"],
["Alcool g", "nutriments.alcohol_g"],
["Vit A µg", "nutriments.vitamin-a_µg"],
["Vit B1 Thiamine mg", "nutriments.vitamin-b1_mg"],
["Vit B2 Riboflavine mg", "nutriments.vitamin-b2_mg"],
["Vit B3 Niacine mg", "nutriments.vitamin-pp_mg"],
["Vit B5 Acide pantothenique mg", "nutriments.pantothenic-acid_mg"],
["Vit B6 mg", "nutriments.vitamin-b6_mg"],
["Vit B8 Biotine µg", "nutriments.biotin_µg"],
["Vit B9 Acide folique µg", "nutriments.vitamin-b9_µg" ],
["Vit B12 µg", "nutriments.vitamin-b12_µg" ],
["Vit C mg", "nutriments.vitamin-c_mg" ],
["Vit D µg", "nutriments.vitamin-d_mg" ],
["Vit E mg", "nutriments.vitamin-e_mg" ],
["Vit K µg", "nutriments.vitamin-k_µg" ],
["Calcium mg", "nutriments.calcium_mg" ],
["Chlorure mg", "nutriments.chloride_mg" ],
["Chrome µg", "nutriments.chromium_mg" ],
["Cuivre mg", "nutriments.copper_mg" ],
["Fer mg", "nutriments.iron_mg" ],
["Fluorure mg", "nutriments.fluoride_mg" ],
["Iode µg", "nutriments.iodine_mg" ],
["Magnesium mg", "nutriments.magnesium_mg" ],
["Manganese mg", "nutriments.manganese_mg" ],
["Molybdene µg", "nutriments.molybdenum_mg" ],
["Phosphore mg", "nutriments.phosphorus_mg" ],
["Potassium mg", "nutriments.potassium_mg" ],
["Selenium µg", "nutriments.selenium_mg" ],
["Zinc mg", "nutriments.zinc_mg" ],


);



my @files = get_list_of_files(@ARGV);


foreach my $file (@files) {

	load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines => 4, csv_fields_mapping => \@csv_fields_mapping});

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
	
	if (defined $products{$code}{brands}) {
		$products{$code}{brands} =~ s/Casino Famili - Enfant/Casino Famili/;
		$products{$code}{brands} =~ s/^Casino (\w.*)$/Casino $1, Casino/;
	}	

}

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

