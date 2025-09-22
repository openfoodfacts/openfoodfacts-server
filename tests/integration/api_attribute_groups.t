#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready(__FILE__);

remove_all_users();

remove_all_products();

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'preferences_v2',
		method => 'GET',
		path => '/api/v2/preferences',
	},
	{
		test_case => 'preferences_fr_v2',
		method => 'GET',
		path => '/api/v2/preferences_fr',
	},
	{
		test_case => 'preferences_v3',
		method => 'GET',
		path => '/api/v3/preferences',
	},
	{
		test_case => 'attribute_groups_v2',
		method => 'GET',
		path => '/api/v2/attribute_groups',
	},
	{
		test_case => 'attribute_groups_fr_v2',
		method => 'GET',
		path => '/api/v2/attribute_groups_fr',
	},
	{
		test_case => 'attribute_groups_v3',
		method => 'GET',
		path => '/api/v3/attribute_groups',
	},
	{
		test_case => 'attribute_groups_v3.4',
		method => 'GET',
		path => '/api/v3.4/attribute_groups',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
