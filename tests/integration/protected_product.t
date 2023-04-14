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
	};
	store_product("organization-owner", $product_ref, "protecting the product");
}

# Note: expected results are stored in json files, see execute_api_tests
# Each test is composed of two test case:
# 1. one that edits a product,
# 2. one that gets the product to verify if it was edited or protected

my $tests_ref = [
	# Test with the /cgi/product_jqm_multilingual.pl API v0/v2
	{
		test_case => 'edit-unprotected-product-api-v2',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',    # API v0/v2
		form => {
			cc => "be",
			lc => "fr",
			code => "0200000000034",
			product_name_en => "Changed product name",
			product_name_fr => "New French product name",
			categories => "Changed category",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '0.7',
			nutriment_salt_unit => 'mg',
			nutriment_fat => '12.7',
			nutriment_sugars => '7',
		}
	},
	{
		test_case => 'get-edited-unprotected-product-api-v2',
		method => 'GET',
		path => '/api/v2/product/0200000000034',
	},
	{
		test_case => 'edit-protected-product-api-v2',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',    # API v0/v2
		form => {
			cc => "be",
			lc => "fr",
			code => "0200000000035",
			product_name_en => "Changed product name",
			product_name_fr => "New French product name",
			categories => "Changed category",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '0.7',
			nutriment_salt_unit => 'mg',
			nutriment_fat => '12.7',
			nutriment_sugars => '7',
		}
	},
	{
		test_case => 'get-edited-protected-product-api-v2',
		method => 'GET',
		path => '/api/v2/product/0200000000035',
	},
	# Test with the /cgi/product.pl web form
	{
		test_case => 'edit-unprotected-product-web-form',
		method => 'POST',
		path => '/cgi/product.pl',
		form => {
			type => "edit",
			action => "process",
			sorted_langs => "en,fr",
			cc => "be",
			lc => "fr",
			code => "0200000000134",
			product_name_en => "Changed product name",
			product_name_fr => "New French product name",
			categories => "Changed category",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '0.7',
			nutriment_salt_unit => 'mg',
			nutriment_fat => '12.7',
			nutriment_sugars => '7',
		},
		expected_type => 'html',
	},
	{
		test_case => 'get-edited-unprotected-product-web-form',
		method => 'GET',
		path => '/api/v2/product/0200000000134',
	},
	{
		test_case => 'edit-protected-product-web-form',
		method => 'POST',
		path => '/cgi/product.pl',
		form => {
			type => "edit",
			action => "process",
			sorted_langs => "en,fr",
			cc => "be",
			lc => "fr",
			code => "0200000000135",
			product_name_en => "Changed product name",
			product_name_fr => "New French product name",
			categories => "Changed category",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '0.7',
			nutriment_salt_unit => 'mg',
			nutriment_fat => '12.7',
			nutriment_sugars => '7',
		},
		expected_type => 'html',
		response_content_must_not_match => "Erreur",
	},
	{
		test_case => 'get-edited-protected-product-web-form',
		method => 'GET',
		path => '/api/v2/product/0200000000135',
	},
	# Repeat the edition of protected products by a moderator
	{
		test_case => 'edit-protected-product-api-v2-moderator',
		method => 'POST',
		path => '/cgi/product_jqm_multilingual.pl',    # API v0/v2
		form => {
			cc => "be",
			lc => "fr",
			code => "0200000000235",
			product_name_en => "Changed product name",
			product_name_fr => "New French product name",
			categories => "Changed category",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '0.7',
			nutriment_salt_unit => 'mg',
			nutriment_fat => '12.7',
			nutriment_sugars => '7',
		},
		ua => $moderator_ua,
	},
	{
		test_case => 'get-edited-protected-product-api-v2-moderator',
		method => 'GET',
		path => '/api/v2/product/0200000000235',
	},
	{
		test_case => 'edit-protected-product-web-form-moderator',
		method => 'POST',
		path => '/cgi/product.pl',
		form => {
			type => "edit",
			action => "process",
			sorted_langs => "en,fr",
			cc => "be",
			lc => "fr",
			code => "0200000000335",
			product_name_en => "Changed product name",
			product_name_fr => "New French product name",
			categories => "Changed category",
			quantity => "250 g",
			serving_size => '20 g',
			ingredients_text_fr => "Farine de blé, eau, sel, sucre",
			labels => "Bio, Max Havelaar",
			nutriment_salt => '0.7',
			nutriment_salt_unit => 'mg',
			nutriment_fat => '12.7',
			nutriment_sugars => '7',
		},
		ua => $moderator_ua,
		expected_type => 'html',
		response_content_must_not_match => "Erreur",
	},
	{
		test_case => 'get-edited-protected-product-web-form-moderator',
		method => 'GET',
		path => '/api/v2/product/0200000000335',
	},
];

# Note: some tests override $ua with $moderator_ua
execute_api_tests(__FILE__, $tests_ref, $ua);

done_testing();
