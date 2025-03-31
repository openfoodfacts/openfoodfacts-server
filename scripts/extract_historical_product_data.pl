#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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

use ProductOpener::PerlStandards;

my $usage = <<TXT
extract_historical_product_data.pl iterates over all the revisions of specific products and extracts the value of a specific field for each year.
The corresponding data is output in a tab-separated format, with the product code followed by the values for each year.

Usage:

extract_historical_product_data.pl --field [direct_field or some_tags_field=en:some_prefix] --min-year 2017 --max-year 2024 [--recompute-taxonomies] [--analyze-and-enrich-product-data] [--query some_field=some_value] [--codes-file some_file] [--omit-prefix]

Examples:

Extract the Nutri-Score label printed on the packaging for all products from 2017 to 2024 (we recompute taxonomies in order to canonicalize the Nutri-Score labels):
./scripts/extract_historical_product_data.pl --field labels_tags=en:nutriscore- --recompute-taxonomies --min 2017 --max 2024

Compute and extract the Nutri-Score based on product data:
./scripts/extract_historical_product_data.pl --field nutriscore_grade --recompute-taxonomies --analyze-and-enrich-product-data --min 2017 --max 2024



The key is used to keep track of which products have been updated. If there are many products and field to updates,
it is likely that the MongoDB cursor of products to be updated will expire, and the script will have to be re-run.

--query some_field=some_value (e.g. categories_tags=en:beers)	filter the products (--query parameters can be repeated to have multiple filters)
--query some_field=-some_value	match products that don't have some_value for some_field
--query some_field=value1,value2	match products that have value1 and value2 for some_field (must be a _tags field)
--query some_field=value1\|value2	match products that have value1 or value2 for some_field (must be a _tags field)
--codes-file some_file		read the list of product codes from a file
--field field_name		field to extract data for
--field some_tags_field=en:some_prefix		extract the value of a tag field that has a specific prefix (e.g. labels_tags=en:nutriscore-)
--omit-prefix        do not output the prefix in the extracted values
--min-year year		minimum year to extract data for
--max-year year		maximum year to extract data for
--recompute-taxonomies	recompute tag fields like categories and labels with the current taxonomies
--analyze-and-enrich-product-data	run all the analysis and enrichments

TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve store/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::EnvironmentalScore qw(compute_environmental_score);
use ProductOpener::LoadData qw/load_data/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Data::DeepAccess qw(deep_get deep_exists deep_set);

use Log::Any::Adapter 'TAP';

use Getopt::Long;

my $analyze_and_enrich_product_data;
my $codes_file;
my $field_to_extract;
my $min_year;
my $max_year;
my $recompute_taxonomies;
my $omit_prefix;

my $query_params_ref = {};    # filters for mongodb query

GetOptions(
	# We can extract data for products matching a specific query, or for a list of product codes
	"query=s%" => $query_params_ref,    # filters for mongodb query
	"codes-file=s" => \$codes_file,    # file with product codes to extract data for
	"field=s" => \$field_to_extract,
	"omit-prefix" => \$omit_prefix,
	"recompute-taxonomies" =>
		\$recompute_taxonomies,    # Recompute tag fields like categories and labels with the current taxonomies
	"analyze-and-enrich-product-data" => \$analyze_and_enrich_product_data,
	"min-year=i" => \$min_year,
	"max-year=i" => \$max_year,
) or die("Error in command line arguments:\n\n$usage");

my @codes = ();

# Get the list of product codes from a file
if (defined $codes_file) {
	open(my $fh, '<', $codes_file) or die("Could not open file '$codes_file' $!");
	while (my $row = <$fh>) {
		chomp $row;
		$row =~ s/\t.*//;    # Assume codes are in the first column; remove the rest
		push @codes, $row;
	}
	close $fh;
	my $products_count = scalar @codes;
	print STDERR "$products_count documents retrieved from MongoDB\n";

}
else {
	# Use query filters entered using --query categories_tags=en:plant-milks

	# Build the mongodb query from the --query parameters
	my $query_ref = {};

	add_params_to_query($query_params_ref, $query_ref);

	use Data::Dumper;
	print STDERR "MongoDB query:\n" . Dumper($query_ref);

	my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

	# Collection that will be used to iterate products
	# TODO: we should query both the products and obsolete products collections
	my $products_collection = get_products_collection({obsolete => 0, timeout => $socket_timeout_ms});

	my $products_count = "";

	eval {
		$products_count = $products_collection->count_documents($query_ref);

		print STDERR "$products_count documents retrieved from MongoDB\n";
	};

	my $cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});
	$cursor->immortal(1);

	while (my $product_ref = $cursor->next) {
		push @codes, $product_ref->{code};
	}
}

# load data needed to analyze and enrich products
if ($analyze_and_enrich_product_data) {
	load_data();
}

# Print the header
my $years = "";
for (my $year = $min_year; $year <= $max_year; $year++) {
	$years .= "\t" . $year;
}

print "code" . "\t" . "found" . "\t" . "url" . $years . "\n";

# Go through all products
my $products = 0;
my $found_products = 0;

sub save_product_field_value_for_year($product_ref, $field_to_extract, $year, $value_per_year_ref) {

	my $value;

	# Make sure we have a lc field
	if ((not defined $product_ref->{lc}) and (defined $product_ref->{lang})) {
		$product_ref->{lc} = $product_ref->{lang};
	}

	# This option runs all the data enrichment functions
	if ($analyze_and_enrich_product_data) {
		analyze_and_enrich_product_data($product_ref, {});
	}

	# Value of a tag field that has a specific prefix
	# e.g. labels_tags=en:nutriscore-
	# We will take the value of the first tag that has the prefix

	if ($field_to_extract =~ /^(.+)_tags=(.+)$/) {
		my $tagtype = $1;
		my $prefix = $2;
		# *_tags fields may contain old canonical tags, we can recompute tag fields with the newest taxonomy
		if (($recompute_taxonomies) and (defined $taxonomy_fields{$tagtype})) {
			# if the field was previously not taxonomized, the $field_hierarchy field does not exist
			# assume the $field value is in the main language of the product
			if (

				defined $product_ref->{$tagtype . "_hierarchy"}
				)
			{
				# we do not know the language of the current value of $product_ref->{$tagtype}
				# so regenerate it in English

				$product_ref->{$tagtype}
					= list_taxonomy_tags_in_language("en", $tagtype, $product_ref->{$tagtype . "_hierarchy"});
			}

			compute_field_tags($product_ref, "en", $tagtype);
		}
		foreach my $tag (@{$product_ref->{$tagtype . "_tags"}}) {
			if ($tag =~ /^$prefix/) {
				if ($omit_prefix) {
					$value = $';
				}
				else {
					$value = $tag;
				}
				last;
			}
		}
	}
	else {
		# Access any field in the product
		# e.g. nutriments.energy_100g
		$value = deep_get($product_ref, split(/\./, $field_to_extract));
	}
	$value_per_year_ref->{$year} = $value;

	return;
}

foreach my $code (@codes) {

	$products++;

	my $productid = $code;
	my $path = product_path_from_id($productid);
	my $found = 0;

	# We will go through revision one by one, and for the requested field, we will
	# store the value we have at the beginning of each year
	my %value_per_year = ();
	my $url = "";

	# Go through all product revisions
	my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");

	# If we don't have a changes.sto file, the product is not in the database
	if (defined $changes_ref) {
		$found = 1;
		$found_products++;

		# Go through all revisions, keep the latest value of all fields

		my %deleted_values = ();
		my $previous_product_ref;
		my $revs = 0;
		my $current_year;

		foreach my $change_ref (@{$changes_ref}) {
			$revs++;
			my $rev = $change_ref->{rev};
			if (not defined $rev) {
				$rev = $revs;    # was not set before June 2012
			}

			my $product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");

			if (defined $product_ref) {

				# Determine the year of the revision, using the UNIX timestamp last_modified_t
				my $year = (localtime($product_ref->{last_modified_t}))[5] + 1900;

				# We consider the value at the beginning of the year
				# So the last value of the previous year is the value for the current year
				# Save the value if the year has changed
				if ((not defined $current_year) or ($year != $current_year)) {
					if ($current_year) {
						save_product_field_value_for_year($previous_product_ref, $field_to_extract, $current_year + 1,
							\%value_per_year);
					}
					$current_year = $year;
				}

				# Keep a reference to the previous revision
				$previous_product_ref = $product_ref;
			}
		}

		# Save the value for the last year
		if ($current_year) {
			save_product_field_value_for_year($previous_product_ref, $field_to_extract, $current_year + 1,
				\%value_per_year);
		}

		if ($previous_product_ref) {
			$url = "https://world.$server_domain" . product_url($previous_product_ref);
		}
	}

	# Assign values for missing years and output values between min_year and max_year
	my $values = "";
	for (my $year = 2000; $year <= $max_year; $year++) {
		if (not defined $value_per_year{$year}) {
			$value_per_year{$year} = $value_per_year{$year - 1};
		}
		if ($year >= $min_year) {
			$values .= "\t" . ($value_per_year{$year} || '');
		}
	}

	print $code . "\t" . $found . "\t" . $url . $values . "\n";
}

print STDERR "$products products processed, $found_products products found in the database\n";

exit(0);
