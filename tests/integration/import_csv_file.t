#!/usr/bin/perl -w

use Modern::Perl '2017';

use Log::Any::Adapter 'TAP';
use Mock::Quick qw/qobj qmeth/;
use Test::MockModule;
use Test::More;

use File::Path qw/make_path remove_tree/;

use ProductOpener::Config '$data_root';
use ProductOpener::Data qw/execute_query get_products_collection/;
use ProductOpener::Producers qw/load_csv_or_excel_file convert_file/;
use ProductOpener::Products "retrieve_product";
use ProductOpener::Store "store";
use ProductOpener::Test qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (
	init_expected_results(__FILE__)
);
my $inputs_dir = "$test_dir/inputs/$test_id/";
my $outputs_dir = "$test_dir/outputs/$test_id";
make_path($outputs_dir);


# fake image download using input directory instead of distant server
sub fake_download_image ($) {
	my $image_url = shift;

	my $fname = (split(m|/|, $image_url))[-1];
	my $image_path = $inputs_dir . $fname;
	my $response = qobj(
		is_success => qmeth {return (-e $fname);},
		decoded_content => qmeth {
			open(my $image, "<r", $fname);
			my $content = <$image>;
			close $image;
			return $content;
		},
	);
	return $response;
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
	# import csv can create some organizations if they don't exist, remove them
	remove_all_orgs();

	# step1: parse xls
	my ($out, $err, $csv_result) = capture_ouputs(
		sub {
			return scalar load_csv_or_excel_file($my_excel);
		}
	);
	ok(!$csv_result->{error});

	# step2: get columns match
	my $default_values_ref = {lc => "en", countries => "en"};

	# this is the file we need
	my $columns_fields_file = $outputs_dir . "test.columns_fields.sto";
	create_sto_from_json($columns_fields_json, $columns_fields_file);

	# step3 convert file
	my $converted_file = $outputs_dir . "test.converted.csv";
	my $conv_result;
	($out, $err, $conv_result) = capture_ouputs(
		sub {
			return scalar convert_file($default_values_ref, $my_excel, $columns_fields_file, $converted_file);
		}
	);
	ok(!$conv_result->{error});

	# step4 import file
	my $datestring = localtime();
	my $args = {
		"user_id" => "test-user",
		"org_id" => "test-org",
		"owner_id" => "org-test-org",
		"csv_file" => $converted_file,
		"exported_t" => $datestring,
	};

	my $stats_ref;

	# run
	($out, $err) = capture_ouputs(
		sub {
			$stats_ref = ProductOpener::Import::import_csv_file($args);
		}
	);

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
	compare_array_to_expected_results(\@products, $expected_result_dir, $update_expected_results);

	# also verify sto
	if (!$update_expected_results) {
		my @sto_products = ();
		foreach my $product (@products) {
			push(@sto_products, retrieve_product($product->{code}));
		}
		normalize_products_for_test_comparison(\@sto_products);
		compare_array_to_expected_results(\@products, $expected_result_dir, $update_expected_results);
	}

	compare_to_expected_results($stats_ref, $expected_result_dir . "/stats.json", $update_expected_results);

	# TODO verify images
	# clean csv and sto
	unlink $inputs_dir . "eco-score-template.xlsx.csv";
	unlink $inputs_dir . "test.columns_fields.sto";
	rmdir remove_tree($outputs_dir);
}

done_testing();
