#!/usr/bin/perl -w

# Unit coverage for app-<azp> synthetic M2M client identities
# (client_credentials / service-account tokens without a PO user).

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Users qw/init_user $User_id %User/;

{

	package FakeApacheReq;

	sub new ($class, $auth) {
		return bless {auth => $auth}, $class;
	}

	sub headers_in ($self) {
		return defined $self->{auth} ? {Authorization => $self->{auth}} : {};
	}
}

sub _mock_users ($verify_sub, $retrieve_sub) {
	return mock 'ProductOpener::Users' => (
		override => [
			verify_access_token => $verify_sub,
			retrieve_user_using_token => $retrieve_sub,
		],
	);
}

subtest 'service-account token maps to synthetic app user' => sub {
	my $users_mock = _mock_users(
		sub {return {azp => 'myclient', preferred_username => 'service-account-myclient', scope => 'products:write'};},
		sub {die 'retrieve_user_using_token must not be consulted for service accounts';},
	);

	my $request_ref = {};
	my $r = FakeApacheReq->new('Bearer svc-token');
	is(ProductOpener::Users::process_auth_header($request_ref, $r), 1, 'service-account token authenticates');
	is($request_ref->{oidc_user_id}, 'app-myclient', 'oidc_user_id is app-<azp>');
	is($request_ref->{oidc_client_id}, 'myclient', 'oidc_client_id is azp');
	is($request_ref->{client_id}, 'myclient', 'client_id is azp');
	is($request_ref->{is_client}, 1, 'is_client flag is set');
	is($request_ref->{access_token}, 'svc-token', 'raw token is kept for scope checks');

	$users_mock = undef;
};

subtest 'service-account match is case-insensitive on username' => sub {
	# Keycloak lowercases the service account username while azp keeps its case.
	# The synthetic id itself is lowercased to match tag canonicalization.
	my $users_mock = _mock_users(
		sub {return {azp => 'OFF', preferred_username => 'service-account-off'};},
		sub {die 'retrieve_user_using_token must not be consulted for service accounts';},
	);

	my $request_ref = {};
	my $r = FakeApacheReq->new('Bearer svc-token');
	is(ProductOpener::Users::process_auth_header($request_ref, $r), 1, 'mixed-case service account authenticates');
	is($request_ref->{oidc_user_id}, 'app-off', 'app id is lowercased');
	is($request_ref->{oidc_client_id}, 'OFF', 'exact azp is kept separately');

	$users_mock = undef;
};

subtest 'regular user token still resolves via retrieve_user_using_token' => sub {
	my $users_mock
		= _mock_users(sub {return {azp => 'OFF', preferred_username => 'bob'};}, sub {return {userid => 'bob'};},);

	my $request_ref = {};
	my $r = FakeApacheReq->new('Bearer user-token');
	is(ProductOpener::Users::process_auth_header($request_ref, $r), 1, 'user token authenticates');
	is($request_ref->{oidc_user_id}, 'bob', 'oidc_user_id is the userid');
	ok(!defined $request_ref->{is_client}, 'is_client is not set for real users');

	$users_mock = undef;
};

subtest 'unknown user with regular azp is rejected, not mapped to app-*' => sub {
	my $users_mock = _mock_users(sub {return {azp => 'OFF', preferred_username => 'ghost'};}, sub {return;},);

	my $request_ref = {};
	my $r = FakeApacheReq->new('Bearer ghost-token');
	is(ProductOpener::Users::process_auth_header($request_ref, $r), -1, 'unknown user returns -1');
	ok(!defined $request_ref->{oidc_user_id}, 'no synthetic identity is created');

	$users_mock = undef;
};

subtest 'azp / preferred_username mismatch is rejected' => sub {
	my $users_mock = _mock_users(sub {return {azp => 'clientA', preferred_username => 'service-account-clientB'};},
		sub {return;},);

	my $request_ref = {};
	my $r = FakeApacheReq->new('Bearer mismatch-token');
	is(ProductOpener::Users::process_auth_header($request_ref, $r), -1, 'mismatched service-account returns -1');
	ok(!defined $request_ref->{oidc_user_id}, 'no synthetic identity is created');

	$users_mock = undef;
};

subtest 'invalid token and missing header' => sub {
	{
		my $users_mock = _mock_users(sub {return;}, sub {die 'must not be called';},);

		my $request_ref = {};
		my $r = FakeApacheReq->new('Bearer bad-token');
		is(ProductOpener::Users::process_auth_header($request_ref, $r), -1, 'unverifiable token returns -1');

		$users_mock = undef;
	}

	{
		my $request_ref = {};
		my $r = FakeApacheReq->new(undef);
		is(ProductOpener::Users::process_auth_header($request_ref, $r), 0, 'missing header returns 0');
	}
};

subtest 'init_user accepts synthetic client without session or .sto file' => sub {
	my $app_id = 'app-unit-test-client';
	my $sto_path = "$BASE_DIRS{USERS}/$app_id.sto";
	unlink($sto_path);

	# retrieve_user must not be consulted for synthetic clients
	my $users_mock = mock 'ProductOpener::Users' => (
		override => [
			retrieve_user => sub {die 'retrieve_user must not be called for synthetic clients';},
		],
	);

	my $request_ref = {oidc_user_id => $app_id, is_client => 1};
	is(init_user($request_ref), 0, 'init_user succeeds');
	is($User_id, $app_id, 'User_id is the synthetic app id');
	is($User{userid}, $app_id, '%User is the synthetic identity');
	is($User{is_client}, 1, 'is_client survives in %User');
	ok(!defined $request_ref->{cookie}, 'no session cookie is set for stateless clients');
	ok(!-e $sto_path, 'no .sto file is created for synthetic clients');

	$users_mock = undef;
	unlink($sto_path);
};

subtest 'init_user without is_client flag still goes through retrieve_user' => sub {
	my $called = 0;
	my $users_mock = mock 'ProductOpener::Users' => (
		override => [
			retrieve_user => sub {
				$called++;
				return {userid => 'app-foo', name => 'real app-foo user'};
			},
		],
	);

	my $request_ref = {oidc_user_id => 'app-foo'};
	is(init_user($request_ref), 0, 'init_user succeeds');
	is($User_id, 'app-foo', 'real app-foo user keeps its identity');
	is($called, 1, 'retrieve_user was consulted (no synthetic shortcut without is_client)');

	$users_mock = undef;
};

subtest 'tagid classification keeps legacy app users separate' => sub {
	ok('app-myclient' =~ /^app-[^.]++$/, 'synthetic app-<azp> matches');
	ok('app-foo.bar' !~ /^app-[^.]++$/, 'legacy appid.uuid does not match synthetic pattern');
	ok('app-foo.bar' =~ /\./, 'legacy appid.uuid still matches dot rule');
	ok('org-foo' =~ /^org-/, 'org prefix still matches first');
};

done_testing();
