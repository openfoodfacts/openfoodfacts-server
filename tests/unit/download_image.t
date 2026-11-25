#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Mock::Quick qw/qobj qmeth/;
use Test2::V0;

use HTTP::Headers;
use HTTP::Response;

use ProductOpener::Config qw/:all/;
use ProductOpener::Import qw/download_image/;

# The image url of an import comes from an uploaded file, and it is fetched from inside our
# network: an url that does not resolve to a globally routable address must not be fetched, and
# neither must a redirect that points at one.
# 127.0.0.1 is not globally routable either, so we allowlist it here: these tests fake the HTTP
# layer, and what is tested is the check and the redirect loop, not the addresses themselves.

$server_options{allowed_image_download_hosts} = ["127.0.0.1"];

my @requested_urls;

sub redirect_to ($location) {
	return sub {
		my ($ua, $url) = @_;
		push @requested_urls, $url;
		if (@requested_urls > 6) {
			# Past the redirect limit of download_image()
			return HTTP::Response->new(200, "OK", HTTP::Headers->new(Content_Type => "image/png"), "image");
		}
		return HTTP::Response->new(302, "Found", HTTP::Headers->new(Location => $location), "");
	};
}

sub respond_with ($code) {
	return sub {
		my ($ua, $url) = @_;
		push @requested_urls, $url;
		return HTTP::Response->new($code, "Response", HTTP::Headers->new(Content_Type => "image/png"), "image");
	};
}

# An url that does not resolve to a globally routable address is not requested at all

my $ua_module = mock 'LWP::UserAgent' => (override => [get => respond_with(200)]);
@requested_urls = ();

my $response = download_image("http://169.254.169.254/latest/meta-data/");
is($response->code, 403, "the metadata service url is not fetched");
is(scalar @requested_urls, 0, "no request was made");

$response = download_image("http://10.0.0.1/image.png");
is($response->code, 403, "an address on a private network is not fetched");
is(scalar @requested_urls, 0, "no request was made");

# A redirect to an address that is not globally routable is not followed

$ua_module = mock 'LWP::UserAgent' => (override => [get => redirect_to("http://169.254.169.254/latest/")]);
@requested_urls = ();

$response = download_image("http://127.0.0.1/image.png");
is($response->code, 403, "a redirect to the metadata service is not followed");
is(scalar @requested_urls, 1, "only the first url was requested");
is($requested_urls[0], "http://127.0.0.1/image.png", "the first url is the one of the import file");

$ua_module = mock 'LWP::UserAgent' => (override => [get => redirect_to("http://[::1]:8881/image.png")]);
@requested_urls = ();

$response = download_image("http://127.0.0.1/image.png");
is($response->code, 403, "a redirect to an IPv6 loopback address is not followed");
is(scalar @requested_urls, 1, "only the first url was requested");

$ua_module = mock 'LWP::UserAgent' => (override => [get => redirect_to("file:///etc/passwd")]);
@requested_urls = ();

$response = download_image("http://127.0.0.1/image.png");
is($response->code, 403, "a redirect to another scheme is not followed");
is(scalar @requested_urls, 1, "only the first url was requested");

# A redirect to an allowlisted host is followed

my $redirects = 0;
$ua_module = mock 'LWP::UserAgent' => (
	override => [
		get => sub {
			my ($ua, $url) = @_;
			push @requested_urls, $url;
			if ($redirects++ == 0) {
				return HTTP::Response->new(302, "Found", HTTP::Headers->new(Location => "/second.png"), "");
			}
			return HTTP::Response->new(200, "OK", HTTP::Headers->new(Content_Type => "image/png"), "image");
		}
	]
);
@requested_urls = ();

$response = download_image("http://127.0.0.1/image.png");
is($response->code, 200, "a redirect to an allowlisted host is followed");
is(scalar @requested_urls, 2, "the redirect was followed once");
is($requested_urls[1], "http://127.0.0.1/second.png", "the relative redirect was resolved");

# Redirects are bounded

$ua_module = mock 'LWP::UserAgent' => (override => [get => redirect_to("http://127.0.0.1/loop.png")]);
@requested_urls = ();

$response = download_image("http://127.0.0.1/image.png");
is($response->code, 302, "a redirect loop ends with the last redirect response");
is(scalar @requested_urls, 6, "the number of redirects is bounded");

# A 403 is retried with a different User-Agent, on the same url

$ua_module = mock 'LWP::UserAgent' => (override => [get => respond_with(403)]);
@requested_urls = ();

$response = download_image("http://127.0.0.1/image.png");
is($response->code, 403, "a 403 is still a 403");
is(scalar @requested_urls, 2, "a 403 is retried once on the same url");
is($requested_urls[0], $requested_urls[1], "the retry uses the same url");

done_testing();
