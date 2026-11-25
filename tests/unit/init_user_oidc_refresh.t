#!/usr/bin/perl -w

# init_user() refreshes expired OIDC access tokens and signs out locally when
# refresh fails (openfoodfacts-auth#459 Device Activity sync).

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Auth qw/get_oidc_implementation_level/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Users qw/store_user_preferences retrieve_user_preferences init_user $User_id/;

# These paths only run when Keycloak back-channel auth is enabled
skip_all('OIDC implementation level < 2') if get_oidc_implementation_level() < 2;

my $user_id = 'init-user-oidc-refresh';
my $session_id = 'init-user-oidc-refresh-sid';

sub remove_test_data {
	unlink("$BASE_DIRS{USERS}/$user_id.sto");
	return;
}

remove_test_data();

sub _store_session_with_tokens (%token_overrides) {
	my $session_ref = {
		ip => '127.0.0.1',
		time => time(),
		refresh_token => 'refresh-1',
		refresh_expires_at => time() + 3600,
		access_token => 'access-1',
		access_expires_at => time() - 10,
		id_token => 'id.jwt.token',
		%token_overrides,
	};
	my $user_ref = {
		userid => $user_id,
		user_sessions => {$session_id => $session_ref},
	};
	store_user_preferences($user_ref);
	return $user_ref;
}

sub _set_session_cookie {
	# CGI hash-cookie serialization used by Product Opener sessions
	$ENV{HTTP_COOKIE} = "session=user_id&${user_id}&user_session&${session_id}";
	return;
}

sub _users_mock {
	# Avoid Keycloak network calls from retrieve_user() during unit tests
	return mock 'ProductOpener::Users' => (
		override => [
			retrieve_user => sub {
				my ($id) = @_;
				return retrieve_user_preferences($id);
			},
		],
	);
}

subtest 'expired access token is refreshed and persisted' => sub {
	_store_session_with_tokens();
	_set_session_cookie();
	my $users_mock = _users_mock();
	my $auth_mock = mock 'ProductOpener::Auth' => (
		override => [
			refresh_access_token => sub {
				return ('refresh-2', time() + 3600, 'access-2', time() + 300);
			},
		],
	);

	my $request_ref = {};
	is(init_user($request_ref), 0, 'init_user succeeds');
	is($User_id, $user_id, 'user stays signed in');
	is($request_ref->{access_token}, 'access-2', 'request gets new access token');
	is($request_ref->{refresh_token}, 'refresh-2', 'request gets rotated refresh token');

	my $stored = retrieve_user_preferences($user_id);
	is($stored->{user_sessions}{$session_id}{access_token}, 'access-2', 'session access token persisted');
	is($stored->{user_sessions}{$session_id}{refresh_token}, 'refresh-2', 'session refresh token persisted');

	$auth_mock = undef;
	$users_mock = undef;
	delete $ENV{HTTP_COOKIE};
};

subtest 'failed refresh signs the user out locally' => sub {
	_store_session_with_tokens();
	_set_session_cookie();
	my $users_mock = _users_mock();
	my $auth_mock = mock 'ProductOpener::Auth' => (
		override => [
			refresh_access_token => sub {return;},
		],
	);

	my $request_ref = {};
	is(init_user($request_ref), 0, 'init_user returns');
	ok(!defined $User_id, 'user is signed out');
	ok(!defined $request_ref->{access_token}, 'access token cleared from request');
	ok(!defined $request_ref->{refresh_token}, 'refresh token cleared from request');

	my $stored = retrieve_user_preferences($user_id);
	ok(!defined $stored->{user_sessions}{$session_id}, 'local session removed');

	$auth_mock = undef;
	$users_mock = undef;
	delete $ENV{HTTP_COOKIE};
};

remove_test_data();

done_testing();
