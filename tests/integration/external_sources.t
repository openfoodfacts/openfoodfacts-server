#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::APITest qw/create_test_users execute_api_tests wait_application_ready/;

wait_application_ready(__FILE__);
remove_all_users();
my $users = create_test_users(1, 1);

my $tests_ref = [
	{
		test_case => 'external-sources-en',
		path => '/api/v3/external_sources',
		expected_type => "json",
	},
	{
		test_case => 'external-sources-fr',
		path => '/api/v3/external_sources?lc=fr',
		expected_type => "json",
	},
	# authenticated request
	{
		test_case => 'external-sources-en-user',
		path => '/api/v3/external_sources',
		expected_type => "json",
		ua => $users->{user},
	},
	{
		test_case => 'external-sources-en-moderator',
		path => '/api/v3/external_sources',
		expected_type => "json",
		ua => $users->{moderator},
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
