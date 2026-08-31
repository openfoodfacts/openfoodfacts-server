#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use ProductOpener::APITest qw/create_user execute_api_tests login new_client wait_application_ready/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Users qw/retrieve_user/;

use File::Basename "dirname";

use Storable qw/dclone/;

wait_application_ready(__FILE__);
remove_all_products();
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'csrf-test@example.com'));
create_user($ua, \%create_user_args);

# Login to establish a session
login($ua, $create_user_args{userid}, $default_user_form{password});

# Retrieve the CSRF token from the user's session
my $user_ref = retrieve_user($create_user_args{userid});
my $session_token = (keys %{$user_ref->{user_sessions}})[0];
my $csrf_token = $user_ref->{csrf_token};

# Test 1: GET request to product_multilingual.pl process action should return 405
my $tests_ref = [
	{
		test_case => 'product_multilingual-get-process-returns-405',
		method => 'GET',
		path => '/cgi/product_multilingual.pl?type=edit&code=1234567890001&action=process',
		expected_status_code => 405,
	},
];
execute_api_tests(__FILE__, $tests_ref, $ua);

# Test 2: GET request to export_products.pl process action should return 405
$tests_ref = [
	{
		test_case => 'export_products-get-process-returns-405',
		method => 'GET',
		path => '/cgi/export_products.pl?action=process',
		expected_status_code => 405,
	},
];
execute_api_tests(__FILE__, $tests_ref, $ua);

# Test 3: GET request to org.pl process action should return 405
$tests_ref = [
	{
		test_case => 'org-get-process-returns-405',
		method => 'GET',
		path => '/cgi/org.pl?type=edit&action=process',
		expected_status_code => 405,
	},
];
execute_api_tests(__FILE__, $tests_ref, $ua);

# Test 4: POST request to product_multilingual.pl without CSRF token should return 403
$tests_ref = [
	{
		test_case => 'product_multilingual-post-no-csrf-token-returns-403',
		method => 'POST',
		path => '/cgi/product_multilingual.pl?type=edit&code=1234567890001&action=process',
		form => {
			action => 'process',
			type => 'edit',
			code => '1234567890001',
		},
		expected_status_code => 403,
	},
];
execute_api_tests(__FILE__, $tests_ref, $ua);

# Test 5: POST request to product_multilingual.pl with invalid CSRF token should return 403
$tests_ref = [
	{
		test_case => 'product_multilingual-post-invalid-csrf-token-returns-403',
		method => 'POST',
		path => '/cgi/product_multilingual.pl?type=edit&code=1234567890001&action=process',
		form => {
			action => 'process',
			type => 'edit',
			code => '1234567890001',
			csrf_token => 'invalid_token',
		},
		expected_status_code => 403,
	},
];
execute_api_tests(__FILE__, $tests_ref, $ua);

# Test 6: POST request to product_multilingual.pl with valid CSRF token should NOT return 403
# The product doesn't exist, so we expect 404 (CSRF validation passed, request reached product lookup)
$tests_ref = [
	{
		test_case => 'product_multilingual-post-valid-csrf-token-proceeds',
		method => 'POST',
		path => '/cgi/product_multilingual.pl?type=edit&code=1234567890001&action=process',
		form => {
			action => 'process',
			type => 'edit',
			code => '1234567890001',
			csrf_token => $csrf_token,
		},
		expected_status_code => 404,
		expected_type => 'none',
	},
];
execute_api_tests(__FILE__, $tests_ref, $ua);

done_testing();
