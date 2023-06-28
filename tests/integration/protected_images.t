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

# Create an admin
my $admin_ua = new_client();
my $resp = create_user($admin_ua, \%admin_user_form);
ok(!html_displays_error($resp));

# Create a normal user
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
$resp = create_user($ua, \%create_user_args);
ok(!html_displays_error($resp));

# Create a moderator
my $moderator_ua = new_client();
$resp = create_user($moderator_ua, \%moderator_user_form);
ok(!html_displays_error($resp));

#Create a producer
my $producer_ua = new_client();
$resp = create_user($producer_ua, \%producer_user_form);
ok(!html_displays_error($resp));

# Admin gives moderator status
my %moderator_edit_form = (
	%moderator_user_form,
	user_group_moderator => "1",
	type => "edit",
);
$resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp));

# Create some products

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
	nutrition_facts_image => "image_nutrition",
	packager_codes_image => "image_packager",
	ingredients_image => "image_ingredients",
	packaging_image => "image_packaging",
	front_image => "image_front",
);

my @products = (
	{
		%{dclone(\%default_product_form)},
		%{dclone(\%product_form)},
		(
			code => '0200000000034',
			product_name => "An unprotected product",
		)
	},
	{
		%{dclone(\%default_product_form)},
		%{dclone(\%product_form)},
		(
			code => '0200000000035',
			product_name => "A protected product",
		)
	},
	{
		%{dclone(\%default_product_form)},
		%{dclone(\%product_form)},
		(
			code => '0200000000134',
			product_name => "An unprotected product",
		)
	},
	{
		%{dclone(\%default_product_form)},
		%{dclone(\%product_form)},
		(
			code => '0200000000135',
			product_name => "A protected product",
		)
	},
	{
		%{dclone(\%default_product_form)},
		%{dclone(\%product_form)},
		(
			code => '0200000000235',
			product_name => "A protected product",
		)
	},
	{
		%{dclone(\%default_product_form)},
		%{dclone(\%product_form)},
		(
			code => '0200000000335',
			product_name => "A protected product",
		)
	},
);

# create the products in the database
foreach my $product_form_override (@products) {
	edit_product($ua, $product_form_override);
}

# Declare which fields have been sent by an owner and should be protected
for my $code ('0200000000035', '0200000000135') {
	my $product_ref = retrieve_product($code);
	$product_ref->{owner_fields} = {
		"categories" => 1680183938,
		"labels" => 1680183938,
		"brands" => 1680183938,
		"product_name_en" => 1680183938,
		"generic_name_en" => 1680183938,
		"ingredients_text_en" => 1680183938,
		"energy-kj" => 1680183938,
		"fat" => 1680183938,
		"proteins" => 1680183938,
		"quantity" => 1680183938,
		"nutrition_facts_image" => 1680183938,
		"packager_codes_image" => 1680183938,
		"ingredients_image" => 1680183938,
		"packaging_image" => 1680183938,
		"front_image" => 1680183938,
	};
	store_product("organization-owner", $product_ref, "protecting the product");
}

# Note: expected results are stored in json files, see execute_api_tests
# Each test is composed of two test case:
# 1. one that edits a product,
# 2. one that gets the product to verify if it was edited or protected

my $tests_ref = [

	# Test with /cgi/product_image_upload.pl
	{
		test_case => 'select-image-unprotected-product-api-v2',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			cc => 'be',
			lc => 'fr',
			code => '0200000000034',
			field => 'front_image',
			imagefield => 'front',
		},

	},
	{
		test_case => 'get-selected-image-unprotected-product-api-v2',
		method => 'GET',
		path => '/api/v2/product/0200000000034',
	},

	{
		test_case => 'select-image-protected-product-api-v2',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			cc => 'be',
			lc => 'fr',
			code => '0200000000035',
			field => 'front_image',
			imagefield => 'front',
		},

	},
	{
		test_case => 'get-selected-image-protected-product-api-v2',
		method => 'GET',
		path => '/api/v2/product/0200000000035',
	},

	# Test with the /cgi/product.pl web form
	{
		test_case => 'select-image-unprotected-product-web-form',
		method => 'POST',
		path => '/cgi/product.pl',
		form => {
			cc => 'be',
			lc => 'fr',
			code => '0200000000134',
			field => 'front_image',
			imagefield => 'front',
		},
		expected_type => 'html',
	},
	{
		test_case => 'get-selected-image-unprotected-product-web-form',
		method => 'GET',
		path => '/api/v2/product/0200000000134',
	},

	{
		test_case => 'select-image-protected-product-web-form',
		method => 'POST',
		path => '/cgi/product.pl',
		form => {
			cc => 'be',
			lc => 'fr',
			code => '0200000000135',
			field => 'front_image',
			imagefield => 'front',
		},
		expected_type => 'html',
		response_content_must_not_match => "Erreur",
	},
	{
		test_case => 'get-selected-image-protected-product-web-form',
		method => 'GET',
		path => '/api/v2/product/0200000000135',
	},

	# Select image for a protected product (by a moderator)
	{
		test_case => 'select-image-protected-product-api-v2-moderator',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			cc => 'be',
			lc => 'fr',
			code => '0200000000235',
			field => 'front_image',
			imagefield => 'front',
		},
		ua => $moderator_ua,
	},
	{
		test_case => 'get-selected-image-protected-product-api-v2-moderator',
		method => 'GET',
		path => '/api/v2/product/0200000000235',
	},

	{
		test_case => 'select-image-protected-product-web-form-moderator',
		method => 'POST',
		path => '/cgi/product.pl',
		form => {
			cc => 'be',
			lc => 'fr',
			code => '0200000000335',
			field => 'front_image',
			imagefield => 'front',
		},
		ua => $moderator_ua,
		expected_type => 'html',
		response_content_must_not_match => "Erreur",
	},
	{
		test_case => 'get-selected-image-protected-product-web-form-moderator',
		method => 'GET',
		path => '/api/v2/product/0200000000335',
	},

];

# Note: some tests override $ua with $moderator_ua
execute_api_tests(__FILE__, $tests_ref, $ua);

done_testing();
