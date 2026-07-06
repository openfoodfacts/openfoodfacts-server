#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/$data_root/;
use ProductOpener::Store qw/retrieve/;
use ProductOpener::Users qw/retrieve_user/;
use ProductOpener::Auth qw/get_oidc_implementation_level/;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults
	qw/%admin_user_form %default_org_edit_admin_form %default_org_edit_form %default_user_form %pro_moderator_user_form/;

use Clone qw/clone/;
use List::Util qw/first/;
use Storable qw(dclone);
use JSON::MaybeXS qw/to_json/;
use List::MoreUtils qw/first_index any/;

=head1 Test creation of a producer user

=cut

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

#11867: These tests need to be re-written for the new workflow

# clean
wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();
remove_all_orgs();

my $admin_ua = new_client();
create_user($admin_ua, \%admin_user_form);

# create a pro moderator
my $moderator_ua = new_client();
create_user($moderator_ua, \%pro_moderator_user_form);

# admin pass him moderator
my %moderator_edit_form = (
	%pro_moderator_user_form,
	user_group_pro_moderator => "1",
	type => "edit",
);
my $resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp), "no error on admin adding moderator role");

# A user comes along, creates its profile and requests to be part of an org
my $user_ua = new_client();
my %user_form = (%{clone(\%default_user_form)}, requested_org => "Acme Inc.");
my $log_path = "/var/log/apache2/log4perl.log";
if (get_oidc_implementation_level() > 1) {
	# Emails will be in the Minion log once Keycloak is the master source of truth
	$log_path = "/var/log/apache2/minion_log4perl.log";
}
my $tail = tail_log_start($log_path);
my $before_create_ts = get_last_minion_job_created();
create_user($user_ua, \%user_form);

if (get_oidc_implementation_level() > 1) {
	# Create user starts in Keycloak, then triggers Redis which creates minion job
	# Wait for the requested orgs job to complete
	my $jobs_ref = get_minion_jobs("process_user_requested_org", $before_create_ts);
	is(scalar @{$jobs_ref}, 1, "One process_user_requested_org was triggered");
}

my $logs = tail_log_read($tail);

# As it is the first user of the org, user is already part of the org
my $user_ref = retrieve_user("tests");
# user is already part of org
is($user_ref->{pro}, 1, "user is marked as pro");

is($user_ref->{org}, "acme-inc", "org is correct");
is($user_ref->{org_id}, "acme-inc", "org_id is correct");
# remove password for comparison and timestamps
my $user_cmp_ref = dclone($user_ref);
normalize_user_for_test_comparison($user_cmp_ref);
compare_to_expected_results(
	$user_cmp_ref, "$expected_result_dir/user-after-subscription.json",
	$update_expected_results, {desc => "user after subscription is as expected"}
);

# Org was created
my $org_ref = retrieve("$data_root/orgs/acme-inc.sto");
my $org_cmp_ref = dclone($org_ref);
normalize_org_for_test_comparison($org_cmp_ref);
compare_to_expected_results(
	$org_cmp_ref, "$expected_result_dir/org-after-subscription.json",
	$update_expected_results, {desc => "org after subscription is as expected"}
);

# Get mails from log
my @mails = mails_from_log($logs);
# get text
@mails = map {; normalize_mail_for_comparison($_)} @mails;

# Ensure the promoter email is at the start for comparison as with Minion jobs they aren't always processed in the same order
my $promoter_email_index = first_index {
	any {index($_, "user_new_pro_account_admin_notification.tt.html") != -1} @{$_}
}
@mails;
my $promoter_email = splice(@mails, $promoter_email_index, 1);
unshift(@mails, $promoter_email);

# we got three
is(scalar @mails, 3, "3 mails sent on subscription");
# compare
compare_to_expected_results(\@mails, "$expected_result_dir/mails.json",
	$update_expected_results, {desc => "mail sent after subscription"});

# the pro moderator got to the org page
$resp = get_page($moderator_ua, "/cgi/org.pl?type=edit&orgid=org-acme-inc");
# the pro moderator validates the user org by going on org page and changes the org validation status from 'unreviewed' to 'accepted'
my %fields = (%{dclone(\%default_org_edit_form)}, %{dclone(\%default_org_edit_admin_form)}, valid_org => 'accepted');
$resp = post_form($moderator_ua, "/cgi/org.pl", \%fields);
# the org is now validated
$org_ref = retrieve("$data_root/orgs/acme-inc.sto");
$org_cmp_ref = dclone($org_ref);
normalize_org_for_test_comparison($org_cmp_ref);
compare_to_expected_results($org_cmp_ref, "$expected_result_dir/org-after-validation.json",
	$update_expected_results, {desc => "org validated"});

done_testing();
