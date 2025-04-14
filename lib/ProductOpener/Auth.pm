# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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

ProductOpener::Auth - Perl module for OpenID Connect (OIDC) and Keycloak authentication

=head1 DESCRIPTION

This Perl module provides functions for user authentication, token verification, and access to protected resources using OpenID Connect (OIDC) and Keycloak.

=cut

package ProductOpener::Auth;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&access_to_protected_resource
		&signin_callback
		&signout_callback
		&password_signin
		&verify_access_token
		&verify_id_token
		&get_user_id_using_token
		&get_token_using_client_credentials
		&get_token_using_password_credentials
		&get_azp
		&write_auth_deprecated_headers
		&start_signout
		&get_keycloak_level

		$oidc_discover_document
		$jwks
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/$subdomain $formatted_subdomain display_error_and_exit/;
use ProductOpener::HTTP qw/single_param redirect_to_url/;
use ProductOpener::URL qw/get_cookie_domain format_subdomain/;
use ProductOpener::Users qw/$User_id retrieve_user store_user_session generate_token init_user open_user_session/;
use ProductOpener::Lang qw/$lc/;

use OIDC::Lite;
use OIDC::Lite::Client::WebServer;
use OIDC::Lite::Model::IDToken;
use Crypt::JWT qw(decode_jwt);

use CGI qw/:cgi :form escapeHTML/;
use Apache2::RequestIO();
use Apache2::RequestRec();
use MIME::Base64 qw(decode_base64);
use JSON::PP;
use Data::DeepAccess qw(deep_get);
use Storable qw(dclone);
use Encode;
use LWP::UserAgent;
use LWP::UserAgent::Plugin 'Retry';
use HTTP::Request;
use URI::Escape::XS qw/uri_escape/;

# Initialize some constants

my $cookie_name = 'oidc';
my $cookie_domain = get_cookie_domain();

my $callback_uri = format_subdomain('world') . '/cgi/oidc_signin_callback.pl';
my $signout_callback_uri = format_subdomain('world') . '/cgi/oidc_signout_callback.pl';

my $client = undef;

=head2 start_authorize($request_ref)

Initiates the authorization process by redirecting the user to the authorization page.

=head3 Arguments

=head4 A reference to a hash containing request information. $request_ref

=head3 Return Values

None

=cut

sub start_authorize ($request_ref) {
	# random private token to identify the sign-in process
	my $nonce = generate_token(64);
	my $return_url = $request_ref->{return_url};
	if (   (not $return_url)
		or (not($return_url =~ /^https?:\/\/$subdomain\.$server_domain/)))
	{
		$return_url = $formatted_subdomain;
	}

	# get main OIDC client (keycloak)
	my $current_client = _get_client();
	my $redirect_url = $current_client->uri_to_redirect(
		redirect_uri => $callback_uri,
		scope => q{openid profile offline_access},
		state => $nonce,
		)
		. '&ui_locales='
		. uri_escape($lc) . '&lc='
		. uri_escape($lc) . '&cc='
		. uri_escape($request_ref->{cc});

	$request_ref->{cookie} = generate_oidc_cookie($nonce, $return_url);
	redirect_to_url($request_ref, 302, $redirect_url);
	return;
}

=head2 signin_callback($request_ref)

Handles the callback after successful authentication, verifies the ID token, and creates or retrieves the user's information.

=head3 Arguments

=head4 A reference to a hash containing request information. $request_ref

=head3 Return values

The return URL after successful authentication.

=cut

sub signin_callback ($request_ref) {
	if (not(defined cookie($cookie_name))) {
		display_error_and_exit(lang('oidc_signin_no_cookie'), 400);
		return;
	}

	my $code = single_param('code');
	if (not defined $code) {
		my $error = single_param('error');
		if ($error eq 'temporarily_unavailable') {
			# Start the login process again if we get a temporarily_unavailable error
			# This can happen when the user has validate their email on another tab
			start_authorize($request_ref);
		}
		else {
			display_error_and_exit($request_ref, $error, 500);
		}

		return;
	}
	my $state = single_param('state');
	my $time = time;
	my $current_client = _get_client();
	# access token shall have been set by OIDC service, get it
	my $access_token = $current_client->get_access_token(
		code => $code,
		redirect_uri => $callback_uri,
	) or display_error_and_exit($request_ref, $current_client->errstr, 500);
	$log->info('got access token during callback', {access_token => $access_token}) if $log->is_info();

	my %cookie_ref = cookie($cookie_name);
	# verify we are in the right sign-in process, thanks to the randomly generated token
	my $nonce = $cookie_ref{'nonce'};
	if (not($state eq $nonce)) {
		$log->info('unexpected nonce', {nonce => $nonce, expected_nonce => $state}) if $log->is_info();
		display_error_and_exit($request_ref, 'Invalid Nonce during OIDC login', 500);
	}

	# validation against JWKS
	my $id_token = verify_id_token($access_token->id_token);
	unless ($id_token) {
		$log->info('id token did not verify') if $log->is_info();
		display_error_and_exit($request_ref, 'Authentication error', 401);
	}

	my $user_id = get_user_id_using_token($id_token, $request_ref);
	unless (defined $user_id) {
		$log->info('User not found and not created') if $log->is_info();
		display_error_and_exit($request_ref, 'Internal error', 500);
	}

	my $user_ref = retrieve_user($user_id);
	unless ($user_ref) {
		$log->info('User not found', {user_id => $user_id}) if $log->is_info();
		display_error_and_exit($request_ref, 'Internal error', 500);
	}

	$log->debug('user found', {user_ref => $user_ref}) if $log->is_debug();
	my $user_session = open_user_session(
		$user_ref,
		$access_token->{refresh_token},
		$time + $access_token->{refresh_expires_in},
		$access_token->{access_token},
		$time + $access_token->{expires_in},
		$access_token->{id_token}, $request_ref
	);
	# add as apache parameter for now (should better be in request_ref)
	param('user_id', $user_id);
	param('user_session', $user_session);
	init_user($request_ref);

	return $cookie_ref{'return_url'};
}

=head2 password_signin($username, $password, $request_ref)

Signs in the user with a username and password, and returns the user's ID, refresh token, refresh token expiration time, access token, and access token expiration time.

We support this to enable passing user and password in the request json. This is a legacy way of doing.

=head3 Arguments

=head4 The username for password-based authentication. $username

=head4 The password for password-based authentication. $password

=head3 Return Values

A list containing the user's ID, refresh token, refresh token expiration time, access token, access token expiration time, and the ID token

=cut

sub password_signin ($username, $password, $request_ref) {
	unless ($username and $password) {
		return;
	}

	my $time = time;
	my $access_token = get_token_using_password_credentials($username, $password);
	unless ($access_token) {
		return;
	}

	my $id_token = verify_id_token($access_token->{id_token});
	unless ($id_token) {
		$log->info('id token did not verify') if $log->is_info();
		return;
	}

	my $user_id = get_user_id_using_token($id_token, $request_ref);
	$log->debug('user_id found', {user_id => $user_id}) if $log->is_debug();
	return (
		$user_id,
		$access_token->{refresh_token},
		# use absolute time instead of relative time
		$time + $access_token->{refresh_expires_in},
		$access_token->{access_token},
		# use absolute time instead of relative time
		$time + $access_token->{expires_in},
		$id_token
	);
}

=head2 get_user_id_using_token ($id_token, , $request_ref, $require_verified_email)

Extract the user id from the OIDC identification token (which contains an email).

It verifies that the email is a verified email before proceeding.

If the user properties file does not yet exists, it create it.

=head3 Arguments

=head4 hash ref $id_token

The OIDC identification token information

=head4 boolean $require_verified_email

If true, the email must be verified before proceeding.

=head3 Return Value

The userid as a string

=cut

sub get_user_id_using_token ($id_token, $request_ref, $require_verified_email = 0) {
	if ($require_verified_email and (not($id_token->{'email_verified'} eq $JSON::PP::true))) {
		$log->info('User email is not verified.', {email => $id_token->{'email'}}) if $log->is_info();
		return;
	}

	my $user_id = $id_token->{'preferred_username'};
	my $user_ref = retrieve_user($user_id);
	unless ($user_ref) {
		$log->info('User not found', {user_id => $user_id}) if $log->is_info();
		$user_ref = {userid => $user_id};
	}

	# Update duplicated information from Keycloak
	$user_ref->{name} = $id_token->{'name'} // $user_id;
	$user_ref->{email} = $id_token->{'email'};

	# Make sure initial information is set (user may have been created by Redis)
	defined $user_ref->{registered_t} or $user_ref->{registered_t} = time();
	defined $user_ref->{last_login_t} or $user_ref->{last_login_t} = time();
	defined $user_ref->{ip} or $user_ref->{ip} = remote_addr();
	defined $user_ref->{initial_lc} or $user_ref->{initial_lc} = $lc;
	defined $user_ref->{initial_cc} or $user_ref->{initial_cc} = $request_ref->{cc};
	defined $user_ref->{initial_user_agent} or $user_ref->{initial_user_agent} = user_agent();

	# Don't use store_user here as will sync the user back to keycloak
	store_user_session($user_ref);

	return $user_ref->{userid};
}

=head2 refresh_access_token ($id_token)

Refreshes the access token using the OIDC client.

Access token have a limited life span but can be refreshed

=head3 Arguments

=head4 hash ref $refresh_token

OIDC refresh token

=head3 Return Value

A list containing the user's ID, new refresh token, refresh token expiration time, new access token, and access token expiration time.

=cut

sub refresh_access_token ($refresh_token) {
	my $time = time;
	my $current_client = _get_client();
	my $access_token = $current_client->refresh_access_token(refresh_token => $refresh_token,)
		or die $current_client->errstr;

	$log->info('refreshed access token', {access_token => $access_token}) if $log->is_info();
	return (
		$access_token->{refresh_token}, $time + $access_token->{refresh_expires_in},
		$access_token->{access_token}, $time + $access_token->{expires_in}
	);
}

=head2 access_to_protected_resource ($request_ref)

This method insure a user is authenticated before proceeding to a specific page.

If user is not authenticated, or his access token can't be refreshed,
it will be redirected to signin process.

=head3 Arguments

=head4 A reference to a hash containing request information. $request_ref

=head3 Return Values

None

=cut

sub access_to_protected_resource ($request_ref) {
	unless ($User_id) {
		start_authorize($request_ref);
		return;
	}

	my $access_token = $request_ref->{access_token};
	my $refresh_expires_at = $request_ref->{refresh_expires_at};
	my $refresh_token = $request_ref->{refresh_token};
	my $access_expires_at = $request_ref->{access_expires_at};

	unless ($access_token) {
		start_authorize($request_ref);
		return;
	}

	# refresh access token if it has already expired
	if ((defined $access_expires_at) and ($access_expires_at < time)) {
		($refresh_token, $refresh_expires_at, $access_token, $access_expires_at) = refresh_access_token($refresh_token);
		unless ($access_token) {
			start_authorize($request_ref);
			return;
		}
	}

	# ID Token validation
	#my $id_token = OIDC::Lite::Model::IDToken->load($token->id_token);

	$log->info('request is ok', $request_ref) if $log->is_info();

	return;
}

=head2 start_signout($request_ref)

Initiates the sign-out process by redirecting the user to the authorization page.

=head3 Arguments

=head4 A reference to a hash containing request information. $request_ref

=head3 Return Values

None

=cut

sub start_signout ($request_ref) {
	# compute return_url, so that after sign out, user will be redirected to the home page
	my $return_url = single_param('return_url');
	die $return_url if defined $return_url;
	if (   (not $return_url)
		or (not($return_url =~ /^https?:\/\/$subdomain\.$server_domain/sxm)))
	{
		$return_url = $formatted_subdomain;
	}

	my $id_token = $request_ref->{id_token};
	unless ($User_id and $id_token) {
		# user is not authenticated, nothing to do; sign-out is already done, redirect to home page
		param('length', 'logout');
		init_user($request_ref);
		redirect_to_url($request_ref, 302, $return_url);
		return;
	}

	_ensure_oidc_is_discovered();

	# random private token to identify the sign-out process
	my $nonce = generate_token(64);
	my $end_session_endpoint = $oidc_discover_document->{end_session_endpoint};
	my $redirect_url
		= $end_session_endpoint
		. '?post_logout_redirect_uri='
		. uri_escape($signout_callback_uri)
		. '&id_token_hint='
		. uri_escape($id_token)
		. '&state='
		. uri_escape($nonce);

	# start OIDC signout process by storing nonce and return_url in a cookie
	$request_ref->{cookie} = generate_oidc_cookie($nonce, $return_url);
	# then, redirect to OIDC end_session_endpoint
	redirect_to_url($request_ref, 302, $redirect_url);
	return;
}

=head2 signout_callback($request_ref)

Handles the callback after successful sign-out, clears session cookie.

=head3 Arguments

=head4 A reference to a hash containing request information. $request_ref

=head3 Return values

The return URL after successful sign-out.

=cut

sub signout_callback ($request_ref) {
	# no cookie, nothing to do
	unless (defined cookie($cookie_name)) {
		return $formatted_subdomain;
	}

	# ensure we are in the right process thanks to private random token
	my $state = single_param('state');
	my %cookie_ref = cookie($cookie_name);
	my $nonce = $cookie_ref{'nonce'};
	if (not($state eq $nonce)) {
		$log->info('unexpected nonce', {nonce => $nonce, expected_nonce => $state}) if $log->is_info();
		display_error_and_exit($request_ref, 'Invalid Nonce during OIDC logout', 500);
	}

	param('length', 'logout');
	init_user($request_ref);

	return $cookie_ref{'return_url'};
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
	_ensure_oidc_is_discovered();

	# Build a request and emit it using our app specific key
	# to authenticate user
	my $token_request = HTTP::Request->new(POST => $oidc_discover_document->{token_endpoint});
	$token_request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$token_request->content('grant_type=password&client_id='
			. uri_escape($oidc_options{client_id})
			. '&client_secret='
			. uri_escape($oidc_options{client_secret})
			. '&username='
			. uri_escape($username)
			. '&password='
			. uri_escape($password)
			. "&scope=openid%20profile%20offline_access");

	my $token_response = LWP::UserAgent::Plugin->new->request($token_request);
	unless ($token_response->is_success) {
		$log->info('bad password - no token returned from IdP', {content => $token_response->content})
			if $log->is_info();
		return;
	}

	my $access_token = decode_json($token_response->content);
	$log->info('got access token from password credentials', {access_token => $access_token}) if $log->is_info();
	return $access_token;
}

=head2 get_token_using_client_credentials()

Gets a token for the user.

Method uses the Client Credentials Grant to
pre-configured Client ID, and Client Secret.

=head3 Arguments

None

=head3 Return values

Open ID Access token, or undefined if sign-in wasn't successful.

=cut

sub get_token_using_client_credentials () {
	_ensure_oidc_is_discovered();

	my $token_request = HTTP::Request->new(POST => $oidc_discover_document->{token_endpoint});
	$token_request->header('Content-Type' => 'application/x-www-form-urlencoded');
	$token_request->content('grant_type=client_credentials&client_id='
			. uri_escape($oidc_options{client_id})
			. '&client_secret='
			. uri_escape($oidc_options{client_secret}));
	my $token_response = LWP::UserAgent::Plugin->new->request($token_request);
	unless ($token_response->is_success) {
		$log->info('bad client credentials - no token returned from IdP', {content => $token_response->content})
			if $log->is_info();
		return;
	}

	my $access_token = decode_json($token_response->content);
	$log->info('got access token client credentials', {access_token => $access_token}) if $log->is_info();
	return $access_token;
}

=head2 generate_oidc_cookie($nonce, $user_session)

Generate a sign-in/sign-out cookie.

The cookie is used to store information related to the current sign-in/sign-out
for validation, and to redirect the user to the correct URL.

=head3 Arguments

=head4 Nonce $nonce

=head4 Return URL after sign-in/-out $return_url

=head3 Return values

Sign-in/sign-out cookie.

=cut

sub generate_oidc_cookie ($nonce, $return_url) {
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

=head2 verify_access_token($access_token_string)

Verifies the access token by decoding and validating it using the JSON Web Key Set (JWKS).
(see https://auth0.com/docs/secure/tokens/json-web-tokens/json-web-key-sets)

Parameters:
- $access_token_string: The access token to be verified.

Returns: The verified access token or undefined if verification fails.

=cut

sub verify_access_token ($access_token_string) {
	_ensure_oidc_is_discovered();

	my $access_token_verified = decode_jwt(token => $access_token_string, kid_keys => $jwks);
	$log->debug('access_token found', {access_token => $access_token_string, access_token => $access_token_verified})
		if $log->is_debug();
	unless ($access_token_verified) {
		return;
	}

	return $access_token_verified;
}

=head2 verify_id_token($id_token_string)

Verifies the ID token by decoding and validating it using the JWKS.

Parameters:
- $id_token_string: The ID token to be verified.

Returns: The verified ID token or undefined if verification fails.

=cut

sub verify_id_token ($id_token_string) {
	_ensure_oidc_is_discovered();

	my $id_token = OIDC::Lite::Model::IDToken->load($id_token_string);
	my $id_token_verified = decode_jwt(token => $id_token_string, kid_keys => $jwks);
	$log->debug('id_token found', {id_token => $id_token, id_token_verified => $id_token_verified}) if $log->is_debug();
	unless ($id_token_verified) {
		return;
	}

	return $id_token_verified;
}

=head2 get_azp($access_token)

Retrieves the authorized party (client ID) from the access token.

It is different for example between the website and the mobile app.

This is useful for example for products change log.

=head3 Arguments

=head4 The access token string. $access_token_string

=head3 Return values

The authorized party (client ID) or undefined if the token is not issued by the correct issuer.

=cut

sub get_azp ($access_token_string) {
	if (not(defined $access_token_string)) {
		return;
	}

	_ensure_oidc_is_discovered();

	my $access_token;
	# verify token using JWKS (see Auth.pm)
	eval {$access_token = verify_access_token($access_token_string);};
	my $error = $@;
	if ($error) {
		$log->info('Access token invalid', {token => $access_token_string}) if $log->is_info();
		return;
	}

	if (    (defined $oidc_discover_document->{issuer})
		and (not($oidc_discover_document->{issuer} eq $access_token->{iss})))
	{
		$log->warn(
			'Given token was not issued by the correct issuer',
			{
				actual_iss => $access_token->{iss},
				expected_iss => $oidc_discover_document->{issuer},
				azp => $access_token->{azp},
				sub => $access_token->{sub}
			}
		) if $log->is_warn();
		return;
	}

	return $access_token->{azp};
}

=head2 _get_client()

Get the OIDC client that is used to interact with the OIDC server.

This subroutine creates and returns an instance of the OIDC::Lite::Client::WebServer class, which represents the client profile for OpenID Connect (OIDC) authentication. The client profile is used to interact with the OIDC server for authentication and authorization purposes.

The client profile is created with the following parameters:
- id: The client ID provided by the OIDC server.
- secret: The client secret provided by the OIDC server.
- authorize_uri: The authorization endpoint URL provided by the OIDC server.
- access_token_uri: The token endpoint URL provided by the OIDC server.

If the client profile has already been created, it is returned directly without re-creating it.

See L<https://metacpan.org/pod/OIDC::Lite::Client::WebServer> for more information on the OIDC::Lite::Client::WebServer module.

=head3 Arguments

None.

=head3 Return values

A workable instance of OIDC::Lite::Client::WebServer.

=cut

sub _get_client () {
	if ($client) {
		return $client;
	}

	_ensure_oidc_is_discovered();
	$client = OIDC::Lite::Client::WebServer->new(
		id => $oidc_options{client_id},
		secret => $oidc_options{client_secret},
		authorize_uri => $oidc_discover_document->{authorization_endpoint},
		access_token_uri => $oidc_discover_document->{token_endpoint},
	);
	return $client;
}

=head2 _ensure_oidc_is_discovered( )

Ensures that OIDC (OpenID Connect) is discovered and configured.

If OIDC is already discovered, the function returns without doing anything.

Otherwise, it sends a discovery request to the OIDC endpoint and loads the discovery document.
If successful, it updates the OIDC options with the JWKS (JSON Web Key Set) configuration.

=head3 Arguments

None.

=head3 Return values

None.

=cut

sub _ensure_oidc_is_discovered () {
	if ($jwks) {
		return;
	}
	my $discovery_endpoint
		= $oidc_options{keycloak_backchannel_base_url}
		. "/realms/"
		. $oidc_options{keycloak_realm_name}
		. "/.well-known/openid-configuration";

	$log->info('Original OIDC configuration', {discovery_endpoint => $discovery_endpoint})
		if $log->is_info();

	my $discovery_request = HTTP::Request->new(GET => $discovery_endpoint);
	my $discovery_response = LWP::UserAgent::Plugin->new->request($discovery_request);
	unless ($discovery_response->is_success) {
		$log->info('Unable to load OIDC data from IdP', {response => $discovery_response->content}) if $log->is_info();
		return;
	}

	$oidc_discover_document = decode_json($discovery_response->content);
	$log->info('got discovery document', {discovery => $oidc_discover_document}) if $log->is_info();

	_load_jwks_configuration_to_oidc_options($oidc_discover_document->{jwks_uri});

	return;
}

=head2 _load_jwks_configuration_to_oidc_options( $jwks_uri )

Loads the JWKS from $jwks_uri, and stores it in the $jkw variable.

JWKS aka JSON Web Key Sets are essential to validate access tokens
https://auth0.com/docs/secure/tokens/json-web-tokens/json-web-key-sets

=head3 Arguments

=head4 URI to the JWKS. $jwks_uri

=head3 Return values

None.

=cut

sub _load_jwks_configuration_to_oidc_options ($jwks_uri) {
	my $jwks_request = HTTP::Request->new(GET => $jwks_uri);
	my $jwks_response = LWP::UserAgent::Plugin->new->request($jwks_request);
	unless ($jwks_response->is_success) {
		$log->info('Unable to load JWKS from IdP', {response => $jwks_response->content}) if $log->is_info();
		return;
	}

	$jwks = decode_json($jwks_response->content);
	$log->info('got JWKS', {jwks => $jwks}) if $log->is_info();
	return;
}

=head2 write_auth_deprecated_headers()

Writes the deprecation notice for old authentication sites as HTTP headers.

=head3 Arguments

None.

=head3 Return values

None.

=cut

sub write_auth_deprecated_headers() {
	if (get_keycloak_level() >= 3) {
		my $r = Apache2::RequestUtil->request();
		$r->err_headers_out->set('Deprecation', 'Mon, 01 Apr 2024 00:00:00 GMT');
		$r->err_headers_out->set('Sunset', 'Tue, 01 Apr 2025 18:00:00 GMT');
	}
	return;
}

=head2 get_keycloak_level()

Returns the current Keycloak implementation level

=head3 Return values

0 = Not available
1 = Use legacy Authentication and Registration but keep users in sync
2 = Use Keycloak for back-channel authentication but legacy login and Registration UI
3 = Use Keycloak backend and UI for all authentication. Legacy Registration UI
4 = Respond to Keycloak events for user registration / deletion tasks (welcome email, etc.)
5 = Fully implemented, including Keycloak registration UI

=cut

sub get_keycloak_level() {
	return $oidc_options{keycloak_level};
}

1;
