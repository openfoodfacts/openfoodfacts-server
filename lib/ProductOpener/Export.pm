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

ProductOpener::Export - export products data in CSV format

=head1 SYNOPSIS

C<ProductOpener::Export> is used to export the data of all populated fields
of products matching a given MongoDB search query in Open Food Facts CSV format
(UTF-8 encoding, tab separated).

    use ProductOpener::Export qw/:all/;
	export_csv( { filehandle=>*STDOUT,
		query=>{ countries_tags=>"en:france", labels_tags=>"en:organic" } });

Only columns that are not completely empty will be included in the resulting CSV file.
This is to avoid generating CSV files with thousands of empty columns (e.g. all possible
nutrients and all the language specific fields like ingredients_text_[language code] for
all the hundreds of possible languages.

Fields that are computed from other fields are not directly provided by users or producers
are not exported by default. They can be exported by passing a list of extra fields:

	export_csv( { filehandle=>$fh,
		extra_fields=>[qw(nova_group nutrition_grade_fr)] });

It is also possible to restrict the set of fields to be exported:

	export_csv( { filehandle=>$fh,
		fields=>[qw(code ingredients_text_en additives_tags)] });

This module is used in particular to export product data provided by manufacturers on
the producers platform so that it can then be imported in the public database.

In the producers platform, the C<export_csv> function is executed through a Minion worker.

It is also used in the C<scripts/export_csv_file.pl> script.


=head1 DESCRIPTION

Use the list of fields from C<Product::Opener::Config::options{import_export_fields_groups}>
and the list of nutrients from C<Product::Opener::Food::nutriments_tables> to list fields
that need to be exported.

The results of the query are scanned a first time to compute the list of non-empty columns.

The results of the query are scanned a second time to output the CSV file.

This 2 phases approach is done to avoid having to store all the products data in memory.

If the fields to exports are specified with the C<fields> parameter, the first phase is skipped.

=cut

package ProductOpener::Export;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&export_csv

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Ecoscore qw/localize_ecoscore/;

use Text::CSV;
use Excel::Writer::XLSX;
use Data::DeepAccess qw(deep_get deep_exists);
use Apache2::RequestRec;

=head1 FUNCTIONS

=head2 export_csv( FILEHANDLE, QUERY[, OPTIONS ] )

C<export_csv()> outputs data in CSV format for products matching a query.

Only non empty columns are included. By default, fields that are computed from other fields
are not included, but extra fields can be exported using the third OPTIONS argument.

=head3 Arguments

Arguments are passed through a single hash reference with the following keys:

=head4 filehandle - required - File handle where the CSV data will be output

The file handle can be to a file on disk, to STDOUT etc.

=head4 query - optional - MongoDB Query

Hash ref that specifies the query that will be passed to MongoDB.
Each key value pair will be used to filter products with matching field values.

   export_csv( { filehandle=>$fh,
	query => { categories_tags => "en:beers", ingredients_tags => "en:wheat" }});

=head4 extra_fields - optional - Extra fields to export

Array ref that specifies a list of additional fields to export, including fields
that are computed from other fields such as the NOVA group or the Nutri-Score nutritional grade.

Columns for the extra fields will be added after the columns for the populated fields
from user and producers.

	export_csv({ filehandle=>$fh,
		extra_fields => [qw(nova_group nutrition_grade_fr)] });

=head4 fields - optional - Restrict the fields to export

Array ref that specifies the exact list of fields to export. Only the specified
fields will be exported.

	export_csv({ filehandle=>$fh,
		fields => [qw(code ingredients_text_en additives_tags)] });


=head4 include_images_paths - optional - Export local file paths to images

If defined and not null, specifies to export local file paths for selected images
for front, ingredients and nutrition in all languages.

This option is used in particular for exporting from the producers platform
and importing to the public database.

=head4 include_obsolete_products - optional - Also export obsolete products

Obsolete products are in the products_obsolete collection.

=head4 Return value

Count of the exported documents.

Note: if the max_count parameter is passed

=cut

sub export_csv ($args_ref) {

	my $filehandle = $args_ref->{filehandle};
	my $filename = $args_ref->{filename};
	my $send_http_headers
		= $args_ref->{send_http_headers};    # Used for downloads of CSV / Excel results on the OFF website
	my $format = $args_ref->{format} || "csv";
	my $separator = $args_ref->{separator} || "\t";
	my $query_ref = $args_ref->{query};
	my $fields_ref = $args_ref->{fields};
	my $extra_fields_ref = $args_ref->{extra_fields};
	my $export_computed_fields
		= $args_ref->{export_computed_fields};    # Fields like the Nutri-Score score computed by OFF
	my $export_canonicalized_tags_fields
		= $args_ref->{export_canonicalized_tags_fields};    # e.g. include "categories_tags" and not only "categories"
	my $export_cc = $args_ref->{cc} || "world";    # used to localize Eco-Score fields

	$log->debug("export_csv - start", {args_ref => $args_ref}) if $log->is_debug();

	# We have products in 2 MongoDB collections:
	# - products: current products
	# - products_obsolete: obsolete products (withdrawn from the market)

	my @collections = ("products");    # products collection
	if ($args_ref->{include_obsolete_products}) {
		push @collections, "products_obsolete";
	}

	# Create a list of the fields that we will export
	my @sorted_populated_fields;

	my %other_images = ();

	# We will have one cursor for each collection
	# We store cursors because we will iterate them twice
	# (or only once if the fields to export are specified)
	my %cursors = ();

	foreach my $collection (@collections) {

		my $obsolete = ($collection eq "products_obsolete") ? 1 : 0;

		my $count = get_products_collection({obsolete => $obsolete})->count_documents($query_ref);

		$log->debug("export_csv - documents to export", {count => $count, collection => $collection})
		if $log->is_debug();

		$cursors{$collection} = get_products_collection({obsolete => $obsolete})->find($query_ref);
		$cursors{$collection}->immortal(1);
	}

	# First pass to determine which fields should be exported
	
	if (defined $fields_ref) {
		# The fields to export are specified by the fields parameter
		@sorted_populated_fields = @{$fields_ref};
	}
	else {

		# First pass - go through products to see which fields are populated,
		# unless the fields to export are specified with the fields parameter.
		# %populated_fields will contain the field name as the key,
		# and a sort key as the value so that the CSV columns are in the order of $options{import_export_fields_groups}
		my %populated_fields = ();

		# Loop on collections
		foreach my $collection (@collections) {

			while (my $product_ref = $cursors{$collection}->next) {

				# Possible fields to export are listed in $options{import_export_fields_groups}

				my @fields_groups = @{$options{import_export_fields_groups}};

				# Add fields computed by OFF if requested
				if (($export_computed_fields) and (defined $options{off_export_fields_groups})) {
					push @fields_groups, @{$options{off_export_fields_groups}};
				}

				my $group_number = 0;

				foreach my $group_ref (@fields_groups) {

					$group_number++;
					my $item_number = 0;

					my $group_id = $group_ref->[0];

					if (($group_id eq "nutrition") or ($group_id eq "nutrition_other")) {

						if ($group_id eq "nutrition") {
							foreach my $field ("no_nutrition_data", "nutrition_data_per", "nutrition_data_prepared_per")
							{
								$item_number++;
								if ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "")) {
									$populated_fields{$field} = sprintf("%08d", $group_number * 1000 + $item_number);
								}
							}
						}

						next if not defined $product_ref->{nutriments};

						# Go through the nutriment table
						foreach my $nutriment (@{$nutriments_tables{europe}}) {

							next if $nutriment =~ /^\#/;
							my $nid = $nutriment;

							# %Food::nutriments_tables ids have an ending - for nutrients that are not displayed by default

							if ($group_id eq "nutrition") {
								if ($nid =~ /-$/) {
									next;
								}
							}
							else {
								if ($nid !~ /-$/) {
									next;
								}
							}

							$item_number++;
							my $field_sort_key = sprintf("%08d", $group_number * 1000 + $item_number);

							$nid =~ s/^(-|!)+//g;
							$nid =~ s/-$//g;

							# Order of the fields: sugars_value, sugars_unit, sugars_prepared_value, sugars_prepared_unit

							if (    (defined $product_ref->{nutriments}{$nid . "_value"})
								and ($product_ref->{nutriments}{$nid . "_value"} ne ""))
							{
								$populated_fields{$nid . "_value"} = $field_sort_key . "_1";
								$populated_fields{$nid . "_unit"} = $field_sort_key . "_2";
							}
							if (    (defined $product_ref->{nutriments}{$nid . "_prepared_value"})
								and ($product_ref->{nutriments}{$nid . "_prepared_value"} ne ""))
							{
								$populated_fields{$nid . "_prepared_value"} = $field_sort_key . "_3";
								$populated_fields{$nid . "_prepared_unit"} = $field_sort_key . "_4";
							}
						}
					}
					elsif ($group_id eq "packaging") {
						# packaging data will be exported in the CSV file in columns named like packaging_1_number_of_units
						if (defined $product_ref->{packagings}) {
							my $i = 0;    # number of the packaging component
							foreach my $packaging_ref (@{$product_ref->{packagings}}) {
								$i++;
								my $j = 0;    # number of the field
								foreach my $field (
									qw(number_of_units shape material recycling quantity_per_unit weight_specified weight_measured)
									)
								{
									$j++;
									if (defined $packaging_ref->{$field}) {
										# Generate a sort key so that the packaging fields in the CSV file are in this order:
										# - all fields for packaging component 1, then all fields for packaging component 2
										# - number_of_units, shape, material etc. (same a for loop above)
										my $field_sort_key = sprintf("%08d", $group_number * 1000 + $i * 10 + $j);
										$populated_fields{"packaging_" . $i . "_" . $field} = $field_sort_key;
									}
								}
							}
						}
					}
					elsif ($group_id eq "images") {
						if ($args_ref->{include_images_paths}) {
							if (defined $product_ref->{images}) {
								include_image_paths($product_ref, \%populated_fields, \%other_images);
							}
						}
					}
					else {

						foreach my $field (@{$group_ref->[1]}) {

							# Prefix fields that are not primary data, but that are computed by OFF, with the "off:" prefix
							my $group_prefix = "";
							if ($group_id eq "off") {
								$group_prefix = "off:";
							}

							$item_number++;
							my $field_sort_key = sprintf("%08d", $group_number * 1000 + $item_number);

							if ($field =~ /_value_unit$/) {
								# Column can contain value + unit, value, or unit for a specific field
								$field = $`;
							}

							if (defined $tags_fields{$field}) {
								if (    (defined $product_ref->{$field . "_tags"})
									and (scalar @{$product_ref->{$field . "_tags"}} > 0))
								{
									# Export the tags field in the main language of the product
									$populated_fields{$group_prefix . $field} = $field_sort_key;
									# Also possibly export the canonicalized tags
									if ($export_canonicalized_tags_fields) {
										$populated_fields{$group_prefix . $field . "_tags"} = $field_sort_key . "_tags";
									}
								}
							}
							elsif (defined $language_fields{$field}) {
								if (defined $product_ref->{languages_codes}) {
									foreach my $l (keys %{$product_ref->{languages_codes}}) {
										if (    (defined $product_ref->{$field . "_$l"})
											and ($product_ref->{$field . "_$l"} ne ""))
										{
											# Add language code to sort key
											$populated_fields{$group_prefix . $field . "_$l"} = $field_sort_key . "_$l";
										}
									}
								}
							}
							else {
								my $key = $field;
								# Special case for ecoscore_data.adjustments.origins_of_ingredients.value
								# which is only present if the Eco-Score fields have been localized (done only once after)
								# we check for .values (with an s) instead
								if ($field eq "ecoscore_data.adjustments.origins_of_ingredients.value") {
									$key = $key . "s";
								}
								# Allow returning fields that are not at the root of the product structure
								# e.g. ecoscore_data.agribalyse.score  -> $product_ref->{ecoscore_data}{agribalyse}{score}
								if (deep_exists($product_ref, split(/\./, $key))) {
									$populated_fields{$group_prefix . $field} = $field_sort_key;
								}
							}
						}
					}
				}

				# Source specific fields in the sources_fields hash
				if (defined $product_ref->{sources_fields}) {
					foreach my $source_id (sort keys %{$product_ref->{sources_fields}}) {
						foreach my $field (sort keys %{$product_ref->{sources_fields}{$source_id}}) {
							$populated_fields{"sources_fields:${source_id}:$field"}
								= sprintf("%08d", 10 * 1000) . "_${source_id}:$field";
						}
					}
				}
			}
		}

		@sorted_populated_fields = sort ({$populated_fields{$a} cmp $populated_fields{$b}} keys %populated_fields);

		push @sorted_populated_fields, "data_sources";

		if (not defined $populated_fields{"obsolete"}) {
			# Always output the "obsolete" field so that obsolete products can be unobsoleted
			push @sorted_populated_fields, "obsolete";
		}
	}

	# Extra fields such as Nova or Nutri-Score that do not originate from users or producers but are computed
	if (defined $extra_fields_ref) {
		@sorted_populated_fields = (@sorted_populated_fields, @{$extra_fields_ref});
	}

	if ($args_ref->{export_owner}) {
		push @sorted_populated_fields, "owner";
	}

	# Second pass - output CSV data

	# Initialize the XLSX or CSV modules, optionally send HTTP headers (if called from the website)
	# and output the header row
	my $csv;
	my $workbook;
	my $worksheet;

	if ($format eq "xlsx") {

		# Send HTTP headers, unless search_and_export_products() is called from a script
		if ($send_http_headers) {
			my $r = Apache2::RequestUtil->request();
			$r->headers_out->set("Content-type" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
			$r->headers_out->set("Content-disposition" => "attachment;filename=$filename");
			print "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n";

			binmode($filehandle);
		}

		$workbook = Excel::Writer::XLSX->new($filehandle);
		$worksheet = $workbook->add_worksheet();
		my $workbook_format = $workbook->add_format();
		$workbook_format->set_bold();
		$worksheet->write_row(0, 0, \@sorted_populated_fields, $workbook_format);

		# Set the width of the columns
		for (my $i = 0; $i <= $#sorted_populated_fields; $i++) {
			my $width = length($sorted_populated_fields[$i]);
			($width < 20) and $width = 20;
			$worksheet->set_column($i, $i, $width);
		}
	}
	else {

		if ($send_http_headers) {
			require Apache2::RequestRec;
			my $r = Apache2::RequestUtil->request();
			$r->headers_out->set("Content-type" => "text/csv; charset=UTF-8");
			$r->headers_out->set("Content-disposition" => "attachment;filename=$filename");
			print "Content-Type: text/csv; charset=UTF-8\r\n\r\n";

			binmode($filehandle, ":encoding(UTF-8)");
		}

		$csv = Text::CSV->new(
			{
				eol => "\n",
				sep => $separator,
				quote_space => 0,
				binary => 1
			}
		) or die "Cannot use CSV: " . Text::CSV->error_diag();

		# Print the header line with fields names
		$csv->print($filehandle, \@sorted_populated_fields);
	}

	my $j = 0;    # Row number

	# Go through the products and products_obsolete collections again

	foreach my $collection (@collections) {

		$cursors{$collection}->reset();

		while (my $product_ref = $cursors{$collection}->next) {

			$j++;
			my @values = ();

			my $added_images_urls = 0;
			my $product_path = product_path($product_ref);

			my $scans_ref;

			# If an ecoscore_* field is requested, we will localize all the Eco-Score fields once
			my $ecoscore_localized = 0;

			foreach my $field (@sorted_populated_fields) {

				my $nutriment_field = 0;

				my $value;

				# Remove the off: prefix for fields computed by OFF, as we don't have the prefix in the product structure
				$field =~ s/^off://;

				# Localize the Eco-Score fields that depend on the country of the request
				if (($field =~ /^ecoscore/) and (not $ecoscore_localized)) {
					localize_ecoscore($export_cc, $product_ref);
					$ecoscore_localized = 1;
				}

				# Scans must be loaded separately
				if ($field =~ /^scans_(\d\d\d\d)_(.*)_(\w+)$/) {

					my ($scan_year, $scan_field, $scan_cc) = ($1, $2, $3);

					if (not defined $scans_ref) {
						# Load the scan data
						$scans_ref = retrieve_json("$BASE_DIRS{PRODUCTS}/$product_path/scans.json");
					}
					if (not defined $scans_ref) {
						$scans_ref = {};
					}
					if (    (defined $scans_ref->{$scan_year})
						and (defined $scans_ref->{$scan_year}{$scan_field})
						and (defined $scans_ref->{$scan_year}{$scan_field}{$scan_cc}))
					{
						$value = $scans_ref->{$scan_year}{$scan_field}{$scan_cc};
					}
					else {
						$value = "";
					}
				}
				# Source specific fields
				elsif ($field =~ /^sources_fields:([a-z0-9-]+):/) {
					my $source_id = $1;
					my $source_field = $';
					if (    (defined $product_ref->{sources_fields})
						and (defined $product_ref->{sources_fields}{$source_id})
						and (defined $product_ref->{sources_fields}{$source_id}{$source_field}))
					{
						$value = $product_ref->{sources_fields}{$source_id}{$source_field};
					}
				}
				else {

					foreach my $suffix ("_value", "_unit", "_prepared_value", "_prepared_unit") {
						if ($field =~ /$suffix$/) {
							my $nid = $`;
							if (defined $product_ref->{nutriments}) {
								$value = $product_ref->{nutriments}{$nid . $suffix};
							}
							$nutriment_field = 1;
							last;
						}
					}

					if (not $nutriment_field) {

						# If we export image fields, we first need to generate the paths to images

						if (($field =~ /^image_(.*)_(url|json)/) and (not $added_images_urls)) {
							add_images_urls_to_product($product_ref, $lc);
							$added_images_urls = 1;
						}

						if ($field =~ /^image_(.*)_file/) {
							# File path for the image on the server, used for exporting from producers platform to public database

							my $imagefield = $1;

							if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$imagefield})) {
								$value
									= "$BASE_DIRS{PRODUCTS_IMAGES}/"
									. $product_path . "/"
									. $product_ref->{images}{$imagefield}{imgid} . ".jpg";
							}
							elsif (defined $other_images{$product_ref->{code} . "." . $imagefield}) {
								$value
									= "$BASE_DIRS{PRODUCTS_IMAGES}/"
									. $product_path . "/"
									. $other_images{$product_ref->{code} . "." . $imagefield}{imgid} . ".jpg";
							}
						}
						elsif ($field =~ /^image_(.*)_(x1|y1|x2|y2|angle|normalize|white_magic|coordinates_image_size)/)
						{
							# Coordinates for image cropping
							my $imagefield = $1;
							my $coord = $2;

							if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$imagefield})) {
								$value = $product_ref->{images}{$imagefield}{$coord};
							}
						}
						elsif ($field =~ /^image_(ingredients|nutrition|packaging)_json$/) {
							if (defined $product_ref->{"image_$1_url"}) {
								$value = $product_ref->{"image_$1_url"};
								$value =~ s/\.(\d+)\.jpg/.json/;
							}
						}
						elsif ($field =~ /^image_(.*)_full_url$/) {
							if (defined $product_ref->{"image_$1_url"}) {
								$value = $product_ref->{"image_$1_url"};
								$value =~ s/\.(\d+)\.jpg/.full.jpg/;
							}
						}
						elsif (($field =~ /_tags$/) and (defined $product_ref->{$field})) {
							$value = join(",", @{$product_ref->{$field}});
						}
						elsif ((defined $taxonomy_fields{$field}) and (defined $product_ref->{$field . "_hierarchy"})) {
							# we do not know the language of the current value of $product_ref->{$field}
							# so regenerate it in the main language of the product
							# Note: some fields like nova_groups and food_groups do not have a _hierarchy subfield,
							# but they are not entered directly, but computed from other fields, so we can take their values as is.
							$value = list_taxonomy_tags_in_language($product_ref->{lc}, $field,
								$product_ref->{$field . "_hierarchy"});
						}
						# packagings field of the form packaging_2_number_of_units
						elsif ($field =~ /^packaging_(\d+)_(.*)$/) {
							my $index = $1 - 1;
							my $property = $2;
							$value = deep_get($product_ref, ("packagings", $index, $property));
						}
						# Allow returning fields that are not at the root of the product structure
						# e.g. ecoscore_data.agribalyse.score  -> $product_ref->{ecoscore_data}{agribalyse}{score}
						elsif ($field =~ /\./) {
							$value = deep_get($product_ref, split(/\./, $field));
						}
						# Fields like "obsolete" : output 1 for true values or 0
						elsif ($field eq "obsolete") {
							if ((defined $product_ref->{$field}) and ($product_ref->{$field})) {
								$value = 1;
							}
							else {
								$value = 0;
							}
						}
						else {
							$value = $product_ref->{$field};
						}
					}
				}

				push @values, $value;
			}

			if ($format eq "xlsx") {
				$worksheet->write_row($j, 0, \@values);
			}
			else {
				$csv->print($filehandle, \@values);
			}

		}

	}

	# Return the count of products exported
	return $j;
}

sub include_image_paths ($product_ref, $populated_fields_ref, $other_images_ref) {

	# First list the selected images
	my %selected_images = ();
	foreach my $imageid (sort keys %{$product_ref->{images}}) {

		if ($imageid =~ /^(front|ingredients|nutrition|packaging|other)_(\w\w)$/) {

			$selected_images{$product_ref->{images}{$imageid}{imgid}} = 1;
			$populated_fields_ref->{"image_" . $imageid . "_file"} = sprintf("%08d", 10 * 1000) . "_" . $imageid;
			# Also export the crop coordinates
			foreach my $coord (qw(x1 x2 y1 y2 angle normalize white_magic coordinates_image_size)) {
				if (
					(defined $product_ref->{images}{$imageid}{$coord})
					and (  ($coord !~ /^(x|y)/)
						or ($product_ref->{images}{$imageid}{$coord} != -1)
					)    # -1 is passed when the image is not cropped
					)
				{
					$populated_fields_ref->{"image_" . $imageid . "_" . $coord}
						= sprintf("%08d", 10 * 1000) . "_" . $imageid . "_" . $coord;
				}
			}
		}
	}

	# Then list unselected images as other
	my $other = 0;
	foreach my $imageid (sort keys %{$product_ref->{images}}) {

		if (($imageid =~ /^(\d+)$/) and (not defined $selected_images{$imageid})) {
			$other++;
			$populated_fields_ref->{"image_" . "other_" . $other . "_file"}
				= sprintf("%08d", 10 * 1000) . "_" . "other_" . $other;
			# Keep the imgid for second loop on products
			$other_images_ref->{$product_ref->{code} . "." . "other_" . $other} = {imgid => $imageid};
		}
	}
	return;
}

1;

