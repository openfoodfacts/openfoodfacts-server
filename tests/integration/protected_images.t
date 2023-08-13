#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();
my $sample_products_images_path = dirname(__FILE__) . "/inputs/upload_images";

# Create an owner
my $owner_ua = new_client();
my %create_user_argss = (%default_user_form, (name => 'sample-owner', userid => "sample-owner"));
my $resp = create_user($owner_ua, \%create_user_argss);
ok(!html_displays_error($resp));

# Create a normal user
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
$resp = create_user($ua, \%create_user_args);
ok(!html_displays_error($resp));

my %product_form = (
	generic_name => "A generic name",
	ingredients_text => "apple, milk, eggs, palm oil",
	categories => "some unknown category",
	labels => "organic",
	origin => "france",
	brands => "Test brand",
	packaging_text_en =>
		"1 wooden box to recycle, 6 25cl glass bottles to reuse, 3 steel lids to recycle, 1 plastic film to discard",
	'nutriment_energy-kj' => 10,
	nutriment_fat => 5,
	nutriment_proteins => 2,
	quantity => "90g",
);

my @products = (
	{
		%{dclone(\%default_product_form)},
		%{dclone(\%product_form)},
		(
			code => '0900000000139',
			product_name => "A test product",
		)
	},
);
# create the products in the database
foreach my $product_form_override (@products) {
	edit_product($owner_ua, $product_form_override);
}

# Setting the owner of the product
my $product_ref = retrieve_product('0900000000139');
$product_ref->{owner} = "sample-owner", store_product("sample-owner", $product_ref, "protecting image");

my $tests_ref = [

	{
		test_case => 'post-protected-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {

			code => '0900000000139',
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/pulses-cereals.jpg", 'pulses-cereals.jpg'],
		},
		ua => $owner_ua,
		expected_status => 200,
	},

	{
		test_case => 'post-select-protected-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => '0900000000139',
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/1.jpg", '1.jpg'],
		},
		ua => $ua,
	},
	{
		test_case => 'get-protected-image',
		method => 'GET',
		path => '/api/v2/product/0900000000139?fields=images,owner,selected_images',
	},

];

execute_api_tests(__FILE__, $tests_ref, $ua);

done_testing();
