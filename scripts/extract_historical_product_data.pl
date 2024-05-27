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

my @fields_to_update = ();
my $key;
my $index = '';
my $count = '';
my $just_print_codes = '';
my $pretend = '';
my $analyze_and_enrich_product_data = '';
my $process_ingredients = '';
my $process_packagings = '';
my $clean_ingredients = '';
my $compute_nutriscore = '';
my $compute_serving_size = '';
my $compute_data_sources = '';
my $compute_nova = '';
my $check_quality = '';
my $compute_codes = '';
my $compute_carbon = '';
my $compute_history = '';
my $compute_sort_key = '';
my $comment = '';
my $fix_serving_size_mg_to_ml = '';
my $fix_missing_lc = '';
my $fix_zulu_lang = '';
my $fix_rev_not_incremented = '';
my $fix_yuka_salt = '';
my $run_ocr = '';
my $autorotate = '';
my $remove_team = '';
my $remove_label = '';
my $remove_category = '';
my $remove_nutrient = '';
my $remove_old_carbon_footprint = '';
my $fix_spanish_ingredientes = '';
my $team = '';
my $assign_categories_properties = '';
my $restore_values_deleted_by_user = '';
my $delete_debug_tags = '';
my $all_owners = '';
my $mark_as_obsolete_since_date = '';
my $reassign_energy_kcal = '';
my $delete_old_fields = '';
my $mongodb_to_mongodb = '';
my $compute_ecoscore = '';
my $compute_forest_footprint = '';
my $fix_nutrition_data_per = '';
my $fix_nutrition_data = '';
my $compute_main_countries = '';
my $prefix_packaging_tags_with_language = '';
my $fix_non_string_ids = '';
my $fix_non_string_codes = '';
my $fix_string_last_modified_t = '';
my $assign_ciqual_codes = '';
my $obsolete = 0;
my $fix_obsolete;
my $fix_last_modified_t;    # Will set the update key and ensure last_updated_t is initialised

my $query_ref = {};    # filters for mongodb query

GetOptions(
	# We can extract data for products matching a specific query, or for a list of product codes
	"query=s%" => $query_ref,    # filters for mongodb query
	"codes-file=s" => \$codes_file,    # file with product codes to extract data for
	"field=s" => \@field,
	"index" => \$index,
	"analyze-and-enrich-product-data" => \$analyze_and_enrich_product_data,
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
}

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

# Query products that have the _id field stored as a number
if ($fix_non_string_ids) {
	$query_ref->{_id} = {'$type' => "long"};
}

# Query products that have the _id field stored as a number
if ($fix_non_string_codes) {
	$query_ref->{code} = {'$type' => "long"};
}

# Query products that have the last_modified_t field stored as a number
if ($fix_string_last_modified_t) {
	$query_ref->{last_modified_t} = {'$type' => "string"};
}

# On the producers platform, require --query owners_tags to be set, or the --all-owners field to be set.

if ((defined $server_options{private_products}) and ($server_options{private_products})) {
	if ((not $all_owners) and (not defined $query_ref->{owners_tags})) {
		print STDERR "On producers platform, --query owners_tags=... or --all-owners must be set.\n";
		exit();
	}
}

if ((defined $remove_team) and ($remove_team ne "")) {
	$query_ref->{teams_tags} = $remove_team;
}

if ((defined $remove_label) and ($remove_label ne "")) {
	$query_ref->{labels_tags} = $remove_label;
}

if ((defined $remove_category) and ($remove_category ne "")) {
	$query_ref->{categories_tags} = $remove_category;
}

if (defined $key) {
	$query_ref->{update_key} = {'$ne' => "$key"};
}
else {
	$key = "key_" . time();
}

# $query_ref->{unknown_nutrients_tags} = { '$exists' => true,  '$ne' => [] };

print STDERR "Update key: $key\n\n";

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);

my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

# Collection that will be used to iterate products
my $products_collection = get_products_collection({obsolete => $obsolete, timeout => $socket_timeout_ms});

# Collections for saving current / obsolete products
my %products_collections = (
	current => get_products_collection({timeout => $socket_timeout_ms}),
	obsolete => get_products_collection({obsolete => $obsolete, timeout => $socket_timeout_ms}),
);

my $products_count = "";

eval {
	$products_count = $products_collection->count_documents($query_ref);

	print STDERR "$products_count documents to update.\n";
};

if ($count) {exit(0);}

my $cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});
$cursor->immortal(1);

# load data needed to analyze and enrich products
if ($analyze_and_enrich_product_data) {
	load_data();
}

while (my $product_ref = $cursor->next) {
	push @codes, $product_ref->{code};
}

# Go through all products
foreach my $code (@codes) {

	my $productid = $code;
	my $path = product_path_from_id($product_id);

	$product_ref = retrieve_product($productid);

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
	my $previous_rev_product_ref = {};
	my $revs = 0;

	foreach my $change_ref (@{$changes_ref}) {
		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;    # was not set before June 2012
		}

		my $rev_product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");

		if (defined $rev_product_ref) {

			# This option runs all the data enrichment functions
			if ($analyze_and_enrich_product_data) {
				analyze_and_enrich_product_data($product_ref);
			}

			$previous_rev_product_ref = $rev_product_ref;
		}
	}
}

exit(0);
