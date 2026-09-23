#!/usr/bin/perl -w

# Import a CSV file

use ProductOpener::PerlStandards;

use Log::Any::Adapter 'TAP';
use Mock::Quick qw/qobj qmeth/;
use Test2::V0;
use HTTP::Headers;
use HTTP::Response;

use File::Path qw/make_path remove_tree/;

use ProductOpener::Config '$data_root';
use ProductOpener::Data qw/execute_query get_products_collection/;
use ProductOpener::Producers qw/load_csv_or_excel_file convert_file/;
use ProductOpener::Products "retrieve_product";
use ProductOpener::Store "store";
use ProductOpener::Test qw/:all/;
use ProductOpener::LoadData qw/load_data/;

load_data();

my ($test_id, $test_dir, $expected_results_dir, $update_expected_results) = (init_expected_results(__FILE__));
my $inputs_dir = "$test_dir/inputs/$test_id/";
my $outputs_dir = "$test_dir/outputs/$test_id/";

# fake image download using input directory instead of distant server
sub fake_download_image ($image_url) {

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

# fake LWP::UserAgent::get for the Google Drive end-to-end tests below: unlike fake_download_image,
# this leaves the real download_image() (and its Drive virus-scan-interstitial retry logic) in
# place, and only fakes the underlying HTTP layer - so the retry wiring itself gets exercised,
# not just the final result.
# First call (no &confirm= yet) returns the "can't scan this file for viruses" interstitial page
# (in the form-based format Google Drive currently uses); the second call (after download_image()
# retries against the form's action url) returns the real image.
sub fake_lwp_get_virus_scan_retry {
	my ($ua, $url, @headers) = @_;
	if ($url =~ m{^https://drive\.usercontent\.google\.com/download\?}) {
		my $image_path = $inputs_dir . "uc?export=download&id=1cwIDauHR8svuiLDgzfxoW89TSMLm0Am0";
		open(my $image, "<", $image_path);
		binmode($image);
		read $image, my $content, -s $image;
		close $image;
		return HTTP::Response->new(200, "OK", HTTP::Headers->new(Content_Type => "image/png"), $content);
	}
	else {
		return HTTP::Response->new(200, "OK", HTTP::Headers->new(Content_Type => "text/html; charset=utf-8"),
				  '<form id="download-form" action="https://drive.usercontent.google.com/download" method="get">'
				. '<input type="submit" id="uc-download-link" value="Download anyway"/>'
				. '<input type="hidden" name="id" value="1cwIDauHR8svuiLDgzfxoW89TSMLm0Am0">'
				. '<input type="hidden" name="export" value="download">'
				. '<input type="hidden" name="confirm" value="t">'
				. '<input type="hidden" name="uuid" value="087411e0-09cb-41b9-9bd4-514f70f0f303"></form>');
	}
}

# fake LWP::UserAgent::get for a private/deleted Google Drive file: Drive returns a "you need
# permission" HTML page (no confirm token to retry with) for every request, on both the rewritten
# uc? URL and the original view URL fallback - so download_image() never retries, and the product
# should end up with no image at all.
sub fake_lwp_get_permission_denied {
	my ($ua, $url, @headers) = @_;
	return HTTP::Response->new(
		200, "OK",
		HTTP::Headers->new(Content_Type => "text/html; charset=utf-8"),
		'<html><body>You need permission to access this file.</body></html>'
	);
}

my @tests = (
	{
		test_case => "test",
		csv_files => ["test.csv"],
	},
	{
		test_case => "replace_existing_values",
		csv_files => ["replace_existing_values_1.csv", "replace_existing_values_2.csv"],
	},
	{
		test_case => "old_nutrition",
		csv_files => ["old_nutrition.csv"],
	},
	{
		test_case => "new_nutrition",
		csv_files => ["new_nutrition.csv"],
	},
	{
		test_case => "agena",
		csv_files => ["agena.csv"],
	},
	{
		test_case => "new_tags",
		csv_files => ["new_tags_1.csv"]
	},
	# Update with empty values in tag fields, should not change the initial values
	{
		test_case => "new_tags_empty_values",
		csv_files => ["new_tags_1.csv", "new_tags_2_empty_values.csv"]
	},
	# Update with '-( values in tag fields, should remove the initial values
	{
		test_case => "new_tags_dash_values",
		csv_files => ["new_tags_1.csv", "new_tags_3_dash_values.csv"]
	},
	# Updates
	# Update with empty values in tag fields, should not change the initial values
	{
		test_case => "new_tags_updates",
		csv_files => ["new_tags_1.csv", "new_tags_4_updates.csv"]
	},
	# A Google Drive "view" share link should be rewritten to a direct-download link
	# and the image downloaded, instead of being dropped because the link returns an HTML page
	# https://github.com/openfoodfacts/openfoodfacts-server/issues/14308
	{
		test_case => "google_drive_image",
		csv_files => ["google_drive_image.csv"],
	},
	# End-to-end test of the virus-scan-interstitial retry: unlike the test case above, this one
	# lets the real download_image() run (only the HTTP layer is faked), to check the confirm-token
	# retry actually results in a saved, assigned image - not just that the extraction helper works.
	{
		test_case => "google_drive_image_virus_scan_retry",
		csv_files => ["google_drive_image_virus_scan_retry.csv"],
		mock_lwp_get => \&fake_lwp_get_virus_scan_retry,
	},
	# A private/deleted Google Drive file: the product should be imported but end up with no image,
	# instead of an HTML error page being saved as if it were the product photo.
	{
		test_case => "google_drive_image_permission_denied",
		csv_files => ["google_drive_image_permission_denied.csv"],
		mock_lwp_get => \&fake_lwp_get_permission_denied,
	},
);

# Testing import of a csv file
foreach my $test_ref (@tests) {

	# Most test cases mock download_image() away entirely (fake_download_image) and just serve a
	# fixture file. A few Google Drive test cases instead mock LWP::UserAgent's get(), so the real
	# download_image() - including its Drive-specific retry logic - actually runs.
	my ($import_module, $ua_module);
	if (defined $test_ref->{mock_lwp_get}) {
		$ua_module = mock 'LWP::UserAgent' => (override => [get => $test_ref->{mock_lwp_get}]);
	}
	else {
		$import_module = mock 'ProductOpener::Import' => (
			override => [
				# mock download image to fetch image in inputs_dir
				'download_image' => \&fake_download_image
			]
		);
	}

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

	# images_download_dir persists across test runs (it lives under a Docker volume),
	# clear it so a downloaded image from a previous run doesn't hit Import.pm's
	# "image already downloaded" reuse path instead of the fresh-download path we want to test
	my $images_download_dir = "$data_root/tmp/tests/$test_id/$test_case/images";
	remove_tree($images_download_dir, {safe => 1});

	# inputs
	foreach my $csv (@{$test_ref->{csv_files}}) {

		my $csv_file = $inputs_dir . $csv;

		# import file
		my $datestring = localtime();
		my $args = {
			"lc" => "fr",
			"user_id" => "test-user",
			"org_id" => "test-org",
			"owner_id" => "org-test-org",
			"csv_file" => $csv_file,
			"exported_t" => $datestring,
			# images_download_dir must be under one of the base directories in ProductOpener::Paths,
			# otherwise ensure_dir_created() (called by Import.pm) refuses to create it
			"images_download_dir" => $images_download_dir,
		};

		# run import_csv_file
		print STDERR "Running ProductOpener::Import::import_csv_file and capturing its output\n";

		# Note: if the code executed by capture_outputs() dies, the test will end without showing why/where it died.
		my ($out, $err) = capture_outputs(
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
