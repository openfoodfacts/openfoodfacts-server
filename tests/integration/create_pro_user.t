#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/$data_root/;
use ProductOpener::Store qw/retrieve/;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use Clone qw/clone/;
use List::Util qw/first/;
use Storable qw(dclone);

=head1 Test creation of a producer user

=cut

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# clean
remove_all_users();
remove_all_orgs();
wait_application_ready();

my $admin_ua = new_client();
my $resp = create_user($admin_ua, \%admin_user_form);
ok(!html_displays_error($resp));
# create a pro moderator
my $moderator_ua = new_client();
$resp = create_user($moderator_ua, \%pro_moderator_user_form);
ok(!html_displays_error($resp), "no error on future moderator creation");
# admin pass him moderator
my %moderator_edit_form = (
	%pro_moderator_user_form,
	user_group_pro_moderator => "1",
	type => "edit",
);
$resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp), "no error on admin adding moderator role");

# A user comes along, creates its profile and requests to be part of an org
my $user_ua = new_client();
my %user_form = (
	%{clone(\%default_user_form)},
	pro => "1",
	requested_org => "Acme Inc."
);
my $tail = tail_log_start();
$resp = create_user($user_ua, \%user_form);
ok(!html_displays_error($resp), "no error creating pro user");
my $logs = tail_log_read($tail);

# As it is the first user of the org, user is already part of the org
my $user_ref = retrieve("$data_root/users/tests.sto");
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
# we got three
is(scalar @mails, 3, "3 mails sent on subscription");
# compare
compare_to_expected_results(\@mails, "$expected_result_dir/mails.json",
	$update_expected_results, {desc => "mail sent after subscription"});

# the pro moderator got to the org page
$resp = get_page($moderator_ua, "/cgi/org.pl?type=edit&orgid=org-acme-inc");
# the pro moderator validates the user org by going on org page and adding a tick
my %fields = (%{dclone(\%default_org_edit_form)}, %{dclone(\%default_org_edit_admin_form)}, valid_org => 1);
$resp = post_form($moderator_ua, "/cgi/org.pl", \%fields);
# the org is now validated
$org_ref = retrieve("$data_root/orgs/acme-inc.sto");
$org_cmp_ref = dclone($org_ref);
normalize_org_for_test_comparison($org_cmp_ref);
compare_to_expected_results($org_cmp_ref, "$expected_result_dir/org-after-validation.json",
	$update_expected_results, {desc => "org validated"});

done_testing();
