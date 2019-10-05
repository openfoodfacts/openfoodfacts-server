# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(

		&export_csv

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Data qw/:all/;

use Text::CSV;


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

=cut

sub export_csv($) {

	my $args_ref = shift;

	my $filehandle = $args_ref->{filehandle};
	my $separator = $args_ref->{separator} || "\t";
	my $query_ref = $args_ref->{query};
	my $fields_ref = $args_ref->{fields};
	my $extra_fields_ref = $args_ref->{extra_fields};

	$log->debug("export_csv - start", { args_ref=>$args_ref }) if $log->is_debug();

	my $count = get_products_collection()->count_documents($query_ref);

	$log->debug("export_csv - documents to export", { count=>$count }) if $log->is_debug();

	my $cursor = get_products_collection()->find($query_ref);
	$cursor->immortal(1);

	# First pass - go through products to see which fields are populated,
	# unless the fields to export are specified with the fields parameter.

	my @sorted_populated_fields;

	if (not defined $fields_ref) {

		# %populated_fields will contain the field name as the key,
		# and a sort key as the value so that the CSV columns are in the order of $options{import_export_fields_groups}
		my %populated_fields = ();

		while (my $product_ref = $cursor->next) {

			# Possible fields to export are listed in $options{import_export_fields_groups}

			my $fields_groups_ref = $options{import_export_fields_groups};

			my $group_number = 0;

			foreach my $group_ref (@$fields_groups_ref) {

				$group_number++;
				my $item_number = 0;

				my $group_id = $group_ref->[0];

				if (($group_id eq "nutrition") or ($group_id eq "nutrition_other")) {

					if ($group_id eq "nutrition") {
						foreach my $field ("no_nutrition_data", "nutrition_data_per", "nutrition_data_prepared_per") {
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

						$nid =~ s/^(-|!)+//g;
						$nid =~ s/-$//g;

						# Order of the fields: sugars_value, sugars_prepared_value, sugars_unit

						if ((defined $product_ref->{nutriments}{$nid . "_value"}) and ($product_ref->{nutriments}{$nid . "_value"} ne "")) {
							$populated_fields{$nid . "_value"} = sprintf("%08d", $group_number * 1000 + $item_number) . "_1";
							$populated_fields{$nid . "_unit"} = sprintf("%08d", $group_number * 1000 + $item_number) . "_3";
						}
						if ((defined $product_ref->{nutriments}{$nid . "_prepared_value"}) and ($product_ref->{nutriments}{$nid . "_prepared_value"} ne "")) {
							$populated_fields{$nid . "_prepared_value"} = sprintf("%08d", $group_number * 1000 + $item_number) . "_2";
							$populated_fields{$nid . "_unit"} = sprintf("%08d", $group_number * 1000 + $item_number) . "_3";
						}
					}
				}
				else {

					foreach my $field (@{$group_ref->[1]}) {

						$item_number++;

						if ($field =~ /_value_unit$/) {
							# Column can contain value + unit, value, or unit for a specific field
							$field = $`;
						}

						if (defined $tags_fields{$field}) {
							if ((defined $product_ref->{$field . "_hierarchy"}) and (scalar @{$product_ref->{$field . "_hierarchy"}} > 0)) {
								$populated_fields{$field} = sprintf("%08d", $group_number * 1000 + $item_number);
							}
						}
						elsif (defined $language_fields{$field}) {
							if (defined $product_ref->{languages_codes}) {
								foreach my $l (keys %{$product_ref->{languages_codes}}) {
									if ((defined $product_ref->{$field . "_$l"}) and ($product_ref->{$field . "_$l"} ne "")) {
										# Add language code to sort key
										$populated_fields{$field . "_$l"} = sprintf("%08d", $group_number * 1000 + $item_number) . "_$l";
									}
								}
							}
						}
						elsif ((defined $product_ref->{$field}) and ($product_ref->{$field} ne "")) {
							$populated_fields{$field} = sprintf("%08d", $group_number * 1000 + $item_number);
						}
					}
				}
			}
		}

		@sorted_populated_fields = sort ({ $populated_fields{$a} cmp $populated_fields{$b} } keys %populated_fields);

		push @sorted_populated_fields, "data_sources";
	}
	else {
		# The fields to export are specified by the fields parameter
		@sorted_populated_fields = @$fields_ref;
	}

	# Extra fields such as Nova or Nutri-Score that do not originate from users or producers but are computed
	if (defined $extra_fields_ref) {
		@sorted_populated_fields = (@sorted_populated_fields, @{$extra_fields_ref});
	}

	# Second pass - output CSV data

	my $csv = Text::CSV->new ( { binary => 1 , sep_char => $separator } )  # should set binary attribute.
		or die "Cannot use CSV: ".Text::CSV->error_diag ();

	# Print the header line with fields names
	$csv->print ($filehandle, \@sorted_populated_fields);
	print $filehandle "\n";

	$cursor->reset();

	while (my $product_ref = $cursor->next) {

		my @values = ();

		my $added_images_urls = 0;

		foreach my $field (@sorted_populated_fields) {

			my $nutriment_field = 0;

			my $value;

			foreach my $suffix ("_prepared_value", "_value", "_unit") {
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

				if (($field =~ /^image_/) and (not $added_images_urls)) {
					ProductOpener::Display::add_images_urls_to_product($product_ref);
					$added_images_urls = 1;
				}

				if ($field =~ /^image_(ingredients|nutrition)_json$/) {
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
				elsif (defined $taxonomy_fields{$field}) {
					# we do not know the language of the current value of $product_ref->{$field}
					# so regenerate it in the main language of the product
					$value = display_tags_hierarchy_taxonomy($product_ref->{lc}, $field, $product_ref->{$field . "_hierarchy"});
					# Remove tags
					$value =~ s/<(([^>]|\n)*)>//g;
				}
				else {
					$value = $product_ref->{$field};
				}
			}

			push @values, $value;
		}

		$csv->print ($filehandle, \@values);
		print $filehandle "\n";
	}
}


1;

