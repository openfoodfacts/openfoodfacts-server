#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'default',
		method => 'GET',
		path => '/cgi/nutrients.pl',
	},
	{
		test_case => 'fr-fr',
		method => 'GET',
		path => '/cgi/nutrients.pl?cc=fr&lc=fr',
	},
	{
		test_case => 'en-us',
		method => 'GET',
		path => '/cgi/nutrients.pl?cc=us&lc=en',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
