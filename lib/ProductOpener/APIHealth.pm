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

ProductOpener::Health - API for executing health checks

=head1 DESCRIPTION

This module implements GET /api/v3/health

It executes a series of health checks to verify that the server is functioning correctly.

Authentication is via an optional fixed API key passed the X-API-Key header. If the key is valid, the response includes additional details about the health checks.

=cut

package ProductOpener::Health;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&read_health_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::API qw/add_error/;

use HealthCheck;

my $checker = HealthCheck->new();
$checker->register(ProductOpener::Minion::get_health_check());

=head2 read_health_api ( $request_ref )

Process API V3 GET /api/v3/health requests.

Executes a series of health checks to verify that the server is functioning correctly.
Authentication is via an optional fixed API key passed the X-API-Key header. If the key is valid, the response includes additional details about the health checks.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object. Must have $request_ref->{oidc_user_id} set
by process_auth_header() prior to this call.

=head3 Response

On success: HTTP 200 with an object matching GSG Health Check Standard.
On error (bad health): HTTP 503 with an object matching GSG Health Check Standard.
On error (not authenticated): HTTP 401 with error details

=cut

sub read_health_api ($request_ref) {

	$log->debug("read_health_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	unless (defined $user_id) {
		$log->info("read_health_api - no authenticated user", {}) if $log->is_info();
		add_error(
			$response_ref,
			{
				message => {id => "authentication_required"},
				impact => {id => "failure"},
			},
			401
		);
		return;
	}

	$response_ref->{result} = {id => "user_found"};
	$response_ref->{user} = {
		userid => $user_id,
		name => $User{name} // $user_id,
		moderator => ($request_ref->{moderator} ? 1 : 0),
		admin => ($request_ref->{admin} ? 1 : 0),
	};

	$log->debug("read_health_api - stop", {user_id => $user_id}) if $log->is_debug();

	return;
}

1;
