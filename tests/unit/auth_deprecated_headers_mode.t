use Modern::Perl '2017';
use utf8;

use Test2::V0;

use ProductOpener::Auth ();
use ProductOpener::Config qw/%oidc_options/;

subtest 'implementation level below 5 never emits headers' => sub {
	local $oidc_options{oidc_implementation_level} = 4;
	local $oidc_options{oidc_auth_legacy_headers_mode} = 'legacy';

	my ($emit, $reason, $mode) = ProductOpener::Auth::_should_emit_auth_deprecated_headers({endpoint => 'cgi/session.pl'});
	is($emit, 0, 'headers are not emitted');
	is($reason, 'implementation_level_below_5', 'suppression reason is explicit');
	is($mode, undef, 'mode is irrelevant before level 5');
};

subtest 'legacy mode keeps current behavior' => sub {
	local $oidc_options{oidc_implementation_level} = 5;
	local $oidc_options{oidc_auth_legacy_headers_mode} = 'legacy';

	my ($emit, $reason, $mode) = ProductOpener::Auth::_should_emit_auth_deprecated_headers({endpoint => 'cgi/session.pl'});
	is($emit, 1, 'headers are emitted');
	is($reason, 'legacy_allowed', 'legacy mode allows emission');
	is($mode, 'legacy', 'legacy mode is selected');
};

subtest 'off mode disables deprecated headers explicitly' => sub {
	local $oidc_options{oidc_implementation_level} = 5;
	local $oidc_options{oidc_auth_legacy_headers_mode} = 'off';

	my ($emit, $reason, $mode) = ProductOpener::Auth::_should_emit_auth_deprecated_headers({endpoint => 'cgi/session.pl'});
	is($emit, 0, 'headers are not emitted');
	is($reason, 'mode_off', 'off mode blocks emission');
	is($mode, 'off', 'off mode is selected');
};

subtest 'transitional mode allows listed endpoints' => sub {
	local $oidc_options{oidc_implementation_level} = 5;
	local $oidc_options{oidc_auth_legacy_headers_mode} = 'transitional';

	my ($emit, $reason, $mode)
		= ProductOpener::Auth::_should_emit_auth_deprecated_headers({endpoint => 'cgi/session.pl', api_version => 2});
	is($emit, 1, 'listed endpoint emits headers');
	is($reason, 'transitional_allowed', 'transitional allowlist permits emission');
	is($mode, 'transitional', 'transitional mode is selected');
};

subtest 'transitional mode blocks unknown endpoints' => sub {
	local $oidc_options{oidc_implementation_level} = 5;
	local $oidc_options{oidc_auth_legacy_headers_mode} = 'transitional';

	my ($emit, $reason, $mode)
		= ProductOpener::Auth::_should_emit_auth_deprecated_headers({endpoint => 'cgi/auth.pl', api_version => 2});
	is($emit, 0, 'unknown endpoint is blocked');
	is($reason, 'transitional_endpoint_blocked', 'endpoint policy blocks emission');
	is($mode, 'transitional', 'transitional mode is selected');
};

subtest 'transitional mode can block newer API versions' => sub {
	local $oidc_options{oidc_implementation_level} = 5;
	local $oidc_options{oidc_auth_legacy_headers_mode} = 'transitional';

	my ($emit, $reason, $mode)
		= ProductOpener::Auth::_should_emit_auth_deprecated_headers({endpoint => 'cgi/session.pl', api_version => 3});
	is($emit, 0, 'newer API version is blocked');
	is($reason, 'transitional_api_version_blocked', 'version policy blocks emission');
	is($mode, 'transitional', 'transitional mode is selected');
};

subtest 'unknown mode falls back to legacy behavior' => sub {
	local $oidc_options{oidc_implementation_level} = 5;
	local $oidc_options{oidc_auth_legacy_headers_mode} = 'surprise-value';

	my ($emit, $reason, $mode) = ProductOpener::Auth::_should_emit_auth_deprecated_headers({endpoint => 'cgi/session.pl'});
	is($emit, 1, 'fallback emits headers');
	is($reason, 'legacy_allowed', 'fallback uses legacy policy');
	is($mode, 'legacy', 'unknown mode normalizes to legacy');
};

done_testing();
