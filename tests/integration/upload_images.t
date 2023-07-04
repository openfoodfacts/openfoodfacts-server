#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

my $sample_products_images_path = dirname(__FILE__) . "/inputs/sample-products-images";

# Create a normal user
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Create some products

my @products = (
	{
		%{dclone(\%default_product_form)},

		(
			code => '1234567890012',
			product_name => "An arbitrary product",
			generic_name => "Tester",
			ingredients_text => "apple, milk, eggs, palm oil",
			origin => "france",
			packaging_text_en => "1 25cl glass bottle, 1 steel lid, 1 plastic wrap"
		)
	},
	{
		%{dclone(\%default_product_form)},

		(
			code => '1234567890013',
			product_name => "Nutella Ferrero",
			generic_name => "Tester",
			ingredients_text => "fruit, rice",
			packaging_text => "no"
		)
	},
	{
		%{dclone(\%default_product_form)},

		(
			code => '1234567890014',
			product_name => "A Soda Product",
			generic_name => "Tester",
			quantity => "100 ml",
			ingredients_text => "apple, milk, eggs",
			origin => "france",

			imgupload_front_en =>
				["$sample_products_images_path/300/000/000/0001/front_en.3.full.jpg", 'front_en.3.full.jpg']

		)
	},
	# {
	# 	%{dclone(\%default_product_form)},
	# 	%{dclone(\%product_form)},
	# 	(
	# 		code => 'nonexistent_product_code',
	# 		product_name => "A protected product",
	# 	)
	# },

);

# create the products in the database
foreach my $product_form_override (@products) {
	edit_product($ua, $product_form_override);
}

my $tests_ref = [
	{
		test_case => 'post-nonexistent-product-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890011",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/300/000/000/0001/1.jpg", '1.jpg'],
		}
	},
	{
		test_case => 'get-nonexistent-product-image',
		method => 'GET',
		path => '/api/v2/product/1234567890011?fields=images&images_client=web',
		expected_status_code => 404,
	},
	{
		test_case => 'post-existing-product-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890012",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/300/000/000/0001/1.jpg", '1.jpg'],
		}
	},
	{
		test_case => 'get-existing-product-image',
		method => 'GET',
		path => '/api/v2/product/1234567890012?fields=images&images_client=web',
	},
	{
		test_case => 'post-image-too-small',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890013",
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/300/000/000/0001/small-img.jpg", 'small-img.jpg'],
		}
	},
	{
		test_case => 'get-image-too-small',
		method => 'GET',
		path => '/api/v2/product/1234567890013?fields=images&images_client=web',
		expected_status_code => 404,
	},
	{
		test_case => 'post-same-image-twice',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => "1234567890014",
			imagefield => "front_en",
			imgupload_front_en =>
				["$sample_products_images_path/300/000/000/0001/front_en.3.full.jpg", 'front_en.3.full.jpg'],
		}
	},
	{
		test_case => 'get-same-image-twice',
		method => 'GET',
		path => '/api/v2/product/1234567890014?fields=images&images_client=web',

	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();

