#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Producers qw/:all/;

remove_all_users();
wait_application_ready();

#new common user agent
my $ua = new_client();
my %create_client_args = (%default_user_form, (email => 'bob@test.com'));
create_user($ua, \%create_client_args);

#new admin user agent
my $admin = new_client();
create_user($admin, \%admin_user_form);

#common ua add a new product then delete the account while being still logged in
edit_product($ua, \%default_product);

my $url_userid = construct_test_url("/cgi/user.pl?type=edit&userid=tests", "world");
my $url_delete = construct_test_url("/cgi/user.pl", "world");
my $response_edit = $ua->get($url_userid);

my %delete_form = (
	name => 'Test',
	email => 'bob@test.com',
	password => '',
	confirm_password => '',
	delete => 'on',
	action => 'process',
	type => 'edit',
	userid => 'tests'
);

#checking if the delete button exist
like($response_edit->content, qr/Delete the user/, "the delete button does exist");

#deleting the account
my $before_delete_ts = time();
my $response_delete = $ua->post($url_delete, \%delete_form);
#checking if we are redirected to the account deleted page
like($response_delete->content, qr/User is being deleted\. This may take a few minutes\./, "the account was deleted");

#waiting the deletion task to be done (weirdly enough it is not useful anymore..)
my $max_time = 60;
my $jobs_ref = get_minion_jobs("delete_user", $before_delete_ts, $max_time);

is(scalar @{$jobs_ref}, 1, "One delete_user was triggered");
my $delete_job_state = $jobs_ref->[0]{state};
is($delete_job_state, "finished", "delete_user finished without errors");

#user sign out of its account
my %signout_form = (
	length => "logout",
	".submit" => "Sign out"
);
my $url_signout = construct_test_url("/cgi/session.pl", "world");
my $response_signout = $ua->post($url_signout, \%signout_form);

like($response_signout->content, qr/See you soon\!/, "the user signed out");

#admin ua checking if the account is well deleted
my $response_userid = $admin->get($url_userid);
#checking if the edit page of the common ua is well deleted
like($response_userid->content, qr/Invalid user\./, "the userid edit page is well deleted");

my $url_email = construct_test_url('/cgi/user.pl?type=edit&userid=bob@test.com', "world");
my $response_email = $admin->get($url_email);
#checking if the edit page of the common ua is well deleted
like($response_email->content, qr/Invalid user\./, "the email edit page is well deleted");

my $url_contributor = construct_test_url("/contributor/tests", "world");
my $response_contributor = $admin->get($url_contributor);
#checking if the edit page of the common ua is well deleted
like($response_contributor->content, qr/Unknown user\./, "the contributor page of the ua is well deleted");

#checking if an ua can reconnect with the deleted account ids
my $url_login = construct_test_url("/cgi/login.pl", "world");
my %login_form = (
	user_id => "tests",
	password => "testtest",
	submit => "Sign in"
);
my $response_login = $ua->post($url_login, \%login_form);
like(
	$response_login->content,
	qr/Incorrect user name or password\./,
	"an user can't login with the deleted account ids"
);

#checking if the added product has been anonymized
my $url_product = construct_test_url("/cgi/product.pl?type=edit&code=2000000000001", "world");
my $response_product = $admin->get($url_product);
like($response_product->content, qr/\/editor\/anonymous/, "the product has been anonymized");

done_testing();
