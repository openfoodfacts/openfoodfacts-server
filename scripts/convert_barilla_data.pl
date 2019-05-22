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
	# params below are already in the csv file
	# lc => 'de',
	# countries => "Deutchland",
	# brands => "Iglo",
	# stores => "Casino",
	lc => 'fr',
	countries => "France",
);





my @csv_fields_mapping = (
		
["EAN", "code"],
["product_name", "product_name_fr"],
["brand", "brands"],
["quantity", "quantity"],
["category","categories"],
["ingredient_list", "ingredients_text_fr"],
["allergens_list", "allergens"],
["traces_list", "traces"],
["organic", "labels_y_en:organic"],	# Y or N
["calories", "nutriments.energy_kcal"],
["total_fat", "nutriments.fat_g"],
["saturated_fat", "nutriments.saturated-fat_g"],
["carbohydronate", "nutriments.carbohydrates_g"],
["sugar", "nutriments.sugars_g"],
["fiber", "nutriments.fiber_g"],
["protein", "nutriments.proteins_g"],
["salt", "nutriments.salt_g"],
["Visuel", "download_to:/srv/off/imports/barilla/images/"],


);



my @files = get_list_of_files(@ARGV);

# first load the CSV file, then get the product name from the images

foreach my $file (@files) {

	if ($file =~ /.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines=> 0, skip_lines_after_header=> 0,  skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping});
	}
}

# Fix specific issues that are not likely to be present in other sources
# -> otherwise fix them in Import::clean_fields_for_all_products

foreach my $code (sort keys %products) {
	
	my $product_ref = $products{$code};
	
	
}

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

