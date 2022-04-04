#!/usr/bin/perl -w

use Modern::Perl '2017';

use Getopt::Long qw/GetOptions/;
use Log::Any::Adapter 'TAP';
use Mock::Quick qw/qobj qmeth/;
use Test::MockModule;
use Test::More;

use Data::DeepAccess qw(deep_exists deep_get deep_set);
use File::Basename "dirname";
use File::Path qw/make_path remove_tree/;

use ProductOpener::Config '$data_root';
use ProductOpener::Data qw/execute_query get_products_collection/;
use ProductOpener::Producers qw/load_csv_or_excel_file convert_file/;
use ProductOpener::Products "retrieve_product";
use ProductOpener::Store "store";
use ProductOpener::Test qw/:all/;


my $test_id = "import_csv_file";
my $test_dir = dirname(__FILE__);
my $inputs_dir = "$test_dir/inputs/$test_id/";
my $expected_dir = "$test_dir/expected_test_results/$test_id/";
my $outputs_dir = "$test_dir/outputs/$test_id";
make_path($outputs_dir);

my $usage = <<TXT

The expected results of the tests are saved in $test_dir/expected_test_results/$test_id

To verify differences and update the expected test results,
actual test results can be saved by passing --update-expected-results

The directory will be created if it does not already exist.

TXT
;


my $update_expected_results;

GetOptions ("update-expected-results"   => \$update_expected_results)
  or die("Error in command line arguments.\n\n" . $usage);

# fake image download using input directory instead of distant server
sub fake_download_image ($) {
    my $image_url = shift;

    my $fname = (split(m|/|, $image_url))[-1];
    my $image_path = $inputs_dir . $fname;
    my $response = qobj(
        is_success => qmeth { return (-e $fname); },
        decoded_content => qmeth {
            open(my $image, "<r", $fname);
            my $content = <$image>;
            close $image;
            return $content;
        },
    );
    return $response;
}


# fields we don't want to check for they vary from test to test
my @fields_ignore_content = qw(last_modified_t created_t owner_fields sources.0.import_t);
# fields that are array and need to sort to have predictable results
my @fields_sort = qw(_keywords);


# clean products fields that we can't check because they change over runs
# we may still add some test on those fields here
sub clean_products_fields($) {
    my $array_ref = shift;

    my @missing_fields = ();

    for my $product (@$array_ref) {
        my $code = $product->{code};
        my @key;
        for my $field_ic (@fields_ignore_content) {
            @key = split(/\./, $field_ic);
            if (!deep_exists($product, @key)) {
                push(@missing_fields, ($code, $field_ic));
            } else {
                deep_set($product, @key, "--ignore--");
            }
        }
        for my $field_s (@fields_sort) {
            @key = split(/\./, $field_s);
            if (!deep_exists($product, @key)) {
                push(@missing_fields, ($code, $field_s));
            } else {
                my @sorted = sort @{deep_get($product, @key)};
                deep_set($product, @key, \@sorted);
            }
        }
    }
    if (@missing_fields) {
        fail(
            "Some fields are missing on objects:\n" .
            join("\n- ", map {join(" - ", @$_)} @missing_fields)
        );
    }
}


# Testing import of a csv file
{
    my $import_module = Test::MockModule->new('ProductOpener::Import');
    # mock download image to fetch image in inputs_dir
    $import_module->mock('download_image', \&fake_download_image);
    # inputs
    my $my_excel = $inputs_dir . "test.xlsx";
    my $columns_fields_json = $inputs_dir . "test.columns_fields.json";
    # clean data
    remove_all_products();
    # step1: parse xls
    my ($out, $err, $csv_result) = capture_ouputs (sub {
        return scalar load_csv_or_excel_file($my_excel);
    });
    ok( !$csv_result->{error} );
    # step2: get columns match
    my $default_values_ref = {lc => "en", countries => "en"};
    # this is the file we need
    my $columns_fields_file = $outputs_dir . "test.columns_fields.sto";
    create_sto_from_json($columns_fields_json, $columns_fields_file);
    # step3 convert file
    my $converted_file = $outputs_dir . "test.converted.csv";
    my $conv_result;
    ($out, $err, $conv_result) = capture_ouputs (sub {
        return scalar convert_file(
            $default_values_ref, $my_excel, $columns_fields_file, $converted_file
        );
    });
    ok( !$conv_result->{error} );
    # step4 import file
    my $datestring = localtime();
    my $args = {
        "user_id" => "test-user",
        "org_id" => "test-org",
        "owner_id" => "org-test-org",
        "csv_file" => $converted_file,
        "exported_t" => $datestring,
    };
    # run
    ($out, $err) = capture_ouputs (sub {
        ProductOpener::Import::import_csv_file($args);
    });
    # get all products in db, sorted by code for perdictability
    my $cursor = execute_query(sub {
		return get_products_collection()->query({})->sort({code => 1});
	});
    my @products = ();
    while ( my $doc = $cursor->next ) {
        push(@products, $doc);
    }
    # clean
    clean_products_fields(\@products);
    # verify result
    compare_array_to_expected_results(\@products, $expected_dir, $update_expected_results);
    # also verify sto
    if (! $update_expected_results) {
        my @sto_products = ();
        foreach my $product (@products) {
            push(@sto_products, retrieve_product($product->{code}));
        }
        clean_products_fields(\@sto_products);
        compare_array_to_expected_results(\@products, $expected_dir, $update_expected_results);
    }

    # TODO check outputs ? for
    # import done
    # 1 products
    # 1 new products
    # 0 skipped not existing products
    # 0 skipped no images products
    # 0 existing products
    # 0 differing values
    # 1 products with edited nutrients
    # 1 products with edited fields or nutrients
    # 1 products updated

    # TODO verify images
    # clean csv and sto
    unlink $inputs_dir . "eco-score-template.xlsx.csv";
    unlink $inputs_dir . "test.columns_fields.sto";
    rmdir remove_tree($outputs_dir);
}

done_testing();