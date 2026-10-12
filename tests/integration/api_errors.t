#!/usr/bin/perl -w

# Errors for API requests should be returned in JSON, not in an HTML page
# https://github.com/openfoodfacts/openfoodfacts-server/issues/7365

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/execute_api_tests new_client wait_application_ready/;

wait_application_ready(__FILE__);

my $tests_ref = [
	{
		test_case => 'api-v2-invalid-address',
		desc => 'An invalid API v2 address returns the error in JSON',
		method => 'GET',
		path => '/api/v2',
		expected_status_code => 404,
		headers => {
			'Content-Type' => '/application\/json/',
		},
	},
	{
		test_case => 'web-invalid-address-with-json-parameter',
		desc => 'An error on a web url requested with json=1 is returned in JSON',
		method => 'GET',
		path => '/product/not-a-barcode',
		query_string => '?json=1',
		expected_status_code => 404,
		headers => {
			'Content-Type' => '/application\/json/',
		},
	},
	{
		test_case => 'web-invalid-address',
		desc => 'An error on a web page is still returned in an HTML page',
		method => 'GET',
		path => '/product/not-a-barcode',
		expected_status_code => 404,
		expected_type => 'none',
		headers => {
			'Content-Type' => '/text\/html/',
		},
		response_content_must_match => '<html',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
