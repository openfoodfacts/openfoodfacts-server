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

ProductOpener::APIUserRead - implementation of READ API for accessing user data

=head1 DESCRIPTION

This module implements GET /api/v3/users/me

It returns the current user's information (including moderator/admin flags)
from the Open Food Facts server database.

Authentication is via a Keycloak Bearer token passed in the Authorization header.
The token is validated by process_auth_header() before this function is called,
which sets $request_ref->{oidc_user_id} to the authenticated user's ID.

=cut

package ProductOpener::APIUserRead;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&read_user_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Users qw/%User/;
use ProductOpener::API qw/add_error/;

=head2 read_user_api ( $request_ref )

Process API V3 GET /api/v3/users/me requests.

Returns the authenticated user's information including moderator and admin flags.
Requires a valid Keycloak Bearer token in the Authorization header.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object. Must have $request_ref->{oidc_user_id} set
by process_auth_header() prior to this call.

=head3 Response

On success:
  {
    "status": "success",
    "user": {
      "userid":    "swastik",
      "name":      "Swastik Panigrahi",
      "moderator": 0,
      "admin":     0
    }
  }

On error (not authenticated): HTTP 401 with error details

=cut

sub read_user_api ($request_ref) {

	$log->debug("read_user_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# By the time this handler runs, init_user() in Display.pm has already:
	# 1. Picked up oidc_user_id (set by process_auth_header() from the Bearer token)
	# 2. Called retrieve_user() to load the user from the .sto file
	# 3. Set $request_ref->{user_id}, $request_ref->{moderator}, $request_ref->{admin}
	#
	# So we use those fields directly, avoiding a redundant retrieve_user() call.

	my $user_id = $request_ref->{user_id};

	unless (defined $user_id) {
		$log->info("read_user_api - no authenticated user", {}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "authentication_required"},
				impact  => {id => "failure"},
			},
			401
		);
		return;
	}

	# Build the user info response using fields already set by init_user().
	$response_ref->{result} = {id => "user_found"};
	$response_ref->{user}   = {
		userid    => $user_id,
		name      => $User{name} // $user_id,
		moderator => ($request_ref->{moderator} ? 1 : 0),
		admin     => ($request_ref->{admin}     ? 1 : 0),
	};

	$log->debug("read_user_api - stop", {user_id => $user_id}) if $log->is_debug();

	return;
}

1;
