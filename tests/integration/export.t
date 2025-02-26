#!/usr/bin/perl -w

# This test scripts:
# 1. import some products from a CSV file
# 2. exports the products with various options, and checks that we get the expected exports

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP', filter => "info";

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::Import qw/import_csv_file/;
use ProductOpener::Export qw/export_csv/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::EnvironmentalScore qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Test qw/compare_csv_file_to_expected_results init_expected_results remove_all_products/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Paths qw/%BASE_DIRS/;

use Getopt::Long;
use JSON;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Remove all products

ProductOpener::Test::remove_all_products();

# Import test products

load_data();

my $import_args_ref = {
	user_id => "test",
	csv_file => $test_dir . "/inputs/export/products.csv",
	no_source => 1,
};

my $stats_ref = import_csv_file($import_args_ref);

# Export products

my $query_ref = {};
my $separator = "\t";

# Export database script to generate CSV exports of the whole database

# unlink CSV export if it exists, and launch script
my $csv_filename = "$BASE_DIRS{PUBLIC_DATA}/en.$server_domain.products.csv";
unlink($csv_filename) if -e $csv_filename;

my $script_out = `perl scripts/export_database.pl`;

ProductOpener::Test::compare_csv_file_to_expected_results($csv_filename, $expected_result_dir,
	$update_expected_results, "export_database");

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
