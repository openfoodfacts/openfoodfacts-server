# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Producers - functions specific to the platform for producers

=head1 SYNOPSIS

C<ProductOpener::Producers> contains the functions specific to the producers platform:

- Functions to import CSV / Excel files, match column names, convert to OFF csv format
- Minion tasks for import and export

=head1 DESCRIPTION

..

=cut

package ProductOpener::Producers;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&get_minion

		&load_csv_or_excel_file

		&init_fields_columns_names_for_lang
		&match_column_name_to_field
		&init_columns_fields_match
		&normalize_column_name

		&generate_import_export_columns_groups_for_select2

		&convert_file

		&export_and_import_to_public_database

		&import_products_categories_from_public_database_task

		$GOOGLE_DRIVE_IMPORT_MAX_IMAGES
		$GOOGLE_DRIVE_DOWNLOAD_RETRY_DELAY
		&start_google_drive_photos_import
		&import_photos_from_google_drive_folder

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created ensure_dir_created_or_die/;
use ProductOpener::Store qw/get_string_id_for_lang retrieve store/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/%nutrients_tables/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/$lc %Lang lang/;
use ProductOpener::Display qw/$nutrient_table/;
use ProductOpener::Export qw/export_csv/;
use ProductOpener::Import
	qw/$IMPORT_MAX_PACKAGING_COMPONENTS download_image import_csv_file import_products_categories_from_public_database/;
use ProductOpener::ImportConvert qw/clean_fields/;
use ProductOpener::Minion qw/get_minion write_minion_log/;
use ProductOpener::ProductImageUpload qw/import_product_image_file/;
use ProductOpener::Config2;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id %User/;
use ProductOpener::Orgs qw/update_export_date/;
use ProductOpener::Images qw/$valid_image_types_regexp/;
use ProductOpener::GoogleDrive
	qw/parse_google_drive_folder_url list_google_drive_folder_images get_google_drive_file_download_url/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Time::Local;
use File::Temp qw/tempdir/;
use Data::Dumper;
use Text::CSV();

=head1 FUNCTIONS

=head2 load_csv_or_excel_file ( $file )

Load a CSV or Excel file in a Perl structure.

- CSV files should be in UTF-8 and separated with a comma. They are processed with Text::CSV.
- Excel files are first converted to CSV with gnumeric's ssconvert.

=head3 Arguments

=head4 file name with absolute path

CSV or Excel file

=head3 Return values

A hash ref with:

=head4 headers

A reference to an array of header names.

=head4 rows

A reference to an array of rows, containing each an array of column values

=cut

sub load_csv_or_excel_file ($file) {    # path and file name

	my $input_headers_ref;
	my $rows_ref = [];
	my $results_ref = {};

	# Spreadsheet::CSV does not like CSV files with a BOM:
	# Wide character in print at /usr/local/share/perl/5.24.1/Spreadsheet/CSV.pm line 87.

	# There are many issues with Spreadsheet::CSV handling of CSV files
	# (depending on whether there is a BOM, encoding, line endings etc.
	# -> use Spreadsheet::CSV only for Excel files
	# -> use Text::CSV directly for CSV files

	my $extension = $file;
	$extension =~ s/^(.*)\.//;
	$extension = lc($extension);
	my $csv_file = $file;

	my $encoding = "UTF-8";

	# By default, assume the separator is a comma
	my $separator = ",";

	if ($extension =~ /^xls.?$/) {
		$log->debug("converting Excel file with gnumeric's ssconvert", {file => $file, extension => $extension})
			if $log->is_debug();
		$csv_file = $file . ".csv";
		system("ssconvert", $file, $csv_file);
		$log->debug(
			"converting Excel file with gnumeric's ssconvert - output",
			{file => $file, extension => $extension, command => $0, error => $?}
		) if $log->is_debug();
	}
	else {
		# If there are tabs in the first line, assume the separator is tab
		if (open(my $io, "<:encoding($encoding)", $file)) {
			my $line = <$io>;
			if ($line =~ /\t/) {
				$separator = "\t";
			}
			# Otherwise, if the first line does not have a separator, check if it is a ;
			elsif (($line !~ /$separator/) and ($line =~ /;/)) {
				$separator = ";";
			}
		}
	}

	$log->debug("opening CSV file", {file => $csv_file, extension => $extension}) if $log->is_debug();

	my $csv_options_ref = {binary => 1, sep_char => $separator};    # should set binary attribute.

	$log->debug("opening CSV file with Text::CSV", {file => $csv_file, extension => $extension}) if $log->is_debug();

	my $csv = Text::CSV->new($csv_options_ref)
		or die("Cannot use CSV: " . Text::CSV->error_diag());

	if (open(my $io, "<:encoding($encoding)", $csv_file)) {

		$log->debug("opened file with Text::CSV", {file => $csv_file, extension => $extension}) if $log->is_debug();

		# Remove completely empty rows and columns

		my @original_rows = ();
		my @non_empty_columns = ();

		while (my $row_ref = $csv->getline($io)) {
			my $non_empty_values = 0;
			for (my $i = 0; $i < scalar(@$row_ref); $i++) {
				if ((defined $row_ref->[$i]) and ($row_ref->[$i] ne "")) {
					$non_empty_values++;
				}
			}
			# Remove rows with a value for only one column, and do not use that value for non empty columns
			# Those can be "comment" rows added at the top of the file
			if ($non_empty_values >= 2) {
				push @original_rows, $row_ref;

				for (my $i = 0; $i < scalar(@$row_ref); $i++) {
					if ((defined $row_ref->[$i]) and ($row_ref->[$i] ne "")) {
						not defined $non_empty_columns[$i] and $non_empty_columns[$i] = 0;
						$non_empty_columns[$i]++;
					}
				}
			}
		}

		$log->debug("non empty columns",
			{number_of_original_rows => scalar(@original_rows), non_empty_columns => \@non_empty_columns})
			if $log->is_debug();

		# Check if the file contains a "Description" row and a header "Row"
		# in that case, the first column contains an empty cell, then "Description:" and "Example:" (possibly translated)
		my $has_description_and_example_rows = 0;
		if (    ($original_rows[0][0] eq "")
			and ($non_empty_columns[0] == 2)
			and ($original_rows[1][0] ne "")
			and ($original_rows[2][0] ne ""))
		{
			$has_description_and_example_rows = 1;
		}

		# Copy non empty columns and rows

		my $seen_header = 0;

		foreach my $row_ref (@original_rows) {
			# If we have a description and example row, skip rows that have a value only in the first column (description and example title)
			if (($has_description_and_example_rows) and ($row_ref->[0] ne "")) {
				next;
			}

			my @new_row = ();
			for (my $i = 0; $i < scalar(@$row_ref); $i++) {
				# Skip empty columns + the first column if there are description and example rows
				if (($non_empty_columns[$i]) and not(($i == 0) and $has_description_and_example_rows)) {
					push @new_row, $row_ref->[$i];
				}
			}

			$log->debug("new_row", {new_row => \@new_row}) if $log->is_debug();

			# Is it a header? (column 1 and 2 should not be empty)
			if (not $seen_header) {

				if ((defined $new_row[0]) and ($new_row[0] ne "") and (defined $new_row[1]) and ($new_row[1] ne "")) {
					$seen_header = 1;
					@{$input_headers_ref} = @new_row;

					$log->debug("seen header", {input_headers_ref => $input_headers_ref}) if $log->is_debug();
				}

				# Otherwise skip the line until we see a header
			}
			else {
				push @{$rows_ref}, \@new_row;
			}
		}
	}
	else {
		$results_ref->{error} = "Could not open CSV $file.csv: $!";
	}

	if (not $results_ref->{error}) {

		# If some columns have the same name, add a suffix
		my %headers = ();
		my $i = 0;
		foreach my $header (@{$input_headers_ref}) {
			if (defined $headers{$header}) {
				$headers{$header}++;
				$input_headers_ref->[$i] = $header . " - " . $headers{$header};
			}
			else {
				$headers{$header} = 1;
			}
			$i++;
		}
		$results_ref = {headers => $input_headers_ref, rows => $rows_ref};
	}

	return $results_ref;
}

# Go through the headers of the input CSV file, determine the match to OFF columns

sub create_off_columns_to_input_columns_match ($default_values_ref, $input_headers_ref, $columns_fields_ref,
	$output_headers_ref, $output_to_input_columns_ref)
{

	my $col = 0;

	# Some fields like image_other_url may be present multiple times,
	# in which case suffix them with .2 , .3 etc.
	my %seen_fields = ();

	foreach my $column (@{$input_headers_ref}) {

		my $field;

		# columns_fields_ref may contain unnormalized or normalized column names
		# we will try to match both
		my $columnid = get_string_id_for_lang("no_language", normalize_column_name($column));

		if ((defined $columns_fields_ref->{$column}) and (defined $columns_fields_ref->{$column}{field})) {
			$field = $columns_fields_ref->{$column}{field};
		}
		elsif ((defined $columns_fields_ref->{$columnid}) and (defined $columns_fields_ref->{$columnid}{field})) {
			$field = $columns_fields_ref->{$columnid}{field};
			$column = $columnid;
		}

		if (defined $field) {

			# For columns mapped to a specific label, output labels:Label name as the column name
			if ($field =~ /^(labels|categories)_specific$/) {
				$field = $1;
				if (defined $columns_fields_ref->{$column}{tag}) {
					$field .= ":" . $columns_fields_ref->{$column}{tag};
				}
				else {
					$field = undef;
				}
			}
			# Source specific fields
			elsif ($field eq "sources_fields_specific") {
				my $source_id;
				if (defined $default_values_ref->{source_id}) {
					# e.g. org-database-usda
					$source_id = "org-" . $default_values_ref->{source_id};
				}
				elsif (defined $Owner_id) {
					$source_id = $Owner_id;
				}
				$field = "sources_fields:" . $source_id . ":";
				if (defined $columns_fields_ref->{$column}{tag}) {
					$field .= $columns_fields_ref->{$column}{tag};
				}
				else {
					$field .= $column;
				}
			}
			elsif ($field =~ /_value_unit/) {
				$field = $`;
				if (defined $columns_fields_ref->{$column}{value_unit}) {
					$field .= "_" . $columns_fields_ref->{$column}{value_unit};
				}
				else {
					$field = undef;
				}
			}
			# For language specific field, add the language code at the end of the field name
			elsif ((defined $language_fields{$field}) and (defined $columns_fields_ref->{$column}{lc})) {
				$field .= "_" . $columns_fields_ref->{$column}{lc};
			}

			$log->debug("convert_file - found matching column", {column => $column, field => $field, col => $col})
				if $log->is_debug();

			if (defined $field) {
				# If we have already seen the field, suffix it with a number
				if (defined $seen_fields{$field}) {
					$seen_fields{$field}++;
					$field = $field . "." . $seen_fields{$field};
				}
				else {
					$seen_fields{$field} = 1;
				}

				push @$output_headers_ref, $field;
				$output_to_input_columns_ref->{$field} = $col;
			}
		}
		else {
			$log->debug("convert_file - no matching column", {column => $column}) if $log->is_debug();
		}

		$col++;
	}

	# Add headers from default values

	foreach my $field (sort keys %{$default_values_ref}) {

		if (not defined $seen_fields{$field}) {
			unshift @$output_headers_ref, $field;
			$output_to_input_columns_ref->{$field} = undef;
		}
	}

	return;
}

# Convert an uploaded file to OFF CSV format
# Note: some files sent from producers have the same product code on several lines
# e.g. with one line for each packaging component, with 1 column for packaging shape, 1 for packaging size etc.
# instead of having only 1 line for the product with different columns for each packaging component

sub convert_file ($default_values_ref, $file, $columns_fields_file, $converted_file) {

	# $default_values_ref  ->  values for lc, countries
	# $file  ->  path and file name

	my $columns_fields_ref = retrieve($columns_fields_file);

	my $load_results_ref = load_csv_or_excel_file($file);

	if ($load_results_ref->{error}) {
		return ($load_results_ref);
	}

	my $input_headers_ref = $load_results_ref->{headers};
	my $rows_ref = $load_results_ref->{rows};

	my $results_ref = {};

	# Output CSV header

	my $output_headers_ref = [];
	my $output_to_input_columns_ref = {};

	create_off_columns_to_input_columns_match(
		$default_values_ref, $input_headers_ref, $columns_fields_ref,
		$output_headers_ref, $output_to_input_columns_ref
	);

	# If we don't have a column mapped to the barcode, then we cannot use the file
	if (not defined $output_to_input_columns_ref->{"code"}) {
		$log->error("no column mapped to code", {output_to_input_columns_ref => $output_to_input_columns_ref})
			if $log->is_error();
		$results_ref->{error} = "no_column_mapped_to_code";
		$results_ref->{status} = "error";
		return $results_ref;
	}

	# Read the CSV file line by line and construct a hash of products data
	# Note that some products may have data on multiple lines
	# so we need to read all data in memory before writing the converted CSV file

	my $products_ref = {};

	# Keep track of the number of lines for each product
	my %product_lines = ();

	# We may add some output columns if there are products on multiple lines
	my $extra_output_headers_ref = [];

	foreach my $row_ref (@{$rows_ref}) {

		$log->debug("convert_file - row", {row_ref => $row_ref}) if $log->is_debug();

		# First get the barcode of the product
		my $code = $row_ref->[$output_to_input_columns_ref->{"code"}];

		if (not defined $code) {
			# The line is missing a barcode, we do not know which product it relates to
			$log->error("ignoring row without a value for the code column",
				{code_column => $output_to_input_columns_ref->{"code"}, row_ref => $row_ref})
				if $log->is_error();
			next;
		}

		if (not defined $products_ref->{$code}) {
			$products_ref->{$code} = {};
			$product_lines{$code} = 1;
		}
		else {
			# this is a line complementing info about a product
			$product_lines{$code}++;
		}

		my $product_ref = $products_ref->{$code};

		foreach my $field_orig (@$output_headers_ref) {
			my $field = $field_orig;    # Needed in order to be able to modify $field without changing the array content
			my $col = $output_to_input_columns_ref->{$field};

			# If we have multiple lines per product, we need to rename some fields by adding a number
			# so that the values on multiple lines are saved in multiple columns

			if ($product_lines{$code} > 1) {

				# If the field is of the form packaging_1_*
				# we rename the field to packaging_[current number of lines of the product]_*
				if ($field =~ /^packaging_1_/) {
					$field = "packaging_" . $product_lines{$code} . "_" . $';
				}
				# If the field is of the form image_other_url or image_other_type
				# we rename the field to image_other_(url|type).[current number of lines of the product]
				elsif (($product_lines{$code} > 1) and ($field =~ /^image_other_/)) {
					$field .= '.' . $product_lines{$code};
				}

				# Add the field to the list of columns in the output file if the column does not exist yet
				if (not exists $output_to_input_columns_ref->{$field}) {
					$output_to_input_columns_ref->{$field} = undef;
					push @$extra_output_headers_ref, $field;
				}
			}

			if (defined $col) {
				$product_ref->{$field} = $row_ref->[$col];
			}

			# If no value specified, use default value
			if (   (defined $default_values_ref->{$field}) and (not defined $product_ref->{$field})
				or ($product_ref->{$field} eq ""))
			{
				$product_ref->{$field} = $default_values_ref->{$field};
			}
		}
	}

	# Output the CSV file

	my $csv_out = Text::CSV->new({binary => 1, sep_char => "\t"})    # should set binary attribute.
		or die "Cannot use CSV: " . Text::CSV->error_diag();

	open(my $out, ">:encoding(UTF-8)", $converted_file) or die("Cannot write $converted_file: $!\n");

	$csv_out->print($out, [@$output_headers_ref, @$extra_output_headers_ref]);
	print $out "\n";

	foreach my $code (sort keys %$products_ref) {

		my $product_ref = $products_ref->{$code};

		# Make sure we have a value for lc, as it is needed for clean_fields()
		# if lc is not a 2 letter code, use the default value
		if (   (not defined $product_ref->{lc})
			or ($product_ref->{lc} eq "")
			or ($product_ref->{lc} !~ /^[a-z]{2}$/))
		{
			$product_ref->{lc} = $default_values_ref->{lc};
		}

		my @values = ();
		foreach my $field (@$output_headers_ref, @$extra_output_headers_ref) {
			push @values, $product_ref->{$field};
			#print STDERR "$field - $product_ref->{$field} . \n";
		}

		$csv_out->print($out, [@values]);
		print $out "\n";
	}

	close($out);

	$results_ref->{status} = "success";
	$results_ref->{rows} = scalar @{$rows_ref};
	$results_ref->{products} = scalar keys %$products_ref;

	return $results_ref;
}

# Normalize column names

sub normalize_column_name ($name) {

	# remove HTML tags

	$name =~ s/<(([^>]|\n)*)>//g;

	# non-alpha chars will be turned to -, change the ones we want to keep

	$name =~ s/%/percent/g;
	$name =~ s/µg/mcg/ig;

	# nutrient in unit
	$name =~ s/ in / /i;

	# 100g / 100ml
	$name =~ s/100(\s|_|-)*g(r?)(\b|$)/100g/i;
	$name =~ s/100(\s|_|-)*ml(\b|$)/100ml/i;
	$name =~ s/100g(\s|_|-)*(or|ou|\/|-)?(\s|_|-)*100ml/100g/i;

	# estampille(s) sanitaire(s)

	$name =~ s/\(s\)\b/s/ig;

	# remove stopwords

	$name =~ s/\b(vitamina|vitamine|vit(\.)?) /vitamin /ig;
	$name =~ s/\b(b|k)(-| )(\d+)\b/$1$3/ig;

	# fr
	$name =~ s/^(teneur|taux) (en |de |d')?//i;
	$name =~ s/^(dont|soit) //i;
	$name =~ s/ en / /i;

	$name =~ s/pourcentage/percent/i;
	$name =~ s/percent (of |en |de |d')?/percent /i;

	# move percent at the end
	$name =~ s/^(\)?percent\)?)(\s)?(.*)$/$3$2$1/i;

	# remove question mark
	$name =~ s/ ?\?$//;

	# remove "of the product" at the end (e.g. "category of the product")
	$name =~ s/ ((of the )?product|(del )?producto|(du )?produit)$//i;

	# remove "is the product" at the start (e.g. "is the product vegan")
	$name =~ s/^(is the product|le produit est(-| )il) //i;

	# "does the product contains XYZ"
	$name =~ s/^(does the product contain|the product contains) /contains /i;
	$name =~ s/^(le produit contient((-| )il)?) /contient /i;

	return $name;
}

# Initialize the list of synonyms of fields and nutrients in the different languages only once

my %fields_columns_names_for_lang = ();

# Extra synonyms

my %fields_synonyms = (

	en => {
		lc => ["lang"],
		code => [
			"code", "codes", "barcodes", "barcode",
			"ean", "ean-13", "ean13", "gtin",
			"eans", "gtins", "upc", "ean/gtin1",
			"gencod", "gencods", "gencode", "gencodes",
			"ean-barcode", "ean-barcode-number", "ean-code", "ean codes",
			"ean barcodes"
		],
		producer_product_id => ["internal code"],
		product_name =>
			["name", "name of the product", "name of product", "product name", "product", "commercial name"],
		carbohydrates_100g_value_unit => ["carbohydronate", "carbohydronates"],    # yuka bug, does not exist
		ingredients_text => ["ingredients", "ingredients list", "ingredient list", "list of ingredients"],
		allergens => ["allergens", "allergens list", "allergen list", "list of allergens"],
		traces => ["traces", "traces list", "trace list", "list of traces"],
		nutriscore_grade_producer => ["nutri-score", "nutriscore"],
		nova_group_producer => ["nova"],
		obsolete => ["The product is no longer sold", "Product is no longer sold.", "Product no longer sold"],
	},

	de => {
		code => ["Strichcode"],
	},

	es => {
		code => ["Código de barras", "Códigos de barras"],
		product_name => ["nombre", "nombre producto", "nombre del producto"],
		ingredients_text => ["ingredientes", "lista ingredientes", "lista de ingredientes"],
		net_weight_value_unit => ["peso unitrario", "peso unitario"],    # Yuka
		"energy-kcal_100g_value_unit" => ["calorias"],
		"link" => ["Enlace a la página del producto en el sitio oficial del fabricante"],
	},

	fr => {
		code => [
			"code barre",
			"codebarre",
			"codes barres",
			"code barre EAN/GTIN",
			"code barre EAN",
			"code barre GTIN",
			"code-barres",
			"code EAN",
			"codes EAN",
			"code GTIN",
			"codes GTIN"
		],
		producer_product_id => ["code interne", "code int"],
		categories => ["Catégorie(s)"],
		brands => ["Marque(s)", "libellé marque"],
		product_name => [
			"nom",
			"nom produit",
			"nom du produit",
			"produit",
			"nom commercial",
			"dénomination",
			"dénomination commerciale",
			"dénomination marketing",
			"nom marketing",
			"libellé marketing",
			"libellé",
			"désignation"
		],
		abbreviated_product_name =>
			["nom abrégé", "nom abrégé du produit", "nom du produit abrégé", "nom du produit avec abbréviations"],
		generic_name => ["dénomination légale", "déno légale", "dénomination légale de vente"],
		ingredients_text => [
			"ingrédients",
			"ingredient",
			"liste des ingrédients",
			"liste d'ingrédients",
			"liste ingrédients",
			"listes d'ingrédients"
		],
		allergens => [
			"Substances ou produits provoquant des allergies ou intolérances",
			"Allergènes et Traces Potentielles",
			"allergènes et traces",
			"allergènes (ingrédients)"
		],
		traces => ["Traces éventuelles", "allergènes (traces)"],
		origin => ["Origine(s) des ingrédients"],
		image_front_url_fr => ["visuel", "photo", "photo produit"],
		labels => ["signes qualité", "signe qualité", "Allégations santé", "Labels, certifications, récompenses"],
		countries => ["pays de vente"],
		serving_size_value_unit => ["Taille d'une portion"],
		volume_value_unit => ["volume net"],
		net_weight_value_unit => ["poids"],
		drained_weight_value_unit => ["poids net égoutté"],
		recycling_instructions_to_recycle => ["à recycler", "consigne à recycler"],
		recycling_instructions_to_discard => ["à jeter", "consigne à jeter"],
		packaging => ["Etat physique du produit", "état physique"],
		conservation_conditions => ["Conservation", "Conditions de conservation et d'utilisation"],
		preparation => ["conseils de préparation", "instructions de préparation", "Mode d'emploi"],
		link => ["lien", "lien du produit", "lien internet", "lien vers la page internet"],
		manufacturing_places => [
			"lieu de conditionnement",
			"lieux de conditionnement",
			"lieu de fabrication",
			"lieux du fabrication",
			"lieu de fabrication du produit"
		],
		nutriscore_grade_producer => ["note nutri-score", "note nutriscore", "lettre nutri-score", "lettre nutriscore"],
		nutriscore_score_producer => ["score nutri-score", "score nutritionnel"],
		emb_codes => ["estampilles sanitaires / localisation", "codes emballeurs / localisation"],
		lc => ["langue", "langue du produit"],
		obsolete => ["Le produit n'est plus en vente.", "Produit retiré de la vente", "Produit obsolète", "Obsolète"],
		packaging_text => ["Instruction de recyclage et/ou information d'emballage"],
	},

);

my %prepared_synonyms = (
	# "" is the default unprepared, it needs to have "" as the first synonym
	"" => {
		en => ["", "unprepared"],
		fr => ["", "non préparé"],
	},
	"_prepared" => {
		en => ["prepared"],
		es => ["preparado"],
		fr => ["préparé", "préparation"],
	}
);

my %per_synonyms = (
	# per 100g includes an empty "" synonym
	# may need to be changed for the US, CA etc.
	"100g" => {
		en => ["", "for 100g", "per 100g", "100g"],
		fr => ["", "pour 100g", "100g"],
	},
	"serving" => {
		en => ["per serving", "serving"],
		es => ["por porción", "porción"],
		fr => ["par portion", "pour une portion", "portion", "par plat", "pour un plat", "plat"],
	}
);

# Note: This is not a conversion table, it is a list of synonyms used by producers when they transmit us data.
# In practice, no producer uses cal (as in 1/1000 of kcal) as a unit for energy.
# When they have "cal" or "calories" in the header of a column, they always mean kcal.
# The units in this table are lowercased, so "cal" is for the "big Calories". 1 Cal = 1 kcal.

my %units_synonyms = (
	"g" => "g",
	"gr" => "g",
	"grams" => "g",
	"grammes" => "g",
	"mg" => "mg",
	"mcg" => "mcg",
	"ug" => "mcg",
	"percent" => "percent",
	"kj" => "kj",
	"kcal" => "kcal",
	"cal" => "kcal",
	"calories" => "kcal",
	"calorie" => "kcal",
	"iu" => "iu",
	"ui" => "iu",
);

my %in = (
	"en" => "in",
	"es" => "en",
	"fr" => "en",
);

=head2 init_fields_columns_names_for_lang ( $l )

Populates global $fields_columns_names_for_lang for the specified language.

The function creates a hash of all the possible localized column names
that we can automatically recognize, and maps them to the corresponding field in OFF.

Nutrient column names are not included in the hash: they are matched by match_nutrient_column_name()
from the nutrient synonyms and the possible suffixes computed by init_nutrients_columns_names_for_lang()

The column names are computed the first time they are needed for a language.

=head3 Arguments

=head4 $l - required

Language code (string)

=head3 Return value

Reference to the column names hash.

=cut

sub init_fields_columns_names_for_lang ($l) {

	if (defined $fields_columns_names_for_lang{$l}) {
		return $fields_columns_names_for_lang{$l};
	}

	$fields_columns_names_for_lang{$l} = {};

	init_nutrients_columns_names_for_lang($l);
	init_packaging_columns_names_for_lang($l);
	init_other_fields_columns_names_for_lang($l);

	# Other known fields

	foreach my $column_id (qw(calories kcal)) {
		$fields_columns_names_for_lang{$l}{$column_id}
			= {field => "energy-kcal_100g_value_unit", value_unit => "value_in_kcal"};
	}
	$fields_columns_names_for_lang{$l}{"kj"} = {field => "energy-kj_100g_value_unit", value_unit => "value_in_kj"};

	return $fields_columns_names_for_lang{$l};
}

# Generate column names for a language field
# It populates %fields_columns_names_for_lang

sub add_language_field_column_names ($l, $field) {

	foreach my $field_l ($l, "en") {

		my @synonyms = ($field, $Lang{$field}{$field_l});
		if ((defined $fields_synonyms{$field_l}) and (defined $fields_synonyms{$field_l}{$field})) {
			foreach my $synonym (@{$fields_synonyms{$field_l}{$field}}) {
				push @synonyms, $synonym;
			}
		}

		foreach my $synonym (@synonyms) {
			$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $synonym)}
				= {field => $field, lc => $l};
			$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $synonym . " " . $l)}
				= {field => $field, lc => $l};
			$fields_columns_names_for_lang{$l}
				{get_string_id_for_lang("no_language", $synonym . " " . $language_codes{$l})}
				= {field => $field, lc => $l};
			$fields_columns_names_for_lang{$l}{
				get_string_id_for_lang("no_language",
					$synonym . " " . display_taxonomy_tag($field_l, 'languages', $language_codes{$l}))
			} = {field => $field, lc => $l};
		}
	}

	return;
}

# Create column names for packaging data in a specific language
# It populates %fields_columns_names_for_lang

sub init_packaging_columns_names_for_lang ($l) {

	# Language fields

	foreach my $field ("packaging_text", "recycling_instructions_to_recycle", "recycling_instructions_to_discard") {
		add_language_field_column_names($l, $field);
	}

	# Packaging components

	for (my $i = 1; $i <= $IMPORT_MAX_PACKAGING_COMPONENTS; $i++) {
		my $packaging_i = $Lang{"packaging_part_short"}{$l} . " " . $i . " - ";
		foreach my $property ("number_of_units", "shape", "material", "recycling", "weight", "quantity_per_unit") {
			my $name = $packaging_i . $Lang{"packaging_" . $property}{$l};
			my $field = "packaging_${i}_${property}";
			# If producers send a weight, we assign it to the weight_specified field
			$field =~ s/_weight$/_weight_specified/g;

			$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $name)} = {field => $field};
		}
	}

	return;
}

# Nutrient column names are made of a nutrient synonym followed by a suffix:
# prepared or not, per 100g or per serving, value or unit, unit of measure
# e.g. "proteines preparees pour 100g en g"
# Storing all the combinations for all nutrients would result in millions of column names
# for some languages (more than 200 MB for French), so we store the nutrient synonyms
# and the suffixes separately, and match_nutrient_column_name() splits the column names.

my %nutrients_columns_names_for_lang = ();

sub get_column_name_part_id (@parts) {
	return get_string_id_for_lang("no_language", join(" ", map {$_ // ""} @parts));
}

# Create the nutrient synonyms and the suffixes of nutrient column names for a specific language
# It populates %nutrients_columns_names_for_lang

sub init_nutrients_columns_names_for_lang ($l) {

	# synonym id -> list of [nutrient id, order]
	# with_unit synonyms are used with suffixes that contain a unit of measure:
	# for energy kj/kcal, we remove the unit from the synonym
	my %synonyms = (without_unit => {}, with_unit => {});

	# The order is used to select a match when a column name can be split in different ways
	my $synonym_order = 0;

	# Go through all the nutrients in the nutrients taxonomy
	foreach my $nutrient_tagid (sort(get_all_taxonomy_entries("nutrients"))) {

		my $nid = $nutrient_tagid;
		$nid =~ s/^zz://g;

		foreach my $synonym (get_taxonomy_tag_synonyms($l, "nutrients", $nutrient_tagid)) {

			$synonym = normalize_column_name($synonym);
			$synonym_order++;

			push @{$synonyms{without_unit}{get_column_name_part_id($synonym)}}, [$nid, $synonym_order];

			my $synonym2 = $synonym;
			if ($nid eq "energy-kcal") {
				$synonym2 =~ s/kcal//;
			}
			elsif ($nid eq "energy-kj") {
				$synonym2 =~ s/kj//;
			}
			push @{$synonyms{with_unit}{get_column_name_part_id($synonym2)}}, [$nid, $synonym_order];
		}
	}

	# suffix id -> list of suffixes (prepared, per, value_unit or unit, order)
	# value_prefix and unit_prefix suffixes are used when the column name starts with "value" or "unit"
	my %suffixes = (without_unit => {}, with_unit => {}, value_prefix => {}, unit_prefix => {});
	my $suffix_order = 0;

	my $add_suffix = sub ($type, $parts_ref, $suffix_ref) {
		push @{$suffixes{$type}{get_column_name_part_id(@{$parts_ref})}}, {%{$suffix_ref}, order => ++$suffix_order};
		return;
	};

	# Product as sold / unprepared or prepared
	# "" is unprepared

	foreach my $prepared ("", "_prepared") {

		# Synonyms for unprepared and prepared
		# We need at least an empty entry for the unprepared ""
		my @prepared_synonyms = @{$prepared_synonyms{$prepared}{$l} // ($prepared eq "" ? [""] : [])};

		foreach my $prepared_synonym (@prepared_synonyms) {

			# Nutrients per 100g and per serving

			foreach my $per ("100g", "serving") {

				# per 100 g / 100 ml -> per 100g
				my $nutrition_data_per = $Lang{"nutrition_data_per_" . $per}{$l};
				my $nutrition_data_per_normalized = $nutrition_data_per // "";
				# remove the 100ml from "per 100g / 100ml";
				$nutrition_data_per_normalized =~ s/100 g/100g/i;
				$nutrition_data_per_normalized =~ s/100 ml/100ml/i;
				$nutrition_data_per_normalized =~ s/100ml//i;

				# Synonyms of per 100g and per serving
				# Use the English synonyms if we don't have language specific strings
				foreach my $per_synonym (@{$per_synonyms{$per}{$l} // $per_synonyms{$per}{en}},
					$nutrition_data_per, $nutrition_data_per_normalized)
				{
					my %suffix = (prepared => $prepared, per => $per);

					# field name without "unit" or "quantity"
					$add_suffix->("without_unit", [$prepared_synonym, $per_synonym], \%suffix);

					# field name with "quantity" or "unit" at beginning or end
					$add_suffix->(
						"without_unit",
						[$prepared_synonym, $per_synonym, $Lang{value}{$l}],
						{%suffix, value_unit => "value"}
					);
					$add_suffix->("value_prefix", [$prepared_synonym, $per_synonym], {%suffix, value_unit => "value"});
					$add_suffix->(
						"without_unit",
						[$prepared_synonym, $per_synonym, $Lang{unit}{$l}],
						{%suffix, value_unit => "unit"}
					);
					$add_suffix->("unit_prefix", [$prepared_synonym, $per_synonym], {%suffix, value_unit => "unit"});
				}
			}

			# Field names with actual units. e.g. Energy kcal, carbohydrates g, calcium mg

			foreach my $unit (sort keys %units_synonyms) {

				$add_suffix->(
					"with_unit",
					[$prepared_synonym, $unit],
					{prepared => $prepared, per => "100g", unit => $unit}
				);

				foreach my $per ("100g", "serving") {
					foreach my $per_synonym (@{$per_synonyms{$per}{$l} // $per_synonyms{$per}{en}}) {
						my %suffix = (prepared => $prepared, per => $per, unit => $unit);
						$add_suffix->("with_unit", [$prepared_synonym, $unit, $per_synonym], \%suffix);
						$add_suffix->("with_unit", [$prepared_synonym, $per_synonym, $unit], \%suffix);
						if (defined $in{$l}) {
							$add_suffix->("with_unit", [$prepared_synonym, $in{$l}, $unit, $per_synonym], \%suffix);
							$add_suffix->("with_unit", [$prepared_synonym, $per_synonym, $in{$l}, $unit], \%suffix);
						}
					}
				}
			}
		}
	}

	$nutrients_columns_names_for_lang{$l} = {
		synonyms => \%synonyms,
		suffixes => \%suffixes,
		value_prefix => get_column_name_part_id($Lang{value}{$l}) . "-",
		unit_prefix => get_column_name_part_id($Lang{unit}{$l}) . "-",
	};

	return;
}

sub nutrient_column_unit_is_allowed ($nid, $unit) {

	if ($nid eq "energy-kcal") {
		return ($unit =~ /^(kcal|cal|calories)$/);
	}
	elsif ($nid eq "energy-kj") {
		return ($unit eq "kj");
	}
	elsif ($nid =~ /^energy/) {
		# Give priority to energy-kj and energy-kcal
		return 0;
	}
	return 1;
}

=head2 match_nutrient_column_name ( $l, $column_id )

Match a column id to a nutrient field, by splitting it into a nutrient synonym and a suffix.

If the column id can be split in different ways, the match with the last synonym
(in the order of the nutrients taxonomy) and then the last suffix is selected.

=head3 Return value

Reference to a hash with the field and value_unit, or undef if the column id does not match a nutrient.

=cut

sub match_nutrient_column_name ($l, $column_id) {

	my $columns_names_ref = $nutrients_columns_names_for_lang{$l} // return;

	my $match_ref;
	my @match_order = (-1, -1);

	my $match_split = sub ($id, $synonyms_type, $suffixes_type) {

		# Try all the possible splits at a dash, the synonym and the suffix can be empty
		my @positions = (-1);
		my $position = -1;
		while (($position = index($id, "-", $position + 1)) >= 0) {
			push @positions, $position;
		}
		push @positions, length($id);

		foreach my $position (@positions) {
			my $synonym_id = $position < 0 ? "" : substr($id, 0, $position);
			my $suffix_id = $position < length($id) ? substr($id, $position + 1) : "";
			my $synonyms_ref = $columns_names_ref->{synonyms}{$synonyms_type}{$synonym_id} // next;
			my $suffixes_ref = $columns_names_ref->{suffixes}{$suffixes_type}{$suffix_id} // next;

			foreach my $synonym_ref (@{$synonyms_ref}) {
				my ($nid, $synonym_order) = @{$synonym_ref};
				foreach my $suffix_ref (@{$suffixes_ref}) {
					next
						if defined $suffix_ref->{unit}
						and not nutrient_column_unit_is_allowed($nid, $suffix_ref->{unit});
					if (   ($synonym_order > $match_order[0])
						or (($synonym_order == $match_order[0]) and ($suffix_ref->{order} > $match_order[1])))
					{
						@match_order = ($synonym_order, $suffix_ref->{order});
						$match_ref = [$nid, $suffix_ref];
					}
				}
			}
		}
		return;
	};

	$match_split->($column_id, "without_unit", "without_unit");
	$match_split->($column_id, "with_unit", "with_unit");
	foreach my $prefix_type ("value_prefix", "unit_prefix") {
		my $prefix = $columns_names_ref->{$prefix_type};
		if (index($column_id, $prefix) == 0) {
			$match_split->(substr($column_id, length($prefix)), "without_unit", $prefix_type);
		}
	}

	return if not defined $match_ref;

	my ($nid, $suffix_ref) = @{$match_ref};
	my $result_ref = {field => $nid . $suffix_ref->{prepared} . "_" . $suffix_ref->{per} . "_value_unit"};
	if (defined $suffix_ref->{unit}) {
		$result_ref->{value_unit} = "value_in_" . $units_synonyms{$suffix_ref->{unit}};
	}
	elsif (defined $suffix_ref->{value_unit}) {
		$result_ref->{value_unit} = $suffix_ref->{value_unit};
	}
	elsif ($nid eq "energy-kcal") {
		$result_ref->{value_unit} = "value_in_kcal";
	}
	elsif ($nid eq "energy-kj") {
		$result_ref->{value_unit} = "value_in_kj";
	}
	return $result_ref;
}

=head2 get_column_id_field ( $l, $column_id )

Match a column id to a field in a specific language.

=head3 Return value

Reference to a hash with the field (and optionally value_unit, lc, tag), or undef if there is no match.

=cut

sub get_column_id_field ($l, $column_id) {

	init_fields_columns_names_for_lang($l);

	return $fields_columns_names_for_lang{$l}{$column_id} // match_nutrient_column_name($l, $column_id);
}

sub init_other_fields_columns_names_for_lang ($l) {

	my $fields_groups_ref = $options{import_export_fields_groups};

	foreach my $group_ref (@{$fields_groups_ref}) {

		my $group_id = $group_ref->[0];

		if (($group_id eq "nutrition") or ($group_id eq "nutrition_other")) {
		}
		else {

			foreach my $field (@{$group_ref->[1]}) {

				if ($group_id eq "images") {
					# front / ingredients / nutrition : specific to one language
					if ($field =~ /image_($valid_image_types_regexp)/) {
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", normalize_column_name($Lang{$field}{$l}))}
							= {field => $field . "_$l"};
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $1 . "_" . $l . "_url")} = {field => $field . "_$l"};
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", "image_" . $1 . "_" . $l . "_url")}
							= {field => $field . "_$l"};
						$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $field)}
							= {field => $field . "_$l"};
						$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $field . " " . $l)}
							= {field => $field . "_$l"};
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $field . " " . $language_codes{$l})}
							= {field => $field . "_$l"};
						$fields_columns_names_for_lang{$l}{
							get_string_id_for_lang("no_language",
								$field . " " . display_taxonomy_tag($l, 'languages', $language_codes{$l}))
						} = {field => $field . "_$l"};
					}
					elsif ($field =~ /image_(other)/) {
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", normalize_column_name($Lang{$field}{$l}))}
							= {field => $field};
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $1 . "_" . $l . "_url")} = {field => $field};
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", "image_" . $1 . "_" . $l . "_url")}
							= {field => $field};
					}
				}
				elsif ($field =~ /_value_unit$/) {
					# Column can contain value + unit, value, or unit for a specific field
					my $field_name = $`;

					my @synonyms = ($field_name, $Lang{$field_name}{$l});
					if ((defined $fields_synonyms{$l}) and (defined $fields_synonyms{$l}{$field})) {
						foreach my $synonym (@{$fields_synonyms{$l}{$field}}) {
							push @synonyms, $synonym;
						}
					}

					foreach my $synonym (@synonyms) {
						$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $synonym)}
							= {field => $field};

						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $synonym . " " . $Lang{value}{$l})} = {
							field => $field,
							value_unit => "value",
							};
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $Lang{value}{$l} . " " . $synonym)} = {
							field => $field,
							value_unit => "value",
							};

						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $synonym . " " . $Lang{unit}{$l})} = {
							field => $field,
							value_unit => "unit",
							};
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $Lang{unit}{$l} . " " . $synonym)} = {
							field => $field,
							value_unit => "unit",
							};

						my @units = keys %units_synonyms;

						foreach my $unit (@units) {
							$fields_columns_names_for_lang{$l}
								{get_string_id_for_lang("no_language", $synonym . " " . $unit)} = {
								field => $field,
								value_unit => "value_in_" . $units_synonyms{$unit},
								};
						}
					}
				}
				elsif (defined $tags_fields{$field}) {
					my $tagtype = $field;
					# Plural and singular
					$fields_columns_names_for_lang{$l}
						{get_string_id_for_lang("no_language", $Lang{$tagtype . "_p"}{$l})} = {field => $field};
					$fields_columns_names_for_lang{$l}
						{get_string_id_for_lang("no_language", $Lang{$tagtype . "_s"}{$l})} = {field => $field};
				}
				elsif (defined $language_fields{$field}) {

					# Example matches:
					# Liste d'ingrédients / Liste d'ingrédients (fr) /
					# Ingredients list / Ingredients list (fr) / Ingredients list (French) / Ingredients list (français)

					add_language_field_column_names($l, $field);
				}
				else {
					$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $field)}
						= {field => $field};
					$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $Lang{$field}{$l})}
						= {field => $field};
				}

				if ($field eq "nova_group_producer") {
					$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", lang("nova_groups_s"))}
						= {field => $field};
					$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", lang("nova_groups_p"))}
						= {field => $field};
				}
			}
		}
	}

	# Specific labels that can have a dedicated column
	my @labels = (
		"en:organic", "en:fair-trade",
		"en:palm-oil-free", "en:contains-palm-oil",
		"en:gluten-free", "en:contains-gluten",
		"en:vegan", "en:vegetarian",
		"fr:ab-agriculture-biologique", "fr:label-rouge",
		"en:pdo", "en:pgi",
		"en:tsg"
	);
	foreach my $labelid (@labels) {
		next if not defined $translations_to{labels}{$labelid}{$l};
		my $results_ref = {field => "labels_specific", tag => $translations_to{labels}{$labelid}{$l}};
		my @synonyms = ();
		my $label_lc_labelid = get_string_id_for_lang($l, $translations_to{labels}{$labelid}{$l});
		foreach my $synonym (@{$synonyms_for{labels}{$l}{$label_lc_labelid}}) {
			# $log->debug("labels_specific", { l=>$l, label_lc_labelid=>$label_lc_labelid, label=>$labelid, synonym=>$synonym }) if $log->is_debug();

			$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $synonym)} = $results_ref;
			$fields_columns_names_for_lang{$l}
				{get_string_id_for_lang("no_language", $synonym . " " . $Lang{"labels_s"}{$l})} = $results_ref;
			$fields_columns_names_for_lang{$l}
				{get_string_id_for_lang("no_language", $Lang{"labels_s"}{$l} . " " . $synonym)} = $results_ref;
		}
	}

	# Extra synonyms
	if (defined $fields_synonyms{$l}) {
		foreach my $field (keys %{$fields_synonyms{$l}}) {
			# Language specific fields synonyms have already been included
			if (not defined $language_fields{$field}) {
				foreach my $synonym (@{$fields_synonyms{$l}{$field}}) {
					# $log->debug("synonyms", { l=>$l, field=>$field, synonym=>$synonym }) if $log->is_debug();
					$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $synonym)}
						= {field => $field};
				}
			}
		}
	}

	# lc field uses translations for "lang"
	$fields_columns_names_for_lang{$l}{get_string_id_for_lang("no_language", $Lang{lang}{$l})} = {field => "lc"};

	return;
}

sub match_column_name_to_field ($l, $column_id) {

	my $results_ref = get_column_id_field($l, $column_id) // get_column_id_field("en", $column_id);

	if (defined $results_ref) {
		return $results_ref;
	}
	# Try removing ending numbers (e.g. for columns like image_other_url_2)
	elsif ($column_id =~ /-(\d+)$/) {
		my $column_id_without_number = $`;
		$results_ref = get_column_id_field($l, $column_id_without_number)
			// get_column_id_field("en", $column_id_without_number);
	}
	# try to see if there is a trailing language code
	# e.g. ingredients-text-fr
	elsif ($column_id =~ /-([a-z]{2})$/) {
		my $column_id_without_lc = $`;
		my $field_lc = $1;
		$results_ref = get_column_id_field($l, $column_id_without_lc)
			// get_column_id_field("en", $column_id_without_lc);
		if (defined $results_ref) {
			$results_ref = dclone($results_ref);
			$results_ref->{lc} = $field_lc;
		}
	}

	return $results_ref // {};
}

# Go through all rows to extract examples, compute stats etc.

sub compute_statistics_and_examples ($input_headers_ref, $rows_ref, $columns_fields_ref) {

	foreach my $column (@{$input_headers_ref}) {
		if (not defined $columns_fields_ref->{$column}) {
			$columns_fields_ref->{$column} = {
				examples => [],
				existing_examples => {},
				n => 0,
				numbers => 0,
				letters => 0,
				both => 0,
				min => undef,
				max => undef
			};
		}
	}

	my $row = 0;

	foreach my $row_ref (@{$rows_ref}) {

		my $col = 0;

		foreach my $value (@{$row_ref}) {

			my $column = $input_headers_ref->[$col];

			# empty value?

			if ((not defined $value) or ($value =~ /^\s*$/)) {

			}
			else {
				# defined value
				$columns_fields_ref->{$column}{n}++;

				# examples
				if (@{$columns_fields_ref->{$column}{examples}} < 3) {
					if (not defined $columns_fields_ref->{$column}{existing_examples}{$value}) {
						$columns_fields_ref->{$column}{existing_examples}{$value} = 1;
						push @{$columns_fields_ref->{$column}{examples}}, $value;
					}
				}

				# content
				if ($value =~ /[0-9]/) {
					$columns_fields_ref->{$column}{numbers}++;
				}
				if ($value =~ /[a-z]/i) {
					$columns_fields_ref->{$column}{letters}++;
				}
				if ($value =~ /[0-9].*[a-z]/i) {
					$columns_fields_ref->{$column}{both}++;
				}

				# min and max number values
				if ($value =~ /^(<|\s)*((\d+)((\.|\,)(\d+)))?$/) {
					my $numeric_value = $2;
					not defined $columns_fields_ref->{$column}{min}
						and $columns_fields_ref->{$column}{min} = $numeric_value;
					not defined $columns_fields_ref->{$column}{max}
						and $columns_fields_ref->{$column}{max} = $numeric_value;
					($numeric_value < $columns_fields_ref->{$column}{min})
						and $columns_fields_ref->{$column}{min} = $numeric_value;
					($numeric_value > $columns_fields_ref->{$column}{max})
						and $columns_fields_ref->{$column}{max} = $numeric_value;
				}
			}

			$col++;
		}

		$row++;
	}

	return;
}

# Analyze the headers column names and rows content to pre-assign fields to columns

sub init_columns_fields_match ($input_headers_ref, $rows_ref) {

	my $columns_fields_ref = {};

	# Go through all rows to extract examples, compute stats etc.

	$log->debug("before compute_statistics_and_examples", {}) if $log->is_debug();

	compute_statistics_and_examples($input_headers_ref, $rows_ref, $columns_fields_ref);

	# Load previously assigned fields by the owner

	my $all_columns_fields_ref = {};

	if (defined $Owner_id) {
		$all_columns_fields_ref = retrieve("$BASE_DIRS{IMPORT_FILES}/${Owner_id}/all_columns_fields.sto");
	}

	# Match known column names to OFF fields

	# Initialize the column matching (done only once)

	$log->debug("before init_fields_columns_names_for_lang", {}) if $log->is_debug();

	init_fields_columns_names_for_lang($lc);

	if ($lc ne "en") {
		# we also add english names
		init_fields_columns_names_for_lang("en");
	}

	$log->debug("after init_fields_columns_names_for_lang", {}) if $log->is_debug();

	foreach my $column (@{$input_headers_ref}) {

		my $column_id = get_string_id_for_lang("no_language", normalize_column_name($column));

		# Skip empty columns
		next if $column_id eq "";

		if ((defined $all_columns_fields_ref->{$column_id}) and (defined $all_columns_fields_ref->{$column_id}{field}))
		{

			$columns_fields_ref->{$column}
				= {%{$columns_fields_ref->{$column}}, %{$all_columns_fields_ref->{$column_id}}};
		}
		else {

			# Name of a field in the current language or in English?

			$log->debug(
				"before match_column_name_to_field",
				{
					lc => $lc,
					column => $column,
					column_id => $column_id,
					column_field => $columns_fields_ref->{$column}
				}
			) if $log->is_debug();

			$columns_fields_ref->{$column}
				= {%{$columns_fields_ref->{$column}}, %{match_column_name_to_field($lc, $column_id)}};
			$columns_fields_ref->{$column}{column_id} = $column_id;

			$log->debug(
				"after match_column_name_to_field",
				{
					lc => $lc,
					column => $column,
					column_id => $column_id,
					column_field => $columns_fields_ref->{$column}
				}
			) if $log->is_debug();

			# If we don't know if the column contains value + unit, value, or unit,
			# try to guess from the content of the column
			if (not defined $columns_fields_ref->{$column}{value_unit}) {
				if ($columns_fields_ref->{$column}{both}) {
					$columns_fields_ref->{$column}{value_unit} = "value_unit";
				}
				elsif ($columns_fields_ref->{$column}{numbers}) {
					$columns_fields_ref->{$column}{value_unit} = "value";

					# Try to guess the unit

					# Common nutrients usually in grams, max value <= 100
					if (
						(
							$columns_fields_ref->{$column}{field}
							=~ /^(fat|saturated-fat|carbohydrates|sugars|proteins|salt|fiber|fruits-vegetables-nuts|fruits-vegetables-legumes)_100g_value_unit$/
						)
						and ($columns_fields_ref->{$column}{max} <= 100)
						)
					{
						$columns_fields_ref->{$column}{value_unit} = "value_in_g";
					}

					# Sodium usually in mg
					elsif ( ($columns_fields_ref->{$column}{field} =~ /^(sodium)_100g_value_unit$/)
						and ($columns_fields_ref->{$column}{max} > 50))
					{
						$columns_fields_ref->{$column}{value_unit} = "value_in_mg";
					}

				}
				elsif ($columns_fields_ref->{$column}{letters}) {
					$columns_fields_ref->{$column}{value_unit} = "unit";
				}
			}

			# "Nutri-Score" columns sometime contains the nutriscore score (number) or grade (letter)
			if (    ($columns_fields_ref->{$column}{field} eq "nutriscore_score_producer")
				and ($columns_fields_ref->{$column}{letters})
				and (not $columns_fields_ref->{$column}{numbers})
				and (not $columns_fields_ref->{$column}{both}))
			{
				$columns_fields_ref->{$column}{field} = "nutriscore_grade_producer";
			}
			if (    ($columns_fields_ref->{$column}{field} eq "nutriscore_grade_producer")
				and ($columns_fields_ref->{$column}{numbers})
				and (not $columns_fields_ref->{$column}{letters})
				and (not $columns_fields_ref->{$column}{both}))
			{
				$columns_fields_ref->{$column}{field} = "nutriscore_score_producer";
			}
			if (    ($columns_fields_ref->{$column}{field} eq "nutriscore_score_producer")
				and ($columns_fields_ref->{$column}{numbers})
				and (not $columns_fields_ref->{$column}{numbers})
				and (not $columns_fields_ref->{$column}{both}))
			{
				$columns_fields_ref->{$column}{field} = "nutriscore_grade_producer";
			}
		}

		delete $columns_fields_ref->{$column}{existing_examples};
	}

	return $columns_fields_ref;
}

# Generate an array of options for select2

sub generate_import_export_columns_groups_for_select2 ($lcs_ref) {    # array of language codes

	my $fields_groups_ref = $options{import_export_fields_groups};

	# Sample select2 groups and fields definition format from Config.pm:
	my $sample_fields_groups_ref = [
		[
			"identification",
			[
				"code", "producer_product_id",
				"producer_version_id", "lc",
				"product_name", "abbreviated_product_name",
				"generic_name",
				"quantity_value_unit", "net_weight_value_unit",
				"drained_weight_value_unit", "volume_value_unit",
				"serving_size_value_unit", "packaging",
				"brands", "brand_owner",
				"categories", "categories_specific",
				"labels", "labels_specific",
				"countries", "stores",
				"obsolete", "obsolete_since_date",
				"periods_after_opening"    # included for OBF imports via the producers platform
			]
		],
		[
			"origins",
			["origins", "origin", "manufacturing_places", "producer", "emb_codes"]
		],
		["ingredients", ["ingredients_text", "allergens", "traces"]],
		["nutrition"],
		["nutrition_other"],
		["packaging"],
		[
			"other",
			[
				"conservation_conditions", "warning",
				"preparation", "nutriscore_score_producer",
				"nutriscore_grade_producer", "nova_group_producer",
				"recipe_idea", "customer_service",
				"link",
			]
		],
		[
			"images",
			[
				"image_front_url", "image_ingredients_url", "image_nutrition_url", "image_packaging_url",
				"image_other_url", "image_other_type",
			]
		],
	];

	# Special fields only selectable by moderators

	if (defined $User{pro_moderator_owner}) {
		push @{$fields_groups_ref}, ["other", ["sources_fields_specific"]];
	}

	# Create an options array for select2

	my $select2_options_sample = <<JSON
{
  "results": [
    {
      "text": "Group 1",
      "children" : [
        {
            "id": 1,
            "text": "Option 1.1"
        },
        {
            "id": 2,
            "text": "Option 1.2"
        }
      ]
    },
    {
      "text": "Group 2",
      "children" : [
        {
            "id": 3,
            "text": "Option 2.1"
        },
        {
            "id": 4,
            "text": "Option 2.2"
        }
      ]
    }
  ],
}
JSON
		;

	# Populate the select2 options array from the groups and fields definition

	my $select2_options_ref = [];

	foreach my $group_ref (@{$fields_groups_ref}) {

		my $group_id = $group_ref->[0];
		my $select2_group_ref = {text => lang("fields_group_" . $group_id), children => [], group_id => $group_id};

		# For some specific groups, we generate the corresponding lists of fields

		# List of nutrients
		if (($group_id eq "nutrition") or ($group_id eq "nutrition_other")) {

			# Go through the nutrient table
			foreach my $nutrient (@{$nutrients_tables{$nutrient_table}}) {

				next if $nutrient =~ /^\#/;
				my $nid = $nutrient;

				# %Food::nutrients_tables ids have an ending - for nutrients that are not displayed by default
				# Keep the % of fruits/vegetables/nuts in the main nutrition group

				if (    ($nid =~ /-$/)
					and ($nid ne 'fruits-vegetables-nuts-')
					and ($nid ne 'fruits-vegetables-nuts-dried-')
					and ($nid ne 'fruits-vegetables-legumes-'))
				{
					next if ($group_id eq "nutrition");
				}
				else {
					next if ($group_id eq "nutrition_other");
				}

				$nid =~ s/^(-|!)+//g;
				$nid =~ s/-$//g;

				my $field = $nid;

				my $name = display_taxonomy_tag($lc, "nutrients", "zz:$nid");

				push @{$select2_group_ref->{children}},
					{id => $nid . "_100g_value_unit", text => ucfirst($name) . " " . lang("nutrition_data_per_100g")};
				push @{$select2_group_ref->{children}},
					{
					id => $nid . "_serving_value_unit",
					text => ucfirst($name) . " " . lang("nutrition_data_per_serving")
					};
				push @{$select2_group_ref->{children}},
					{
					id => $nid . "_prepared_100g_value_unit",
					text => ucfirst($name) . " - "
						. lang("preparation_prepared") . " "
						. lang("nutrition_data_per_100g")
					};
				push @{$select2_group_ref->{children}},
					{
					id => $nid . "_prepared_serving_value_unit",
					text => ucfirst($name) . " - "
						. lang("preparation_prepared") . " "
						. lang("nutrition_data_per_serving")
					};
			}
		}
		# Packaging
		if ($group_id eq "packaging") {
			foreach
				my $field ("packaging_text", "recycling_instructions_to_recycle", "recycling_instructions_to_discard")
			{
				my $name = lang($field);
				push @{$select2_group_ref->{children}}, {id => "$field", text => ucfirst($name)};
			}

			for (my $i = 1; $i <= 5; $i++) {
				my $packaging_i = lang("packaging_part_short") . " " . $i . " - ";
				foreach
					my $property ("number_of_units", "shape", "material", "recycling", "weight", "quantity_per_unit")
				{
					my $name = $packaging_i . lang("packaging_" . $property);
					my $field = "packaging_${i}_${property}";
					# If producers send a weight, we assign it to the weight_specified field
					$field =~ s/_weight$/_weight_specified/g;
					push @{$select2_group_ref->{children}}, {id => "$field", text => ucfirst($name)};
				}
			}
		}
		# Other groups have fields listed directly in the $options{import_export_fields_groups} structure
		else {

			foreach my $field (@{$group_ref->[1]}) {
				my $name;
				if ($field eq "code") {
					$name = lang("barcode");
				}
				elsif ($field eq "lc") {
					$name = lang("lang");
				}
				elsif ($field =~ /_value_unit$/) {
					# Column can contain value + unit, value, or unit for a specific field
					my $field_name = $`;
					$name = lang($field_name);
				}
				elsif (defined $tags_fields{$field}) {
					my $tagtype = $field;
					$name = lang($tagtype . "_p");
				}
				else {
					$name = lang($field);
				}

				$log->debug("Select2 option", {group_id => $group_id, field => $field, name => $name})
					if $log->is_debug();

				if (($group_id eq "images") and ($field =~ /image_($valid_image_types_regexp)/)) {

					foreach my $l (@{$lcs_ref}) {
						my $language = "";    # Don't specify the language if there is just one
						if (@{$lcs_ref} > 1) {
							$language = " (" . display_taxonomy_tag($lc, 'languages', $language_codes{$l}) . ")";
						}
						$log->debug(
							"Select2 option - language field",
							{
								group_id => $group_id,
								field => $field,
								name => $name,
								lc => $lc,
								l => $l,
								language => $language
							}
						) if $log->is_debug();
						push @{$select2_group_ref->{children}},
							{id => $field . "_$l", text => ucfirst($name) . $language};
					}
				}
				else {
					push @{$select2_group_ref->{children}}, {id => $field, text => ucfirst($name)};
				}
			}
		}

		push @{$select2_options_ref}, $select2_group_ref;
	}

	return $select2_options_ref;
}

sub export_and_import_to_public_database ($args_ref) {

	my $started_t = time();
	my $export_id = $started_t;

	# sync CRM
	update_export_date($Org_id, $started_t);

	my $exports_ref = retrieve("$BASE_DIRS{EXPORT_FILES}/${Owner_id}/exports.sto");
	if (not defined $exports_ref) {
		$exports_ref = {};
	}

	my $exported_file = "$BASE_DIRS{EXPORT_FILES}/${Owner_id}/export.$export_id.exported.csv";

	$exports_ref->{$export_id} = {
		started_t => $started_t,
		exported_file => $exported_file,
	};

	# Set the user to the owner userid or org

	my $user_id = $User_id;
	if ($Owner_id =~ /^(user)-/) {
		$user_id = $';
	}
	elsif ($Owner_id =~ /^(org)-/) {
		$user_id = $Owner_id;
	}
	elsif ($Owner_id eq 'all') {
		$user_id = 'all';
	}

	# First export the data locally

	$args_ref->{user_id} = $user_id;
	$args_ref->{org_id} = $Org_id;
	$args_ref->{owner_id} = $Owner_id;
	$args_ref->{csv_file} = $exported_file;
	$args_ref->{export_id} = $export_id;
	$args_ref->{comment} = "Import from producers platform";
	$args_ref->{include_obsolete_products} = 1;
	$args_ref->{include_images_paths} = 1;    # Export file paths to images
	$args_ref->{exported_t} = $started_t;

	if (defined $Org_id) {

		$args_ref->{source_id} = "org-" . $Org_id;
		$args_ref->{source_name} = $Org_id;

		# We currently do not have organization profiles to differentiate producers, apps, labels databases, other databases
		# in the mean time, use a naming convention:  label-something, database-something and treat
		# everything else as a producers
		if ($Org_id =~ /^app-/) {
			$args_ref->{manufacturer} = 0;
			$args_ref->{global_values} = {data_sources => "Apps, " . $Org_id};
		}
		elsif ($Org_id =~ /^database-/) {
			$args_ref->{manufacturer} = 0;
			$args_ref->{global_values} = {data_sources => "Databases, " . $Org_id};
		}
		elsif ($Org_id =~ /^label-/) {
			$args_ref->{manufacturer} = 0;
			$args_ref->{global_values} = {data_sources => "Labels, " . $Org_id};
		}
		else {
			$args_ref->{manufacturer} = 1;
			$args_ref->{global_values} = {data_sources => "Producers, Producer - " . $Org_id};
		}
	}
	else {
		$args_ref->{no_source} = 1;
	}

	# Local export

	my $local_export_job_id
		= get_minion()->enqueue(export_csv_file => [$args_ref] => {queue => $server_options{minion_local_queue}});

	$args_ref->{export_job_id} = $local_export_job_id;

	# Remote import

	my $remote_import_job_id
		= get_minion()
		->enqueue(import_csv_file => [$args_ref] =>
			{queue => $server_options{minion_export_queue}, parents => [$local_export_job_id]});

	# Local export status update

	my $local_export_status_job_id
		= get_minion()
		->enqueue(update_export_status_for_csv_file => [$args_ref] =>
			{queue => $server_options{minion_local_queue}, parents => [$remote_import_job_id]});

	$exports_ref->{$export_id}{local_export_job_id} = $local_export_job_id;
	$exports_ref->{$export_id}{remote_import_job_id} = $remote_import_job_id;
	$exports_ref->{$export_id}{local_export_status_job_id} = $local_export_status_job_id;

	ensure_dir_created_or_die("$BASE_DIRS{EXPORT_FILES}/${Owner_id}");

	store("$BASE_DIRS{EXPORT_FILES}/${Owner_id}/exports.sto", $exports_ref);

	return {
		export_id => $export_id,
		exported_file => $exported_file,
		local_export_job_id => $local_export_job_id,
		remote_import_job_id => $remote_import_job_id,
		local_export_status_job_id => $local_export_status_job_id,
	};
}

=head2 $GOOGLE_DRIVE_IMPORT_MAX_IMAGES

Maximum number of images imported from a Google Drive folder at once. Images after this number
(in name order) are not imported.

=cut

$GOOGLE_DRIVE_IMPORT_MAX_IMAGES = 1000;

=head2 get_running_google_drive_photos_import_job_id ( $owner_id )

Return the id of a Google Drive photos import of the owner that is queued or running, or undef

=cut

sub get_running_google_drive_photos_import_job_id ($owner_id) {

	my $jobs
		= get_minion()->jobs({tasks => ['import_photos_from_google_drive_folder'], states => ['inactive', 'active']});

	while (my $info_ref = $jobs->next) {
		if (($info_ref->{args}[0]{owner_id} // '') eq ($owner_id // '')) {
			return $info_ref->{id};
		}
	}
	return;
}

=head2 start_google_drive_photos_import ( $args_ref )

Check the URL of a Google Drive folder, and queue a minion job to import its photos.

=head3 Arguments

A hash ref with folder_url, user_id, org_id, owner_id, lc, country, add_field_values (see import_product_image_file())

=head3 Return value

A hash ref with the job_id, or with an error id: google_drive_invalid_folder_url, google_drive_no_api_key
or google_drive_import_already_running (with the job_id of the running import)

=cut

sub start_google_drive_photos_import ($args_ref) {

	my ($folder_id, $resource_key) = parse_google_drive_folder_url($args_ref->{folder_url});

	if (not defined $folder_id) {
		return {error => "google_drive_invalid_folder_url"};
	}

	my $api_key = $ProductOpener::Config2::google_drive_api_key;
	if ((not defined $api_key) or ($api_key eq '')) {
		return {error => "google_drive_no_api_key"};
	}

	# One import at a time per owner: two imports would compete to add the same photos to the same products
	my $running_job_id = get_running_google_drive_photos_import_job_id($args_ref->{owner_id});
	if (defined $running_job_id) {
		return {error => "google_drive_import_already_running", job_id => $running_job_id};
	}

	my $job_args_ref = {%$args_ref, folder_id => $folder_id, resource_key => $resource_key};

	my $job_id
		= get_minion()
		->enqueue(
		import_photos_from_google_drive_folder => [$job_args_ref] => {queue => $server_options{minion_local_queue}});

	return {job_id => $job_id};
}

=head2 $GOOGLE_DRIVE_DOWNLOAD_RETRY_DELAY

Seconds to wait before retrying the download of an image after a temporary error (HTTP 429 or 5xx)

=cut

$GOOGLE_DRIVE_DOWNLOAD_RETRY_DELAY = 5;

# Download an image listed in a Google Drive folder to $file_path.
# Temporary errors (rate limiting, server errors) are retried once.
# Returns undef on success, or an error message

sub download_google_drive_image ($image_ref, $file_path) {

	my $url = get_google_drive_file_download_url($image_ref);

	# download_image() checks that the URL and the redirects it follows point to globally routable addresses
	my $response = download_image($url);

	if ((not $response->is_success) and (($response->code == 429) or ($response->code >= 500))) {
		$log->info("retrying Google Drive image download", {file => $image_ref->{path}, status => $response->code})
			if $log->is_info();
		sleep($GOOGLE_DRIVE_DOWNLOAD_RETRY_DELAY);
		$response = download_image($url);
	}

	if (not $response->is_success) {
		return "could not download the image: " . $response->status_line;
	}
	if (($response->header('Content-Type') // '') =~ m{^text/html}i) {
		return "could not download the image: Google Drive returned a web page";
	}

	my $out;
	if (not open($out, ">:raw", $file_path)) {
		$log->error("could not write the downloaded image", {file_path => $file_path, error => $!})
			if $log->is_error();
		return "could not save the image";
	}
	print $out $response->content;
	close($out);

	return;
}

# Return how the code of an image was found, from the response of import_product_image_file()
sub get_code_source ($file_ref) {
	return "file_name" if defined $file_ref->{code_from_file_name};
	return "scan" if defined $file_ref->{scanned_code};
	return "previous_photo" if defined $file_ref->{using_previous_code};
	return;
}

=head2 import_photos_from_google_drive_folder ( $args_ref, $progress_callback = undef )

Import all the photos of a public Google Drive folder (and of its subfolders) to the products of the owner.

The photos are processed in the order of their names, as they would be when uploaded on the import photos page:
a photo that does not have a barcode in its file name or in the image is assigned to the product of the previous photo.

=head3 Arguments

=head4 $args_ref

A hash ref with folder_id, resource_key, user_id, org_id, owner_id, lc, country and add_field_values

=head4 $progress_callback

Optional function called after each image with the results hash ref

=head3 Return value

A hash ref with:

=over

=item status - "done" or "error"

=item error, error_message - if the folder could not be listed

=item images_in_folder - number of images in the folder

=item skipped_files - number of files that are not images (e.g. videos)

=item max_images - set if the folder has more images than the number of images we import at once

=item total, processed - number of images to process, and processed

=item results - array of hashes with the file name (path), code, code_source (file_name, scan, previous_photo), product_url, thumbnail_url, error and info (e.g. image already uploaded)

=back

=cut

sub import_photos_from_google_drive_folder ($args_ref, $progress_callback = undef) {

	local $User_id = $args_ref->{user_id};
	local $Org_id = $args_ref->{org_id};
	local $Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});
	local $lc = $args_ref->{lc} // $lc;

	my $results_ref = {status => "listing", results => [], processed => 0};

	my $listing_ref = list_google_drive_folder_images($args_ref->{folder_id}, $args_ref->{resource_key});

	if (defined $listing_ref->{error}) {
		$results_ref->{status} = "error";
		$results_ref->{error} = $listing_ref->{error};
		$results_ref->{error_message} = $listing_ref->{error_message};
		return $results_ref;
	}

	my @images = @{$listing_ref->{images}};

	$results_ref->{images_in_folder} = scalar @images;
	$results_ref->{skipped_files} = $listing_ref->{skipped};

	if (scalar @images > $GOOGLE_DRIVE_IMPORT_MAX_IMAGES) {
		$results_ref->{max_images} = $GOOGLE_DRIVE_IMPORT_MAX_IMAGES;
		splice(@images, $GOOGLE_DRIVE_IMPORT_MAX_IMAGES);
	}

	$results_ref->{total} = scalar @images;
	$results_ref->{status} = "importing";
	defined $progress_callback and $progress_callback->($results_ref);

	ensure_dir_created_or_die($BASE_DIRS{PRODUCTS_IMAGES});
	ensure_dir_created_or_die($BASE_DIRS{CACHE_TMP});
	# Each import downloads to its own temporary directory, so that two imports never share a file
	my $tmp_dir = tempdir("google_drive_import_XXXXXXXX", DIR => $BASE_DIRS{CACHE_TMP}, CLEANUP => 1);

	my $previous_code;
	my $previous_imgid;
	my %field_values_added_for_codes = ();
	my $i = 0;

	foreach my $image_ref (@images) {

		$i++;
		my $result_ref = {file => $image_ref->{path}};

		# Keep the extension of the file name (e.g. .HEIC) so that the barcode is scanned
		my ($extension) = $image_ref->{name} =~ /\.(\w+)$/;
		my $file_path = "$tmp_dir/$i." . lc($extension // "jpg");

		my $download_error = download_google_drive_image($image_ref, $file_path);

		if (defined $download_error) {
			$result_ref->{error} = $download_error;
		}
		else {
			my $response_ref = eval {
				import_product_image_file(
					{
						user_id => $User_id,
						org_id => $Org_id,
						owner_id => $Owner_id,
						moderator => $args_ref->{moderator},
						lc => $lc,
						country => $args_ref->{country},
						filename => $image_ref->{name},
						file_path => $file_path,
						previous_code => $previous_code,
						previous_imgid => $previous_imgid,
						add_field_values => $args_ref->{add_field_values},
						field_values_added_for_codes => \%field_values_added_for_codes,
					}
				);
			};
			my $import_error = $@;

			unlink($file_path);

			if (not defined $response_ref) {
				# Details of the exception (with our file paths) are logged, not shown to the producer
				$log->error("could not import image from Google Drive",
					{file => $image_ref->{path}, error => $import_error})
					if $log->is_error();
				$result_ref->{error} = "could not process the image";
			}
			else {
				my $file_ref = $response_ref->{files}[0] // {};

				$result_ref->{code} = $file_ref->{code} // $response_ref->{code};
				$result_ref->{code_source} = get_code_source($file_ref);
				$result_ref->{product_url} = $file_ref->{url};
				$result_ref->{thumbnail_url} = $file_ref->{thumbnailUrl};
				if (defined $file_ref->{info}) {
					$result_ref->{info} = $file_ref->{info};
				}
				elsif (($response_ref->{status} // "") ne "status ok") {
					$result_ref->{error} = $file_ref->{error} // $response_ref->{error} // $response_ref->{status};
				}

				# Same as the import photos page: the code of the next photos is the last scanned code,
				# and the image id of the photo with the barcode is kept to select the next photo as the front image
				if (defined $file_ref->{scanned_code}) {
					$previous_code = $file_ref->{scanned_code};
					$previous_imgid = (defined $response_ref->{image}) ? $response_ref->{image}{imgid} : "";
				}
				else {
					$previous_imgid = "";
				}
			}
		}

		# If a photo could not be downloaded or processed, we do not know if it had a barcode:
		# the next photos without a barcode would be added to the wrong product, so we do not
		# add them to the previous product (they are reported as photos without a barcode)
		if ((defined $download_error) or (not defined $result_ref->{code})) {
			$previous_code = undef;
			$previous_imgid = undef;
		}

		$log->info("imported image from Google Drive", {i => $i, total => scalar @images, result => $result_ref})
			if $log->is_info();

		push @{$results_ref->{results}}, $result_ref;
		$results_ref->{processed} = $i;
		defined $progress_callback and $progress_callback->($results_ref);
	}

	$results_ref->{status} = "done";

	return $results_ref;
}

=head1 Minion tasks

Minion tasks that can be added to the queue by standalone scripts or the web site,
that are then executed by the minion-off and minion-off-pro daemons.

The daemons are configured in /etc/systemd/system

e.g. /etc/systemd/system/minion-off.service 

[Unit]
Description=off minion workers
After=postgresql.service

[Service]
Type=simple
User=off
WorkingDirectory=/srv/off/scripts
Environment="PERL5LIB=/srv/off/lib/"
ExecStart=/srv/off/scripts/minion_producers.pl minion worker -m production -q openfoodfacts.org
KillMode=process

[Install]
WantedBy=multi-user.target

=cut

sub import_csv_file_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	write_minion_log("import_csv_file_task - job: $job_id started - args: " . encode_json($args_ref));

	ProductOpener::Import::import_csv_file($args_ref);

	write_minion_log("import_csv_file_task - job: $job_id done");
	$job->finish("done");

	return;
}

sub import_photos_from_google_drive_folder_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	write_minion_log("import_photos_from_google_drive_folder_task - job: $job_id started - folder: "
			. $args_ref->{folder_id}
			. " - owner: "
			. ($args_ref->{owner_id} // ''));

	my $results_ref = import_photos_from_google_drive_folder(
		$args_ref,
		sub ($progress_ref) {
			# The import photos page displays the progress and the results stored in the notes of the job
			$job->note(import => $progress_ref);
		}
	);

	write_minion_log("import_photos_from_google_drive_folder_task - job: $job_id done - status: "
			. $results_ref->{status}
			. " - processed: "
			. $results_ref->{processed});

	$job->note(import => $results_ref);
	$job->finish($results_ref);

	return;
}

sub export_csv_file_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	write_minion_log("export_csv_file_task - job: $job_id started - args: " . encode_json($args_ref));

	my $filehandle;
	open($filehandle, ">:encoding(UTF-8)", $args_ref->{csv_file})
		or die("Could not write " . $args_ref->{csv_file} . " : $!\n");

	$args_ref->{filehandle} = $filehandle;

	ProductOpener::Export::export_csv($args_ref);

	close($filehandle);

	write_minion_log("export_csv_file_task - job: $job_id done");

	$job->finish("done");

	return;
}

sub import_products_categories_from_public_database_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	write_minion_log("import_products_categories_from_public_database_file_task - job: $job_id started - args: "
			. encode_json($args_ref));

	ProductOpener::Import::import_products_categories_from_public_database($args_ref);

	write_minion_log("import_products_categories_from_public_database_file_task - job: $job_id done");

	$job->finish("done");

	return;
}

sub update_export_status_for_csv_file_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	write_minion_log("update_export_status_for_csv_file_task - job: $job_id started - args: " . encode_json($args_ref));

	ProductOpener::Import::update_export_status_for_csv_file($args_ref);

	write_minion_log("update_export_status_file_task - job: $job_id done");

	$job->finish("done");

	return;
}

1;
