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
	no_nutrition_data => "on",
#	categories => "Condiments",
);


my @csv_fields_mapping = (
		
["codes barres", "code"],
["dénomination", "product_name_fr"],
["quantité","quantity"],
["conditionnement","packaging"],
["marques", "brands"],
["code emballeur ", "emb_codes"],
["pays de vente", "countries"],
["ingrédients", "ingredients_text_fr"],


);


my @files = get_list_of_files(@ARGV);

# first load the CSV file, then get the product name from the images

foreach my $file (@files) {

	if ($file =~ /.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_lines=> 3, skip_lines_after_header=> 0,  skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping});
	}
}

# Fix specific issues that are not likely to be present in other sources
# -> otherwise fix them in Import::clean_fields_for_all_products

foreach my $code (sort keys %products) {
	
	my $product_ref = $products{$code};
	
	# Paprika moulu BIO
	match_taxonomy_tags($product_ref, "product_name_fr", "labels",
	{
		split => ' ',
		# stopwords =>
	}
	);
	
	# also try the product name
	match_taxonomy_tags($product_ref, "product_name_fr", "categories",
	{
		# split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		stopwords => '(bio|aop|pot)',
	}
	);
	
	match_taxonomy_tags($product_ref, "product_name_fr", "categories",
	{
		# split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		stopwords => '(de|au|en|bio|aop|pot|moulu|concassé|graine|semoule|entier|entière|bâton|coupé|feuille|aromatique|haché|poudre|gousse|moulin|lyophilisé|lamelle|naturel|france)(e)?(s)?',
	}
	);
}

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

