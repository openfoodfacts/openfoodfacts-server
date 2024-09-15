#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::HTTP qw/get_cors_headers/;

{

	# mock download image to fetch image in inputs_dir
	my $HEADERS_IN = {};
	my $apache_util_module = mock 'Apache2::RequestUtil' => (
		add => [
			request => sub {
				my $r = {};
				bless $r, 'Apache2::RequestRec';
				return $r;
			}
		]
	);
	my $apache_rec_module = mock 'Apache2::RequestRec' => (
		add => [
			headers_in => sub {
				return $HEADERS_IN;
			}
		]
	);

	my $expected_base_ref = {
		"Access-Control-Allow-Methods" => "HEAD, GET, PATCH, POST, PUT, OPTIONS",
		"Access-Control-Allow-Headers" =>
			"DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,If-None-Match,Authorization",
		"Access-Control-Expose-Headers" => "Content-Length,Content-Range",
	};

	my $headers_ref = get_cors_headers();
	my $expected_ref = {%$expected_base_ref, ("Access-Control-Allow-Origin" => "*")};
	is($headers_ref, $expected_ref);

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
	is($headers_ref, $expected_ref);

	# but do not allow for alien domains, we do not block request, but do not allow credentials
	$HEADERS_IN = {"Origin" => "https://fr.example.com"};
	$headers_ref = get_cors_headers(1);
	$expected_ref = {%$expected_base_ref, ("Access-Control-Allow-Origin" => "*")};
	is($headers_ref, $expected_ref);

	# restrict to subdomain -> allow sub domain
	$HEADERS_IN = {"Origin" => "https://fr.openfoodfacts.localhost"};
	$headers_ref = get_cors_headers(0, 1);
	$expected_ref = {
		%$expected_base_ref, ("Access-Control-Allow-Origin" => "https://fr.openfoodfacts.localhost", "Vary" => "Origin")
	};
	is($headers_ref, $expected_ref);
	$headers_ref = get_cors_headers(1, 1);
	$expected_ref = {
		%$expected_base_ref,
		(
			"Access-Control-Allow-Origin" => "https://fr.openfoodfacts.localhost",
			"Access-Control-Allow-Credentials" => "true",
			"Vary" => "Origin"
		)
	};
	is($headers_ref, $expected_ref);

	# restrict to subdomain -> deny alien domain
	$HEADERS_IN = {"Origin" => "https://fr.example.com"};
	$headers_ref = get_cors_headers(0, 1);
	$expected_ref = {%$expected_base_ref,
		("Access-Control-Allow-Origin" => "https://openfoodfacts.localhost", "Vary" => "Origin")};
	is($headers_ref, $expected_ref);
	$headers_ref = get_cors_headers(1, 1);
	is($headers_ref, $expected_ref);

	done_testing();
}
