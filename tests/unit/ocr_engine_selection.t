#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Images qw/select_ocr_engine/;
use ProductOpener::Routing ();
use ProductOpener::Config qw/%options/;

# select_ocr_engine(): server-side requests (flag = 0) honour the requested engine,
# requests from a CGI parameter (flag = 1) are ignored so the caller cannot choose
# who pays for the billed Google Cloud Vision call.

{
	local $ProductOpener::Config::tesseract_ocr_available = 1;
	local $ProductOpener::Config::google_cloud_vision_api_key = 'test-key';

	is(select_ocr_engine('tesseract', 0), 'tesseract', 'server: tesseract requested, both available');
	is(select_ocr_engine('google_cloud_vision', 0), 'google_cloud_vision', 'server: google requested, both available');
	is(select_ocr_engine(undef, 0), 'google_cloud_vision', 'server: undef defaults to google when key set');
	is(select_ocr_engine('bogus', 0), 'google_cloud_vision', 'server: unknown engine falls back to google');
}

{
	local $ProductOpener::Config::tesseract_ocr_available = 1;
	local $ProductOpener::Config::google_cloud_vision_api_key = undef;

	is(select_ocr_engine('tesseract', 0), 'tesseract', 'server: tesseract requested, only tesseract available');
	is(select_ocr_engine('google_cloud_vision', 0),
		'tesseract', 'server: google requested but no key falls back to tesseract');
	is(select_ocr_engine(undef, 0), 'tesseract', 'server: undef defaults to tesseract when no key');
}

{
	local $ProductOpener::Config::tesseract_ocr_available = 0;
	local $ProductOpener::Config::google_cloud_vision_api_key = 'test-key';

	is(select_ocr_engine('google_cloud_vision', 0),
		'google_cloud_vision', 'server: google requested, only google available');
	is(select_ocr_engine('tesseract', 0),
		'google_cloud_vision', 'server: tesseract requested but unavailable falls back to google');
}

{
	local $ProductOpener::Config::tesseract_ocr_available = 0;
	local $ProductOpener::Config::google_cloud_vision_api_key = undef;

	is(select_ocr_engine('tesseract', 0), undef, 'server: no engine available returns undef');
	is(select_ocr_engine('google_cloud_vision', 0), undef, 'server: no engine available returns undef');
	is(select_ocr_engine(undef, 0), undef, 'server: no engine available returns undef');
}

{
	local $ProductOpener::Config::tesseract_ocr_available = 1;
	local $ProductOpener::Config::google_cloud_vision_api_key = 'test-key';
	my $server_default = select_ocr_engine(undef, 0);

	is(select_ocr_engine('google_cloud_vision', 1),
		$server_default, 'from request: paid engine asked for is not honoured, server default used');
	is(select_ocr_engine('tesseract', 1),
		$server_default, 'from request: tesseract asked for is not honoured either, server default used');
	is(select_ocr_engine(undef, 1), $server_default, 'from request: undef falls back to server default');
	is(select_ocr_engine('bogus', 1), $server_default, 'from request: unknown engine falls back to server default');
}

{
	local $ProductOpener::Config::tesseract_ocr_available = 1;
	local $ProductOpener::Config::google_cloud_vision_api_key = undef;

	is(select_ocr_engine('google_cloud_vision', 1),
		'tesseract', 'from request: paid engine asked for falls back to tesseract when no key');
	is(select_ocr_engine('tesseract', 1), 'tesseract', 'from request: falls back to tesseract when no key');
}

# The ocr rate limiter bucket must resolve to $options{rate_limit_ocr},
# otherwise the CGI scripts count requests that are never blocked.

is($options{rate_limit_ocr}, 10, 'rate_limit_ocr is configured');

{
	my $mock_requests = 0;
	my $redis_mock = mock 'ProductOpener::Routing' => (
		override => [
			get_rate_limit_user_requests => sub {return $mock_requests;},
		]
	);

	my $request_ref = {rate_limiter_bucket => 'ocr',};
	ProductOpener::Routing::set_rate_limit_attributes($request_ref, '1.2.3.4');
	is($request_ref->{rate_limiter_limit}, 10, 'ocr bucket resolves to rate_limit_ocr');
	is($request_ref->{rate_limiter_blocking}, 0, 'ocr bucket below limit does not block');

	$mock_requests = 10;
	$request_ref = {rate_limiter_bucket => 'ocr',};
	ProductOpener::Routing::set_rate_limit_attributes($request_ref, '1.2.3.4');
	is($request_ref->{rate_limiter_limit}, 10, 'ocr bucket limit still 10 at the limit');
	is($request_ref->{rate_limiter_blocking}, 1, 'ocr bucket at limit blocks a non-whitelisted IP');

	$request_ref = {rate_limiter_bucket => 'ocr',};
	ProductOpener::Routing::set_rate_limit_attributes($request_ref, '163.5.3.4');
	is($request_ref->{rate_limiter_blocking}, 0, 'ocr bucket at limit does not block a whitelisted IP');

	$request_ref = {rate_limiter_bucket => undef,};
	ProductOpener::Routing::set_rate_limit_attributes($request_ref, '1.2.3.4');
	is($request_ref->{rate_limiter_blocking}, 0, 'undef bucket is not rate limited');
	is($request_ref->{rate_limiter_limit}, undef, 'undef bucket has no limit');
}

# The Cloud Vision timeout must be plumbed through Config so the env var takes effect.

ok(defined $ProductOpener::Config::google_cloud_vision_timeout, 'google_cloud_vision_timeout is exported via Config');

done_testing();
