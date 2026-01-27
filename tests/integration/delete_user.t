#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::TestDefaults qw/%admin_user_form %default_product %default_user_form/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Auth qw/get_oidc_implementation_level/;

use Clone qw/clone/;
use Minion::Job;

wait_application_ready(__FILE__);
remove_all_users();

#new common user agent
my $ua = new_client();
my %create_client_args = (%default_user_form, (email => 'bob@example.com'));
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
if (get_oidc_implementation_level() < 5) {
	# Use legacy method until we have moved account management to Keycloak
	my $url_delete = construct_test_url("/cgi/user.pl", "world");
	my $response_edit = $ua->get($url_userid);

	my %delete_form = (
		name => 'Test',
		email => 'bob@example.com',
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
	my $before_delete_ts = get_last_minion_job_created();
	my $response_delete = $ua->post($url_delete, \%delete_form);
	#checking if we are redirected to the account deleted page
	like(
		$response_delete->content,
		qr/User is being deleted\. This may take a few minutes\./,
		"the account was deleted"
	);

	#waiting the deletion task to be done (weirdly enough it is not useful anymore..)
	my $jobs_ref = get_minion_jobs("delete_user", $before_delete_ts);

	is(scalar @{$jobs_ref}, 1, "One delete_user was triggered");
	my $delete_job_state = $jobs_ref->[0]{state};
	is($delete_job_state, "finished", "delete_user finished without errors");
}
else {
	#deleting the account
	# TODO: This should us the Keycloak API
	my $job_result;
	my $mocked_job = mock 'Minion::Job' => (
		override => [
			'finish' => sub {
				my ($self, $result) = @_;
				$job_result = $result;
			}
		],
	);
	delete_user_task(Minion::Job->new(), {userid => 'tests', newuserid => 'anonymous-123'});
	is($job_result, 'done', 'delete_user finished without errors');
}

#user can't access their preference page anymore
my $response_preferences = $ua->get($url_userid);
like($response_preferences->content, qr/Authentication error/, "user can no longer access their preferences");

#admin ua checking if the account is well deleted
my $response_userid = $admin->get($url_userid);
#checking if the edit page of the common ua is well deleted
like($response_userid->content, qr/Invalid user\./, "the userid edit page is well deleted");

my $url_email = construct_test_url('/cgi/user.pl?type=edit&userid=bob@example.com', "world");
my $response_email = $admin->get($url_email);
#checking if the edit page of the common ua is well deleted
like($response_email->content, qr/Invalid user\./, "the email edit page is well deleted");

my $url_contributor = construct_test_url("/facets/contributors/tests", "world");
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
# Create a new ua that doesn't contain the access_token
$ua = new_client();
my $response_login = $ua->post($url_login, \%login_form);
like(
	$response_login->content,
	qr/Incorrect user name or password\./,
	"an user can't login with the deleted account ids"
);

#checking if the added product has been anonymized
my $url_product = construct_test_url("/cgi/product.pl?type=edit&code=2000000000001", "world");
my $response_product = $admin->get($url_product);
like($response_product->content, qr/\/editors\/anonymous/, "the product has been anonymized");

done_testing();
