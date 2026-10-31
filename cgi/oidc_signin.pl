#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

=head1 DESCRIPTION

This cgi script initiates sign-in process with the OIDC service (eg. keycloak)

It redirects to the OIDC service, which will redirect back to oidc_signin_callback.pl

=cut

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Auth qw/access_to_protected_resource is_allowed_return_url/;
use ProductOpener::Display qw/display_too_many_requests_page_and_exit init_request/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Routing qw/analyze_request/;

use Log::Any qw($log);

$log->info('start') if $log->is_info();

my $request_ref = init_request();
analyze_request($request_ref);

# init_request() defers enforcement for routed requests: block here on the final bucket
if ($request_ref->{rate_limiter_blocking}) {
	display_too_many_requests_page_and_exit();
}

# A return url is redirected to after the sign in: only keep it if it is one of our own urls
$request_ref->{return_url} = single_param('return_url');
if (not is_allowed_return_url($request_ref->{return_url})) {
	delete $request_ref->{return_url};
}
access_to_protected_resource($request_ref);

1;
