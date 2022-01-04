#!/usr/bin/perl -w

use Modern::Perl '2017';

use Log::Any::Adapter 'TAP';
use Mock::Quick qw/qobj qmeth/;
use IO::Capture::Stdout::Extended;
use IO::Capture::Stderr::Extended;
use JSON "decode_json";
use Test::Deep qw/cmp_deeply supersetof/;
use Test::MockModule;
use Test::More;
use Test::Number::Delta;

use List::MoreUtils "each_array";
use File::Basename "dirname";
use File::Path qw/make_path remove_tree/;
use Path::Tiny qw/path/;

use ProductOpener::Config '$data_root';
use ProductOpener::Data qw/execute_query get_products_collection/;
use ProductOpener::Producers qw/load_csv_or_excel_file convert_file/;
use ProductOpener::Products "retrieve_product";
use ProductOpener::Store "store";

my $inputs_dir = dirname(__FILE__) . "/inputs/import_csv_file/";
my $expected_dir = dirname(__FILE__) . "/expected_test_results/import_csv_file/";
my $outputs_dir = dirname(__FILE__) . "/outputs/import_csv_file";
make_path($outputs_dir);

# capturing out / err with Stdout/Stderr::Extended
# while following Capture::Tiny style
sub capture ($) {
    my $meth = shift;
    my $out = IO::Capture::Stdout::Extended->new();
    my $err = IO::Capture::Stderr::Extended->new();
    $out->start();
    $err->start();
    # call in array context
    my @result = $meth -> ();
    $out ->stop();
    $err ->stop();
    return ($out, $err, @result);
}

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

# create a sto columns file from a json structure
sub create_sto_from_json ($$) {
    my $json_path = shift;
    my $sto_path = shift;
    my $data = decode_json(path($json_path)->slurp_raw());
    store($sto_path, $data);
}

sub remove_all_products () {
    # check we are not on a prod database, by checking there are not more than 100 products
    my $products_count = execute_query(sub {
		return get_products_collection()->count_documents({});
	});
    unless ((0 <= $products_count) && ($products_count < 100)) {
        die("Refusing to run destructive test on a DB of more than 100 items");
    }
    # clean database
    execute_query(sub {
		return get_products_collection()->delete_many({});
	});
    # clean files
    remove_tree("$data_root/products", {keep_root => 1, error => \my $err});
    if (@$err) {
        die("not able to remove some products directories: ". join(":", @$err));
    }
}

# deeply copy item1 but only keeping keys of item2
# this prepare a match with cmp_deeply whith an intentionally incomplete object
# this does not support extracting key on deep objects in a bag or set (from Test::Deep)
sub deep_extract_keys_from($$) {
    my ($item1, $item2) = @_;
    my $result = $item1;  # default is no transformation
    if ((ref $item1 eq ref {}) && (ref $item2 eq ref {})) {
        # only keeps keys in item2
        $result = {};
        for my $key (keys %$item2) {
            $result->{$key} = deep_extract_keys_from($item1->{$key}, $item2->{$key});
        }
    }
    if ((ref $item1 eq ref []) && (ref $item2 eq ref []) && (scalar @$item1 == scalar @$item2)) {
        # note that the case where $item2 is a bag/set is not (yet?) supported
        $result = [];
        my $iterator = each_array(@$item1, @$item2);
        while ( my ($value1, $value2) = $iterator->() ) {
            push @$result, deep_extract_keys_from($value1, $value2);
        }
    }
    # Note: if $item1 and $item2 does not have same type, 
    # leave item1 as is, deep comparison will fail
    return $result
}


# Testing import of a csv file
{
    my $import_module = new Test::MockModule('ProductOpener::Import');
    # mock download image to fetch image in inputs_dir
    $import_module->mock('download_image', \&fake_download_image);
    # inputs
    my $my_excel = $inputs_dir . "test.xlsx";
    my $columns_fields_json = $inputs_dir . "test.columns_fields.json";
    my $expected_products_path = $expected_dir . "test_products.perl";
    # clean data
    remove_all_products();
    # step1: parse xls
    my ($out, $err, $csv_result) = capture (sub {
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
    ($out, $err, $conv_result) = capture (sub {
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
    ($out, $err) = capture (sub {
        ProductOpener::Import::import_csv_file($args);
    });
    # get all products in db, sorted by code for perdictability
    my $cursor = execute_query(sub {
		return get_products_collection()->query({})->sort({code =>1});
	});
    my @products = ();
    while ( my $doc = $cursor->next ) {
        push(@products, $doc);
    }
    # expected values
    ## no critic (ProhibitStringyEval)
    my $expected_products = eval(path($expected_products_path)->slurp_raw());
    ## use critic
    # same number of products
    is(scalar @products, scalar @$expected_products, , "As much expected produts as in db");
    my $items_iter = each_array(@products, @$expected_products);
    while ( my ($product, $expected_product) = $items_iter->() )
    {
        # load from sto
        my $product_obj = retrieve_product($product->{code});
        # values are those expected
        my $cmp_product = deep_extract_keys_from($product, $expected_product);
        cmp_deeply(
            $cmp_product,
            $expected_product,
            "Product " . $product->{code} . " from mongo equals expected",
        );
        my $cmp_product_obj = deep_extract_keys_from($product_obj, $expected_product);
        cmp_deeply(
            $cmp_product_obj,
            $expected_product,
            "Product " . $product->{code} . " from sto equals expected",
        );
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