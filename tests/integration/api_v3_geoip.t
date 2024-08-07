#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;


wait_application_ready();
my $ua = new_client();

my $tests_ref = [
	{
		test_case => 'ipv4-united-states',
		method => 'GET',
		path => '/api/v3/geopip/12.45.23.45',
        expected_status_code => 200,
    },
    {
        test_case => 'ipv6-france',
        method => 'GET',
        path => '/api/v3/geopip/2001:ac8:25:3b::e01d'
        expected_status_code => 200,
    },
    {
        test_case => 'frac'
    },
];