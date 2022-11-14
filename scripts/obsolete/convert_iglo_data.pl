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
	# params below are already in the csv file
	# lc => 'de',
	# countries => "Deutchland",
	# brands => "Iglo",
	# stores => "Casino",
);





my @csv_fields_mapping = (
		
["Code", "code"],
#["code", "code"],
["lang", "lc"],
["product_name_de", "product_name_de"],
["brands", "brands"],
["categories", "categories"],
["countries", "countries"],
#["ingredients_text_de", "ingredients_text_de"],
["ingredients_text_ de", "ingredients_text_de"],
["allergens", "allergens"],
["traces", "traces"],
["quantity_value ", "quantity_value"],
["quanity_unit", "quantity_unit"],
#["quantity_unit", "quantity_unit"],
["energy", "nutriments.energy_kJ"],
["fat", "nutriments.fat_g"],
["saturated fat", "nutriments.saturated-fat_g"],
["carbohydrates", "nutriments.carbohydrates_g"],
["sugars", "nutriments.sugars_g"],
["fibers", "nutriments.fiber_g"],
["proteins", "nutriments.proteins_g"],
["salt", "nutriments.salt_g"],
["fruits vegetables nuts", "nutriments.fruits-vegetables-nuts_g"],
["labels", "labels"],
["nutri_score", "nutrition_grade_fr_producer"],
["Link", "link"],

);


my @files = get_list_of_files(@ARGV);

# first load the CSV file, then get the product name from the images

foreach my $file (@files) {

	if ($file =~ /.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines=> 0, skip_lines_after_header=> 1,  skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping});
	}
}

# Fix specific issues that are not likely to be present in other sources
# -> otherwise fix them in Import::clean_fields_for_all_products

foreach my $code (sort keys %products) {
	
	my $product_ref = $products{$code};
	
	
	if (defined $product_ref->{"fruits-vegetables-nuts_value"}) {
	
		# values:  < 40 , 40 - 60, 60 - 80, > 80
		
		if ($product_ref->{"fruits-vegetables-nuts_value"} =~ /<(\s?)40/) {
			$product_ref->{"fruits-vegetables-nuts_value"} = 20;
		}
		if ($product_ref->{"fruits-vegetables-nuts_value"} =~ /40(\s?)-(\s?)60/) {
			$product_ref->{"fruits-vegetables-nuts_value"} = 50;
		}
		if ($product_ref->{"fruits-vegetables-nuts_value"} =~ /60(\s?)-(\s?)80/) {
			$product_ref->{"fruits-vegetables-nuts_value"} = 70;
		}
		if ($product_ref->{"fruits-vegetables-nuts_value"} =~ />(\s?)80/) {
			$product_ref->{"fruits-vegetables-nuts_value"} = 90;
		}
	}
	
}

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

