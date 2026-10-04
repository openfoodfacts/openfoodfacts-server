use Modern::Perl '2017';
use utf8;

use Test2::V0;

use ProductOpener::HTTP ();

my $formatted_subdomain = 'https://world.openfoodfacts.org';

# get_http_request_header() reads the Apache request object: simulate the Origin header
my $origin;
{
	no strict 'refs';
	no warnings 'redefine';
	*ProductOpener::HTTP::get_http_request_header = sub {
		my ($header_name) = @_;
		return $origin if ($header_name eq 'Origin');
		return undef;
	};
}

subtest 'GET requests are rejected' => sub {
	$origin = $formatted_subdomain;
	my $request_ref = {method => 'GET', formatted_subdomain => $formatted_subdomain};
	ok(!ProductOpener::HTTP::require_same_origin_post($request_ref), 'GET is rejected even for our own origin');
};

subtest 'POST requests from our own origin are accepted' => sub {
	$origin = $formatted_subdomain;
	my $request_ref = {method => 'POST', formatted_subdomain => $formatted_subdomain};
	ok(ProductOpener::HTTP::require_same_origin_post($request_ref), 'same origin POST is accepted');
};

subtest 'POST requests from another origin are rejected' => sub {
	$origin = 'https://www.example.org';
	my $request_ref = {method => 'POST', formatted_subdomain => $formatted_subdomain};
	ok(!ProductOpener::HTTP::require_same_origin_post($request_ref), 'cross origin POST is rejected');

	$origin = $formatted_subdomain . '/';
	ok(!ProductOpener::HTTP::require_same_origin_post($request_ref), 'origin with a trailing slash is rejected');

	$origin = 'http://world.openfoodfacts.org';
	ok(!ProductOpener::HTTP::require_same_origin_post($request_ref), 'origin with another scheme is rejected');
};

subtest 'POST requests without an Origin header are accepted' => sub {
	# non browser clients (curl, mobile apps) and our integration tests do not send Origin
	$origin = undef;
	my $request_ref = {method => 'POST', formatted_subdomain => $formatted_subdomain};
	ok(ProductOpener::HTTP::require_same_origin_post($request_ref), 'POST without Origin header is accepted');
};

subtest 'other request methods are rejected' => sub {
	$origin = $formatted_subdomain;
	foreach my $method (qw(PUT DELETE PATCH OPTIONS HEAD)) {
		my $request_ref = {method => $method, formatted_subdomain => $formatted_subdomain};
		ok(!ProductOpener::HTTP::require_same_origin_post($request_ref), "$method is rejected");
	}
};

subtest 'the method can be read from the environment' => sub {
	local $ENV{REQUEST_METHOD} = 'POST';
	$origin = $formatted_subdomain;
	ok(
		ProductOpener::HTTP::require_same_origin_post({formatted_subdomain => $formatted_subdomain}),
		'POST from the environment is accepted'
	);

	local $ENV{REQUEST_METHOD} = 'GET';
	ok(
		!ProductOpener::HTTP::require_same_origin_post({formatted_subdomain => $formatted_subdomain}),
		'GET from the environment is rejected'
	);
};

done_testing();