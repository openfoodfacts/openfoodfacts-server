#!/usr/bin/perl -w

# cgi/minion_job_status.pl returned the Minion job info of any job id to anyone: the job
# arguments carry e-mail addresses, the mapping from a deleted account to the pseudonym its edit
# history was reassigned to, and the server-side file paths of the producers-platform tenants.
# Job ids are small numbers, so an anonymous client could walk them and harvest all of it.
#
# This test checks that a job can only be read by an administrator, or by the user who queued it
# (which is what the export and import pages of the producers platform do when they poll their
# jobs).

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::APITest qw/construct_test_url create_test_users new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Producers qw/get_minion/;

use JSON qw/decode_json/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $users_ref = create_test_users(1);
my $user_id = $default_user_form{userid};

# A job of the user (like the export and import jobs of the producers platform, whose arguments
# carry the user_id / org_id / owner_id of the caller) and a job of somebody else.
# They are queued on a queue that no worker reads, so that they stay available during the test.

my $own_job_id
	= get_minion()->enqueue(sleep => [{user_id => $user_id, csv_file => "/tmp/own.csv"}] => {queue => 'test'});
my $other_job_id
	= get_minion()->enqueue(sleep => [{user_id => "another-user", newuserid => "deleted-user"}] => {queue => 'test'});

my $url = construct_test_url('/cgi/minion_job_status.pl?job_id=');

# Anonymous callers

my $anonymous_ua = new_client();

foreach my $job_id ($own_job_id, $other_job_id) {
	my $response = $anonymous_ua->get($url . $job_id);
	is(decode_json($response->content)->{error} // "",
		"no_permission", "an anonymous caller is refused the job $job_id");
	ok(not(defined decode_json($response->content)->{job_info}), "no job info is returned to an anonymous caller");
}

# A user that did not queue the job

my $response = $users_ref->{user}->get($url . $other_job_id);
is(decode_json($response->content)->{error} // "", "no_permission", "a user is refused a job of another user");
ok(not(defined decode_json($response->content)->{job_info}), "no job info is returned for a job of another user");

# Control: a user can read the jobs they queued

$response = $users_ref->{user}->get($url . $own_job_id);
is($response->code, 200, "a user can read the job they queued");
ok(defined decode_json($response->content)->{job_info}, "the job info is returned for the caller's own job");

# Administrators can read any job

$response = $users_ref->{admin}->get($url . $other_job_id);
is($response->code, 200, "an administrator can read any job");
ok(defined decode_json($response->content)->{job_info}, "the job info is returned to an administrator");

done_testing();
