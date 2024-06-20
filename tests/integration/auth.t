#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user execute_api_tests login new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# TODO: add more tests !
my $tests_ref = [
	{
		test_case => 'auth-not-authenticated',
		method => 'GET',
		path => '/cgi/auth.pl',
		expected_status_code => 403,    # we are not authenticated
		headers => {
			"Set-Cookie" => undef,
		},
		expected_type => "none",
	},
	{
		test_case => 'auth-authenticated-with-userid-and-password',
		method => 'POST',
		path => '/cgi/auth.pl',
		form => {
			user_id => "tests",
			password => "testtest",
			body => 1,
		},
		expected_status_code => 200,
		headers => {
			"Set-Cookie" => "/session=/",    # We get a session cookie
		},
		expected_type => "json",
	},
];
execute_api_tests(__FILE__, $tests_ref);

# Test auth.pl with authenticated user
create_user($ua, \%default_user_form);

my $auth_ua = new_client();
login($auth_ua, "tests", 'testtest');

$tests_ref = [
	{
		test_case => 'auth-authenticated-with-cookie',
		method => 'GET',
		path => '/cgi/auth.pl',
		expected_status_code => 200,
		headers => {
			"Set-Cookie" => undef,    # No session cookie
		},
		expected_type => "none",
	},
];
execute_api_tests(__FILE__, $tests_ref, $auth_ua);

done_testing();
