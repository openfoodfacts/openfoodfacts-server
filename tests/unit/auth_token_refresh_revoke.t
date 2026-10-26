#!/usr/bin/perl -w

# Unit coverage for soft-fail refresh_access_token() and revoke_token()
# used to keep PO sessions in sync with Keycloak Device Activity (auth#459).

use ProductOpener::PerlStandards;

use Test2::V0;
use HTTP::Response;
use HTTP::Headers;

use ProductOpener::Auth qw/refresh_access_token revoke_token/;
use ProductOpener::Config qw/%oidc_options/;

subtest 'refresh_access_token returns nothing without a token' => sub {
	my @result = refresh_access_token(undef);
	is(\@result, [], 'no refresh token yields empty list');
	@result = refresh_access_token('');
	is(\@result, [], 'empty refresh token yields empty list');
};

subtest 'refresh_access_token soft-fails when the IdP rejects the refresh' => sub {
	my $client = mock {} => (
		add => [
			refresh_access_token => sub {return;},
			errstr => sub {'invalid_grant'},
		],
	);
	my $auth_mock = mock 'ProductOpener::Auth' => (override => [_get_client => sub {$client},],);

	my @result = refresh_access_token('dead-refresh-token');
	is(\@result, [], 'failed refresh returns empty list instead of dying');

	$auth_mock = undef;
};

subtest 'refresh_access_token returns rotated tokens on success' => sub {
	my $client = mock {} => (
		add => [
			refresh_access_token => sub {
				return {
					refresh_token => 'rotated-refresh',
					refresh_expires_in => 3600,
					access_token => 'new-access',
					expires_in => 300,
				};
			},
			errstr => sub {''},
		],
	);
	my $auth_mock = mock 'ProductOpener::Auth' => (override => [_get_client => sub {$client},],);

	my ($refresh, $refresh_exp, $access, $access_exp) = refresh_access_token('good-refresh');
	is($refresh, 'rotated-refresh', 'returns rotated refresh token');
	is($access, 'new-access', 'returns new access token');
	ok($refresh_exp > time(), 'refresh expiry is absolute');
	ok($access_exp > time(), 'access expiry is absolute');

	$auth_mock = undef;
};

subtest 'revoke_token is a no-op without a token' => sub {
	ok(!revoke_token(undef), 'undef token');
	ok(!revoke_token(''), 'empty token');
};

subtest 'revoke_token returns when revocation_endpoint is missing' => sub {
	my $auth_mock = mock 'ProductOpener::Auth' => (
		override => [
			get_oidc_configuration => sub {
				return {issuer => 'https://issuer.example'};
			},
		],
	);

	ok(!revoke_token('some-token'), 'no revocation_endpoint');
	$auth_mock = undef;
};

subtest 'revoke_token posts to the revocation endpoint' => sub {
	local $oidc_options{client_id} = 'test-client';
	local $oidc_options{client_secret} = 'test-secret';

	my $request_state_ref = {calls => 0, last_content => undef, last_uri => undef};
	my $auth_mock = mock 'ProductOpener::Auth' => (
		override => [
			get_oidc_configuration => sub {
				return {revocation_endpoint => 'https://issuer.example/revoke'};
			},
		],
	);
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				$request_state_ref->{calls}++;
				$request_state_ref->{last_uri} = $request->uri->as_string;
				$request_state_ref->{last_content} = $request->content;
				return HTTP::Response->new(200, 'OK', HTTP::Headers->new(), '');
			},
		],
	);

	ok(revoke_token('refresh-abc', 'refresh_token'), 'successful revoke');
	is($request_state_ref->{calls}, 1, 'one HTTP request');
	is($request_state_ref->{last_uri}, 'https://issuer.example/revoke', 'posts to revocation_endpoint');
	like($request_state_ref->{last_content}, qr/token=refresh-abc/, 'includes token');
	like($request_state_ref->{last_content}, qr/client_id=test-client/, 'includes client_id');
	like($request_state_ref->{last_content}, qr/token_type_hint=refresh_token/, 'includes token_type_hint');

	$ua_mock = undef;
	$auth_mock = undef;
};

subtest 'revoke_token soft-fails when the IdP returns an error' => sub {
	my $auth_mock = mock 'ProductOpener::Auth' => (
		override => [
			get_oidc_configuration => sub {
				return {revocation_endpoint => 'https://issuer.example/revoke'};
			},
		],
	);
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				return HTTP::Response->new(400, 'Bad Request', HTTP::Headers->new(), 'invalid_token');
			},
		],
	);

	ok(!revoke_token('bad-token'), 'failed revoke returns false');

	$ua_mock = undef;
	$auth_mock = undef;
};

done_testing();
