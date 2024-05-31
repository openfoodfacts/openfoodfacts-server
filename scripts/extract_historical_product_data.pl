#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

my $usage = <<TXT
update_all_products.pl is a script that updates the latest version of products in the file system and on MongoDB.
It is used in particular to re-run tags generation when taxonomies have been updated.

Usage:

update_all_products.pl --key some_string_value --fields categories,labels --index

The key is used to keep track of which products have been updated. If there are many products and field to updates,
it is likely that the MongoDB cursor of products to be updated will expire, and the script will have to be re-run.

--count		do not do any processing, just count the number of products matching the --query options
--just-print-codes	do not do any processing, just print the barcodes
--query some_field=some_value (e.g. categories_tags=en:beers)	filter the products
--query some_field=-some_value	match products that don't have some_value for some_field
--analyze-and-enrich-product-data	run all the analysis and enrichments
--process-ingredients	compute allergens, additives detection
--clean-ingredients	remove nutrition facts, conservation conditions etc.
--compute-nutriscore	nutriscore
--compute-serving-size	compute serving size values
--compute-history	compute history and completeness
--check-quality	run quality checks
--compute-codes
--fix-serving-size-mg-to-ml
--index		specifies that the keywords used by the free text search function (name, brand etc.) need to be reindexed. -- TBD
--user		create a separate .sto file and log the change in the product history, with the corresponding user
--team		optional team for the user that is credited with the change
--comment	comment for change in product history
--pretend	do not actually update products
--mongodb-to-mongodb	do not use the .sto files at all, and only read from and write to mongodb
TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve store/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/$User_id %User/;
use ProductOpener::Images qw/process_image_crop/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::DataQuality qw/check_quality/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::Ecoscore qw(compute_ecoscore);
use ProductOpener::Packaging
	qw(analyze_and_combine_packaging_data guess_language_of_packaging_text init_packaging_taxonomies_regexps);
use ProductOpener::ForestFootprint qw(compute_forest_footprint);
use ProductOpener::MainCountries qw(compute_main_countries);
use ProductOpener::PackagerCodes qw/normalize_packager_codes/;
use ProductOpener::API qw/get_initialized_response/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Redis qw/push_to_redis_stream/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Data::DeepAccess qw(deep_get deep_exists deep_set);
use Data::Compare;

use Log::Any::Adapter 'TAP';

use Getopt::Long;

my $analyze_and_enrich_product_data;
my $codes_file;
my $field_to_extract;
my $min_year;
my $max_year;
my $recompute_taxonomies;

my $query_ref = {};    # filters for mongodb query

GetOptions(
	# We can extract data for products matching a specific query, or for a list of product codes
	"query=s%" => $query_ref,    # filters for mongodb query
	"codes-file=s" => \$codes_file,    # file with product codes to extract data for
	"field=s" => \$field_to_extract,
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
		push @codes, $row;
	}
	close $fh;
	my $products_count = scalar @codes;
	print STDERR "$products_count documents retrieved from MongoDB\n";

}
else {
	# Use query filters entered using --query categories_tags=en:plant-milks

	use boolean;

	foreach my $field (sort keys %{$query_ref}) {

		my $not = 0;

		if ($query_ref->{$field} =~ /^-/) {
			$query_ref->{$field} = $';
			$not = 1;
		}

		if ($query_ref->{$field} eq 'null') {
			# $query_ref->{$field} = { '$exists' => false };
			$query_ref->{$field} = undef;
		}
		elsif ($query_ref->{$field} eq 'exists') {
			$query_ref->{$field} = {'$exists' => true};
		}
		elsif ($field =~ /_t$/) {    # created_t, last_modified_t etc.
			$query_ref->{$field} += 0;
		}
		# Multiple values separated by commas
		elsif ($query_ref->{$field} =~ /,/) {
			my @tagids = split(/,/, $query_ref->{$field});

			if ($not) {
				$query_ref->{$field} = {'$nin' => \@tagids};
			}
			else {
				$query_ref->{$field} = {'$in' => \@tagids};
			}
		}
		elsif ($not) {
			$query_ref->{$field} = {'$ne' => $query_ref->{$field}};
		}
	}

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

# Go through all products
foreach my $code (@codes) {

	my $productid = $code;
	my $path = product_path_from_id($productid);

	# Go through all product revisions

	my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
	if (not defined $changes_ref) {
		$changes_ref = [];
	}

	# We will go through revision one by one, and for the requested field, we will
	# store the value we have at the beginning of each year
	my %value_per_year = ();

	# Go through all revisions, keep the latest value of all fields

	my %deleted_values = ();
	my $previous_product_ref = {};
	my $revs = 0;

	foreach my $change_ref (@{$changes_ref}) {
		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;    # was not set before June 2012
		}

		my $product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");

		if (defined $product_ref) {

			my $value;

			# Make sure we have a lc field
			if ((not defined $product_ref->{lc}) and (defined $product_ref->{lang})) {
				$product_ref->{lc} = $product_ref->{lang};
			}

			# Determine the year of the revision, using the UNIX timestamp last_modified_t
			my $year = (localtime($product_ref->{last_modified_t}))[5] + 1900;

			# This option runs all the data enrichment functions
			if ($analyze_and_enrich_product_data) {
				analyze_and_enrich_product_data($product_ref);
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
						# so regenerate it in the main language of the product

						$product_ref->{$tagtype}
							= list_taxonomy_tags_in_language($lc, $tagtype, $product_ref->{$tagtype . "_hierarchy"});
					}

					compute_field_tags($product_ref, $lc, $tagtype);
				}
				foreach my $tag (@{$product_ref->{$tagtype . "_tags"}}) {
					if ($tag =~ /^$prefix/) {
						$value = $tag;
						last;
					}
				}
			}
			else {
				# Access any field in the product
				# e.g. nutriments.energy_100g
				$value = deep_get($product_ref, split(/\./, $field_to_extract));
			}

			# We consider the value at the beginning of the year
			# So the last value of the previous year is the value for the current year
			if ($value) {
				$value_per_year{$year + 1} = $value;
			}
			else {
				delete($value_per_year{$year + 1});
			}

			# Keep a reference to the previous rev, if we want to compute changes between revisions
			$previous_product_ref = $product_ref;
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
	print $code . $values . "\n";
}

exit(0);
