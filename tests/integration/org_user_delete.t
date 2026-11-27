#!/usr/bin/perl -w

# cgi/org.pl's user_delete action authorized the caller against the organization named in the
# request, but never checked that the account it removed belonged to that organization: any admin
# of a self-registered organization could delete the org and org_id fields of any account.
#
# This test checks both layers of the fix: cgi/org.pl refuses to remove an account that is not in
# the organization the caller administers, and remove_user_by_org_admin() does the same check
# before touching the account.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::APITest qw/create_user new_client post_form wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Orgs qw/add_user_to_org create_org is_user_in_org_group/;
use ProductOpener::Users qw/remove_user_by_org_admin retrieve_user_preferences store_user_preferences/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $org_id = "org-acme-inc";
my $other_org_id = "org-other-inc";

# The admin of the organization, a member of the organization, and a member of another one

my $admin_ua = new_client();
create_user($admin_ua, {%default_user_form, userid => "org-admin-user", email => 'org-admin-user@example.com'});

my $member_ua = new_client();
create_user($member_ua, {%default_user_form, userid => "org-member-user", email => 'org-member-user@example.com'});

my $other_ua = new_client();
create_user($other_ua, {%default_user_form, userid => "other-org-user", email => 'other-org-user@example.com'});

create_org("org-admin-user", $org_id);
add_user_to_org($org_id, "org-admin-user", ["admins"]);
add_user_to_org($org_id, "org-member-user", ["members"]);

create_org("other-org-user", $other_org_id);
add_user_to_org($other_org_id, "other-org-user", ["members"]);

# add_user_to_org() does not set the org fields of the accounts (they are set when the account is
# created), so do it here: that is the value an account of an organization has.

foreach my $account ([$org_id, "org-member-user"], [$other_org_id, "other-org-user"]) {
	my $user_ref = retrieve_user_preferences($account->[1]) // {userid => $account->[1]};
	$user_ref->{userid} = $account->[1];
	$user_ref->{org} = $account->[0];
	$user_ref->{org_id} = $account->[0];
	store_user_preferences($user_ref);
}

sub user_org ($user_id) {
	my $user_ref = retrieve_user_preferences($user_id);
	return defined $user_ref->{org} ? $user_ref->{org} : "";
}

# The admin of the organization tries to remove an account of another organization

post_form($admin_ua, "/cgi/org.pl",
	{action => "process", type => "user_delete", orgid => $org_id, user_id => "other-org-user"});

is(user_org("other-org-user"), $other_org_id, "the account of another organization keeps its organization");
ok(
	is_user_in_org_group($other_org_id, "other-org-user", "members"),
	"the other organization still has the account as a member"
);

# Control: the admin can remove a member of their own organization

post_form($admin_ua, "/cgi/org.pl",
	{action => "process", type => "user_delete", orgid => $org_id, user_id => "org-member-user"});

ok(not(is_user_in_org_group($org_id, "org-member-user", "members")), "the member was removed from the organization");
is(user_org("org-member-user"), "", "the org fields of the removed member were reset");

# remove_user_by_org_admin() also refuses an account that is not in the organization

remove_user_by_org_admin($org_id, "other-org-user");

is(user_org("other-org-user"),
	$other_org_id, "remove_user_by_org_admin() did not touch the account of another organization");
ok(
	is_user_in_org_group($other_org_id, "other-org-user", "members"),
	"remove_user_by_org_admin() kept the account in the other organization"
);

# ...and still removes an account of the organization

remove_user_by_org_admin($org_id, "org-admin-user");

ok(
	not(is_user_in_org_group($org_id, "org-admin-user", "admins")),
	"remove_user_by_org_admin() removed an admin of the organization"
);

done_testing();
