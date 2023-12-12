#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

wait_application_ready();

remove_all_users();

remove_all_products();

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'no-tagtype',
		method => 'GET',
		path => '/cgi/suggest.pl',
	},
	{
		test_case => 'incorrect-tagtype',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=not_a_taxonomy',
	},
	{
		test_case => 'categories-no-term',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-term-strawberry',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&term=strawberry',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-strawberry',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&string=strawberry',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-term-fraise',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&term=fraise',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-term-fr-fraise',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&term=fraise&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-term-fr-frais',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&term=frais&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-term-fr-frais',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&term=frais&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-term-fr-cafe-accent',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&term=Café&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'categories-string-fr-cafe-accent',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&string=Café&lc=fr',
		expected_status_code => 200,
	},
	{
		test_case => 'synonym-string-fr-dairy-drinks',
		method => 'GET',
		path => '/cgi/suggest.pl?tagtype=categories&string=jus de fruits au lait&lc=fr',
		expected_status_code => 200,
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
