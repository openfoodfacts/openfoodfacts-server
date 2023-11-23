#!/usr/bin/perl -w

# This test scripts:
# 1. import some products from a CSV file
# 2. exports the products with various options, and checks that we get the expected exports

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP', filter => "info";

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::Import qw/:all/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Test qw/:all/;

use Getopt::Long;
use JSON;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Remove all products

ProductOpener::Test::remove_all_products();

# Import test products

init_emb_codes();
init_packager_codes();
init_geocode_addresses();
init_packaging_taxonomies_regexps();

if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
	load_agribalyse_data();
	load_ecoscore_data();
	load_forest_footprint_data();
}

my $import_args_ref = {
	user_id => "test",
	csv_file => $test_dir . "/inputs/export/products.csv",
	no_source => 1,
};

my $stats_ref = import_csv_file($import_args_ref);

# Export products

my $query_ref = {};
my $separator = "\t";

# CSV export

my $exported_csv_file = "/tmp/export.csv";
open(my $exported_csv, ">:encoding(UTF-8)", $exported_csv_file) or die("Could not create $exported_csv_file: $!\n");

my $export_args_ref = {filehandle => $exported_csv, separator => $separator, query => $query_ref, cc => "fr"};

export_csv($export_args_ref);

close($exported_csv);

ProductOpener::Test::compare_csv_file_to_expected_results($exported_csv_file, $expected_result_dir,
	$update_expected_results, "csv-export");

# Export more fields

$exported_csv_file = "/tmp/export_more_fields.csv";
open($exported_csv, ">:encoding(UTF-8)", $exported_csv_file) or die("Could not create $exported_csv_file: $!\n");

$export_args_ref->{filehandle} = $exported_csv;
$export_args_ref->{export_computed_fields} = 1;
$export_args_ref->{export_canonicalized_tags_fields} = 1;

export_csv($export_args_ref);

close($exported_csv);

ProductOpener::Test::compare_csv_file_to_expected_results($exported_csv_file, "${expected_result_dir}_more_fields",
	$update_expected_results, "csv-export-more-fields");

done_testing();
