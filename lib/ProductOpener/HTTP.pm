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
	);    #the fucntions which are called outside this file
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Apache2::RequestIO();
use Apache2::RequestRec();

use ProductOpener::Config qw/:all/;

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
	while (my ($header_name, $header_value) = each %$headers_ref) {
		$r->err_headers_out->set($header_name, $header_value);
	}
	return;
}

1;
