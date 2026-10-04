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
		&is_post_request
		&is_cross_site_request
		&require_same_origin_post
	);    #the functions which are called outside this file
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Apache2::RequestIO();
use Apache2::RequestRec();
use Encode;
use CGI qw(:cgi :cgi-lib :form escapeHTML charset cookie url_param);
use Data::DeepAccess qw(deep_get);
use LWP::UserAgent;

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

=item * if the request has an C<Origin> header, its host (e.g. C<world.openfoodfacts.org>) is equal to the host the request was sent to (the C<Host> header, including the port if any).

Browsers always send the C<Origin> header for POST requests, and they always send
the C<Host> header of the site they are posting to, so requests coming from another
origin are rejected.

The host of the request is used instead of C<$request_ref->{formatted_subdomain}>
because that value can be different from the host the request was sent to: it is
computed from the configuration and it can be overridden by C<cc> and C<lc>
request parameters. The scheme is not compared, as it can be terminated by a
reverse proxy before the request reaches us.

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

	# Keep the host:port of the Origin header, e.g. world.openfoodfacts.org
	my ($origin_host) = ($origin =~ m{^(?:[^:/?#]+:)?//([^/?#]+)});
	my $r = Apache2::RequestUtil->request();
	my $host = $r->hostname();

	if ((not defined $origin_host) or (not defined $host) or ($host eq '')) {
		$log->warn("require_same_origin_post: could not get the Origin ($origin) or Host ($host) header");
		return !!0;
	}

	return !!($origin_host eq $host);
}

1;
