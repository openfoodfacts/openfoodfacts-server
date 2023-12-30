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
		&create_user_in_keycloak
		&get_token_using_client_credentials
		&get_token_using_password_credentials
		&get_azp
		&write_auth_deprecated_headers
		&start_signout

		$oidc_discover_document
		$jwks
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;

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
my $cookie_domain = '.' . $server_domain;    # e.g. fr.openfoodfacts.org sets the domain to .openfoodfacts.org
$cookie_domain =~ s/\.pro\./\./;    # e.g. .pro.openfoodfacts.org -> .openfoodfacts.org
if (defined $server_options{cookie_domain}) {
	$cookie_domain
		= '.' . $server_options{cookie_domain};    # e.g. fr.import.openfoodfacts.org sets domain to .openfoodfacts.org
}

my $callback_uri = format_subdomain('world') . '/cgi/oidc-signin-callback.pl';
my $signout_callback_uri = format_subdomain('world') . '/cgi/oidc-signout-callback.pl';

my $client = undef;

=head2 start_authorize($request_ref)

Initiates the authorization process by redirecting the user to the authorization page.

=head3 Arguments

=head4 A reference to a hash containing request information. $request_ref

=head3 Return Values

None
=cut

sub start_authorize ($request_ref) {
	my $nonce = generate_token(64);
	my $return_url = single_param('return_url');
	if (   (not $return_url)
		or (not($return_url =~ /^https?:\/\/$subdomain\.$server_domain/)))
	{
		$return_url = $formatted_subdomain;
	}

	my $client = _get_client();
	my $redirect_url = $client->uri_to_redirect(
		redirect_uri => $callback_uri,
		scope => q{openid profile offline_access},
		state => $nonce,
	);

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
		start_authorize($request_ref);
		return;
	}

	my $code = single_param('code');
	my $state = single_param('state');
	my $time = time();
	my $client = _get_client();
	my $access_token = $client->get_access_token(
		code => $code,
		redirect_uri => $callback_uri,
	) or display_error_and_exit($client->errstr, 500);
	$log->info('got access token during callback', {access_token => $access_token}) if $log->is_info();

	my %cookie_ref = cookie($cookie_name);
	my $nonce = $cookie_ref{'nonce'};
	if (not($state eq $nonce)) {
		$log->info('unexpected nonce', {nonce => $nonce, expected_nonce => $state}) if $log->is_info();
		display_error_and_exit('Invalid Nonce during OIDC login', 500);
	}

	my $id_token = verify_id_token($access_token->id_token);
	unless ($id_token) {
		$log->info('id token did not verify') if $log->is_info();
		display_error_and_exit('Authentication error', 401);
	}

	my $user_id = get_user_id_using_token($id_token);
	unless (defined $user_id) {
		$log->info('User not found and not created') if $log->is_info();
		display_error_and_exit('Internal error', 500);
	}

	my $user_file = "$BASE_DIRS{USERS}/" . get_string_id_for_lang("no_language", $user_id) . ".sto";
	unless (-e $user_file) {
		$log->info('User file not found', {user_file => $user_file, user_id => $user_id}) if $log->is_info();
		display_error_and_exit('Internal error', 500);
	}

	$log->debug('user_id found', {user_id => $user_id}) if $log->is_debug();
	my $user_ref = retrieve($user_file);

	my $user_session = open_user_session(
		$user_ref,
		$access_token->{refresh_token},
		$time + $access_token->{refresh_expires_in},
		$access_token->{access_token},
		$time + $access_token->{expires_in},
		$access_token->{id_token}, $request_ref
	);
	param('user_id', $user_id);
	param('user_session', $user_session);
	init_user($request_ref);

	return $cookie_ref{'return_url'};
}

=head2 password_signin($username, $password)

Signs in the user with a username and password, and returns the user's ID, refresh token, refresh token expiration time, access token, and access token expiration time.

=head3 Arguments

=head4 The username for password-based authentication. $username
=head4 The password for password-based authentication. $password

=head3 Return Values

A list containing the user's ID, refresh token, refresh token expiration time, access token, and access token expiration time.
=cut

sub password_signin ($username, $password) {
	unless ($username and $password) {
		return;
	}

	my $time = time();
	my $access_token = get_token_using_password_credentials($username, $password);
	unless ($access_token) {
		return;
	}

	my $id_token = verify_id_token($access_token->{id_token});
	unless ($id_token) {
		$log->info('id token did not verify') if $log->is_info();
		return;
	}

	my $user_id = get_user_id_using_token($id_token);
	$log->debug('user_id found', {user_id => $user_id}) if $log->is_debug();
	return (
		$user_id,
		$access_token->{refresh_token},
		$time + $access_token->{refresh_expires_in},
		$access_token->{access_token},
		$time + $access_token->{expires_in}
	);
}

sub get_user_id_using_token ($id_token) {
	unless ($JSON::PP::true eq $id_token->{'email_verified'}) {
		$log->info('User email is not verified.', {email => $id_token->{'email'}}) if $log->is_info();
		return;
	}

	my $verified_email = $id_token->{'email'};

	return try_retrieve_userid_from_mail($verified_email) // create_user_in_product_opener($id_token);
}

sub refresh_access_token ($refresh_token) {
	my $time = time();
	my $client = _get_client();
	my $access_token = $client->refresh_access_token(refresh_token => $refresh_token,)
		or die $client->errstr;

	$log->info('refreshed access token', {access_token => $access_token}) if $log->is_info();
	return (
		$access_token->{refresh_token}, $time + $access_token->{refresh_expires_in},
		$access_token->{access_token}, $time + $access_token->{expires_in}
	);
}

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

	if ((defined $access_expires_at) and ($access_expires_at < time())) {
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
.
=head3 Return Values

None
=cut

sub start_signout ($request_ref) {
	my $return_url = single_param('return_url');
	if (   (not $return_url)
		or (not($return_url =~ /^https?:\/\/$subdomain\.$server_domain/)))
	{
		$return_url = $formatted_subdomain;
	}

	my $id_token = $request_ref->{id_token};
	unless ($User_id and $id_token) {
		param('length', 'logout');
		init_user($request_ref);
		redirect_to_url($request_ref, 302, $formatted_subdomain);
		return;
	}

	_ensure_oidc_is_discovered();

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

	$request_ref->{cookie} = generate_oidc_cookie($nonce, $return_url);
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
	if (not(defined cookie($cookie_name))) {
		return $formatted_subdomain;
	}

	my $state = single_param('state');
	my %cookie_ref = cookie($cookie_name);
	my $nonce = $cookie_ref{'nonce'};
	if (not($state eq $nonce)) {
		$log->info('unexpected nonce', {nonce => $nonce, expected_nonce => $state}) if $log->is_info();
		display_error_and_exit('Invalid Nonce during OIDC logout', 500);
	}

	param('length', 'logout');
	init_user($request_ref);

	return $cookie_ref{'return_url'};
}

sub create_user_in_keycloak ($user_ref, $password) {
	my $keycloak_users_endpoint = $oidc_options{keycloak_users_endpoint};
	unless ($keycloak_users_endpoint) {
		display_error_and_exit('keycloak_users_endpoint not configured', 500);
	}

	my $token = get_token_using_client_credentials();
	unless ($token) {
		display_error_and_exit('Could not get token to manage users with keycloak_users_endpoint', 500);
	}

	my $api_request_ref = {
		email => $user_ref->{email},
		emailVerified => $JSON::PP::true,    # TODO: Keep this for compat with current register endpoint?
		enabled => $JSON::PP::true,
		username => $user_ref->{userid},
		credentials => [
			{
				type => 'password',
				temporary => $JSON::PP::false,
				value => $password
			}
		],
		attributes => [
			name => [$user_ref->{name}],
			locale => [$user_ref->{initial_lc}],
			country => [$user_ref->{initial_cc}],
		]
	};
	my $json = encode_json($api_request_ref);

	my $create_user_request = HTTP::Request->new(POST => $keycloak_users_endpoint);
	$create_user_request->header('Content-Type' => 'application/json');
	$create_user_request->header('Authorization' => $token->{token_type} . ' ' . $token->{access_token});
	$create_user_request->content($json);
	my $new_user_response = LWP::UserAgent::Plugin->new->request($create_user_request);
	unless ($new_user_response->is_success) {
		display_error_and_exit($new_user_response->content, 500);
	}

	my $get_user_request = HTTP::Request->new(GET => $new_user_response->header('location'));
	$get_user_request->header('Content-Type' => 'application/json');
	$get_user_request->header('Authorization' => $token->{token_type} . ' ' . $token->{access_token});
	my $get_user_response = LWP::UserAgent::Plugin->new->request($get_user_request);
	unless ($get_user_response->is_success) {
		display_error_and_exit($get_user_response->content, 500);
	}

	my $json_response = $get_user_response->decoded_content(charset => 'UTF-8');
	my @created_users = decode_json($json_response);
	return $created_users[0];
}

sub create_user_in_product_opener ($id_token) {
	unless ($id_token) {
		return;
	}

	my $user_ref = {};
	$user_ref->{email} = $id_token->{'email'};
	$user_ref->{userid} = $id_token->{'preferred_username'};
	$user_ref->{name} = $id_token->{'name'};

	my $user_id = $user_ref->{userid};
	my $user_file = "$BASE_DIRS{USERS}/" . get_string_id_for_lang("no_language", $user_id) . ".sto";
	store($user_file, $user_ref);

	# Store email
	my $emails_ref = retrieve("$BASE_DIRS{USERS}/users_emails.sto");
	my $email = $user_ref->{email};

	if ((defined $email) and ($email =~ /\@/)) {
		$emails_ref->{$email} = [$user_id];
	}

	if (defined $user_ref->{old_email}) {
		delete $emails_ref->{$user_ref->{old_email}};
		delete $user_ref->{old_email};
	}

	store("$BASE_DIRS{USERS}/users_emails.sto", $emails_ref);
	return $user_id;
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

=head2 generate_oidc_cookie($user_id, $user_session)

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

=head3 Arguments

=head4 The access token. $access_token

=head3 Return values

The authorized party (client ID) or undefined if the token is not issued by the correct issuer.
=cut

sub get_azp ($access_token) {
	if (not(defined $access_token)) {
		return;
	}

	_ensure_oidc_is_discovered();

	if (not($oidc_discover_document->{issuer} eq $access_token->{iss})) {
		$log->warn(
			'Given token was not issued by the correct issuer',
			{
				actual_iss => $access_token->{iss},
				expected_iss => $oidc_discover_document->{iss},
				azp => $access_token->{azp},
				sub => $access_token->{sub}
			}
		) if $log->is_warn();
		return;
	}

	return $access_token->{azp};
}

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

sub _ensure_oidc_is_discovered () {
	if ($jwks) {
		return;
	}

	$log->info('Original OIDC configuration', {endpoint_configuration => $oidc_options{endpoint_configuration}})
		if $log->is_info();

	my $discovery_request = HTTP::Request->new(GET => $oidc_options{endpoint_configuration});
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
	my $r = Apache2::RequestUtil->request();
	$r->err_headers_out->set('Deprecation', 'Mon, 01 Apr 2024 00:00:00 GMT');
	$r->err_headers_out->set('Sunset', 'Tue, 01 Apr 2025 18:00:00 GMT');
	return;
}

1;
