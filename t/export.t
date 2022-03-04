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

use File::Path qw/make_path remove_tree/;
use File::Basename "dirname";

use Getopt::Long;
use JSON;


=head2 compare_csv_file_to_expected_results($csv_file, $expected_results_dir, $update_expected_results)

Compare a CSV file containing product data (e.g. the result of a CSV export) to expected results.

The expected results are stored as individual JSON files for each of the product,
in files named [barcode].json, with a flat key/value pairs structure corresponding to the CSV columns.

This is so that we can easily see diffs with git diffs:
- we know how many products are affected
- we see individual diffs with the field name

=head3 Arguments

=head4 $csv_file - CSV file to compare

=head4 $expected_results_dir - directory containing the individual JSON files

=head4 $update_expected_results - flag to indicate to save test results as expected results

Tests will pass when this flag is passed, and the new expected results can be diffed / commited in GitHub.

=cut

sub compare_csv_file_to_expected_results($$$) {

    my $csv_file = shift;
    my $expected_results_dir = shift;
    my $update_expected_results = shift;

    # Create the expected results dir
    if ($update_expected_results) {
        if (-e $expected_results_dir) {
            remove_tree("$expected_results_dir", {error => \my $err});
            if (@$err) {
                die("not able to remove some products directories: ". join(":", @$err));
            }
        }
        make_path($expected_results_dir);
    }

    # Read the CSV file

    my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

    open (my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open " . $csv_file . ": $!");

    # first line contains headers
    my $columns_ref = $csv->getline ($io);
    $csv->column_names (@{$columns_ref});

    my $json = JSON->new->allow_nonref->canonical;
    my %codes = ();

    while (my $product_ref = $csv->getline_hr ($io)) {

        my $code = $product_ref->{code};
        $codes{$code} = 1;

        # Update the expected results if the --update parameter was set
        
        if (defined $update_expected_results) {
            open (my $result, ">:encoding(UTF-8)", "$expected_results_dir/$code.json") or die("Could not create $expected_results_dir/$code.json: $!\n");
            print $result $json->pretty->encode($product_ref);
            close ($result);
        }

        # Otherwise compare the result with the expected result
        
        elsif (open (my $expected_result, "<:encoding(UTF-8)", "$expected_results_dir/$code.json")) {

            local $/; #Enable 'slurp' mode
            my $expected_product_ref = $json->decode(<$expected_result>);
            is_deeply ($product_ref, $expected_product_ref) or diag explain $product_ref;
        }
        else {
            diag explain $product_ref;
            fail("could not load $expected_results_dir/$code.json");
        }    
    }

    # Check that we are not missing products

    opendir (my $dh, $expected_results_dir) or die("Could not open the $expected_results_dir directory: $!\n");

    foreach my $file (sort(readdir($dh))) {
        
        if ($file =~ /(\d+)\.json$/) {
            my $code = $1;
            ok(exists $codes{$code}, "product code $code exists in CSV export $csv_file");
        }
    }
}


my $test_id = "export";
my $test_dir = dirname(__FILE__);

my $usage = <<TXT

The expected results of the tests are saved in $test_dir/expected_test_results/$test_id

To verify differences and update the expected test results, actual test results
can be saved to a directory by passing --results [path of results directory]

The directory will be created if it does not already exist.

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

my $import_args_ref = {
	user_id => "test",
	csv_file => $test_dir . "/inputs/export/products.csv",
	no_source => 1,
};

my $stats_ref = import_csv_file( $import_args_ref );

# Export products

my $query_ref = {};
my $separator = "\t";

# CSV export

my $exported_csv_file = "/tmp/export.csv";
open (my $exported_csv, ">:encoding(UTF-8)", $exported_csv_file) or die("Could not create $exported_csv_file: $!\n");

my $export_args_ref = {filehandle=>$exported_csv, separator=>$separator, query=>$query_ref, cc => "fr" };

export_csv($export_args_ref);

close($exported_csv);

compare_csv_file_to_expected_results($exported_csv_file, $test_dir . "/expected_test_results/export", $update_expected_results);

# Export more fields

$exported_csv_file = "/tmp/export_more_fields.csv";
open ($exported_csv, ">:encoding(UTF-8)", $exported_csv_file) or die("Could not create $exported_csv_file: $!\n");

$export_args_ref->{filehandle} = $exported_csv;
$export_args_ref->{export_computed_fields} = 1;
$export_args_ref->{export_canonicalized_tags_fields} = 1;

export_csv($export_args_ref);

close($exported_csv);

compare_csv_file_to_expected_results($exported_csv_file, $test_dir . "/expected_test_results/export_more_fields", $update_expected_results);


done_testing();
