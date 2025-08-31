#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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

This cgi script is called after successful sign-in happens on OIDC service (eg. keycloak)

It verifies authentication is ok, and redirects to a site url.

=cut

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Auth qw/signin_callback/;
use ProductOpener::Display qw/init_request display_error_and_exit/;
use ProductOpener::HTTP qw/redirect_to_url/;
use ProductOpener::Routing qw/analyze_request/;
use ProductOpener::URL qw/format_subdomain/;
use ProductOpener::Users qw/$User_id/;

use Log::Any qw($log);

$log->info('start') if $log->is_info();

my $request_ref = init_request();
analyze_request($request_ref);

my $return_url = signin_callback($request_ref);

unless (defined $User_id) {
	display_error_and_exit($request_ref, 'Unauthorized', 401);
}

unless (defined $return_url) {
	$return_url = format_subdomain('world');
}

redirect_to_url($request_ref, 302, $return_url);

1;
