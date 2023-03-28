#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use Test::MockModule;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use File::Basename "dirname";
use File::Path qw/make_path remove_tree/;
use Getopt::Long qw/GetOptions/;
use Log::Any::Adapter 'TAP';
use Mock::Quick qw/qobj qmeth/;
use ProductOpener::TestDefaults qw/:all/;
use HTTP::Request::Common;

my $test_id = "image_upload";
my $test_dir = dirname(__FILE__);
my $inputs_dir = "$test_dir/inputs/$test_id/";

# mock
sub send_notification_for_product_change($product_ref, $action) {
	return 1;
}

GetOptions("update-expected-results" => \$update_expected_results)
  or die("Error in command line arguments.\n\n");

remove_all_products();
wait_application_ready();

my $admin_ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@test.com'));
my %product_fields = (
	code => '200000000098',
	lang => "en",
	product_name => "Testttt-75ml",
	generic_name => "Tester",
	quantity => "75 ml",
	link => "#",
	expiration_date => "test",
	ingredients_text => "apple, milk",
	origin => "france",
	serving_size => "10g",
	packaging_text => "no",
	action => "process",
	type => "add",
	".submit" => "submit"
);
create_user($admin_ua, \%create_user_args);
edit_product($admin_ua, \%product_fields);

my $file = open(fh, "$inputs_dir/apple.jpg");
my %image_upload_fields = (
	code => '200000000098',
	user_id => "tests",
	password => "testtest",
	imagefield => "ingredients_en",
	imgupload_ingredients_en => "$inputs_dir/apple.jpg"
);

my $result = $admin_ua->post("http://off:off@world.openfoodfacts.localhost/cgi/product_image_upload.pl", Content => \%image_upload_fields);

is($result->{_rc}, 200);

#it tries to contact robotoff
#fake implementation with mock module

# read the product + see the images feild +  front etc. other params 
# "blackbox", may want to check if the file that's on OFF is the same image

done_testing();


