#!/usr/bin/perl -w

# init_user() password auth: persist session only for explicit login endpoints
# (auth.pl / login.pl / session.pl); otherwise revoke the Keycloak session (#15091).

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Auth qw/get_oidc_implementation_level/;
use ProductOpener::Users qw/init_user $User_id/;

skip_all('OIDC implementation level < 2') if get_oidc_implementation_level() < 2;

my $test_user_id = 'password-session-persist';
my $test_password = 'test-password';
my $refresh_token = 'refresh-token-1';

sub _request_with_password ($script_name, %extra_body) {
	return {
		script_name => $script_name,
		body_json => {
			user_id => $test_user_id,
			password => $test_password,
			%extra_body,
		},
	};
}

sub _mock_password_auth () {
	my $opened_session = 0;
	my $revoked = 0;
	my $persist_arg;

	my $users_mock = mock 'ProductOpener::Users' => (
		override => [
			password_signin => sub ($username, $password, $request_ref, $persistent = 1) {
				$persist_arg = $persistent;
				return (
					{userid => $test_user_id},
					$refresh_token, time() + 3600,
					'access-1', time() + 300, 'id-token-1'
				);
			},
			revoke_token => sub ($token, $hint = 'refresh_token') {
				$revoked = 1 if ($token eq $refresh_token) and ($hint eq 'refresh_token');
				return 1;
			},
			open_user_session => sub {
				$opened_session = 1;
				return;
			},
			update_external_login_time => sub {
				return;
			},
		],
	);

	return ($users_mock, \$opened_session, \$revoked, \$persist_arg);
}

subtest 'auth.pl persists a session' => sub {
	delete $ENV{HTTP_COOKIE};
	my ($users_mock, $opened_session_ref, $revoked_ref, $persist_arg_ref) = _mock_password_auth();

	my $request_ref = _request_with_password('/cgi/auth.pl');
	is(init_user($request_ref), 0, 'init_user succeeds');
	is($User_id, $test_user_id, 'user is signed in');
	ok($$persist_arg_ref, 'password_signin called with persistent=true');
	ok($$opened_session_ref, 'open_user_session called');
	ok(!$$revoked_ref, 'refresh token not revoked');

	$users_mock = undef;
};

subtest 'login.pl and session.pl also persist a session' => sub {
	foreach my $script_name ('/cgi/login.pl', '/cgi/session.pl') {
		delete $ENV{HTTP_COOKIE};
		my ($users_mock, $opened_session_ref, $revoked_ref, $persist_arg_ref) = _mock_password_auth();

		my $request_ref = _request_with_password($script_name);
		is(init_user($request_ref), 0, "init_user succeeds for $script_name");
		ok($$persist_arg_ref, "$script_name requests persistent session");
		ok($$opened_session_ref, "$script_name opens a session");
		ok(!$$revoked_ref, "$script_name does not revoke refresh token");

		$users_mock = undef;
	}
};

subtest 'API password auth does not persist and revokes the Keycloak session' => sub {
	delete $ENV{HTTP_COOKIE};
	my ($users_mock, $opened_session_ref, $revoked_ref, $persist_arg_ref) = _mock_password_auth();

	my $request_ref = _request_with_password('/cgi/product_jqm_multilingual.pl');
	is(init_user($request_ref), 0, 'init_user succeeds');
	is($User_id, $test_user_id, 'request is authenticated');
	ok(!$$persist_arg_ref, 'password_signin called with persistent=false');
	ok(!$$opened_session_ref, 'open_user_session not called');
	ok($$revoked_ref, 'refresh token revoked');

	$users_mock = undef;
};

subtest 'no_log on auth.pl skips session persistence and revokes' => sub {
	delete $ENV{HTTP_COOKIE};
	my ($users_mock, $opened_session_ref, $revoked_ref, $persist_arg_ref) = _mock_password_auth();

	my $request_ref = _request_with_password('/cgi/auth.pl', no_log => 1);
	is(init_user($request_ref), 0, 'init_user succeeds');
	ok(!$$persist_arg_ref, 'no_log disables persistent session');
	ok(!$$opened_session_ref, 'open_user_session not called');
	ok($$revoked_ref, 'refresh token revoked');

	$users_mock = undef;
};

done_testing();
