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
use ProductOpener::Test
	qw/compare_csv_file_to_expected_results init_expected_results remove_all_products remove_all_users/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::APITest qw/create_user execute_api_tests new_client wait_application_ready/;
use ProductOpener::TestDefaults qw/:all/;

use Getopt::Long;
use JSON;

use File::Basename "dirname";

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Remove all products

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

# Import test products

load_data();

my $import_args_ref = {
	user_id => "test",
	csv_file => dirname(__FILE__) . "/inputs/export/products.csv",
	no_source => 1,
};

my $stats_ref = import_csv_file($import_args_ref);

# Add some images to products

my $sample_products_images_path = dirname(__FILE__) . "/inputs/upload_images";

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

my $tests_ref = [
	{
		test_case => 'post-product-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "36613446535732",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/1.jpg", '1.jpg'],
		},
		expected_status_code => 200,
	},

	{
		test_case => 'post-product-image-2',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "3661344653573",
			imagefield => "other",
			imgupload_front_en => ["$sample_products_images_path/front_en.3.full.jpg", 'front_en.3.full.jpg'],
		},
		expected_status_code => 200,
	},

	# Select / crop images
	{
		test_case => 'post-product-image-crop',
		method => 'POST',
		path => '/cgi/product_image_crop.pl',
		form => {
			code => "3661344653573",    # Product had an image uploaded in a previous test
			id => "ingredients_fr",
			imgid => "1",
			angle => 0,
			x1 => 10,
			y1 => 20,
			x2 => 100,
			y2 => 200,
			coordinates_image_size => "full",
		},
		expected_status_code => 200,
	},

];

execute_api_tests(__FILE__, $tests_ref);

# Export products

my $query_ref = {};
my $separator = "\t";

# Export database script to generate CSV exports of the whole database
# Note: the test update seems to fail if the expected results files already exist.
# remove tests/integration/expected_test_results/export_database/ before updating expected results.
if ($update_expected_results) {
	#remove_tree($expected_result_dir . "/export_database");
}

# unlink CSV export if it exists, and launch script
my $csv_filename = "$BASE_DIRS{PUBLIC_DATA}/en.$server_domain.products.csv";
unlink($csv_filename) if -e $csv_filename;

my $script_out = `perl scripts/export_database.pl`;

ProductOpener::Test::compare_csv_file_to_expected_results($csv_filename, $expected_result_dir . "/export_database",
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
$export_args_ref->{export_nutrition_aggregated_set} = 1;
$export_args_ref->{include_images_paths} = 1;

export_csv($export_args_ref);

close($exported_csv);

ProductOpener::Test::compare_csv_file_to_expected_results($exported_csv_file,
	"${expected_result_dir}/export_more_fields",
	$update_expected_results, "csv-export-more-fields");

done_testing();
