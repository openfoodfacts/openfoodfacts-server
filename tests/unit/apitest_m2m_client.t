#!/usr/bin/perl -w

# Unit coverage for the M2M Keycloak client test helpers in
# ProductOpener::APITest, using a mocked user agent so no real
# Keycloak is needed (covers the create/delete/token success paths
# that the integration test cannot reach without manage-clients).

use ProductOpener::PerlStandards;

use Test2::V0;
use HTTP::Response;
use HTTP::Headers;

use ProductOpener::APITest qw/create_client_in_keycloak delete_client_in_keycloak
	get_token_using_client_credentials_for/;

my $ADMIN_AUTH = 'Bearer admin-token';
my $CLIENTS_ENDPOINT = 'https://kc.example/admin/realms/r/clients';

sub _mock_keycloak () {
	return mock 'ProductOpener::Keycloak' => (
		override => [
			new => sub {
				my ($class) = @_;
				return bless {users_endpoint => 'https://kc.example/admin/realms/r/users'}, $class;
			},
			get_or_refresh_token => sub {return {token_type => 'Bearer', access_token => 'admin-token'};},
		],
	);
}

sub _mock_oidc () {
	return mock 'ProductOpener::APITest' => (
		override => [
			get_oidc_configuration => sub {
				return {token_endpoint => 'https://kc.example/realms/r/protocol/openid-connect/token'};
			},
		],
	);
}

sub _json_response ($code, $message, $content, $headers = undef) {
	return HTTP::Response->new($code, $message, $headers // HTTP::Headers->new(), $content);
}

subtest 'create_client_in_keycloak creates a fresh client' => sub {
	my $keycloak_mock = _mock_keycloak();
	my @calls;
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				push @calls, [$request->method, $request->uri->as_string];
				is($request->header('Authorization'), $ADMIN_AUTH, 'admin auth header is sent');
				my $uri = $request->uri->as_string;
				if ($request->method eq 'GET' and $uri =~ /\/clients\?/) {
					return _json_response(200, 'OK', '[]');
				}
				if ($request->method eq 'POST' and $uri eq $CLIENTS_ENDPOINT) {
					my $response = _json_response(201, 'Created', '');
					$response->header('Location' => "$CLIENTS_ENDPOINT/uuid-123");
					return $response;
				}
				if ($uri =~ /\/client-secret$/) {
					return _json_response(200, 'OK', '{"value":"s3cret"}');
				}
				return _json_response(500, 'Unexpected', '{}');
			},
		],
	);

	my $client_ref = create_client_in_keycloak('test-m2m');
	is(
		$client_ref,
		{client_id => 'test-m2m', client_secret => 's3cret', id => 'uuid-123'},
		'returns client id, generated secret and internal uuid'
	);
	ok((grep {$_->[0] eq 'DELETE'} @calls) == 0, 'no delete when nothing pre-exists');

	$ua_mock = undef;
	$keycloak_mock = undef;
};

subtest 'create_client_in_keycloak deletes pre-existing clients first' => sub {
	my $keycloak_mock = _mock_keycloak();
	my @calls;
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				push @calls, [$request->method, $request->uri->as_string];
				my $uri = $request->uri->as_string;
				if ($request->method eq 'GET' and $uri =~ /\/clients\?/) {
					return _json_response(200, 'OK', '[{"id":"old-uuid","clientId":"test-m2m"}]');
				}
				if ($request->method eq 'DELETE') {
					return _json_response(204, 'No Content', '');
				}
				if ($request->method eq 'POST' and $uri eq $CLIENTS_ENDPOINT) {
					my $response = _json_response(201, 'Created', '');
					$response->header('Location' => "$CLIENTS_ENDPOINT/uuid-456");
					return $response;
				}
				if ($uri =~ /\/client-secret$/) {
					return _json_response(200, 'OK', '{"value":"s3cret2"}');
				}
				return _json_response(500, 'Unexpected', '{}');
			},
		],
	);

	my $client_ref = create_client_in_keycloak('test-m2m');
	is($client_ref->{id}, 'uuid-456', 'new client uuid is returned');
	ok((grep {$_->[0] eq 'DELETE' and $_->[1] =~ /\/old-uuid$/} @calls),
		'pre-existing client is deleted before creation');

	$ua_mock = undef;
	$keycloak_mock = undef;
};

subtest 'create_client_in_keycloak falls back to re-list without Location' => sub {
	my $keycloak_mock = _mock_keycloak();
	my $search_calls = 0;
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				my $uri = $request->uri->as_string;
				if ($request->method eq 'GET' and $uri =~ /\/clients\?/) {
					$search_calls++;
					return $search_calls == 1
						? _json_response(200, 'OK', '[]')
						: _json_response(200, 'OK', '[{"id":"uuid-9","clientId":"test-m2m"}]');
				}
				if ($request->method eq 'POST') {
					return _json_response(201, 'Created', '');
				}
				if ($uri =~ /\/client-secret$/) {
					return _json_response(200, 'OK', '{"value":"s3cret"}');
				}
				return _json_response(500, 'Unexpected', '{}');
			},
		],
	);

	my $client_ref = create_client_in_keycloak('test-m2m');
	is($client_ref->{id}, 'uuid-9', 'uuid from re-listing is used');

	$ua_mock = undef;
	$keycloak_mock = undef;
};

subtest 'create_client_in_keycloak dies with status on failure' => sub {
	my $keycloak_mock = _mock_keycloak();
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				return _json_response(403, 'Forbidden', '{"error":"HTTP 403 Forbidden"}');
			},
		],
	);

	my $client_ref = eval {create_client_in_keycloak('test-m2m');};
	ok(!defined $client_ref, 'no client is returned on failure');
	like($@, qr/\b403\b/, 'error message contains the HTTP status');

	$ua_mock = undef;
	$keycloak_mock = undef;
};

subtest 'delete_client_in_keycloak removes existing clients' => sub {
	my $keycloak_mock = _mock_keycloak();
	my @calls;
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				push @calls, [$request->method, $request->uri->as_string];
				my $uri = $request->uri->as_string;
				if ($request->method eq 'GET') {
					return _json_response(200, 'OK', '[{"id":"gone-uuid","clientId":"test-m2m"}]');
				}
				if ($request->method eq 'DELETE') {
					return _json_response(204, 'No Content', '');
				}
				return _json_response(500, 'Unexpected', '{}');
			},
		],
	);

	ok(delete_client_in_keycloak('test-m2m'), 'delete returns true');
	ok((grep {$_->[0] eq 'DELETE' and $_->[1] =~ /\/gone-uuid$/} @calls), 'existing client is deleted');

	$ua_mock = undef;
	$keycloak_mock = undef;
};

subtest 'delete_client_in_keycloak succeeds silently when absent' => sub {
	my $keycloak_mock = _mock_keycloak();
	my @calls;
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				push @calls, [$request->method, $request->uri->as_string];
				return _json_response(200, 'OK', '[]');
			},
		],
	);

	ok(delete_client_in_keycloak('test-m2m'), 'delete returns true without matches');
	ok((grep {$_->[0] eq 'DELETE'} @calls) == 0, 'no delete is issued without matches');

	$ua_mock = undef;
	$keycloak_mock = undef;
};

subtest 'get_token_using_client_credentials_for posts grant and scope' => sub {
	my $oidc_mock = _mock_oidc();
	my @calls;
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				push @calls, $request;
				return _json_response(200, 'OK', '{"access_token":"m2m-token","token_type":"Bearer"}');
			},
		],
	);

	my $token_ref = get_token_using_client_credentials_for('my-id', 'my-secret', 'products:write');
	is($token_ref->{access_token}, 'm2m-token', 'token is returned');
	my ($token_request) = @calls;
	is(
		$token_request->uri->as_string,
		'https://kc.example/realms/r/protocol/openid-connect/token',
		'token endpoint is used'
	);
	like($token_request->content, qr/grant_type=client_credentials/, 'client_credentials grant is used');
	like($token_request->content, qr/client_id=my-id/, 'client id is sent');
	like($token_request->content, qr/scope=products%3Awrite/, 'scope is sent');

	$ua_mock = undef;
	$oidc_mock = undef;
};

subtest 'get_token_using_client_credentials_for dies on failure' => sub {
	my $oidc_mock = _mock_oidc();
	my $ua_mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				return _json_response(401, 'Unauthorized', '{"error":"invalid_client"}');
			},
		],
	);

	my $token_ref = eval {get_token_using_client_credentials_for('my-id', 'bad-secret');};
	ok(!defined $token_ref, 'no token is returned on failure');
	like($@, qr/\b401\b/, 'error message contains the HTTP status');

	$ua_mock = undef;
	$oidc_mock = undef;
};

done_testing();
