#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/remove_all_products remove_all_users get_base64_image_data_from_file/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";
use Storable qw(dclone);
use JSON::MaybeXS qw(encode_json);
use boolean qw/:all/;

# Make sure we include convert_blessed to cater for blessed objects, like booleans
my $json = JSON::MaybeXS->new->convert_blessed->utf8->canonical;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

# Create an admin
my $admin_ua = new_client();
create_user($admin_ua, \%admin_user_form);

# Create a normal user
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

# Create a moderator
my $moderator_ua = new_client();
create_user($moderator_ua, \%moderator_user_form);

# Admin gives moderator status
my %moderator_edit_form = (
	%moderator_user_form,
	user_group_moderator => "1",
	type => "edit",
);
my $resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp));

my $sample_products_images_path = dirname(__FILE__) . "/inputs/upload_images";

my $tests_ref = [
	{
		test_case => 'post-product-image',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => '{"image_data_base64":"' . get_base64_image_data_from_file("$sample_products_images_path/1.jpg") . '"}',
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-another-image-ingredients-it',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => $json->encode(
			{
				"image_data_base64" =>
					get_base64_image_data_from_file("$sample_products_images_path/front_en.3.full.jpg"),

				selected => {
					ingredients => {
						it => {}
					},
				}

			}
		),
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-already-uploaded',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => '{"image_data_base64":"' . get_base64_image_data_from_file("$sample_products_images_path/1.jpg") . '"}',
		expected_status_code => 200,
	},
	{
		test_case => 'post-product-image-too-small',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => '{"image_data_base64":"'
			. get_base64_image_data_from_file("$sample_products_images_path/small-img.jpg") . '"}',
		expected_status_code => 400,
	},
	{
		test_case => 'post-product-image-not-in-a-valid-format',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => '{"image_data_base64":"'
			. get_base64_image_data_from_file("$sample_products_images_path/not-an-image.txt") . '"}',
		expected_status_code => 400,
	},
	{
		test_case => 'post-product-image-not-in-base64',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => '{"image_data_base64":"' . "Thïs IŜ NÖT base64!!!" . '"}',
		expected_status_code => 400,
	},
	{
		test_case => 'post-product-image-with-missing-field',
		method => 'POST',
		path => '/api/v3/product/1234567890012/images',
		body => '{}',
		expected_status_code => 400,
	},
	{
		test_case => 'get-product-images',
		method => 'GET',
		path => '/api/v3.3/product/1234567890012',
		expected_status_code => 200,
	},
	# Delete images
	{
		test_case => 'delete-product-image-not-identified',
		method => 'DELETE',
		path => '/api/v3/product/1234567890012/images/uploaded/2',
		expected_status_code => 403,
	},
	{
		test_case => 'delete-product-image-normal-user',
		method => 'DELETE',
		path => '/api/v3/product/1234567890012/images/uploaded/2',
		ua => $ua,
		expected_status_code => 403,
	},
	# Deleting the upload image imgid2 should also unselect ingredients in Italian
	{
		test_case => 'delete-product-image',
		method => 'DELETE',
		path => '/api/v3/product/1234567890012/images/uploaded/2',
		ua => $moderator_ua,
		expected_status_code => 200,
	},
	{
		test_case => 'get-product-images-after-deletion',
		method => 'GET',
		path => '/api/v3.3/product/1234567890012',
		ua => $moderator_ua,
		expected_status_code => 200,
	},
	# Delete an image of a product that does not exist
	{
		test_case => 'delete-product-image-product-not-found',
		method => 'DELETE',
		path => '/api/v3/product/1234567890073/images/uploaded/1',
		ua => $moderator_ua,
		expected_status_code => 404,
	},
	# Delete an image that does not exist
	{
		test_case => 'delete-product-image-not-found',
		method => 'DELETE',
		path => '/api/v3/product/1234567890012/images/uploaded/25',
		ua => $moderator_ua,
		expected_status_code => 404,
	},

];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
