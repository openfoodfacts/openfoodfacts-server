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

=head1 NAME

matomo_to_scan_logs.pl - Converts Matomo API exports to NGINX style logs

=head1 DESCRIPTION

Matomo has an API to export individual visits with a list of the actions/events.

e.g. https://analytics.openfoodfacts.org/?module=API&method=Live.getLastVisitsDetails&idSite=2&period=month&date=2022-12-01&format=JSON&token_auth=[token]

This script filters scan events to convert them to NGINX style logs
that can be used as input to scanbot.pl

Usage:

./matomo_to_scan_logs.pl [list of JSON files]

Sample format:

[
    {
        idSite: "2",
        idVisit: "...",
        visitIp: "[ip]",
        visitorId: "...",
        fingerprint: "...",
        actionDetails: [
            {
                type: "event",
                url: "https://org.openfoodfacts.scanner",
                pageIdAction: "3223185",
                idpageview: "WpZhmY",
                serverTimePretty: "31 déc. 2022 23:52:42",
                pageId: "38550883",
                eventCategory: "scanning",
                eventAction: "scanAction",
                pageviewPosition: "5",
                timestamp: 1672530762,
                icon: "plugins/Morpheus/images/event.png",
                iconSVG: "plugins/Morpheus/images/event.svg",
                title: "Evènement",
                subtitle: "Catégorie: "scanning', Action: "scanAction"",
                eventName: "scanAction",
                eventValue: 3270160743223
            },

Target format:

[ip] "GET /api/v?/product/[code]"

=cut

use ProductOpener::PerlStandards;

use JSON "decode_json";

my $json = JSON->new->allow_nonref->canonical;

foreach my $filename (@ARGV) {
	print STDERR "Processing $filename\n";

	if (open(my $file, "<:encoding(UTF-8)", $filename)) {

		local $/;    #Enable 'slurp' mode
		my $json_ref = $json->decode(<$file>);

		foreach my $visit_ref (@$json_ref) {
			foreach my $action_ref (@{$visit_ref->{actionDetails}}) {
				if (    (defined $action_ref->{eventAction})
					and (($action_ref->{eventAction} eq "scanAction") or ($action_ref->{eventAction} eq "Scanned")))
				{
					print $visit_ref->{visitIp} . ' GET /api/v?/product/' . $action_ref->{eventValue} . "\n";
				}
			}
		}
	}
}

exit(0);

