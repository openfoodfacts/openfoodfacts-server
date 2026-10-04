use Modern::Perl '2017';
use utf8;

use Test2::V0;

use ProductOpener::HTTP ();

our $host = 'world.openfoodfacts.org';

# get_http_request_header() reads the Apache request object:
# simulate the headers sent by the browser, and the Host of the request
my %headers_in = (Origin => undef, 'Sec-Fetch-Site' => undef);
{
	no strict 'refs';
	no warnings 'redefine', 'once';
	*ProductOpener::HTTP::get_http_request_header = sub {
		my ($header_name) = @_;
		return $headers_in{$header_name};
	};
	*Apache2::RequestUtil::request = sub {
		return Test2::Mock::Host->new();
	};
}

package Test2::Mock::Host;
sub new {return bless {}, shift}
sub unparsed_host {return $main::host}
sub hostname {return $main::host}

package main;

subtest 'is_post_request' => sub {
	ok(ProductOpener::HTTP::is_post_request({method => 'POST'}), 'POST is a POST request');

	foreach my $method (qw(GET PUT DELETE PATCH OPTIONS HEAD)) {
		ok(!ProductOpener::HTTP::is_post_request({method => $method}), "$method is not a POST request");
	}

	ok(!ProductOpener::HTTP::is_post_request({}), 'an unknown method is not a POST request');

	local $ENV{REQUEST_METHOD} = 'POST';
	ok(ProductOpener::HTTP::is_post_request({}), 'the method can be read from the environment');

	local $ENV{REQUEST_METHOD} = 'GET';
	ok(!ProductOpener::HTTP::is_post_request({}), 'GET from the environment is not a POST request');
};

subtest 'Sec-Fetch-Site is used to reject cross-site requests' => sub {
	$headers_in{'Sec-Fetch-Site'} = 'cross-site';
	ok(!ProductOpener::HTTP::require_same_origin_post({}), 'cross-site requests are rejected');

	$headers_in{'Sec-Fetch-Site'} = 'CROSS-SITE';
	ok(!ProductOpener::HTTP::require_same_origin_post({}), 'the header value is case insensitive');

	# rejected even if the Origin header matches
	$headers_in{'Origin'} = "https://$host";
	ok(!ProductOpener::HTTP::require_same_origin_post({}), 'cross-site is rejected even with a same origin');

	$headers_in{'Sec-Fetch-Site'} = 'same-origin';
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'same-origin requests are accepted');

	$headers_in{'Sec-Fetch-Site'} = 'same-site';
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'same-site requests are left to the Origin check');

	$headers_in{'Sec-Fetch-Site'} = 'none';
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'requests without a referrer are accepted');

	# non browser clients do not send the header
	$headers_in{'Sec-Fetch-Site'} = undef;
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'requests without the header are accepted');
};

subtest 'the Origin host must match the host of the request' => sub {
	$headers_in{'Origin'} = "https://$host";
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'the same host is accepted');

	# the scheme can be terminated by a reverse proxy before the request reaches us
	$headers_in{'Origin'} = "http://$host";
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'another scheme for the same host is accepted');

	# cc and lc request parameters change the formatted subdomain, but not the host
	$headers_in{'Origin'} = "https://fr.$host";
	ok(!ProductOpener::HTTP::require_same_origin_post({}), 'another host is rejected');

	$headers_in{'Origin'} = "https://www.example.org";
	ok(!ProductOpener::HTTP::require_same_origin_post({}), 'cross origin requests are rejected');

	$headers_in{'Origin'} = "https://$host.example.org";
	ok(!ProductOpener::HTTP::require_same_origin_post({}), 'a host starting with our host is rejected');

	$headers_in{'Origin'} = "https://$host/";
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'a trailing slash is ignored');

	# non browser clients do not send the header
	$headers_in{'Origin'} = undef;
	ok(ProductOpener::HTTP::require_same_origin_post({}), 'requests without an Origin header are accepted');
};

subtest 'the port must match' => sub {
	$headers_in{'Origin'} = "https://$host:8080";
	ok(!ProductOpener::HTTP::require_same_origin_post({}), 'another port is rejected');

	{
		local $host = "world.openfoodfacts.org:8080";
		ok(ProductOpener::HTTP::require_same_origin_post({}),
			'the same host and port is accepted when the request was sent to that port');
	}
};

done_testing();
