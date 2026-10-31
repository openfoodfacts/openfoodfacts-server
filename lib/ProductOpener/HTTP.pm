# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::HTTP - utility functions around http (handling headers, cookies, redirect, etc.)

=head1 SYNOPSIS

C<ProductOpener::Web> consists of functions used only in OpenFoodFacts website for different tasks.

=head1 DESCRIPTION

The module implements http utilities to use in different part of the code.

FIXME: a lot of functions in Display.pm should be moved here.

=cut

package ProductOpener::HTTP;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_http_request_headers
		&set_http_response_header
		&write_http_response_headers
		&extension_and_query_parameters_to_redirect_url
		&redirect_to_url
		&single_param
		&request_param
		&get_http_request_header
		&create_user_agent
		&ip_is_not_public
		&resolve_host_addresses
		&url_is_fetchable
		&is_post_request
		&is_cross_site_request
		&require_same_origin_post
	);    #the functions which are called outside this file
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Apache2::RequestIO();
use Apache2::RequestRec();
use Apache2::RequestUtil();
use Encode;
use CGI qw(:cgi :cgi-lib :form escapeHTML charset cookie url_param);
use Data::DeepAccess qw(deep_get);
use LWP::UserAgent;
use Socket qw(AF_INET AF_INET6 SOCK_STREAM inet_ntop);
use URI;

use ProductOpener::Config qw/:all/;
use ProductOpener::RequestStats qw(:all);
use ProductOpener::Version qw/$version/;

=head2 set_http_response_header($request_ref, $header_name, $header_value)

This function sets a header in the response.

=head3 Parameters

=head4 $request_ref - Reference to the request object.

=head4 $header_name - Name of the header.

=head4 $header_value - Value of the header.

=cut

sub set_http_response_header($request_ref, $header_name, $header_value) {
	not defined $request_ref->{http_response_headers} and $request_ref->{http_response_headers} = {};
	$request_ref->{http_response_headers}{$header_name} = $header_value;
	return;
}

=head2 write_http_response_headers($request_ref)

This function writes the headers in the response.

=head3 Parameters

=head4 $request_ref - Reference to the request object.

=cut

sub write_http_response_headers($request_ref) {
	my $http_response_headers_ref = $request_ref->{http_response_headers};
	return unless $http_response_headers_ref;
	my $r = Apache2::RequestUtil->request();
	foreach my $header_name (sort keys %$http_response_headers_ref) {
		my $header_value = $http_response_headers_ref->{$header_name};
		$r->err_headers_out->set($header_name, $header_value);
	}
	return;
}

sub get_http_request_header($header_name) {
	my $r = Apache2::RequestUtil->request();
	# we need to check if the request object is defined and has headers
	# as this function may be called outside of mod_perl (e.g. in unit tests)
	if ((defined $r) and ($r->can('headers_in'))) {
		return ($r->headers_in->{$header_name});

	}
	$log->error("get_http_request_header: request object does not have headers_in method (not in mod_perl?)");
	return;
}

=head2 extension_and_query_parameters_to_redirect_url($request_ref)

This function returns the extension and query parameters that can be added to a redirect URL.
e.g. if the URL is /ingredients.json?filter=strawberry
we get a .json?filter=strawberry

=head3 Parameters

=head4 $request_ref - Reference to the request object.

=head3 Return value

A string with the extension and query parameters that can be added to a redirect URL.

=cut

sub extension_and_query_parameters_to_redirect_url($request_ref) {
	# Add the extension to the redirect URL
	my $add_to_url = '';

	if ($request_ref->{extension}) {
		$add_to_url .= '.' . $request_ref->{extension};
	}
	# Add the query parameters to the redirect URL
	if ($request_ref->{query_parameters}) {
		$add_to_url .= '?' . $request_ref->{query_parameters};
	}

	return $add_to_url;
}

=head2 redirect_to_url($request_ref, $status_code, $redirect_url)

This function instructs mod_perl to print redirect HTTP header (Location) and to terminate the request immediately.
The mod_perl process is not terminated and will continue to serve future requests.

=head3 Arguments

=head4 Request object $request_ref

The request object may contain a cookie.

=head4 Status code $status_code

e.g. 302 for a temporary redirect

=head4 Redirect url $redirect_url

=cut

sub redirect_to_url ($request_ref, $status_code, $redirect_url) {

	my $r = Apache2::RequestUtil->request();

	$r->headers_out->set(Location => $redirect_url);

	if (defined $request_ref->{cookie}) {
		# Note: mod_perl will not output the Set-Cookie header on a 302 response
		# unless it is set with err_headers_out instead of headers_out
		# https://perl.apache.org/docs/2.0/api/Apache2/RequestRec.html#C_err_headers_out_
		$r->err_headers_out->set("Set-Cookie" => $request_ref->{cookie});
	}

	$r->status($status_code);

	log_request_stats($request_ref->{stats});

	# note: under mod_perl, exit() will end the request without terminating the Apache mod_perl process
	exit();
}

=head2 single_param ($param_name)

CGI.pm param() function returns a list when called in a list context
(e.g. when param() is an argument of a function, or the value of a field in a hash).
This causes issues for function signatures that expect a scalar, and that may get passed an empty list
if the parameter is not set.

So instead of calling CGI.pm param() directly, we call single_param() to prefix it with scalar.

=head3 Arguments

=head4 CGI parameter name $param_name

=head3 Return value

A scalar value for the parameter, or undef if the parameter is not defined.

=cut

sub single_param ($param_name) {
	return scalar param($param_name);
}

=head2 request_param ($request_ref, $param_name)

Return a request parameter. The parameter can be passed in the query string,
as a POST multipart form data parameter, in a POST JSON body, or in cookies
for some parameters like product attribute parameters

=head3 Arguments

=head4 Parameter name $param_name

=head3 Return value

A scalar value for the parameter, or undef if the parameter is not defined.

Note that we really want to return undef, and not use an empty return statement,
as otherwise code like

	my $options_ref = {
		limit => request_param($request_ref, 'limit'),
		get_synonyms => request_param($request_ref, 'get_synonyms')
	};

will result in 'limit' being set to 'get_synonyms' value when the 'limit' parameter is not passed.

This goes against https://metacpan.org/pod/Perl::Critic::Policy::Subroutines::ProhibitExplicitReturnUndef
but we are not using return undef to indicate an error, but to indicate that the parameter is not defined.

=cut

sub request_param ($request_ref, $param_name) {
	my $cgi_param = scalar param($param_name);
	if (defined $cgi_param) {
		return decode utf8 => $cgi_param;
	}
	else {
		# For OPTIONS requests, CGI.pm param() does not parse the query string, so we need to get the parameter from the query string directly
		# e.g. for OPTIONS request for /cgi/search.pl?search_terms=carrots&action=process&json=1
		# we want to be able to get the json parameter to determine that it is an API request
		my $query_param = scalar url_param($param_name);
		if (defined $query_param) {
			return decode utf8 => $query_param;
		}
		else {
			my $body_json_param = deep_get($request_ref, "body_json", $param_name);
			if (defined $body_json_param) {
				return $body_json_param;
			}
			else {
				# For product attributes parameters, we allow cookies so that we do not have parameters
				# included in the URL and in logs
				# e.g. cookie("attribute_unwanted_ingredients_tags")
				my $cookie_param = cookie($param_name);
				return $cookie_param;    # returns undef if there's no cookie
			}
		}
	}
	# We should have returned before reaching this line
}

=head2 create_user_agent([$args])

Creates a standardized LWP::UserAgent

=head3 Parameters

=over 4

=item * C<[$args]> - (Optional) Optional constructor arguments for LWP::UserAgent->new()

=back

=head3 Behavior

Creates a standardized HTTP client with correct user agent.

=head3 Return value

A new LWP::UserAgent instance

=cut

sub create_user_agent {
	my (%cnf) = @_;

	my $ua;
	if (%cnf) {
		$ua = LWP::UserAgent->new(%cnf);
	}
	else {
		$ua = LWP::UserAgent->new();
	}

	$ua->agent("Mozilla/5.0 (compatible; Open Food Facts/$version; +https://world.$server_domain)");

	return $ua;
}

# Address ranges that are not globally routable: fetching an url that resolves to one of them lets
# a caller reach services that are only reachable from inside our network (databases, caches, the
# internal web servers, or the 169.254.169.254 metadata service of the cloud we run on).
# IPv4 prefixes: "this" network, RFC1918, carrier grade NAT, loopback, link-local (metadata
# service), IETF protocol assignments, the documentation and benchmarking ranges, 6to4 relay
# anycast, multicast and reserved space (which includes the broadcast address).

my @non_public_ipv4_prefixes = (
	["0.0.0.0", 8],
	["10.0.0.0", 8],
	["100.64.0.0", 10],
	["127.0.0.0", 8],
	["169.254.0.0", 16],
	["172.16.0.0", 12],
	["192.0.0.0", 24],
	["192.0.2.0", 24],
	["192.88.99.0", 24],
	["192.168.0.0", 16],
	["198.18.0.0", 15],
	["198.51.100.0", 24],
	["203.0.113.0", 24],
	["224.0.0.0", 4],
	["240.0.0.0", 4],
);

# IPv6 prefixes: unspecified, loopback, discard-only, documentation, unique local (RFC4193),
# link-local, site-local (deprecated) and multicast.

my @non_public_ipv6_prefixes = (
	["::", 128],
	["::1", 128],
	["100::", 64],
	["2001:db8::", 32],
	["fc00::", 7],
	["fe80::", 10],
	["fec0::", 10],
	["ff00::", 8],
);

=head2 ip_is_not_public($ip_address)

Returns 1 if an IPv4 or IPv6 address is not globally routable: loopback, private, carrier grade
NAT, link-local (including the 169.254.169.254 metadata service), unique local, site-local,
multicast, documentation, benchmarking or reserved space. IPv4-mapped and IPv4-compatible IPv6
addresses are classified on the IPv4 address they carry.

Returns 0 for a globally routable address, and 1 for a value that is not an address at all: an
address we cannot classify is not an address we want to fetch.

=head3 Arguments

=head4 $ip_address - string: an IPv4 or IPv6 address, in its usual textual form

=head3 Return value

1 if the address is not globally routable or cannot be parsed, 0 if it is

=cut

sub ip_is_not_public ($ip_address) {

	# An IPv6 address can carry a scope id (fe80::1%eth0): it is not part of the address itself,
	# and an address that needs one is a link-local address
	$ip_address =~ s/%.*$// if defined $ip_address;

	my $address_bytes = (defined $ip_address) ? Socket::inet_pton(AF_INET, $ip_address) : undef;

	if (defined $address_bytes) {
		foreach my $prefix (@non_public_ipv4_prefixes) {
			return 1 if ip_address_matches_prefix($address_bytes, AF_INET, $prefix->[0], $prefix->[1]);
		}
		return 0;
	}

	$address_bytes = (defined $ip_address) ? Socket::inet_pton(AF_INET6, $ip_address) : undef;

	if (defined $address_bytes) {
		# IPv4-mapped (::ffff:a.b.c.d) and IPv4-compatible (::a.b.c.d) addresses are classified
		# on the IPv4 address they carry, so that ::ffff:127.0.0.1 is not seen as public
		if (    (substr($address_bytes, 0, 10) eq ("\0" x 10))
			and ((substr($address_bytes, 10, 2) eq ("\xff\xff")) or (substr($address_bytes, 10, 2) eq ("\0\0"))))
		{
			return ip_is_not_public(join(".", unpack("C4", substr($address_bytes, 12, 4))));
		}

		foreach my $prefix (@non_public_ipv6_prefixes) {
			return 1 if ip_address_matches_prefix($address_bytes, AF_INET6, $prefix->[0], $prefix->[1]);
		}
		return 0;
	}

	# Not an address that we can classify
	return 1;
}

=head2 ip_address_matches_prefix($address_bytes, $family, $prefix, $prefix_length)

Returns 1 if the packed address ($address_bytes, in the given address family) starts with the
given prefix, or 0 if it does not. Not exported, only used by ip_is_not_public().

=cut

sub ip_address_matches_prefix ($address_bytes, $family, $prefix, $prefix_length) {

	my $prefix_bytes = Socket::inet_pton($family, $prefix);
	return 0 if not defined $prefix_bytes;

	my $full_bytes = int($prefix_length / 8);

	return 0 if substr($address_bytes, 0, $full_bytes) ne substr($prefix_bytes, 0, $full_bytes);

	my $remaining_bits = $prefix_length % 8;

	if ($remaining_bits) {
		my $mask = (0xFF << (8 - $remaining_bits)) & 0xFF;
		return 0
			if ((ord(substr($address_bytes, $full_bytes, 1)) & $mask)
			!= (ord(substr($prefix_bytes, $full_bytes, 1)) & $mask));
	}

	return 1;
}

=head2 resolve_host_addresses($host)

Returns an array ref with the addresses a host name resolves to, or an empty array ref if it does
not resolve. An address written literally in the url is returned as it is, without asking for a
DNS resolution.

=head3 Arguments

=head4 $host - string: a host name or an IP address

=head3 Return value

array ref with the IPv4 and IPv6 addresses the host resolves to (possibly empty)

=cut

sub resolve_host_addresses ($host) {

	return [] if (not defined $host) or ($host eq "");

	if (defined Socket::inet_pton(AF_INET, $host) or defined Socket::inet_pton(AF_INET6, $host)) {
		return [$host];
	}

	my ($error, @entries) = Socket::getaddrinfo($host, undef, {socktype => SOCK_STREAM});

	if ($error) {
		$log->debug("host does not resolve", {host => $host, error => $error}) if $log->is_debug();
		return [];
	}

	my @addresses = ();

	foreach my $entry (@entries) {
		# The address is unpacked from the sockaddr of the family we asked the resolver for
		my $numeric_address;

		if (defined $entry->{family}) {
			if ($entry->{family} == AF_INET) {
				(undef, $numeric_address) = Socket::unpack_sockaddr_in($entry->{addr});
				$numeric_address = Socket::inet_ntop(AF_INET, $numeric_address);
			}
			elsif ($entry->{family} == AF_INET6) {
				(undef, $numeric_address) = Socket::unpack_sockaddr_in6($entry->{addr});
				$numeric_address = Socket::inet_ntop(AF_INET6, $numeric_address);
			}
		}

		if ((defined $numeric_address) and (not grep {$_ eq $numeric_address} @addresses)) {
			push @addresses, $numeric_address;
		}
	}

	return \@addresses;
}

=head2 url_is_fetchable($url, $allowed_hosts_ref)

Returns 1 if an url can be fetched from the server: its scheme is http or https, it has a host,
and every address that host resolves to is globally routable. Otherwise returns 0.

The second argument defaults to the hosts that an operator listed in
$server_options{allowed_image_download_hosts}: those are fetched without resolving them, for an
operator who imports from a supplier serving images from a non globally routable address.

Note that the address is resolved again by the HTTP client: a host name whose DNS answer changes
between our check and the request can still be reached (DNS rebinding). Pinning the address would
mean connecting to it ourselves, which would break virtual hosting and the TLS certificate check.

=head3 Arguments

=head4 $url - string: the url that would be fetched

=head4 $allowed_hosts_ref - optional array ref: host names that are fetched without a check

=head3 Return value

1 if the url can be fetched, 0 otherwise

=cut

sub url_is_fetchable ($url, $allowed_hosts_ref = $server_options{allowed_image_download_hosts}) {

	my $uri = (defined $url) ? URI->new($url) : undef;

	if (   (not defined $uri)
		or (not defined $uri->scheme)
		or ($uri->scheme !~ /^https?$/i)
		or (not defined $uri->host)
		or ($uri->host eq ""))
	{
		$log->debug("url has no http(s) scheme or no host", {url => $url}) if $log->is_debug();
		return 0;
	}

	my $host = $uri->host;

	if (defined $allowed_hosts_ref) {
		foreach my $allowed_host (@{$allowed_hosts_ref}) {
			return 1 if lc($allowed_host) eq lc($host);
		}
	}

	my $addresses_ref = resolve_host_addresses($host);

	if (not scalar @{$addresses_ref}) {
		$log->warn("url host does not resolve", {url => $url, host => $host}) if $log->is_warn();
		return 0;
	}

	foreach my $ip_address (@{$addresses_ref}) {
		if (ip_is_not_public($ip_address)) {
			$log->warn(
				"url resolves to an address that is not globally routable",
				{url => $url, host => $host, ip_address => $ip_address}
			) if $log->is_warn();
			return 0;
		}
	}

	return 1;
}

=head2 is_post_request($request_ref)

Checks that the request method is C<POST>.

State changing endpoints should refuse other methods, so that a state change cannot
be triggered by a simple link or image tag: the session cookie is issued with
C<SameSite=Lax>, which means that browsers do send it for cross-site top-level GET
navigations.

=head3 Parameters

=head4 $request_ref - Reference to the request object.

The C<method> field is used, falling back on the C<REQUEST_METHOD> environment
variable.

=head3 Return value

Returns true (C<1>) if the request method is C<POST>, and false (C<0>) otherwise.

The function does not set any response status code: the caller is responsible for
rejecting the request, for example by returning a 405 Method Not Allowed status code.

=cut

sub is_post_request ($request_ref) {
	my $method = $request_ref->{method} // $ENV{REQUEST_METHOD} // '';
	return !!($method eq 'POST');
}

=head2 is_cross_site_request()

Returns true if the request was triggered by another site, based on the
C<Sec-Fetch-Site> header sent by browsers.

C<Sec-Fetch-Site> cannot be set by scripts, so a request coming from another site
can be identified without relying on C<Origin> or C<Referer> (which can be missing).

=head3 Return value

Returns true (C<1>) if C<Sec-Fetch-Site> is C<cross-site>, and false (C<0>)
otherwise: C<same-origin>, C<same-site> and C<none> requests are not cross site
requests, and non browser clients (curl, mobile apps, our integration tests) do not
send the header at all.

=cut

sub is_cross_site_request () {
	my $sec_fetch_site = get_http_request_header('Sec-Fetch-Site');
	return !!0 unless defined $sec_fetch_site;
	return !!(lc($sec_fetch_site) eq 'cross-site');
}

=head2 require_same_origin_post($request_ref)

Checks that a request can be attributed to our own origin, in order to protect
cookie authenticated endpoints against CSRF (cross site request forgery).

The request method is not checked here, see is_post_request().

The function returns true only if both of the following checks pass:

=over 4

=item * the request is not a cross site request (see is_cross_site_request()).

C<Sec-Fetch-Site> is set by browsers on all requests, and cannot be set by scripts:
C<same-origin> for requests coming from our own pages, C<cross-site> for requests
triggered by another site. Requests coming from another site are rejected, whatever
their C<Origin> header is. The other values are accepted: C<same-site> requests
(e.g. from another of our subdomains) are rejected by the C<Origin> check below, and
C<none> is sent for requests typed in the address bar.

=item * if the request has an C<Origin> header, its hostname and port match the request hostname and port.

Browsers always send the C<Origin> header for POST requests, and they always send
the C<Host> header of the site they are posting to, so requests coming from another
origin are rejected.

The host of the request is used instead of C<$request_ref->{formatted_subdomain}>
because that value can be different from the host the request was sent to: it is
computed from the configuration and it can be overridden by C<cc> and C<lc>
request parameters. The scheme is not compared, as it can be terminated by a
reverse proxy before the request reaches us. Default HTTP and HTTPS ports are
treated as equivalent for the same reason; non-default ports must match.

Non browser clients (curl, mobile apps) do not send the C<Origin> and C<Sec-Fetch-Site>
headers, so the checks are skipped if they are not present.

=back

Note: an anti-CSRF token is not verified here, as it is handled separately.

=head3 Parameters

=head4 $request_ref - Reference to the request object.

=head3 Return value

Returns true (C<1>) if the request can be attributed to our own origin, and false
(C<0>) otherwise.

The function does not set any response status code: the caller is responsible
for rejecting the request, for example by returning a 403 Forbidden status code.

=cut

sub require_same_origin_post ($request_ref) {

	return !!0 if (is_cross_site_request());

	my $origin = get_http_request_header('Origin');
	# Non browser clients do not send an Origin header
	return !!1 unless defined $origin;

	my $origin_uri = URI->new($origin);
	my $origin_host = $origin_uri->isa('URI::http') ? $origin_uri->host() : undef;
	my $r = Apache2::RequestUtil->request();
	my $host = $r->hostname();

	if ((not defined $origin_host) or (not defined $host) or ($host eq '')) {
		$log->warn("require_same_origin_post: could not get the Origin ($origin) or Host ($host) header");
		return !!0;
	}

	return !!0 if defined $origin_uri->userinfo();
	return !!0 if lc($origin_host) ne lc($host);

	# Apache exposes the port separately from hostname(). TLS may end at a proxy,
	# so compare default HTTP/HTTPS ports as equivalent, while keeping other ports.
	my $origin_port = $origin_uri->port();
	my $request_port = $r->get_server_port();
	$origin_port = 0 if $origin_port == $origin_uri->default_port();
	$request_port = 0 if ($request_port == 80) or ($request_port == 443);

	return !!($origin_port == $request_port);
}

1;
