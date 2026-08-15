#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'health-basic',
		method => 'GET',
		path => '/api/v3/health',
		expected_status_code => 503,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
