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

ProductOpener::APIHealth - API for executing health checks

=head1 DESCRIPTION

This module implements GET /api/v3/health

It executes a series of health checks to verify that the server is functioning correctly.

Authentication is via an optional fixed API key passed the API-Key header. If the key is valid, the response includes additional details about the health checks.

=cut

package ProductOpener::APIHealth;

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
use ProductOpener::Config qw/$health_check_api_key/;
use ProductOpener::Health qw/:all/;
use ProductOpener::Data qw//;
use ProductOpener::Keycloak qw//;
use ProductOpener::Minion qw//;
use ProductOpener::Redis qw//;

my %checks = (
	'off_query:availability' => \&ProductOpener::Data::perform_health_check,
	'keycloak:availability' => \&ProductOpener::Keycloak::perform_health_check,
	'minion_database:responseTime' => \&ProductOpener::Minion::perform_health_check,
	'redis:responseTime' => \&ProductOpener::Redis::perform_health_check,
);

=head2 read_health_api ( $request_ref )

Process API V3 GET /api/v3/health requests.

Executes a series of health checks to verify that the server is functioning correctly.
Authentication is via an optional fixed API key passed the API-Key header. If the key is valid, the response includes additional details about the health checks.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object. Must have $request_ref->{oidc_user_id} set
by process_auth_header() prior to this call.

=head3 Response

On success: HTTP 200 with an object matching draft-inadarei-api-health-check-06
On error (bad health): HTTP 503 with an object matching draft-inadarei-api-health-check-06
On error (not authenticated): HTTP 401 with error details

=cut

sub read_health_api ($request_ref) {

	$log->debug("read_health_api - start", {request => $request_ref}) if $log->is_debug();

	my $r = Apache2::RequestUtil->request();
	if (not _request_has_valid_api_key($request_ref, $r)) {
		add_error(
			$request_ref->{api_response},
			{
				message => {id => "invalid_api_key"},
				impact => {id => "failure"},
			},
			401
		);
		return;
	}

	my $response_ref = $request_ref->{api_response};

	my %check_results;
	my $status = $status_pass;
	my $output = '';
	foreach my $check_name (keys %checks) {
		my $check = $checks{$check_name};
		my $result = eval {$check->()};
		if ($@) {
			$log->error('Health check failed with error', {check => $check_name}) if $log->is_error();
			$result = [
				{
					status => $status_fail,
					output => "Health check failed with error: $@",
				}
			];

			$check_results{$check_name} = $result;
			$status = $status_fail;
			next;
		}

		foreach my $check_entry (@$result) {
			if (ref($check_entry) eq 'HASH' and exists $check_entry->{status}) {
				if ($status eq $status_pass and $check_entry->{status} eq $status_warn) {
					$status = $status_warn;
				}
				elsif ($check_entry->{status} eq $status_fail) {
					$status = $status_fail;
				}

				my %check_entry_copy = %{$check_entry};

				my $full_name;
				if (exists $check_entry_copy{componentName}) {
					$full_name = $check_name . ':' . $check_entry_copy{componentName};
					delete $check_entry_copy{componentName};
				}
				else {
					$full_name = $check_name;
				}

				$check_results{$full_name} = [\%check_entry_copy];
			}
			else {
				$log->error('Health check returned invalid result entry', {check => $check_name, entry => $check_entry})
					if $log->is_error();
				$output .= "Health check returned invalid result entry: "
					. (ref($check_entry) ? ref($check_entry) : $check_entry) . "; ";
				$status = $status_warn if $status eq $status_pass;
			}
		}
	}

	$response_ref->{content_type} = 'application/health+json';
	$response_ref->{status_code} = ($status eq $status_fail ? 503 : 200);
	$response_ref->{body} = {
		status => $status,
		checks => \%check_results,
	};

	$log->debug("read_health_api - stop", {status => $status}) if $log->is_debug();

	return;
}

sub _request_has_valid_api_key($request_ref, $r) {
	if ((not(defined $health_check_api_key)) or ($health_check_api_key eq '')) {
		# If no API key is configured, allow all requests
		return 1;
	}

	my $api_key = $r->headers_in->{'API-Key'};
	if ((not(defined $api_key)) or (not($api_key eq $health_check_api_key))) {
		$log->debug("read_health_api - invalid API key provided", {}) if $log->is_debug();
		return 0;
	}
	else {
		$log->debug("read_health_api - valid API key provided", {}) if $log->is_debug();
		return 1;
	}
}

1;
