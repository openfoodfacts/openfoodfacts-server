use ProductOpener::PerlStandards;

use Test2::V0;
use Test2::Tools::Mock qw/mock/;

use ProductOpener::URL qw/is_https_request should_use_secure_cookies/;
use ProductOpener::Config qw/%server_options/;
use Apache2::RequestUtil ();

my $forwarded_proto;
my $request_util_mock = mock 'Apache2::RequestUtil' => (add => [request => sub {return bless {}, 'URLTestRequest'}]);
my $request_mock
	= mock 'URLTestRequest' => (add => [headers_in => sub {return {'X-Forwarded-Proto' => $forwarded_proto}}]);

local $server_options{secure_cookies} = 0;
local $ENV{HTTPS};
local $ENV{REDIRECT_HTTPS};

for my $variable ('HTTPS', 'REDIRECT_HTTPS') {
	for my $value ('off', 'OFF', 'false', 'no', '0', '', 'unknown', 'only') {
		local $ENV{$variable} = $value;
		ok(!is_https_request(), "$variable=$value does not indicate HTTPS");
		ok(!should_use_secure_cookies(), "$variable=$value keeps plain HTTP cookies usable");
	}
	for my $value ('on', 'ON', '1', 'true', 'TRUE', 'yes', 'YES') {
		local $ENV{$variable} = $value;
		ok(is_https_request(), "$variable=$value indicates HTTPS");
		ok(should_use_secure_cookies(), "$variable=$value enables Secure cookies");
	}
}

$ENV{HTTPS} = 'off';
$ENV{REDIRECT_HTTPS} = 'off';
$forwarded_proto = 'https';
ok(is_https_request(), 'HTTPS terminated at the proxy is still recognized');
$forwarded_proto = 'http';
ok(!is_https_request(), 'plain HTTP from the proxy is not HTTPS');

local $server_options{secure_cookies} = 1;
ok(should_use_secure_cookies(), 'deployment configuration still requires Secure cookies');

done_testing();
