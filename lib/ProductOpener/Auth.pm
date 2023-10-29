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

ProductOpener::API - implementation of READ and WRITE APIs

=head1 DESCRIPTION

This module contains functions that are common to multiple types of API requests.

Specialized functions to process each type of API request is in separate modules like:

APIProductRead.pm : product READ
APIProductWrite.pm : product WRITE

=cut

package ProductOpener::Auth;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&access_to_protected_resource
		&callback
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;

use OIDC::Lite;
use OIDC::Lite::Client::WebServer;

use CGI qw(header);
use Apache2::RequestIO();
use Apache2::RequestRec();
use JSON::PP;
use Data::DeepAccess qw(deep_get);
use Storable qw(dclone);
use Encode;

my $client = OIDC::Lite::Client::WebServer->new(
	id => $oidc_options{client_id},
	secret => $oidc_options{client_secret},
	authorize_uri => $oidc_options{authorize_uri},
	access_token_uri => $oidc_options{access_token_uri},
);

# redirect user to authorize page.
sub start_authorize ($request_ref) {
	my $redirect_url = $client->uri_to_redirect(
		redirect_uri => format_subdomain('world') . '/cgi/oidc-callback.pl',
		scope => q{profile},
		state => $request_ref->{query_string},
	);

	redirect_to_url($request_ref, 302, $redirect_url);
	return;
}

# this method corresponds to the url 'http://yourapp/callback'
sub callback ($request_ref) {
	my $code = single_param("code");

	my $access_token = $client->get_access_token(
		code => $code,
		redirect_uri => format_subdomain('world') . '/cgi/oidc-callback.pl',
	) or die $client->errstr;

	$log->info("got access token", {access_token => $access_token}) if $log->is_info();
return:
}

sub refresh_access_token ($request_ref) {
	my $refresh_token = $request_ref->{refresh_token};
	my $access_token = $client->refresh_access_token(refresh_token => $refresh_token,)
		or die $client->errstr;

	$log->info("refreshed access token", {access_token => $access_token}) if $log->is_info();
	return;
}

sub access_to_protected_resource ($request_ref) {
	my $access_token = $request_ref->{"access_token"};
	my $expires_at = $request_ref->{"expires_at"};
	my $refresh_token = $request_ref->{"refresh_token"};

	unless ($access_token) {
		start_authorize($request_ref);
		return;
	}

	if ($expires_at < time()) {
		refresh_access_token($request_ref);
		return;
	}

	$log->info("request is ok", $request_ref) if $log->is_info();

	return;
}

1;
