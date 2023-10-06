# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

		&import_csv_file_task
		&export_csv_file_task
		&update_export_status_for_csv_file_task
		&import_products_categories_from_public_database_task

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Import qw/:all/;
use ProductOpener::ImportConvert qw/:all/;
use ProductOpener::Users qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV();
use Minion;

# Minion backend
my $minion;

=head2 get_minion()
Function to get the backend minion

=head3 Arguments
None

=head3 Return values
The backend minion $minion

=cut

sub get_minion() {
	if (not defined $minion) {
		if (not defined $server_options{minion_backend}) {
			print STDERR "No Minion backend configured in lib/ProductOpener/Config2.pm\n";
		}
		else {
			print STDERR "Initializing Minion backend configured in lib/ProductOpener/Config2.pm\n";
			$minion = Minion->new(%{$server_options{minion_backend}});
		}
	}
	return $minion;
}

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
			if ($non_empty_values >= 2) {
				push @original_rows, $row_ref;

				for (my $i = 0; $i < scalar(@$row_ref); $i++) {
					if ((defined $row_ref->[$i]) and ($row_ref->[$i] ne "")) {
						$non_empty_columns[$i] = 1;
					}
				}
			}
		}

		$log->debug("non empty columns",
			{number_of_original_rows => scalar(@original_rows), non_empty_columns => \@non_empty_columns})
			if $log->is_debug();

		# Copy non empty columns and rows

		my $seen_header = 0;

		foreach my $row_ref (@original_rows) {
			my @new_row = ();
			for (my $i = 0; $i < scalar(@$row_ref); $i++) {
				if ($non_empty_columns[$i]) {
					push @new_row, $row_ref->[$i];
				}
			}

			$log->debug("new_row", {new_row => \@new_row}) if $log->is_debug();

			# Is it a header? (column 1 or 2 should not be empty)
			if (not $seen_header) {

				if ((defined $new_row[0]) and ($new_row[0] ne "") and (defined $new_row[1]) and ($new_row[1] ne "")) {
					$seen_header = 1;
					@{$input_headers_ref} = @new_row;

					$log->debug("seen header", {input_headers_ref => $input_headers_ref}) if $log->is_debug();
				}

				# Otherwise skip the line until we see a header
			}
			else {
				# Skip empty lines or lines without a barcode (at least 8 digits)
				my $line = join(",", @new_row);
				# some barcodes may have spaces or dots (e.g. 3 770 0131 300 38)
				$line =~ s/ |_|-|\.//g;
				if ($line !~ /[0-9]{8}/) {
					$log->debug("skipping row without barcode", {new_row => \@new_row, line => $line})
						if $log->is_debug();
				}
				else {
					push @{$rows_ref}, \@new_row;
				}
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
	my %product_lines = {};

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

			# If the field is of the form packaging_1_*
			# and we have multiple lines per product,
			# we rename the field to packaging_[current number of lines of the product]_*

			if (($product_lines{$code} > 1) and ($field =~ /^packaging_1_/)) {
				$field = "packaging_" . $product_lines{$code} . "_" . $';

				# Add the field to the list of columns in the output file
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

=head3 Arguments

=head4 $l - required

Language code (string)

=head3 Return value

Reference to the column names hash.

=cut

sub init_fields_columns_names_for_lang ($l) {

	if (defined $fields_columns_names_for_lang{$l}) {
		return;
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

	ensure_dir_created($BASE_DIRS{CACHE_DEBUG});

	store("$BASE_DIRS{CACHE_DEBUG}/fields_columns_names_$l.sto", $fields_columns_names_for_lang{$l});

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

# Create column names for all nutrients in a specific language
# It populates %fields_columns_names_for_lang

sub init_nutrients_columns_names_for_lang ($l) {

	$nutriment_table = $cc_nutriment_table{default};

	# Go through all the nutrients in the nutrients taxonomy
	foreach my $nutrient_tagid (sort(get_all_taxonomy_entries("nutrients"))) {

		my $nid = $nutrient_tagid;
		$nid =~ s/^zz://g;

		my @synonyms = get_taxonomy_tag_synonyms($l, "nutrients", $nutrient_tagid);

		# Synonyms for each nutrient

		foreach my $synonym (@synonyms) {

			$synonym = normalize_column_name($synonym);

			# Product as sold / unprepared or prepared
			# "" is unprepared

			foreach my $prepared ("", "_prepared") {

				# Synonyms for unprepared and prepared

				if (not defined $prepared_synonyms{$prepared}{$l}) {
					# We need at least an empty entry for the unprepared ""
					if ($prepared eq "") {
						$prepared_synonyms{$prepared}{$l} = [""];
					}
					else {
						$prepared_synonyms{$prepared}{$l} = [];
					}
				}

				foreach my $prepared_synonym (@{$prepared_synonyms{$prepared}{$l}}) {

					# Nutrients per 100g and per serving

					foreach my $per ("100g", "serving") {

						# Synonyms of per 100g and per serving

						if (not defined $per_synonyms{$per}{$l}) {
							# Use the English synonyms if we don't have language specific strings
							$per_synonyms{$per}{$l} = $per_synonyms{$per}{"en"};
						}

						foreach my $per_synonym (
							@{$per_synonyms{$per}{$l}},
							$Lang{"nutrition_data_per_" . $per}{$l},
							"nutrition_data_per_" . $per
							)
						{

							if ($per_synonym =~ /^nutrition_data_per/) {
								# per 100 g / 100 ml -> per 100g
								$per_synonym = $Lang{"nutrition_data_per_" . $per}{$l};
								# remove the 100ml from "per 100g / 100ml";
								$per_synonym =~ s/100 g/100g/i;
								$per_synonym =~ s/100 ml/100ml/i;
								$per_synonym =~ s/100ml//i;
							}

							# field name without "unit" or "quantity"
							$fields_columns_names_for_lang{$l}{
								get_string_id_for_lang("no_language",
									$synonym . " " . $prepared_synonym . " " . $per_synonym)
							} = {field => $nid . $prepared . "_" . $per . "_value_unit",};
							if ($nid eq "energy-kcal") {
								$fields_columns_names_for_lang{$l}{
									get_string_id_for_lang("no_language",
										$synonym . " " . $prepared_synonym . " " . $per_synonym)
								}{value_unit} = "value_in_kcal";
							}
							elsif ($nid eq "energy-kj") {
								$fields_columns_names_for_lang{$l}{
									get_string_id_for_lang("no_language",
										$synonym . " " . $prepared_synonym . " " . $per_synonym)
								}{value_unit} = "value_in_kj";
							}

							# field name with "quantity" or "unit" at beginning or end

							$fields_columns_names_for_lang{$l}{
								get_string_id_for_lang("no_language",
									$synonym . " " . $prepared_synonym . " " . $per_synonym . " " . $Lang{value}{$l})
								}
								= {
								field => $nid . $prepared . "_" . $per . "_value_unit",
								value_unit => "value",
								};

							$fields_columns_names_for_lang{$l}{
								get_string_id_for_lang("no_language",
									$Lang{value}{$l} . " " . $synonym . " " . $prepared_synonym . " " . $per_synonym)
								}
								= {
								field => $nid . $prepared . "_" . $per . "_value_unit",
								value_unit => "value",
								};

							$fields_columns_names_for_lang{$l}{
								get_string_id_for_lang("no_language",
									$synonym . " " . $prepared_synonym . " " . $per_synonym . " " . $Lang{unit}{$l})
								}
								= {
								field => $nid . $prepared . "_" . $per . "_value_unit",
								value_unit => "unit",
								};

							$fields_columns_names_for_lang{$l}{
								get_string_id_for_lang("no_language",
									$Lang{unit}{$l} . " " . $synonym . " " . $prepared_synonym . " " . $per_synonym)
								}
								= {
								field => $nid . $prepared . "_" . $per . "_value_unit",
								value_unit => "unit",
								};
						}
					}

					# Field names with actual units. e.g. Energy kcal, carbohydrates g, calcium mg

					my @units = keys %units_synonyms;

					# For energy kj/kcal, remove the unit from the synonym as we will add units to the synonyms
					my $synonym2 = $synonym;

					if ($nid eq "energy-kcal") {
						@units = qw(kcal cal calories);
						$synonym2 =~ s/kcal//;
					}
					elsif ($nid eq "energy-kj") {
						@units = qw(kj);
						$synonym2 =~ s/kj//;
					}
					elsif ($nid =~ /^energy/) {
						# Give priority to energy-kj and energy-kcal
						@units = ();
					}

					foreach my $unit (@units) {
						$fields_columns_names_for_lang{$l}
							{get_string_id_for_lang("no_language", $synonym2 . " " . $prepared_synonym . " " . $unit)}
							= {
							field => $nid . $prepared . "_100g_value_unit",
							value_unit => "value_in_" . $units_synonyms{$unit},
							};

						foreach my $per ("100g", "serving") {
							if (defined $per_synonyms{$per}{$l}) {
								foreach my $per_synonym (@{$per_synonyms{$per}{$l}}) {
									$fields_columns_names_for_lang{$l}{
										get_string_id_for_lang("no_language",
											$synonym2 . " " . $prepared_synonym . " " . $unit . " " . $per_synonym)
										}
										= {
										field => $nid . $prepared . "_" . $per . "_value_unit",
										value_unit => "value_in_" . $units_synonyms{$unit},
										};
									$fields_columns_names_for_lang{$l}{
										get_string_id_for_lang("no_language",
											$synonym2 . " " . $prepared_synonym . " " . $per_synonym . " " . $unit)
										}
										= {
										field => $nid . $prepared . "_" . $per . "_value_unit",
										value_unit => "value_in_" . $units_synonyms{$unit},
										};
									if (defined $in{$l}) {
										$fields_columns_names_for_lang{$l}{
											get_string_id_for_lang("no_language",
													  $synonym2 . " "
													. $prepared_synonym . " "
													. $in{$l} . " "
													. $unit . " "
													. $per_synonym)
											}
											= {
											field => $nid . $prepared . "_" . $per . "_value_unit",
											value_unit => "value_in_" . $units_synonyms{$unit},
											};
										$fields_columns_names_for_lang{$l}{
											get_string_id_for_lang("no_language",
													  $synonym2 . " "
													. $prepared_synonym . " "
													. $per_synonym . " "
													. $in{$l} . " "
													. $unit)
											}
											= {
											field => $nid . $prepared . "_" . $per . "_value_unit",
											value_unit => "value_in_" . $units_synonyms{$unit},
											};
									}
								}
							}
						}
					}
				}
			}
		}
	}

	return;
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
					if ($field =~ /image_(front|ingredients|nutrition|packaging)/) {
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

	my $results_ref = {};

	if (defined $fields_columns_names_for_lang{$l}{$column_id}) {
		$results_ref = $fields_columns_names_for_lang{$l}{$column_id};
	}
	elsif (defined $fields_columns_names_for_lang{en}{$column_id}) {
		$results_ref = $fields_columns_names_for_lang{en}{$column_id};
	}
	# Try removing ending numbers (e.g. for columns like image_other_url_2)
	elsif ($column_id =~ /-(\d+)$/) {
		$column_id = $`;
		if (defined $fields_columns_names_for_lang{$l}{$column_id}) {
			$results_ref = $fields_columns_names_for_lang{$l}{$column_id};
		}
		elsif (defined $fields_columns_names_for_lang{en}{$column_id}) {
			$results_ref = $fields_columns_names_for_lang{en}{$column_id};
		}
	}
	# try to see if there is a trailing language code
	# e.g. ingredients-text-fr
	elsif ($column_id =~ /-([a-z]{2})$/) {
		$column_id = $`;
		my $field_lc = $1;
		if (defined $fields_columns_names_for_lang{$l}{$column_id}) {
			$results_ref = dclone($fields_columns_names_for_lang{$l}{$column_id});
			$results_ref->{lc} = $field_lc;
		}
		elsif (defined $fields_columns_names_for_lang{en}{$column_id}) {
			$results_ref = dclone($fields_columns_names_for_lang{en}{$column_id});
			$results_ref->{lc} = $field_lc;
		}
	}

	return $results_ref;
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
				{lc => $lc, column => $column, column_id => $column_id, column_field => $columns_fields_ref->{$column}}
			) if $log->is_debug();

			$columns_fields_ref->{$column}
				= {%{$columns_fields_ref->{$column}}, %{match_column_name_to_field($lc, $column_id)}};
			$columns_fields_ref->{$column}{column_id} = $column_id;

			$log->debug(
				"after match_column_name_to_field",
				{lc => $lc, column => $column, column_id => $column_id, column_field => $columns_fields_ref->{$column}}
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
							=~ /^(fat|saturated-fat|carbohydrates|sugars|proteins|salt|fiber|fruits-vegetables-nuts)_100g_value_unit$/
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

			# Go through the nutriment table
			foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}) {

				next if $nutriment =~ /^\#/;
				my $nid = $nutriment;

				# %Food::nutriments_tables ids have an ending - for nutrients that are not displayed by default
				# Keep the % of fruits/vegetables/nuts in the main nutrition group

				if (    ($nid =~ /-$/)
					and ($nid ne 'fruits-vegetables-nuts-')
					and ($nid ne 'fruits-vegetables-nuts-dried-'))
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
					text => ucfirst($name) . " - " . lang("prepared_product") . " " . lang("nutrition_data_per_100g")
					};
				push @{$select2_group_ref->{children}},
					{
					id => $nid . "_prepared_serving_value_unit",
					text => ucfirst($name) . " - " . lang("prepared_product") . " " . lang("nutrition_data_per_serving")
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

				if (($group_id eq "images") and ($field =~ /image_(front|ingredients|nutrition|packaging)/)) {

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

	open(my $log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $log "import_csv_file_task - job: $job_id started - args: " . encode_json($args_ref) . "\n";
	close($log);

	print STDERR "import_csv_file_task - job: $job_id started - args: " . encode_json($args_ref) . "\n";

	print STDERR "import_csv_file_task - job: $job_id - running import_csv_file\n";

	ProductOpener::Import::import_csv_file($args_ref);

	$job->finish("done");

	return;
}

sub export_csv_file_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	open(my $minion_log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $minion_log "export_csv_file_task - job: $job_id started - args: " . encode_json($args_ref) . "\n";
	close($minion_log);

	print STDERR "export_csv_file_task - job: $job_id started - args: " . encode_json($args_ref) . "\n";

	print STDERR "export_csv_file_task - job: $job_id - running export_csv_file\n";

	my $filehandle;
	open($filehandle, ">:encoding(UTF-8)", $args_ref->{csv_file})
		or die("Could not write " . $args_ref->{csv_file} . " : $!\n");

	$args_ref->{filehandle} = $filehandle;

	ProductOpener::Export::export_csv($args_ref);

	close($filehandle);

	print STDERR "export_csv_file_task - job: $job_id - done\n";

	open(my $log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $log "export_csv_file_task - job: $job_id done\n";
	close($log);

	$job->finish("done");

	return;
}

sub import_products_categories_from_public_database_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	open(my $minion_log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $minion_log "import_products_categories_from_public_database_file_task - job: $job_id started - args: "
		. encode_json($args_ref) . "\n";
	close($minion_log);

	print STDERR "import_products_categories_from_public_database_file_task - job: $job_id started - args: "
		. encode_json($args_ref) . "\n";

	ProductOpener::Import::import_products_categories_from_public_database($args_ref);

	print STDERR "import_products_categories_from_public_database_file_task - job: $job_id - done\n";

	open(my $log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $log "import_products_categories_from_public_database_file_task - job: $job_id done\n";
	close($log);

	$job->finish("done");

	return;
}

sub update_export_status_for_csv_file_task ($job, $args_ref) {

	return if not defined $job;

	my $job_id = $job->{id};

	open(my $minion_log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $minion_log "update_export_status_for_csv_file_task - job: $job_id started - args: "
		. encode_json($args_ref) . "\n";
	close($minion_log);

	print STDERR "update_export_status_for_csv_file_task - job: $job_id started - args: "
		. encode_json($args_ref) . "\n";

	ProductOpener::Import::update_export_status_for_csv_file($args_ref);

	print STDERR "update_export_status_for_csv_file_task - job: $job_id - done\n";

	open(my $log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $log "update_export_status_file_task - job: $job_id done\n";
	close($log);

	$job->finish("done");

	return;
}

sub queue_job {    ## no critic (Subroutines::RequireArgUnpacking)
	return get_minion()->enqueue(@_);
}

1;
