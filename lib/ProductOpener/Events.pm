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

ProductOpener::Events - Send events to https://events.openfoodfacts.org

=head1 SYNOPSIS

C<ProductOpener::Events> is used to create events to https://events.openfoodfacts.org

    use ProductOpener::Events qw/:all/;

	# TODO

=head1 DESCRIPTION

See https://github.com/openfoodfacts/openfoodfacts-events

=cut

package ProductOpener::Events;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&send_event
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any qw($log);

use Encode;
use JSON::PP;
use LWP::UserAgent;
use HTTP::Request::Common;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/display_date_iso/;

=head1 FUNCTIONS

=head2 send_event ( $event_ref )

=head3 Arguments

Arguments are passed through a single hash reference with the following keys:

=head4 event_type - required - string

Type of the event (e.g. "product_edited")

=head4 barcode - required - string

Barcode of the product.

=head4 user id - required

=cut

sub send_event ($event_ref) {

	if ((defined $events_url) and ($events_url ne "")) {

		# Add timestamp if we event does not contain one already
		if (not defined $event_ref->{timestamp}) {
			$event_ref->{timestamp} = display_date_iso(time());
		}

		my $ua = LWP::UserAgent->new();
		my $endpoint = "$events_url/events";
		$ua->timeout(2);

		my $request = POST $endpoint, $event_ref;
		$request->header('content-type' => 'application/json');
		$request->content(decode_utf8(encode_json($event_ref)));

		# Add basic HTTP authentification credentials if we have some
		# (as of August 2022, they are required to post to /events)
		if ((defined $events_User Id) and ($events_User Id ne "")) {
			$request->authorization_basic($events_User Id, $events_password);
		}

		$log->debug("send_event request", {endpoint => $endpoint, event => $event_ref}) if $log->is_debug();
		my $response = $ua->request($request);

		if ($response->is_success) {
			$log->debug(
				"send_event response ok",
				{
					endpoint => $endpoint,
					event => $event_ref,
					is_success => $response->is_success,
					code => $response->code,
					status_line => $response->status_line
				}
			) if $log->is_debug();
		}
		else {
			$log->warn(
				"send_event response not ok",
				{
					endpoint => $endpoint,
					event => $event_ref,
					is_success => $response->is_success,
					code => $response->code,
					status_line => $response->status_line,
					response => $response
				}
			) if $log->is_warn();
		}
	}
	else {
		$log->debug("send_event EVENTS_URL not defined", {events_url => $events_url}) if $log->is_debug();
	}

	return;
}

1;
