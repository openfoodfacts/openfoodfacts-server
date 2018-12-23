# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

package ProductOpener::Ingredients;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&get_login_request
					&accept_login_request
					&reject_login_request

					&get_consent_request
					&accept_consent_request
					&reject_consent_request
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use experimental 'smartmatch';

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::URL qw/:all/;

use LWP::UserAgent;
use Encode;
use Clone qw(clone);
use JSON::PP;
use Log::Any qw($log);

sub _get($$) {
	my $flow = shift;
	my $challenge = shift;

	my $url = "$hydra_url/oauth2/auth/requests/$flow/$challenge";

	my $ua = LWP::UserAgent->new();

	my $request = HTTP::Request->new(GET => $url);

	my $response = $ua->request($request);

	if ($response->is_success and (not ($response->status < 200 and $response->status > 302))) {
		$log->info("GET request to ORY Hydra was successful") if $log->is_info();

		my $json_response = $response->decoded_content;
		return decode_json($json_response);
	}
	else {
		$log->warn("GET request to ORY Hydra not successful", { code => $response->code, response => $response->message }) if $log->is_warn();
		return;
	}
}

sub _put($$$$) {
	my $flow = shift;
	my $action = shift;
	my $challenge = shift;
	my $body = shift;

	my $url = "$hydra_url/oauth2/auth/requests/$flow/$challenge/$action";
	my $json = encode_json($body);

	my $ua = LWP::UserAgent->new();

	my $request = HTTP::Request->new(PUT => $url);
	$request->header('Content-Type' => 'application/json');
	$request->content($json);

	my $response = $ua->request($request);

	if ($response->is_success and (not ($response->status < 200 and $response->status > 302))) {
		$log->info("PUT request to ORY Hydra was successful") if $log->is_info();

		my $json_response = $response->decoded_content;
		return decode_json($json_response);
	}
	else {
		$log->warn("PUT request to ORY Hydra not successful", { code => $response->code, response => $response->message }) if $log->is_warn();
		return;
	}
}

sub get_login_request($) {
	my $challenge = shift;
	return _get('login', $challenge);
}

sub accept_login_request($$) {
	my $challenge = shift;
	my $body = shift;
	return _put('login', 'accept', $challenge, $body);
}

sub reject_login_request($$) {
	my $challenge = shift;
	my $body = shift;
	return _put('login', 'reject', $challenge, $body);
}

sub get_consent_request($) {
	my $challenge = shift;
	return _get('consent', $challenge);
}

sub accept_consent_request($$) {
	my $challenge = shift;
	my $body = shift;
	return _put('consent', 'accept', $challenge, $body);
}

sub reject_consent_request($$) {
	my $challenge = shift;
	my $body = shift;
	return _put('consent', 'reject', $challenge, $body);
}

1;
