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
	lc => 'fr',
	# countries => "Deutchland",
	# brands => "Iglo",
	# stores => "Casino",
);

#my @csv_fields = qw(code	lang	product_name_fr	generic_name_fr	brands	quantity	categories	countries	ingredients_text_fr	allergens	traces	fruits-vegetables-nuts_100g	nutri_score	serving_size	stores	labels	energy_100g_value	energy_100g_unit	proteins_100g_value	proteins_100g_unit	carbohydrates_100g_value	carbohydrates_100g_unit	sugars_100g_value	sugars_100g_unit	fat_100g_value	fat_100g_unit	saturated-fat_100g_value	saturated-fat_100g_unit	fiber_100g_value	fiber_100g_unit	vitamin-c_100g_value	vitamin-c_100g_unit	sodium_100g_value	sodium_100g_unit	alcohol_100g_value	alcohol_100g_unit	polyols_100g_value	polyols_100g_unit	calcium_100g_value	calcium_100g_unit	vitamin-b6_100g_value	vitamin-b6_100g_unit	vitamin-b2_100g_value	vitamin-b2_100g_unit	phosphorus_100g_value	phosphorus_100g_unit	vitamin-b9_100g_value	vitamin-b9_100g_unit	vitamin-pp_100g_value	vitamin-pp_100g_unit	vitamin-e_100g_value	vitamin-e_100g_unit	iron_100g_value	iron_100g_unit	magnesium_100g_value	magnesium_100g_unit	vitamin-d_100g_value	vitamin-d_100g_unit	polyunsaturated-fat_100g_value	polyunsaturated-fat_100g_unit	monounsaturated-fat_100g_value	monounsaturated-fat_100g_unit	trans-fat_100g_value	trans-fat_100g_unit	vitamin-a_100g_value	vitamin-a_100g_unit	vitamin-b12_100g_value	vitamin-b12_100g_unit	cholesterol_100g_value	cholesterol_100g_unit	omega-6-fat_100g_value	omega-6-fat_100g_unit	docosahexaenoic-acid_100g_value	docosahexaenoic-acid_100g_unit	eicosapentaenoic-acid_100g_value	eicosapentaenoic-acid_100g_unit	alpha-linolenic-acid_100g_value	alpha-linolenic-acid_100g_unit	omega-3-fat_100g_value	omega-3-fat_100g_unit	starch_100g_value	starch_100g_unit	iodine_100g_value	iodine_100g_unit	manganese_100g_value	manganese_100g_unit	copper_100g_value	copper_100g_unit	zinc_100g_value	zinc_100g_unit	potassium_100g_value	potassium_100g_unit	biotin_100g_value	biotin_100g_unit	vitamin-k_100g_value	vitamin-k_100g_unit);

my @csv_fields = qw(code	lang	product_name_fr	generic_name_fr	brands	quantity	categories	countries	ingredients_text_fr	allergens	traces	fruits-vegetables-nuts_100g	nutri_score	serving_size	stores	labels	salt_100g_value	salt_100g_unit	sodium_100g_value	sodium_100g_unit	fiber_100g_value	fiber_100g_unit	proteins_100g_value	proteins_100g_unit	sugars_100g_value	sugars_100g_unit	carbohydrates_100g_value	carbohydrates_100g_unit	saturated-fat_100g_value	saturated-fat_100g_unit	fat_100g_value	fat_100g_unit	energy_100g_value	energy_100g_unit	vitamin-b1_100g_value	vitamin-b1_100g_unit	vitamin-d_100g_value	vitamin-d_100g_unit	calcium_100g_value	calcium_100g_unit	vitamin-c_100g_value	vitamin-c_100g_unit	alcohol_100g_value	alcohol_100g_unit	polyols_100g_value	polyols_100g_unit	iron_100g_value	iron_100g_unit	vitamin-b2_100g_value	vitamin-b2_100g_unit	vitamin-b6_100g_value	vitamin-b6_100g_unit	phosphorus_100g_value	phosphorus_100g_unit	vitamin-e_100g_value	vitamin-e_100g_unit	magnesium_100g_value	magnesium_100g_unit	vitamin-b9_100g_value	vitamin-b9_100g_unit	vitamin-pp_100g_value	vitamin-pp_100g_unit	potassium_100g_value	potassium_100g_unit	pantothenic-acid_100g_value	pantothenic-acid_100g_unit	biotin_100g_value	biotin_100g_unit	vitamin-b12_100g_value	vitamin-b12_100g_unit	chloride_100g_value	chloride_100g_unit	vitamin-k_100g_value	vitamin-k_100g_unit	vitamin-a_100g_value	vitamin-a_100g_unit	iodine_100g_value	iodine_100g_unit	manganese_100g_value	manganese_100g_unit	zinc_100g_value	zinc_100g_unit	copper_100g_value	copper_100g_unit	cholesterol_100g_value	cholesterol_100g_unit	omega-6-fat_100g_value	omega-6-fat_100g_unit	docosahexaenoic-acid_100g_value	docosahexaenoic-acid_100g_unit	eicosapentaenoic-acid_100g_value	eicosapentaenoic-acid_100g_unit	linoleic-acid_100g_value	linoleic-acid_100g_unit	omega-3-fat_100g_value	omega-3-fat_100g_unit	polyunsaturated-fat_100g_value	polyunsaturated-fat_100g_unit	monounsaturated-fat_100g_value	monounsaturated-fat_100g_unit	trans-fat_100g_value	trans-fat_100g_unit);


my @csv_fields_mapping = ();

foreach my $field (@csv_fields) {

	my $target = $field;

	# Create a second product name field that we can override later
	if (($field eq "generic_name_fr") or ($field eq "categories")) {
		push @csv_fields_mapping, [$field, $field . "_orig"];
	}

	elsif ($field eq "nutri_score") {
		push @csv_fields_mapping, [$field, "nutrition_grade_fr_producer"];
	}
	else {
		push @csv_fields_mapping, [$field, $target];
	}

}

push @csv_fields_mapping, [ "cdc", "producer_version_id"];

my @files = get_list_of_files(@ARGV);

# first load the CSV file, then get the product name from the images

foreach my $file (@files) {

	if ($file =~ /.csv/) {
		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", escape_char => "\\", skip_lines=> 0, skip_lines_after_header=> 0,  skip_empty_codes=>1, csv_fields_mapping => \@csv_fields_mapping});
	}
}

# Fix specific issues that are not likely to be present in other sources
# -> otherwise fix them in Import::clean_fields_for_all_products

my %brands = (
"ADELIE" => "Adélie",
"AL JAYID" => "Al Jayid",
"BOUTON D'OR" => "Bouton d'or",
"CAPITAINE COOK" => "Capitaine Cook",
"CHABRIOR" => "Chabrior",
"CLAUDE LEGER" => "Claude Léger",
"ELODIE" => "Elodie",
"CLOS CHEVREL" => "Clos Chevrel",
"FE" => "FE",
"FIORINI" => "Fiorini",
"GRILLERO" => "Grillero",
"G.DUNOY" => "G.Dunoy",
"ITINERAIRE DES SAVEURS" => "Itinéraire des Saveurs",
"IVORIA" => "Ivoria",
"JEAN ROZE" => "Jean Roze",
"LA FOURNEE CAMPANIERE" => "La Fournée Campanière",
"LA JONQUE" => "La Jonque",
"LES CREATIONS" => "Les Créations",
"LOOK" => "Look",
"LUCHON" => "Luchon",
"MONIQUE RANOU" => "Monique Ranou",
"NETTO" => "Netto",
"NETTO BIO" => "Netto Bio",
"ODYSSEE" => "Odyssée",
"ON OFF" => "ON OFF",
"ONNO" => "Onno",
"PAQUITO" => "Paquito",
"PASTOURET" => "Pastouret",
"PATURAGES" => "Pâturages",
"PLANTEUR DES TROPIQUES" => "Planteur des Tropiques",
"POMMETTE" => "Pommette",
"RANOU" => "Monique Ranou",
"REGAIN" => "Regain",
"SAINT ELOI" => "Saint Eloi",
"Saint éloi BIO" => "Saint Eloi Bio",
"TERRIER" => "Terrier",
"TOP BUDGET" => "Top Budget",
"VOLAE" => "Volae",
);

foreach my $code (sort keys %products) {

	my $product_ref = $products{$code};

	# remove brand from product name

	foreach my $field ("product_name_fr", "generic_name_fr_orig") {

		foreach my $key (sort keys %brands) {
			$product_ref->{$field} =~ s/ $key / /i;
			$product_ref->{$field} =~ s/^$key //i;
			$product_ref->{$field} =~ s/ $key$//i;
		}

		# remove quantity
		$product_ref->{$field} =~ s/\s?-?\s?(\d+x)?\d+\s?(g|kg|l|cl|ml)$//i;
	}

	# the product_name_fr field is often, but not always, more cryptic than the generic_name_fr field
	# TOP BUDGET long sac 1kg (F/E/NL/A)
	# YB TOP BUDGET FRT X12

	my $product_name_fr = $product_ref->{"generic_name_fr_orig"};

	# use the generic name, unless the generic name is in ALL CAPS and the product name is not
	if (($product_ref->{"generic_name_fr_orig"} !~ /[a-z]/) and ($product_ref->{"product_name_fr"} =~ /[a-z]/)) {
		$product_name_fr = $product_ref->{"product_name_fr"};
	}
	delete $product_ref->{"generic_name_fr"};

	$product_ref->{"product_name_fr"} = $product_name_fr;

	if (defined $brands{$product_ref->{brands}}) {
		$product_ref->{brands} = $brands{$product_ref->{brands}};
	}

	$product_ref->{stores} =~ s/INTERMARCHE/Intermarché/g;
	$product_ref->{stores} =~ s/NETTO/Netto/g;

	# default unit = g (temporary as we should get units)
	foreach my $field (keys %{$product_ref}) {
		if (($field =~ /_unit/) and ($product_ref->{$field} eq "")) {
			$product_ref->{$field} = "g";
		}
	}

	# Allergens
	# Avoine ou hybrides et produits à base de ces céréales, Blé ou hybrides et produits à base de ces céréales,
	# Kamut ou hybrides et produits à base de ces céréales, Epeautre ou hybrides et produits à base de ces céréales, Orge ou hybrides,
	# et produits à base de ces céréales, Seigle ou hybrides, et produits à base de ces céréales, Soja et produits à base de soja, Œufs et produits à base d'œufs
	# Noix de pécan et produits à base de noix de pécan [Carya illinoiesis (Wangenh.) K. Koch], Noix (Juglans regia), et produits à base de noix,
	# Lait et produits à base de lait (y compris lactose), Epeautre ou hybrides et produits à base de ces céréales, Orge ou hybrides, et produits à base de ces céréales,
	# Soja et produits à base de soja, Noisettes (Corylus avellana), et produits à base de noisettes, Noix de Macadamia et noix du Queensland, et produits à base de ces noix
	# (Macadamia ternifolia), Œufs et produits à base d'œufs, Avoine ou hybrides et produits à base de ces céréales, Arachides et produits à base d'arachides,
	# Blé ou hybrides et produits à base de ces céréales, Amandes (Amygdalus communis L.), Seigle ou hybrides, et produits à base de ces céréales


	$product_ref->{allergens} =~ s/(,)? et produits à base de ces céréales//g;
	$product_ref->{allergens} =~ s/ ou hybrides//g;
	$product_ref->{allergens} =~ s/\[([^\]]+)\]//g;
	$product_ref->{allergens} =~ s/\(([^\)]+)\)//g;
	$product_ref->{allergens} =~ s/ ,/,/g;
	$product_ref->{allergens} =~ s/\s+$//g;
	$product_ref->{allergens} =~ s/ et produits([^,]+)//g;
	$product_ref->{allergens} =~ s/(Noix de Macadamia|Anhydride sulfureux et sulfites)([^,]+)/$1/ig;

	$product_ref->{"fruits-vegetables-nuts_100g"} =~ s/,0$//;

	# Traces éventuelles d'
	$product_ref->{traces} =~ s/Traces( éventuelles|possibles)?\s?(de:d')?\s?:?//;

	# Serving size 0,00g
	# Serving size 100g --> ignore (sometime used on products that are less than 100g)
	if (($product_ref->{serving_size} =~ /^0/) or ($product_ref->{serving_size} =~ /^100/)) {
		delete $product_ref->{serving_size};
	}

	clean_weights($product_ref); # needs the language code


	# also try the product name
	match_taxonomy_tags($product_ref, "product_name_fr", "categories",
	{
		# split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		# stopwords =>
	}
	);

}

# Bugs in data

$products{3250391653386}{quantity} = "540 g";
$products{3250390000723}{quantity} = "750 g";

# Clean / normalize fields

clean_fields_for_all_products();

print_csv_file();

print_stats();

