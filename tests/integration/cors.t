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

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# TODO: add more tests !
my $tests_ref = [
	{
		test_case => 'options-auth',
		method => 'OPTIONS',
		path => '/cgi/auth.pl',
		expected_status_code => 403,    # we are not authenticated
		headers => {
			"Access-Control-Allow-Origin" => "http://world.openfoodfacts.localhost",
			"Access-Control-Allow-Credentials" => "true",
			"Vary" => "Origin"
		},
		expected_type => "html",
	},
	{
		test_case => 'get-auth',
		method => 'GET',
		path => '/cgi/auth.pl',
		expected_status_code => 403,    # we are not authenticated
		headers => {
			"Access-Control-Allow-Origin" => "http://world.openfoodfacts.localhost",
			"Access-Control-Allow-Credentials" => "true",
			"Vary" => "Origin"
		},
		expected_type => "html",
	},
	{
		test_case => 'options-auth-bad-origin',
		method => 'OPTIONS',
		path => '/cgi/auth.pl',
		expected_status_code => 403,    # because Options triggers a GET, and we are unauthenticated
		headers_in => {"Origin" => "http://other.localhost"},
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Credentials" => undef,
		},
		expected_type => "html",
	},
	# Note: in API v3, we return a 200 status code for OPTIONS, even if the product does not exist
	{
		test_case => 'options-api-v3',
		method => 'OPTIONS',
		path => '/api/v3/product/0000002',
		expected_status_code => 200,
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		},
		expected_type => "html",
	},
	{
		test_case => 'options-api-v3-test-product',
		method => 'OPTIONS',
		path => '/api/v3/product/test',
		expected_status_code => 200,
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		},
		expected_type => "html",
	},
	{
		test_case => 'get-api-v3',
		method => 'GET',
		path => '/api/v3/product/0000002',
		expected_status_code => 404,
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		},
		expected_type => "html",
	},
	{
		test_case => 'options-api-v2',
		method => 'OPTIONS',
		path => '/api/v2/product/0000002',
		expected_status_code => 404,
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		},
		expected_type => "html",
	},
	{
		test_case => 'get-api-v2',
		method => 'GET',
		path => '/api/v2/product/0000002',
		expected_status_code => 404,
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		},
		expected_type => "html",
	},
];
execute_api_tests(__FILE__, $tests_ref);

# Test auth.pl with authenticated user
create_user($ua, \%default_user_form);

my $auth_ua = new_client();
login($auth_ua, "tests", $test_password);

$tests_ref = [
	{
		test_case => 'user-options-auth',
		method => 'OPTIONS',
		path => '/cgi/auth.pl',
		expected_status_code => 200,    # authenticated
		headers => {
			"Access-Control-Allow-Origin" => "http://world.openfoodfacts.localhost",
			"Access-Control-Allow-Credentials" => "true",
			"Vary" => "Origin"
		},
		expected_type => "html",
	},
	{
		test_case => 'user-options-auth-bad-origin',
		method => 'OPTIONS',
		path => '/cgi/auth.pl',
		expected_status_code => 200,    # authenticated
		headers_in => {"Origin" => "http://other.localhost"},
		headers => {
			"Access-Control-Allow-Origin" => "*",
			"Access-Control-Allow-Credentials" => undef,
		},
		expected_type => "html",
	},
];
execute_api_tests(__FILE__, $tests_ref, $auth_ua);

done_testing();
