#!/usr/bin/perl -w

# Per-request API auth with user_id+password must not open a Product Opener session cookie,
# and must revoke the Keycloak session created by the password grant. Explicit login
# (auth.pl / login.pl / session.pl) still creates a lasting session. See #15091.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::APITest qw/construct_test_url create_user_in_keycloak new_client wait_application_ready/;
use ProductOpener::Auth
	qw/get_oidc_configuration get_oidc_implementation_level get_token_using_password_credentials revoke_token/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Test qw/remove_all_products remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Users qw/retrieve_user_preferences/;

use HTTP::Request;
use LWP::UserAgent::Plugin 'Retry';
use URI::Escape::XS qw/uri_escape/;

wait_application_ready(__FILE__);

if (get_oidc_implementation_level() < 2) {
	plan skip_all => 'OIDC implementation level < 2; password auth does not use Keycloak';
}

remove_all_products();
remove_all_users();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user_in_keycloak(\%create_user_args);

my $test_user_id = 'tests';
my $test_user_password = 'testtest';

sub count_po_sessions ($userid) {
	my $user_ref = retrieve_user_preferences($userid);
	return 0 unless defined $user_ref;
	return scalar keys %{$user_ref->{user_sessions} // {}};
}

sub can_refresh ($refresh_token) {
	my $oidc_configuration = get_oidc_configuration();
	my $token_request = HTTP::Request->new(POST => $oidc_configuration->{token_endpoint});
	$token_request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$token_request->content('grant_type=refresh_token&client_id='
			. uri_escape($oidc_options{client_id})
			. '&client_secret='
			. uri_escape($oidc_options{client_secret})
			. '&refresh_token='
			. uri_escape($refresh_token));
	my $token_response = LWP::UserAgent::Plugin->new->request($token_request);
	return $token_response->is_success ? 1 : 0;
}

subtest 'password grant without persistent session can be revoked' => sub {
	my $token = get_token_using_password_credentials($test_user_id, $test_user_password, 0);
	ok($token, 'password grant without persistent session succeeds');
	ok($token->{refresh_token}, 'online session still returns a refresh token');
	unlike($token->{scope} // '', qr/\boffline_access\b/, 'scope does not include offline_access');

	ok(revoke_token($token->{refresh_token}, 'refresh_token'), 'refresh token session is revoked');
	ok(!can_refresh($token->{refresh_token}), 'revoked refresh token cannot be reused');
};

subtest 'API password auth does not persist a Product Opener session' => sub {
	my $po_sessions_before = count_po_sessions($test_user_id);

	my $ua = new_client();
	my $response = $ua->post(
		construct_test_url('/cgi/product_jqm_multilingual.pl'),
		{
			user_id => $test_user_id,
			password => $test_user_password,
			code => '3017620422003',
			product_name => 'Password API session test',
		}
	);
	ok($response->is_success, 'product update with user_id+password succeeds')
		or diag($response->status_line . ' ' . $response->decoded_content);

	my $got_session_cookie = 0;
	$ua->cookie_jar->scan(
		sub {
			my (undef, $name) = @_;
			$got_session_cookie = 1 if $name eq 'session';
		}
	);
	ok(!$got_session_cookie, 'API password auth does not set a session cookie');
	is(count_po_sessions($test_user_id), $po_sessions_before,
		'API password auth does not store a Product Opener session');
};

subtest 'explicit auth.pl login still creates a lasting session' => sub {
	my $po_sessions_before = count_po_sessions($test_user_id);

	my $ua = new_client();
	my $response = $ua->post(
		construct_test_url('/cgi/auth.pl'),
		{
			user_id => $test_user_id,
			password => $test_user_password,
			body => 1,
		}
	);
	is($response->code, 200, 'auth.pl login succeeds') or diag($response->status_line);

	my $got_session_cookie = 0;
	$ua->cookie_jar->scan(
		sub {
			my (undef, $name) = @_;
			$got_session_cookie = 1 if $name eq 'session';
		}
	);
	ok($got_session_cookie, 'auth.pl sets a session cookie');
	ok(count_po_sessions($test_user_id) > $po_sessions_before,
		'auth.pl stores a Product Opener session');
};

done_testing();
