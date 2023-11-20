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
		&password_signin
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
use OIDC::Lite::Model::IDToken;

use CGI qw/:cgi :form escapeHTML/;
use Apache2::RequestIO();
use Apache2::RequestRec();
use JSON::PP;
use Data::DeepAccess qw(deep_get);
use Storable qw(dclone);
use Encode;
use LWP::UserAgent;
use HTTP::Request;
use URI::Escape::XS qw/uri_escape/;

# Initialize some constants

my $cookie_name = 'oidc';
my $cookie_domain = '.' . $server_domain;    # e.g. fr.openfoodfacts.org sets the domain to .openfoodfacts.org
$cookie_domain =~ s/\.pro\./\./;    # e.g. .pro.openfoodfacts.org -> .openfoodfacts.org
if (defined $server_options{cookie_domain}) {
	$cookie_domain
		= '.' . $server_options{cookie_domain};    # e.g. fr.import.openfoodfacts.org sets domain to .openfoodfacts.org
}

my $callback_uri = format_subdomain('world') . '/cgi/oidc-callback.pl';

my $client = OIDC::Lite::Client::WebServer->new(
	id => $oidc_options{client_id},
	secret => $oidc_options{client_secret},
	authorize_uri => $oidc_options{authorize_uri},
	access_token_uri => $oidc_options{access_token_uri},
);

# redirect user to authorize page.
sub start_authorize ($request_ref) {
	my $nonce = generate_token(64);

	my $redirect_url = $client->uri_to_redirect(
		redirect_uri => $callback_uri,
		scope => q{profile},
		state => $nonce,
	);

	$request_ref->{cookie} = generate_signin_cookie($nonce, $request_ref->{query_string});
	redirect_to_url($request_ref, 302, $redirect_url);
	return;
}

# this method corresponds to the url 'http://yourapp/callback'
sub callback ($request_ref) {
	if (not(defined cookie($cookie_name))) {
		start_authorize($request_ref);
		return;
	}

	my $code = single_param('code');
	my $state = single_param('state');
	my $access_token = $client->get_access_token(
		code => $code,
		redirect_uri => $callback_uri,
	) or die $client->errstr;

	$log->info('got access token', {access_token => $access_token}) if $log->is_info();

	my %cookie_ref = cookie($cookie_name);
	my $nonce = $cookie_ref{'nonce'};
	if (not($state eq $nonce)) {
		$log->info('unexpected nonce', {nonce => $nonce, expected_nonce => $state}) if $log->is_info();
		display_error_and_exit('Invalid Nonce during OIDC login', 500);
	}

	my $user_id = get_user_id_using_token($access_token->access_token);
	unless (defined $user_id) {
		display_error_and_exit('Unknown user', 404);
	}

	# TODO: Store access_token, expires_at, refresh_token in session instead
	$log->debug('user_id found', {user_id => $user_id}) if $log->is_debug();
	param('user_id', $user_id);
	init_user($request_ref);

	return $cookie_ref{'return_url'};
}

sub password_signin ($username, $password) {
	unless ($username and $password) {
		return;
	}

	my $time = time();
	my $access_token = get_token_using_password_credentials($username, $password);
	unless ($access_token) {
		return;
	}

	my $user_id = get_user_id_using_token($access_token->{access_token});
	$log->debug('user_id found', {user_id => $user_id}) if $log->is_debug();
	return (
		$user_id,
		$access_token->{refresh_token},
		$time + $access_token->{refresh_expires_in},
		$access_token->{access_token},
		$time + $access_token->{expires_in}
	);
}

sub get_user_id_using_token ($access_token) {
	my $userinfo = get_userinfo($access_token);

	unless ($userinfo->{'email_verified'}) {
		$log->info('User email is not verified.', {email => $userinfo->{'email'}}) if $log->is_info();
		return;
	}

	my $verified_email = $userinfo->{'email'};
	$log->info('userinfo', {userinfo => $userinfo}) if $log->is_info();

	return try_retrieve_userid_from_mail($verified_email);
}

sub get_userinfo ($access_token) {
	my $userinfo_request = HTTP::Request->new(GET => $oidc_options{userinfo_endpoint});
	$userinfo_request->header(Authorization => 'Bearer ' . $access_token);
	my $userinfo_response = LWP::UserAgent->new->request($userinfo_request);
	unless ($userinfo_response->is_success) {
		display_error_and_exit(
			'Could not acquire user information: '
				. $userinfo_response->code . ' ('
				. $userinfo_response->content . ')',
			500
		);
	}

	return decode_json($userinfo_response->content);
}

sub refresh_access_token ($request_ref) {
	# TODO: Get access_token from session instead
	my $refresh_token = $request_ref->{refresh_token};
	my $access_token = $client->refresh_access_token(refresh_token => $refresh_token,)
		or die $client->errstr;

	$log->info('refreshed access token', {access_token => $access_token}) if $log->is_info();
	return;
}

sub access_to_protected_resource ($request_ref) {
	# TODO: Get access_token, expires_at, refresh_token from session instead
	my $access_token = $request_ref->{'access_token'};
	my $expires_at = $request_ref->{'expires_at'};
	my $refresh_token = $request_ref->{'refresh_token'};

	unless ($access_token) {
		start_authorize($request_ref);
		return;
	}

	if ($expires_at < time()) {
		refresh_access_token($request_ref);
		return;
	}

	$log->info('request is ok', $request_ref) if $log->is_info();

	return;
}

=head2 get_token_using_password_credentials($username, $password)

Gets a token for the user.

Method uses the Resource Owner Password Credentials Grant to
with the given credentials, and pre-configured Client ID,
and Client Secret.

=head3 Arguments

=head4 Name of the user $usersname

=head4 Password given at sign-in $password

=head3 Return values

Open ID Access token, or undefined if sign-in wasn't successful.

=cut

sub get_token_using_password_credentials ($username, $password) {
	my $token_request = HTTP::Request->new(POST => $oidc_options{access_token_uri});
	$token_request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$token_request->content('grant_type=password&client_id='
			. uri_escape($oidc_options{client_id})
			. '&client_secret='
			. uri_escape($oidc_options{client_secret})
			. '&username='
			. uri_escape($username)
			. '&password='
			. uri_escape($password));
	my $token_response = LWP::UserAgent->new->request($token_request);
	unless ($token_response->is_success) {
		$log->info('bad password - no token returned from IdP') if $log->is_info();
		return;
	}

	my $access_token = decode_json($token_response->content);
	$log->info('got access token', {access_token => $access_token}) if $log->is_info();
	return $access_token;
}

=head2 generate_signin_cookie($user_id, $user_session)

Generate a sign-in cookie.

The cookie is used to store information related to the current sign-in
for validation, and to redirect the user to the correct URL.

=head3 Arguments

=head4 Nonce $nonce

=head4 Return URL after sign-in $return_url

=head3 Return values

Sign-in cookie.

=cut

sub generate_signin_cookie ($nonce, $return_url) {
	my $signin_ref = {'nonce' => $nonce, 'return_url' => $return_url};

	my $cookie_ref = {
		'-name' => $cookie_name,
		'-value' => $signin_ref,
		'-path' => '/',
		'-domain' => $cookie_domain,
		'-samesite' => 'Lax',
	};

	return cookie(%$cookie_ref);
}

1;
