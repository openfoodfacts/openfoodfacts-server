use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;
use JSON qw/encode_json/;
use MIME::Base64 qw(encode_base64);

use ProductOpener::Auth ();
use ProductOpener::Keycloak ();

sub _b64url_encode {
	my ($data) = @_;
	my $b64 = encode_base64($data, '');
	$b64 =~ tr[+/][-_];
	$b64 =~ s/=+$//;
	return $b64;
}

sub _fake_jwt {
	my ($header_ref) = @_;
	return _b64url_encode(encode_json($header_ref)) . '.' . _b64url_encode('{}') . '.c2ln';
}

subtest 'get_token_scopes splits the space-separated scope claim' => sub {
	is(ProductOpener::Auth::get_token_scopes(undef), [], 'undef token gives no scopes');
	is(ProductOpener::Auth::get_token_scopes({}), [], 'missing scope claim gives no scopes');
	is(ProductOpener::Auth::get_token_scopes({scope => ''}), [], 'empty scope claim gives no scopes');
	is(ProductOpener::Auth::get_token_scopes({scope => 'products:read'}),
		['products:read'], 'single scope is extracted');
	is(
		ProductOpener::Auth::get_token_scopes({scope => '  products:read   products:write  '}),
		['products:read', 'products:write'],
		'leading and repeated whitespace is ignored'
	);
	is(
		ProductOpener::Auth::get_token_scopes({scope => "products:read\tproducts:write\n"}),
		['products:read', 'products:write'],
		'tabs and newlines separate scopes'
	);
};

subtest 'has_access_token_scope requires an exact scope match' => sub {
	ok(ProductOpener::Auth::has_access_token_scope({scope => 'products:read products:write'}, 'products:write'),
		'present scope matches');
	ok(!ProductOpener::Auth::has_access_token_scope({scope => 'products:read'}, 'products:write'),
		'absent scope does not match');
	ok(!ProductOpener::Auth::has_access_token_scope({scope => 'products:readwrite'}, 'products:read'),
		'scope prefix does not match');
	ok(!ProductOpener::Auth::has_access_token_scope({scope => 'Products:Read'}, 'products:read'),
		'scope match is case-sensitive');
	ok(!ProductOpener::Auth::has_access_token_scope(undef, 'products:read'), 'undef token has no scope');
};

subtest 'verify_access_token_scopes lists only the missing scopes' => sub {
	my $token = {scope => 'products:read products:write'};
	is([ProductOpener::Auth::verify_access_token_scopes($token, 'products:read')], [], 'no missing scopes');
	is([ProductOpener::Auth::verify_access_token_scopes($token, 'products:read', 'products:write', 'admin')],
		['admin'], 'only the missing scope is reported');
};

subtest 'access token typ header verification' => sub {
	is(ProductOpener::Auth::_verify_access_token_type_header(_fake_jwt({alg => 'RS256', typ => 'JWT'})),
		undef, 'typ JWT is accepted');
	is(ProductOpener::Auth::_verify_access_token_type_header(_fake_jwt({alg => 'RS256', typ => 'at+jwt'})),
		undef, 'typ at+jwt is accepted');
	is(ProductOpener::Auth::_verify_access_token_type_header(_fake_jwt({alg => 'RS256', typ => 'AT+JWT'})),
		undef, 'typ check is case-insensitive');
	like(
		ProductOpener::Auth::_verify_access_token_type_header(_fake_jwt({alg => 'RS256', typ => 'JWS'})) // '',
		qr/unexpected token type/,
		'other typ values are rejected'
	);
	like(
		ProductOpener::Auth::_verify_access_token_type_header(_fake_jwt({alg => 'RS256'})) // '',
		qr/unexpected token type/,
		'missing typ is rejected'
	);
	is(ProductOpener::Auth::_verify_access_token_type_header(''), 'malformed token', 'empty token is malformed');
	is(
		ProductOpener::Auth::_verify_access_token_type_header('a'),
		'malformed token',
		'base64 length % 4 == 1 is malformed'
	);
	like(
		ProductOpener::Auth::_verify_access_token_type_header(_b64url_encode('not json') . '.e30.c2ln') // '',
		qr/invalid token header JSON/,
		'non-JSON header is rejected'
	);
	is(
		ProductOpener::Auth::_verify_access_token_type_header(_b64url_encode('[]') . '.e30.c2ln'),
		'invalid token header',
		'non-object header is rejected'
	);
};

subtest 'require_scope records insufficient_scope when no token is presented' => sub {
	my $request_ref = {api_response => {}};
	ok(!ProductOpener::Auth::require_scope($request_ref, 'products:write'), 'no token fails the scope check');
	is($request_ref->{api_response}{status_code}, 403, 'missing scope is a 403 error');
	is($request_ref->{api_response}{errors}[0]{message}{id},
		'insufficient_scope', 'missing scope uses the insufficient_scope message');
};

subtest 'require_scope reuses the cached verified token without re-verifying' => sub {
	my $request_ref = {
		access_token => 'token-1',
		access_token_verified => {scope => 'products:read products:write'},
		access_token_verified_string => 'token-1',
		api_response => {},
	};
	my $verify_mock = mock 'ProductOpener::Auth' =>
		(override => [verify_access_token => sub {die 'must not re-verify a cached token';},],);
	ok(ProductOpener::Auth::require_scope($request_ref, 'products:write'), 'cached token with scope passes');
	is($request_ref->{api_response}{errors}, undef, 'no error recorded when scope is present');
	$verify_mock = undef;
};

subtest 'require_scope rejects a cached token without the scope' => sub {
	my $request_ref = {
		access_token => 'token-1',
		access_token_verified => {scope => 'products:read'},
		access_token_verified_string => 'token-1',
		api_response => {},
	};
	my $verify_mock = mock 'ProductOpener::Auth' =>
		(override => [verify_access_token => sub {die 'must not re-verify a cached token';},],);
	ok(!ProductOpener::Auth::require_scope($request_ref, 'products:write'), 'cached token without scope fails');
	is($request_ref->{api_response}{status_code}, 403, 'missing scope is a 403 error');
	$verify_mock = undef;
};

subtest 'require_scope verifies and caches an uncached token' => sub {
	my $request_ref = {access_token => 'token-2', api_response => {}};
	my $verify_mock = mock 'ProductOpener::Auth' =>
		(override => [verify_access_token => sub {return {scope => 'products:write'};},],);
	ok(ProductOpener::Auth::require_scope($request_ref, 'products:write'), 'freshly verified token passes');
	is($request_ref->{access_token_verified}, {scope => 'products:write'}, 'verified token is cached on the request');
	is($request_ref->{access_token_verified_string}, 'token-2', 'verified token string is cached');
	$verify_mock = undef;
};

subtest 'require_scope_if_token_present passes through when no token is presented' => sub {
	my $request_ref = {};
	ok(ProductOpener::Auth::require_scope_if_token_present($request_ref, 'products:write'),
		'no token passes through for legacy auth');
	ok((not defined $request_ref->{api_response}), 'no error recorded without a token');
};

subtest 'enforce_scope_if_token_present passes through when no token is presented' => sub {
	ok(ProductOpener::Auth::enforce_scope_if_token_present({}, 'products:write'),
		'no token passes through for legacy auth');
};

subtest 'Keycloak admin token validation' => sub {
	is(ProductOpener::Keycloak::_validate_admin_token(undef), 'missing access token', 'undef token is rejected');
	is(
		ProductOpener::Keycloak::_validate_admin_token({}),
		'missing access token',
		'token without access_token is rejected'
	);

	my $invalid_mock = mock 'ProductOpener::Keycloak' => (override => [verify_access_token => sub {return;},],);
	is(
		ProductOpener::Keycloak::_validate_admin_token({access_token => 'bad'}),
		'token verification failed',
		'unverifiable token is rejected'
	);
	$invalid_mock = undef;

	my $narrow_mock = mock 'ProductOpener::Keycloak' =>
		(override => [verify_access_token => sub {return {scope => 'other:scope'};},],);
	is(
		ProductOpener::Keycloak::_validate_admin_token({access_token => 'narrow'}),
		'token is missing scopes: products:read',
		'token without the read scope is rejected'
	);
	$narrow_mock = undef;

	my $ok_mock = mock 'ProductOpener::Keycloak' =>
		(override => [verify_access_token => sub {return {scope => 'products:read products:write'};},],);
	is(ProductOpener::Keycloak::_validate_admin_token({access_token => 'good'}),
		undef, 'token with the read scope is accepted');
	$ok_mock = undef;
};

done_testing();
