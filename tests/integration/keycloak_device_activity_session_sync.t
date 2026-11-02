#!/usr/bin/perl -w

# Covers openfoodfacts-auth#459:
# 1) PO logout revokes refresh/offline token (Device Activity should clear)
# 2) After IdP invalidates refresh + access token expired, PO signs user out
#
# Note: do not call remove_all_users() — the seeded "tests" user is shared with
# other integration tests in the same CI group (see session_revocation.t).

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::APITest qw/construct_test_url login new_client wait_application_ready create_user/;
use ProductOpener::Test qw/remove_all_users/;
use ProductOpener::TestDefaults qw/%default_user_form/;
use ProductOpener::Auth qw/password_signin refresh_access_token/;
use ProductOpener::Users
	qw/retrieve_user_preferences remove_all_user_sessions store_user_preferences open_user_session update_user_session_tokens/;

wait_application_ready(__FILE__);
remove_all_users();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@example.com'));
create_user($ua, \%create_user_args);

my $test_user_id = 'tests';
my $test_user_password = 'testtest';

sub get_session_cookie_value ($ua) {
	my $session_cookie_value;
	$ua->cookie_jar->scan(
		sub {
			my (undef, $name, $value) = @_;
			$session_cookie_value = $value if $name eq 'session';
		}
	);
	return $session_cookie_value;
}

sub session_id_from_cookie ($session_cookie_value) {
	my ($user_session) = ($session_cookie_value // '') =~ /user_session&([^&]*)/;
	return $user_session;
}

subtest 'Problem 1: PO logout revokes refresh token' => sub {
	remove_all_user_sessions($test_user_id);

	my $ua = new_client();
	login($ua, $test_user_id, $test_user_password);

	my $session_cookie_value = get_session_cookie_value($ua);
	ok(defined $session_cookie_value, 'login set a session cookie');
	my $user_session = session_id_from_cookie($session_cookie_value);
	ok(defined $user_session, 'session cookie contains user_session');

	my $user_ref = retrieve_user_preferences($test_user_id);
	my $session_ref = $user_ref->{user_sessions}{$user_session};
	ok(defined $session_ref->{refresh_token}, 'server session stores refresh_token');
	ok(defined $session_ref->{access_token}, 'server session stores access_token');
	ok(defined $session_ref->{id_token}, 'server session stores id_token');
	ok(!ref($session_ref->{id_token}), 'id_token is a raw JWT string for id_token_hint');

	my $refresh_token_before = $session_ref->{refresh_token};

	# Sanity: refresh works before logout
	my (undef, undef, $access_before) = refresh_access_token($refresh_token_before);
	ok($access_before, 'refresh works before logout');

	# Re-login so stored refresh token was not rotated by the sanity check
	remove_all_user_sessions($test_user_id);
	$ua = new_client();
	login($ua, $test_user_id, $test_user_password);
	$session_cookie_value = get_session_cookie_value($ua);
	$user_session = session_id_from_cookie($session_cookie_value);
	$user_ref = retrieve_user_preferences($test_user_id);
	$session_ref = $user_ref->{user_sessions}{$user_session};
	$refresh_token_before = $session_ref->{refresh_token};

	# OIDC sign-out revokes refresh token then redirects to end_session
	$ua->max_redirect(0);
	my $signout
		= $ua->post(construct_test_url('/cgi/oidc_signout.pl'),
		[return_url => 'http://world.openfoodfacts.localhost/']);
	is($signout->code, 302, 'oidc_signout redirects to Keycloak end_session')
		or diag($signout->status_line . ' loc=' . ($signout->header('Location') // ''));
	my $location = $signout->header('Location') // '';
	like($location, qr{openid-connect/logout}, 'redirect targets Keycloak logout');
	like($location, qr/id_token_hint=/, 'logout URL includes id_token_hint');

	# Refresh must fail after revoke (offline/Device Activity equivalent)
	my (undef, undef, $a2) = refresh_access_token($refresh_token_before);
	ok(!$a2, 'refresh fails after PO logout / token revoke')
		or diag('refresh unexpectedly succeeded after logout');
};

subtest 'Problem 2: revoked refresh + expired access token signs PO out via init_user' => sub {
	remove_all_user_sessions($test_user_id);

	my $ua = new_client();
	login($ua, $test_user_id, $test_user_password);

	my $session_cookie_value = get_session_cookie_value($ua);
	my $user_session = session_id_from_cookie($session_cookie_value);
	ok(defined $user_session, 'session cookie contains user_session');

	my $user_ref = retrieve_user_preferences($test_user_id);
	my $session_ref = $user_ref->{user_sessions}{$user_session};
	ok(defined $session_ref->{refresh_token}, 'refresh_token present');
	my $refresh_token = $session_ref->{refresh_token};

	my $auth_ok = $ua->get(construct_test_url('/cgi/auth.pl'));
	is($auth_ok->code, 200, 'session authenticates before Device Activity revoke');

	# Simulate Device Activity signing out this client session:
	# Keycloak invalidates the refresh/offline token (admin logout-all does NOT).
	ProductOpener::Auth::revoke_token($refresh_token, 'refresh_token');

	# Access token already expired (expected timing for Device Activity sync)
	$user_ref = retrieve_user_preferences($test_user_id);
	$user_ref->{user_sessions}{$user_session}{access_expires_at} = time() - 10;
	store_user_preferences($user_ref);

	# Next request should refresh, fail, and clear local session in init_user
	my $auth_after = $ua->get(construct_test_url('/cgi/auth.pl'));
	is($auth_after->code, 403, 'session does not authenticate after revoke + access expiry')
		or diag($auth_after->status_line . ' ' . substr($auth_after->content // '', 0, 500));

	$user_ref = retrieve_user_preferences($test_user_id);
	is($user_ref->{user_sessions}{$user_session}, undef, 'local session removed after failed refresh')
		or diag('sessions still: ' . join(',', keys %{$user_ref->{user_sessions} // {}}));
};

subtest 'password_signin stores JWT id_token; refresh tokens can be persisted' => sub {
	remove_all_user_sessions($test_user_id);

	my ($user_ref, $refresh_token, $refresh_expires_at, $access_token, $access_expires_at, $id_token)
		= password_signin($test_user_id, $test_user_password, {});
	ok($user_ref, 'password_signin works');
	ok(!ref($id_token), 'password_signin returns raw JWT id_token');
	like($id_token, qr/\./, 'id_token looks like a JWT');

	my ($new_refresh, $new_refresh_exp, $new_access, $new_access_exp) = refresh_access_token($refresh_token);
	ok($new_access, 'refresh_access_token returns new access token');
	ok($new_refresh, 'refresh_access_token returns refresh token');

	my $request_ref = {};
	my $sid = open_user_session($user_ref, $refresh_token, $refresh_expires_at,
		$access_token, $access_expires_at, $id_token, $request_ref);
	ok($sid, 'opened user session');

	ok(update_user_session_tokens($user_ref, $sid, $new_refresh, $new_refresh_exp, $new_access, $new_access_exp),
		'update_user_session_tokens succeeds');

	my $stored = retrieve_user_preferences($test_user_id);
	is($stored->{user_sessions}{$sid}{access_token}, $new_access, 'persisted access token updated');
	is($stored->{user_sessions}{$sid}{refresh_token}, $new_refresh, 'persisted refresh token updated');
};

done_testing();
