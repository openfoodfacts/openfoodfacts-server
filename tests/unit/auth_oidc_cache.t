use Modern::Perl '2017';
use utf8;

use Test2::V0;
use HTTP::Response;
use HTTP::Headers;
use JSON qw/encode_json/;

use ProductOpener::Auth qw/get_oidc_configuration/;
use ProductOpener::Config qw/%oidc_options/;

no warnings 'redefine';

sub _reload_auth_module {
	# Reset lexical state in Auth.pm between tests ($oidc_configuration, $jwks).
	local $^W = 0;
	delete $INC{'ProductOpener/Auth.pm'};
	require ProductOpener::Auth;
	ProductOpener::Auth->import(qw/get_oidc_configuration/);
	return;
}

sub _mock_oidc_requests {
	my ($request_state_ref, $discovery_endpoint) = @_;
	my $mock = mock 'LWP::UserAgent::Plugin' => (
		override => [
			request => sub {
				my ($self, $request) = @_;
				$request_state_ref->{request_calls}++;

				if ($request_state_ref->{request_throws}) {
					die "mock request failure";
				}

				if ($request->uri->as_string eq $discovery_endpoint) {
					my $content = encode_json(
						{
							issuer => 'https://issuer.example',
							authorization_endpoint => 'https://issuer.example/auth',
							token_endpoint => 'https://issuer.example/token',
							jwks_uri => 'https://issuer.example/jwks',
						}
					);
					return HTTP::Response->new(200, 'OK', HTTP::Headers->new(), $content);
				}

				if ($request->uri->as_string eq 'https://issuer.example/jwks') {
					my $content = encode_json({keys => [{kid => 'k1', kty => 'RSA', use => 'sig'}]});
					return HTTP::Response->new(200, 'OK', HTTP::Headers->new(), $content);
				}

				return HTTP::Response->new(404, 'Not Found', HTTP::Headers->new(), '{}');
			},
		],
	);
	return $mock;
}

subtest 'cache hit avoids network and returns cached OIDC config' => sub {
	_reload_auth_module();
	my $discovery_endpoint = 'https://issuer.example/.well-known/openid-configuration';
	local $oidc_options{oidc_discovery_url} = $discovery_endpoint;

	my $cache_store_ref = {};
	my $cache_mode_ref = {get_calls => 0, set_calls => 0, set_ttls => {}};
	my $cache_key_oidc
		= ProductOpener::Cache::generate_cache_key('oidc_configuration', {discovery_endpoint => $discovery_endpoint});
	my $cache_key_jwks
		= ProductOpener::Cache::generate_cache_key('oidc_jwks', {jwks_uri => 'https://issuer.example/jwks'});
	$cache_store_ref->{$cache_key_oidc} = {
		issuer => 'https://issuer.example',
		authorization_endpoint => 'https://issuer.example/auth',
		token_endpoint => 'https://issuer.example/token',
		jwks_uri => 'https://issuer.example/jwks',
	};
	$cache_store_ref->{$cache_key_jwks} = {keys => [{kid => 'k1', kty => 'RSA', use => 'sig'}]};

	my $request_state_ref = {request_calls => 0};
	my $cache_mock = mock 'ProductOpener::Auth' => (
		override => [
			'safe_cache_get' => sub {
				my ($key) = @_;
				$cache_mode_ref->{get_calls}++;
				return $cache_store_ref->{$key};
			},
			'safe_cache_set' => sub {
				my ($key, $value, $ttl) = @_;
				$cache_mode_ref->{set_calls}++;
				$cache_mode_ref->{set_ttls}{$key} = $ttl;
				$cache_store_ref->{$key} = $value;
				return;
			},
		],
	);
	my $request_mock = _mock_oidc_requests($request_state_ref, $discovery_endpoint);

	my $config_ref = get_oidc_configuration();

	is($config_ref->{issuer}, 'https://issuer.example', 'returns cached OIDC configuration');
	is($request_state_ref->{request_calls}, 0, 'does not call OIDC network when both cache entries are warm');
	ok($cache_mode_ref->{get_calls} >= 2, 'checks cache for OIDC config and JWKS');

	$cache_mock = undef;
	$request_mock = undef;
};

subtest 'cache miss fetches data and stores both keys with 2h TTL' => sub {
	_reload_auth_module();
	my $discovery_endpoint = 'https://issuer.example/.well-known/openid-configuration';
	local $oidc_options{oidc_discovery_url} = $discovery_endpoint;

	my $cache_store_ref = {};
	my $cache_mode_ref = {get_calls => 0, set_calls => 0, set_ttls => {}};
	my $request_state_ref = {request_calls => 0};
	my $cache_mock = mock 'ProductOpener::Auth' => (
		override => [
			'safe_cache_get' => sub {
				my ($key) = @_;
				$cache_mode_ref->{get_calls}++;
				return $cache_store_ref->{$key};
			},
			'safe_cache_set' => sub {
				my ($key, $value, $ttl) = @_;
				$cache_mode_ref->{set_calls}++;
				$cache_mode_ref->{set_ttls}{$key} = $ttl;
				$cache_store_ref->{$key} = $value;
				return;
			},
		],
	);
	my $request_mock = _mock_oidc_requests($request_state_ref, $discovery_endpoint);

	my $config_ref = get_oidc_configuration();

	is($config_ref->{token_endpoint}, 'https://issuer.example/token', 'fetches OIDC config on cache miss');
	is($request_state_ref->{request_calls}, 2, 'calls network for discovery and JWKS on cold cache');

	my @ttls = values %{$cache_mode_ref->{set_ttls}};
	ok(scalar(@ttls) >= 2, 'stores OIDC and JWKS in cache');
	is([sort {$a <=> $b} @ttls], [7200, 7200], 'both cached entries use 2h TTL');

	$cache_mock = undef;
	$request_mock = undef;
};

subtest 'cache miss still falls back to direct fetch' => sub {
	_reload_auth_module();
	my $discovery_endpoint = 'https://issuer.example/.well-known/openid-configuration';
	local $oidc_options{oidc_discovery_url} = $discovery_endpoint;

	my $cache_mode_ref = {get_calls => 0, set_calls => 0, set_ttls => {}};
	my $request_state_ref = {request_calls => 0};
	my $cache_mock = mock 'ProductOpener::Auth' => (
		override => [
			'safe_cache_get' => sub {
				my ($key) = @_;
				$cache_mode_ref->{get_calls}++;
				return;
			},
			'safe_cache_set' => sub {
				my ($key, $value, $ttl) = @_;
				$cache_mode_ref->{set_calls}++;
				$cache_mode_ref->{set_ttls}{$key} = $ttl;
				return;
			},
		],
	);
	my $request_mock = _mock_oidc_requests($request_state_ref, $discovery_endpoint);

	my $config_ref = get_oidc_configuration();

	is($config_ref->{authorization_endpoint}, 'https://issuer.example/auth', 'returns config when cache is cold');
	is($request_state_ref->{request_calls}, 2, 'fetches discovery + JWKS on cache miss');

	$cache_mock = undef;
	$request_mock = undef;
};

done_testing();
