#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;

use URI::Escape::XS qw/uri_escape/;

my $request_ref = ProductOpener::Display::init_request();

unless ((defined $oidc_options{client_id}) and (defined $oidc_options{keycloak_reset_password_endpoint})) {
	display_error_and_exit('File not found.', 404);
}

my $redirect = $oidc_options{keycloak_reset_password_endpoint} . '?client_id=' . uri_escape($oidc_options{client_id});

redirect_to_url($request_ref, 302, $redirect);
