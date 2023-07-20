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

my $tests_ref = [

	{
		test_case => 'post-protected-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {

			code => '0300000000134',
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/front_en.4.full.jpg", 'front_en.4.full.jpg'],
		},
	},

	{
		test_case => 'post-select-protected-image',
		method => 'POST',
		path => '/cgi/product_image_upload.pl',
		form => {
			code => '0300000000134',
			imagefield => "front_en",
			imgupload_front_en => ["$sample_products_images_path/front_en.3.full.jpg", 'front_en.3.full.jpg'],
		},

	},
	{
		test_case => 'get-protected-image',
		method => 'GET',
		path => '/api/v2/product/0300000000134',
	},

];

execute_api_tests(__FILE__, $tests_ref, $ua);

done_testing();
