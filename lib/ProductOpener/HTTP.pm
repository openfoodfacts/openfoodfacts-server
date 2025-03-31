# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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
		&get_cors_headers
		&write_cors_headers
		&get_http_request_headers
		&set_http_response_header
		&write_http_response_headers
		&redirect_to_url
		&single_param
		&request_param
		&get_http_request_header
	);    #the fucntions which are called outside this file
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Apache2::RequestIO();
use Apache2::RequestRec();
use Encode;
use CGI qw(:cgi :cgi-lib :form escapeHTML charset);
use Data::DeepAccess qw(deep_get);

use ProductOpener::Config qw/:all/;
use ProductOpener::RequestStats qw(:all);

=head1 FUNCTIONS

=head2 get_cors_headers($allow_credentials = 0, $sub_domain_only = 0)

We handle CORS headers from Perl code, NGINX should not interfere.
So this is the central place for it.

Some parts needs to be more strict than others (eg. auth).

=head3 Parameters

=head4 $allow_credentials - boolean

Whether we should add the Access-Control-Allow-Credential header, should be used with caution.
We will effectively put the headers only if subdomains matches.

We need to send the header Access-Control-Allow-Credentials=true so that websites
such has hunger.openfoodfacts.org that send a query to world.openfoodfacts.org/cgi/auth.pl
can read the resulting response.

=head4 $sub_domain_only - boolean

If true tells to restrict Access to main domain, that is domain.tld (eg. openfoodfacts.org)
It defaults to False,
but as a precaution, setting $allow_credentials to True turns it to True, if allow-credentials is given.


=head3 returns

Reference to a Hashmap with headers.

=cut

sub get_cors_headers ($allow_credentials = 0, $sub_domain_only = 0) {
	my $headers_ref = {};
	my $allow_origins = "*";
	$log->debug("get_cors_headers", {"allow_credentials" => $allow_credentials, "sub_domain_only" => $sub_domain_only})
		if $log->is_debug();
	if ($sub_domain_only || $allow_credentials) {
		# The Access-Control-Allow-Origin header must be set to the main domain of the Origin header
		my $input_request = Apache2::RequestUtil->request();
		my $origin = $input_request->headers_in->{Origin} || '';
		$log->debug("get_cors_headers sub domain test", {origin => $origin, "server_domain" => $server_domain})
			if $log->is_debug();
		# Only allow requests from one of our subdomains
		if ($origin =~ /^https?:\/\/([a-z0-9-.]+\.)*${server_domain}(:\d+)?$/) {
			$allow_origins = $origin;
		}
		else {
			# subdomains does not apply, we must not allow credentials
			$allow_credentials = 0;
			if ($sub_domain_only) {
				# we want to be sure it is not accessed
				# instead of putting the "null" value which is not well supported according to
				# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Origin
				# and to counter-act the potential addition of the header by an external source
				# we will put our server_domain
				$allow_origins = "https://$server_domain";
			}
		}
	}
	$headers_ref->{"Access-Control-Allow-Origin"} = $allow_origins;
	if ($allow_origins ne "*") {
		# see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Origin#cors_and_caching
		$headers_ref->{"Vary"} = "Origin";
	}
	if ($allow_credentials) {
		$headers_ref->{"Access-Control-Allow-Credentials"} = "true";
	}
	# be generous on methods and headers, it does not hurt
	$headers_ref->{"Access-Control-Allow-Methods"} = "HEAD, GET, PATCH, POST, PUT, OPTIONS";
	$headers_ref->{"Access-Control-Allow-Headers"}
		= "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,If-None-Match,Authorization";
	$headers_ref->{"Access-Control-Expose-Headers"} = "Content-Length,Content-Range";

	return $headers_ref;
}

=head2 write_cors_headers($allow_credentials = 0, $sub_domain_only = 0)

This function write cors_headers in response.

see get_cors_headers to see how they are computed and parameters

=cut

sub write_cors_headers ($allow_credentials = 0, $sub_domain_only = 0) {
	my $headers_ref = get_cors_headers($allow_credentials, $sub_domain_only);
	my $r = Apache2::RequestUtil->request();
	# write them
	foreach my $header_name (sort keys %$headers_ref) {
		my $header_value = $headers_ref->{$header_name};
		$r->err_headers_out->set($header_name, $header_value);
	}
	return;
}

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
as a POST multipart form data parameter, or in a POST JSON body

=head3 Arguments

=head4 Parameter name $param_name

=head3 Return value

A scalar value for the parameter, or undef if the parameter is not defined.

=cut

sub request_param ($request_ref, $param_name) {
	my $cgi_param = scalar param($param_name);
	if (defined $cgi_param) {
		return decode utf8 => $cgi_param;
	}
	else {
		return deep_get($request_ref, "body_json", $param_name);
	}
}

1;
