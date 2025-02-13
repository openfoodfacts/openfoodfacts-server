#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests wait_application_ready/;

wait_application_ready();

my $tests_ref = [
	{
		test_case => 'list-countries-world',
		path => '/cgi/countries.pl',
		expected_type => "json",
	},
	{
		test_case => 'list-countries-french',
		subdomain => 'fr',
		path => '/cgi/countries.pl',
		expected_type => "json",
	},
	{
		test_case => 'list-countries-filtered-fr',
		path => '/cgi/countries.pl?term=FR',
		expected_type => "json",
	}
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
