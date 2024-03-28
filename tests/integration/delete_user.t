#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/remove_all_users delete_user_from_keycloak/;
use ProductOpener::TestDefaults qw/%admin_user_form %default_product %default_user_form/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Producers qw/:all/;
use ProductOpener::Keycloak;
use ProductOpener::Config qw/:all/;

use Clone qw/clone/;

wait_application_ready();
remove_all_users();

#new common user agent
my $ua = new_client();
my %create_client_args = (%default_user_form, (email => 'bob@test.com'));
create_user($ua, \%create_client_args);

#new admin user agent - admin user has to be created before the deletion
#and admin user cannot be deleted by another Minion task
my %random_admin_user_form = (
	%{clone(\%default_user_form)},
	email => 'admin' . generate_token(32) . '@openfoodfacts.org',
	userid => generate_token(32),
	name => "Admin",
);
%admins = (%admins, $random_admin_user_form{userid} => 1);

my $admin = new_client();
create_user($admin, \%admin_user_form);

#common ua add a new product then delete the account while being still logged in
edit_product($ua, \%default_product);

my $url_userid = construct_test_url("/cgi/user.pl?type=edit&userid=tests", "world");
my $keycloak = ProductOpener::Keycloak->new();
my $keycloak_user = $keycloak->find_user_by_email('bob@test.com');

#deleting the account
my $before_delete_ts = time();
delete_user_from_keycloak($keycloak_user);

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
	password => '!!!TestTest1!!!',
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
