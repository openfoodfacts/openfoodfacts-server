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

ProductOpener::Brevo -add users' contact to the Brevo contact list.

=head1 DESCRIPTION

=cut

package ProductOpener::Brevo;
use ProductOpener::PerlStandards;
use ProductOpener::Config2;
use Exporter qw< import >;
use Log::Any qw($log);
use JSON;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&add_contact_to_list
		$list_id
		$brevo_api_key

	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::API qw/:all/;

use LWP::UserAgent;
use HTTP::Request::Common;

my $api_base_url = 'https://api.brevo.com/v3';
# Brevo API key
my $brevo_api_key = $ProductOpener::Config2::brevo_api_key;
my $list_id = $ProductOpener::Config2::list_id;

sub add_contact_to_list ($email, $username, $country, $language) {

	# We need a Brevo key to use this API, otherwise we silently fails
	if (!$brevo_api_key) {
		$log->debug("No Brevo key, no list subscription.") if $log->is_debug();
		return -1;
	}
	# Brevo API endpoint for adding a contact to a list
	my $api_endpoint = '/contacts';

	my $ua = LWP::UserAgent->new;

	# HTTP request headers
	my %headers = (
		'Accept' => 'application/json',
		'Content-Type' => 'application/json',
		'api-key' => $brevo_api_key,
	);

	my $contact_data = {

		email => $email,
		attributes => {
			USERNAME => $username,
			COUNTRY => $country,
			LANGUAGE => $language,
		},
		listIds => [$list_id],

	};

	my $json_data = encode_json($contact_data);

	my $request = POST("$api_base_url$api_endpoint", %headers, Content => $json_data);

	my $response = $ua->request($request);

	if ($response && $response->is_success) {
		$log->debug("Contact added successfully! Response: " . $response->content) if $log->is_debug();
		return 1;    # Contact added successfully
	}
	else {
		$log->error("Failed to add contact. Status: " . $response->status_line . ", Response: " . $response->content)
			if $log->is_error();
		return 0;    # Failed to add contact
	}

}

1;

