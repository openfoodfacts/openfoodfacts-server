#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

wait_application_ready(__FILE__);
remove_all_users();

# Create an admin user
my $admin_ua = new_client();
create_user($admin_ua, \%admin_user_form);

# Create a normal user
my $ua = new_client();
my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

# Create a moderator user
my $moderator_ua = new_client();
create_user($moderator_ua, \%moderator_user_form);

# Admin gives moderator status to the moderator user
my %moderator_edit_form = (
	%moderator_user_form,
	user_group_moderator => "1",
	type => "edit",
);
my $resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp));

# Unauthenticated user agent
my $anon_ua = new_client();

my $tests_ref = [
	{
		test_case => 'current-user-permissions-not-authenticated',
		method => 'GET',
		path => '/api/v3/current-user/permissions',
		ua => $anon_ua,
		expected_status_code => 401,
	},
	{
		test_case => 'current-user-permissions-normal-user',
		method => 'GET',
		path => '/api/v3/current-user/permissions',
		ua => $ua,
		expected_status_code => 200,
	},
	{
		test_case => 'current-user-permissions-moderator',
		method => 'GET',
		path => '/api/v3/current-user/permissions',
		ua => $moderator_ua,
		expected_status_code => 200,
	},
	{
		test_case => 'current-user-permissions-admin',
		method => 'GET',
		path => '/api/v3/current-user/permissions',
		ua => $admin_ua,
		expected_status_code => 200,
	},
	{
		test_case => 'current-user-permissions-options',
		method => 'OPTIONS',
		path => '/api/v3/current-user/permissions',
		expected_type => 'none',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
