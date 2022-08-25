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

sub send_notification_for_product_change($product_ref, $action) {
	return 1;
}


my $update_expected_results;

GetOptions("update-expected-results" => \$update_expected_results)
  or die("Error in command line arguments.\n\n");

remove_all_products();
wait_dynamic_front();

my $admin_ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@test.com'));
create_user($admin_ua, \%create_user_args);

my %product_fields = (
	code => '200000000099',
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


# my $file = open(fh, "$inputs_dir/apple.jpg");

# print "$inputs_dir/apple.jpg";

create_product($admin_ua, \%product_fields);

# my $response = $admin_ua->post("http://world.openfoodfacts.localhost/cgi/product_jqm2.pl?code=200000000099&product_image_upload.pl/imgupload_front=$inputs_dir/apple.jpg", Content => "$inputs_dir/apple.jpg");

my $response = $admin_ua->request(POST "http://world.openfoodfacts.localhost/cgi/product_image_upload.pl", 
Content_Type => 'form-data', 
Content => [ code => "200000000099", imagefield => "front", imgupload_front => ["$inputs_dir/apple.jpg"] ], );

#it tries to contact robotoff
#fake implementation with mock module

# read the product + see the images feild +  front etc. other params 
# "blackbox", may want to check if the file that's on OFF is the same image

is($response->{_rc}, 200);

done_testing();


