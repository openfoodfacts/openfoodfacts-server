#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Producers qw/:all/;
use ProductOpener::Producers qw/:all/;

remove_all_users();
wait_application_ready();

# new common user agent
my $ua = new_client();
my %create_client_args = (%default_user_form, (email => 'bob@test.com'));
create_user($ua, \%create_client_args);

# new admin user agent
my $admin = new_client();
create_user($admin, \%admin_user_form);

# common ua add a new product then delete the account while being still logged in
my %product_fields = (
	code => '200000000098',
	lang => "en",
	product_name => "Cool test product 75ml",
	generic_name => "A sample test product",
	quantity => "75 ml",
	link => "https://github.com/openfoodfacts/openfoodfacts-server",
	expiration_date => "test",
	ingredients_text => "apple, milk",
	origin => "france",
	serving_size => "10g",
	packaging_text => "Plastic box, paper lid",
	nutriment_salt_value => "1.1",
	nutriment_salt_unit => "g",
);
edit_product($ua, \%product_fields);

my @words = (
	"Delete the user",
	"User is being deleted. This may take a few minutes.",
	"Invalid user.",
	"Unknown user.",
	"Incorrect user name or password."
);
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
like($response_edit->content, qr/\Q$words[0]\E/i, "the delete button does exist");

#deleting the account
my $before_delete_ts = time();
my $response_delete = $ua->post($url_delete, \%delete_form);
#checking if we are redirected to the account deleted page
like($response_delete->content, qr/\Q$words[1]\E/i, "the account was deleted");

#waiting the deletion task to be done
my $jobs = $minion->jobs({tasks => ["delete_user_task"]});
my $job_id = 0;    # job id
#iterate on job
while (my $job = $jobs->next) {
	#only those who were created after the timestamp
	my $waited = 0;    #waiting time
	if ($job->created > $before_delete_ts) {
		#waiting the job to be done
		while ($job->state == "inactive" or $job->state == "active" or $waited < 200) {
			sleep(2);
			$waited++;
		}
		#checking if it did not fail
		is($job->state, "finished");
		$job_id = $job->id;
	}
}

# admin ua checking if the account is well deleted
my $response_userid = $admin->get($url_userid);

my $url_email = construct_test_url('/cgi/user.pl?type=edit&userid=bob@test.com', "world");
my $response_email = $admin->get($url_email);

my $url_contributor = construct_test_url("/contributor/tests", "world");
my $response_contributor = $admin->get($url_contributor);

#checking if the edit page of the common ua is well deleted
like($response_userid->content, qr/\Q$words[2]\E/i, "the userid edit page is well deleted");
#checking if the edit page of the common ua is well deleted
like($response_email->content, qr/\Q$words[2]\E/i, "the email edit page is well deleted");
#checking if the edit page of the common ua is well deleted
like($response_contributor->content, qr/\Q$words[3]\E/i, "the contributor page of the ua is well deleted");

# checking if an ua can reconnect with the deleted account ids
my $url_login = construct_test_url("/cgi/login.pl", "world");
my %login_form = (
	user_id => "tests",
	password => "testtest",
	submit => "Sign in"
);
my $response_login = $ua->post($url_login, \%login_form);
like($response_login->content, qr/\Q$words[4]\E/i, "an user can't login with the deleted account ids");

done_testing();
