#!/usr/bin/perl -w

# Import a CSV file

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

my @tests = (
	{
		test_case => "test",
		csv_files => ["test.csv"],
	},
	{
		test_case => "replace_existing_values",
		csv_files => ["replace_existing_values_1.csv", "replace_existing_values_2.csv"],

	}
);

# Testing import of a csv file
foreach my $test_ref (@tests) {

	my $import_module = Test::MockModule->new('ProductOpener::Import');

	# mock download image to fetch image in inputs_dir
	$import_module->mock('download_image', \&fake_download_image);

	# clean data
	remove_all_products();
	# import csv can create some organizations if they don't exist, remove them
	remove_all_orgs();

	# expected results
	my $test_case = $test_ref->{test_case};
	my $expected_test_results_dir = $expected_results_dir . "/" . $test_case;
	my $outputs_test_dir = $outputs_dir . "/" . $test_case;
	make_path($outputs_test_dir);
	my $stats_ref;

	# inputs
	foreach my $csv (@{$test_ref->{csv_files}}) {

		my $csv_file = $inputs_dir . $csv;

		# import file
		my $datestring = localtime();
		my $args = {
			"user_id" => "test-user",
			"org_id" => "test-org",
			"owner_id" => "org-test-org",
			"csv_file" => $csv_file,
			"exported_t" => $datestring,
		};

		# run import_csv_file
		print STDERR "Running ProductOpener::Import::import_csv_file and capturing its output\n";

		# Note: if the code executed by capture_outputs() dies, the test will end without showing why/where it died.
		my ($out, $err) = capture_ouputs(
			sub {
				$stats_ref = ProductOpener::Import::import_csv_file($args);
			}
		);
		print STDERR "ProductOpener::Import::import_csv_file - done \n";

	}
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
	compare_array_to_expected_results(\@products, $expected_test_results_dir, $update_expected_results);

	# also verify sto
	if (!$update_expected_results) {
		my @sto_products = ();
		foreach my $product (@products) {
			push(@sto_products, retrieve_product($product->{code}));
		}
		normalize_products_for_test_comparison(\@sto_products);
		compare_array_to_expected_results(\@products, $expected_test_results_dir, $update_expected_results);
	}

	compare_to_expected_results($stats_ref, $expected_test_results_dir . "/stats.json", $update_expected_results);

	# TODO verify images
}

done_testing();
