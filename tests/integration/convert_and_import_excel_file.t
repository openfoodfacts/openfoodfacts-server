#!/usr/bin/perl -w

# This test first convert an Excel files to CSV, then imports it.

use Modern::Perl '2017';

use Log::Any::Adapter 'TAP';
use Mock::Quick qw/qobj qmeth/;
use Test::MockModule;
use Test::More;

use File::Path qw/make_path remove_tree/;

use ProductOpener::Config '$data_root';
use ProductOpener::Data qw/execute_query get_products_collection/;
use ProductOpener::Producers qw/load_csv_or_excel_file convert_file/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products "retrieve_product";
use ProductOpener::Store "store";
use ProductOpener::Test qw/:all/;
use ProductOpener::LoadData qw/:all/;

load_data();

my ($test_id, $test_dir, $expected_results_dir, $update_expected_results) = (init_expected_results(__FILE__));
my $inputs_dir = "$test_dir/inputs/$test_id/";
my $outputs_dir = "$test_dir/outputs/$test_id/";

# fake image download using input directory instead of distant server
sub fake_download_image ($) {
	my $image_url = shift;

	my $fname = (split(m|/|, $image_url))[-1];
	my $image_path = $inputs_dir . $fname;
	my $response = qobj(
		is_success => qmeth {return (-e $image_path);},
		decoded_content => qmeth {
			open(my $image, "<", $image_path);
			binmode($image);
			read $image, my $content, -s $image;
			close $image;
			return $content;
		},
	);
	return $response;
}

my @tests = (
	{
		id => "test",
		excel_file => "test.xlsx",
		columns_fields_json => "test.columns_fields.json",
		default_values => {lc => "en", countries => "en", brands => "Default brand"},
	},
	{
		id => "packagings-mousquetaires",
		excel_file => "packagings-mousquetaires.xlsx",
		columns_fields_json => "packagings-mousquetaires.columns_fields.json",
		default_values => {lc => "fr", countries => "fr"},
	},
	{
		id => "carrefour-images",
		excel_file => "carrefour-images.csv",
		columns_fields_json => "carrefour-images.columns_fields.json",
		default_values => {lc => "fr", countries => "fr"},
	}
);

# Testing import of a csv file
foreach my $test_ref (@tests) {

	my $import_module = Test::MockModule->new('ProductOpener::Import');

	# mock download image to fetch image in inputs_dir
	$import_module->mock('download_image', \&fake_download_image);

	# inputs
	my $excel_file = $inputs_dir . $test_ref->{excel_file};
	my $columns_fields_json = $inputs_dir . $test_ref->{columns_fields_json};

	# expected results
	my $test_case = $test_ref->{id};
	my $expected_test_results_dir = $expected_results_dir . "/" . $test_case;
	my $outputs_test_dir = $outputs_dir . "/" . $test_case;
	make_path($outputs_test_dir);

	# clean data
	remove_all_products();
	# import csv can create some organizations if they don't exist, remove them
	remove_all_orgs();

	# step1: parse xls
	my ($out, $err, $csv_result) = capture_ouputs(
		sub {
			return scalar load_csv_or_excel_file($excel_file);
		}
	);
	ok(!$csv_result->{error});

	# step2: get columns match
	my $default_values_ref = $test_ref->{default_values} // {};

	# this is the file we need
	my $columns_fields_file = $outputs_test_dir . "/test.columns_fields.sto";
	create_sto_from_json($columns_fields_json, $columns_fields_file);

	# step3 convert file
	my $converted_file = $outputs_test_dir . "/test.converted.csv";
	my $conv_results_ref = convert_file($default_values_ref, $excel_file, $columns_fields_file, $converted_file);

	# Compare the converted CSV file to the expected CSV file
	ensure_expected_results_dir($expected_test_results_dir . "/converted_csv", $update_expected_results);
	compare_csv_file_to_expected_results($converted_file, $expected_test_results_dir . "/converted_csv",
		$update_expected_results, "$test_case - convert csv");
	compare_to_expected_results($conv_results_ref,
		$expected_test_results_dir . "/converted_csv/conversion_results.json",
		$update_expected_results, {id => "$test_case - convert"});

	# step4 import file
	my $datestring = localtime();
	my $args = {
		"user_id" => "test-user",
		"org_id" => "test-org",
		"owner_id" => "org-test-org",
		"csv_file" => $converted_file,
		"exported_t" => $datestring,
		"images_download_dir" => $outputs_test_dir . "/images",
	};

	# we need to put $outputs_test_dir in base paths to have ensure_dir_created working
	$BASE_DIRS{TEST_DL_IMAGES_DIR} = $outputs_dir;

	my $stats_ref;

	# run
	$stats_ref = ProductOpener::Import::import_csv_file($args);

	# get all products in db, sorted by code for predictability
	my $cursor = execute_query(
		sub {
			return get_products_collection()->query({})->sort({code => 1});
		}
	);
	my @products = ();
	while (my $doc = $cursor->next) {
		push(@products, $doc);
	}

	# clean
	normalize_products_for_test_comparison(\@products);

	# verify result
	compare_array_to_expected_results(\@products, $expected_test_results_dir . "/products",
		$update_expected_results, "$test_case - import");

	# also verify sto
	if (!$update_expected_results) {
		my @sto_products = ();
		foreach my $product (@products) {
			push(@sto_products, retrieve_product($product->{code}));
		}
		normalize_products_for_test_comparison(\@sto_products);
		compare_array_to_expected_results(\@products, $expected_test_results_dir . "/products",
			$update_expected_results, "$test_case - import sto");
	}

	compare_to_expected_results($stats_ref, $expected_test_results_dir . "/products/stats.json",
		$update_expected_results, {id => "$test_case - import stats"});

	# TODO verify images
	# clean csv and sto
	unlink $inputs_dir . "eco-score-template.xlsx.csv";
	unlink $inputs_dir . "test.columns_fields.sto";
	rmdir remove_tree($outputs_dir);
}

delete($BASE_DIRS{TEST_DL_IMAGES_DIR});

done_testing();
