#!/usr/bin/perl -w

# A user who asks to join an organization is only a pending member until an org admin accepts
# them. add_user_to_org() syncs the CRM, and with it the org's Odoo company record, so it must not
# do that for a pending user: the request alone must not add the requester to the org's CRM, and a
# denial must leave nothing behind to clean up.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Users qw/store_user_preferences retrieve_user_preferences/;
use ProductOpener::Orgs qw/store_org retrieve_org add_user_to_org accept_pending_user_in_org is_user_in_org_group/;
use ProductOpener::Paths qw/%BASE_DIRS/;

# A user and an accepted organization that has a CRM company record. The CRM is not configured in
# the test environment, so the request Odoo would take is a no-op, but add_user_to_company() still
# stores the contact id it resolved on the user: that key is what tells us the CRM was synced.

my $user_id = "poc-org-join-crm-user";
my $org_id = "poc-org-join-crm-org";

sub remove_test_data {
	unlink("$BASE_DIRS{USERS}/$user_id.sto");
	unlink("$BASE_DIRS{ORGS}/$org_id.sto");
	return;
}

# Start from a clean state, whatever a previous run left behind

remove_test_data();

my $user_ref = {
	userid => $user_id,
	email => q{poc-org-join-crm@example.com},
	name => q{PoC Org Join CRM},
	password => q{poc-org-join-crm},
};
store_user_preferences($user_ref);

my $org_ref = {
	org_id => $org_id,
	name => q{PoC Org Join CRM Org},
	valid_org => q{accepted},
	crm_org_id => 4242,
	members => {},
	admins => {},
	pending => {},
};
store_org($org_ref);

# Asking to join does not sync the CRM

add_user_to_org($org_id, $user_id, ["pending"]);

ok(is_user_in_org_group($org_id, $user_id, "pending"), "the user is a pending member of the org");
ok(
	not(is_user_in_org_group($org_id, $user_id, "members")),
	"the user is not a member of the org before it accepted them"
);

my $after_request = retrieve_user_preferences($user_id);
ok(not(exists $after_request->{crm_user_id}), "asking to join an org does not write the requester into the org CRM");

# Accepting the request syncs the CRM, so the guard does not disable the sync altogether

accept_pending_user_in_org(retrieve_org($org_id), $user_id);

ok(is_user_in_org_group($org_id, $user_id, "members"), "the user is a member once accepted");
ok(not(is_user_in_org_group($org_id, $user_id, "pending")), "the user is no longer pending once accepted");

my $after_accept = retrieve_user_preferences($user_id);
ok(exists $after_accept->{crm_user_id}, "accepting a pending user still writes them to the CRM");

remove_test_data();

done_testing();
