#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;

wait_application_ready(__FILE__);

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
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
