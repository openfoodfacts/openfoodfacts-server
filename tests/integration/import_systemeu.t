#!/usr/bin/perl -w

# This test scripts:
# 1. import some products from files in a XML format from Carrefour France
# 2. exports the products, and checks that we get the expected exports

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
use ProductOpener::EnvironmentalScore qw/load_agribalyse_data load_environmental_score_data/;
use ProductOpener::ForestFootprint qw/load_forest_footprint_data/;
use ProductOpener::Test qw/compare_csv_file_to_expected_results init_expected_results remove_all_products/;
use ProductOpener::ImportConvertCarrefourFrance qw/convert_carrefour_france_files/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Paths qw/%BASE_DIRS/;

use JSON;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Remove all products

ProductOpener::Test::remove_all_products();

# Import test products

load_data();

if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
	load_agribalyse_data();
	load_environmental_score_data();
	load_forest_footprint_data();
}

my $input_csv_file = "$test_dir/inputs/import_systemeu/SUYQD_AKENEO_PU_02.csv";
my $converted_csv_file = "/tmp/import_systemeu_converted.csv";
my $exported_csv_file = "/tmp/import_systemeu_export.csv";

my $script_out
	= `perl $BASE_DIRS{SCRIPTS}/imports/systemeu/convert_systemeu_csv_to_off_csv.pl $input_csv_file $converted_csv_file`;

print STDERR $script_out;

my $import_args_ref = {
	user_id => "systeme-u",
	csv_file => $converted_csv_file,
	no_source => 1,
};

my $stats_ref = import_csv_file($import_args_ref);

# Export products

my $query_ref = {};
my $separator = "\t";

# CSV export

open(my $exported_csv, ">:encoding(UTF-8)", $exported_csv_file) or die("Could not create $exported_csv_file: $!\n");

my $export_args_ref = {filehandle => $exported_csv, separator => $separator, query => $query_ref, cc => "fr"};

export_csv($export_args_ref);

close($exported_csv);

ProductOpener::Test::compare_csv_file_to_expected_results($exported_csv_file, $expected_result_dir,
	$update_expected_results, "systeme-u");

done_testing();
