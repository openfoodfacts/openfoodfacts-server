#!/usr/bin/perl -w

# This test scripts:
# 1. import some products from files in a XML format from Carrefour France
# 2. exports the products, and checks that we get the expected exports

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
use ProductOpener::ImportConvertCarrefourFrance qw/:all/;

use File::Basename "dirname";

use Getopt::Long;
use JSON;


my $test_id = "import_convert_carrefour_france";
my $test_dir = dirname(__FILE__);
my $results_dir = "$test_dir/expected_test_results/$test_id";

my $usage = <<TXT

The expected results of the tests are saved in $results_dir

Use the --update-expected-results option to create or update the test results.

TXT
;

my $update_expected_results;

GetOptions ("update-expected-results"   => \$update_expected_results)
  or die("Error in command line arguments.\n\n" . $usage);
  
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

my $converted_csv_file = "/tmp/import_convert_carrefour_france.csv";

open (my $converted_csv, ">:encoding(UTF-8)", $converted_csv_file) or die("Could not create $converted_csv_file: $!\n");

my @files = ();
opendir(my $dh, $test_dir . "/inputs/import_convert_carrefour_france") or die("Cannot read $test_dir" . "/inputs/import_convert_carrefour_france");
foreach my $file (sort { $a cmp $b } readdir($dh)) {
    
    if ($file =~ /\.xml$/) {
        push @files, $test_dir . "/inputs/import_convert_carrefour_france/" . $file;
    }
}

convert_carrefour_france_files($converted_csv, \@files);

close($converted_csv);


my $import_args_ref = {
	user_id => "carrefour-france",
	csv_file => "/tmp/import_convert_carrefour_france.csv",
	no_source => 1,
};

my $stats_ref = import_csv_file( $import_args_ref );

# Export products

my $query_ref = {};
my $separator = "\t";

# CSV export

my $exported_csv_file = "/tmp/import_convert_carrefour_france_export.csv";
open (my $exported_csv, ">:encoding(UTF-8)", $exported_csv_file) or die("Could not create $exported_csv_file: $!\n");

my $export_args_ref = {filehandle=>$exported_csv, separator=>$separator, query=>$query_ref, cc => "fr" };

export_csv($export_args_ref);

close($exported_csv);

ProductOpener::Test::compare_csv_file_to_expected_results($exported_csv_file, $results_dir, $update_expected_results);


done_testing();
