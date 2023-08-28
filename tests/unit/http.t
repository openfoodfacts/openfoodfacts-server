#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';
use Test::MockModule;

use ProductOpener::HTTP qw/:all/;

# fake request
sub fake_request ($fake_arg) {
	my $r = {};
	bless $r, 'Apache2::RequestRec';
	return $r;
}

my $HEADERS_IN = {};

# a fake headers_in method for request
sub fake_headers_in ($fake_arg) {
	return $HEADERS_IN;
}

{

	my $apache_util_module = Test::MockModule->new('Apache2::RequestUtil');
	my $apache_rec_module = Test::MockModule->new('Apache2::RequestRec');

	# mock download image to fetch image in inputs_dir
	$apache_util_module->mock('request', \&fake_request);
	$apache_rec_module->mock('headers_in', \&fake_headers_in);

	my $expected_base_ref = {
		"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		"Access-Control-Allow-Headers" =>
			"DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,If-None-Match,Authorization",
		"Access-Control-Expose-Headers" => "Content-Length,Content-Range",
	};

	my $headers_ref = get_cors_headers();
	my $expected_ref = {%$expected_base_ref, ("Access-Control-Allow-Origin" => "*")};
	is_deeply($headers_ref, $expected_ref);

	# allow credentials from sub domains
	$HEADERS_IN = {"Origin" => "https://fr.openfoodfacts.localhost"};
	$headers_ref = get_cors_headers(1);
	$expected_ref = {
		%$expected_base_ref,
		(
			"Access-Control-Allow-Origin" => "https://fr.openfoodfacts.localhost",
			"Access-Control-Allow-Credentials" => "true",
			"Vary" => "Origin"
		)
	};
	is_deeply($headers_ref, $expected_ref);

	# but do not allow for alien domains, we do not block request, but do not allow credentials
	$HEADERS_IN = {"Origin" => "https://fr.example.com"};
	$headers_ref = get_cors_headers(1);
	$expected_ref = {%$expected_base_ref, ("Access-Control-Allow-Origin" => "*")};
	is_deeply($headers_ref, $expected_ref);

	# restrict to subdomain -> allow sub domain
	$HEADERS_IN = {"Origin" => "https://fr.openfoodfacts.localhost"};
	$headers_ref = get_cors_headers(0, 1);
	$expected_ref = {
		%$expected_base_ref, ("Access-Control-Allow-Origin" => "https://fr.openfoodfacts.localhost", "Vary" => "Origin")
	};
	is_deeply($headers_ref, $expected_ref);
	$headers_ref = get_cors_headers(1, 1);
	$expected_ref = {
		%$expected_base_ref,
		(
			"Access-Control-Allow-Origin" => "https://fr.openfoodfacts.localhost",
			"Access-Control-Allow-Credentials" => "true",
			"Vary" => "Origin"
		)
	};
	is_deeply($headers_ref, $expected_ref);

	# restrict to subdomain -> deny alien domain
	$HEADERS_IN = {"Origin" => "https://fr.example.com"};
	$headers_ref = get_cors_headers(0, 1);
	$expected_ref = {%$expected_base_ref,
		("Access-Control-Allow-Origin" => "https://openfoodfacts.localhost", "Vary" => "Origin")};
	is_deeply($headers_ref, $expected_ref);
	$headers_ref = get_cors_headers(1, 1);
	is_deeply($headers_ref, $expected_ref);

	done_testing();
}
