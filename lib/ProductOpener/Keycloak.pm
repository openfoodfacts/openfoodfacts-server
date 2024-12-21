# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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

ProductOpener::Keycloak - Perl module for Keycloak user management

=head1 DESCRIPTION

This Perl module provides a class that can be used to access Keycloak's user management API.

=cut

package ProductOpener::Keycloak;

use ProductOpener::PerlStandards;

use Log::Any qw($log);

use ProductOpener::Auth qw/get_token_using_client_credentials/;
use ProductOpener::Config qw/:all/;

use JSON;
use LWP::UserAgent;
use LWP::UserAgent::Plugin 'Retry';
use HTTP::Request;
use URI::Escape::XS qw/uri_escape/;

sub new($class) {
	my $self = {};
	bless $self, $class;

	unless ((defined $oidc_options{keycloak_base_url})
		and (defined $oidc_options{keycloak_backchannel_base_url})
		and (defined $oidc_options{keycloak_realm_name}))
	{
		die 'keycloak_base_url or keycloak_backchannel_base_url or keycloak_realm_name not configured';
	}

	$self->{users_endpoint}
		= $oidc_options{keycloak_backchannel_base_url}
		. '/admin/realms/'
		. uri_escape($oidc_options{keycloak_realm_name})
		. '/users';

	$self->{account_service}
		= $oidc_options{keycloak_base_url} . '/realms/' . uri_escape($oidc_options{keycloak_realm_name}) . '/account';

	return $self;
}

=head2 get_or_refresh_token()

Retrieves or refreshes the access token for managing users with Keycloak.

If the token is not defined, it retrieves a new token using client credentials.
If the token is defined but has expired, it refreshes the token.
The token is stored in the object and its expiration time is updated.

=head3 Arguments

None

=head3 Return values

Returns the access token.
Throws an exception if the token cannot be obtained.

=cut

sub get_or_refresh_token ($self) {
	if (not(defined $self->{token})) {
		$self->{token} = get_token_using_client_credentials();
		$self->{token}->{expires_at} = time() + $self->{token}->{expires_in};
	}
	else {
		my $now = time();
		my $cutoff = $self->{token}->{expires_at} - 30;
		if ($now > $self->{token}->{expires_at}) {
			$self->{token} = get_token_using_client_credentials();
			$self->{token}->{expires_at} = time() + $self->{token}->{expires_in};
		}
	}

	return $self->{token} // die 'Could not get token to manage users with users_endpoint';
}

=head2 create_user ($user_ref, $password)

Create use on keycloak side.

This is needed as we register new users via an old, undocumented API function.
We create the user properties file locally before, and we create the user in keycloak in this sub.

=head3 Arguments

=head4 User info hashmap reference $user_ref

=head4 String $password

=head3 Return Value

A hashmap reference with created user information.

=cut

sub create_user ($self, $user_ref, $password) {
	# use a special application authorization to handle creation
	my $token = $self->get_or_refresh_token();
	unless ($token) {
		display_error_and_exit('Could not get token to manage users with keycloak_users_endpoint', 500);
	}

	# user creation payload
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
			name => $user_ref->{name},
			locale => $user_ref->{preferred_language},
			country => $user_ref->{country},
			reqested_org => $user_ref->{requested_org},
			newsletter => ($user_ref->{newsletter} ? 'subscribe' : undef)
		]
	};
	my $json = encode_json($api_request_ref);

	# create request with right headers
	my $create_user_request = HTTP::Request->new(POST => $self->{users_endpoint});
	$create_user_request->header('Content-Type' => 'application/json');
	$create_user_request->header('Authorization' => $token->{token_type} . ' ' . $token->{access_token});
	$create_user_request->content($json);
	# issue the request to keycloak
	my $new_user_response = LWP::UserAgent::Plugin->new->request($create_user_request);
	unless ($new_user_response->is_success) {
		display_error_and_exit($new_user_response->content, 500);
	}

	# continue the process by fetching user data,
	# which profile location is given in previous response
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

=head2 find_user_by_username ($username)

Try to find a user in Keycloak by their username.

=head3 Arguments

=head4 User's username $username

=head3 Return Value

A hashmap reference with user information from Keycloak.

=cut

sub find_user_by_username ($self, $username) {
	return $self->_find_user_by_single_attribute_exact('username', $username);
}

=head2 find_user_by_email ($mail)

Try to find a user in Keycloak by their mail address.

=head3 Arguments

=head4 User's mail address $mail

=head3 Return Value

A hashmap reference with user information from Keycloak.

=cut

sub find_user_by_email ($self, $email) {
	return $self->_find_user_by_single_attribute_exact('email', $email);
}

=head2 get_account_link()

Gets the link to the account service on Keycloak.

=head3 Arguments

=head4 Canonical URL of the current site string $url

=head3 Return values

Returns the URL.

=cut

sub get_account_link ($self, $url) {
	return
		  $self->{account_service}
		. '?referrer='
		. uri_escape($oidc_options{client_id})
		. '&referrer_uri='
		. uri_escape($url);
}

=head2 _find_user_by_single_attribute_exact ($name, $value)

Try to find a user in Keycloak by a single attribute key/value combo.

This should only be used with unique attributes like email or username.

=head3 Arguments

=head4 Name of the attribute $name

=head4 Value of the attribute $value

=head3 Return Value

A hashmap reference with user information from Keycloak.

=cut

sub _find_user_by_single_attribute_exact ($self, $name, $value) {
	# use a special application authorization to handle search
	my $token = $self->get_or_refresh_token();
	unless ($token) {
		display_error_and_exit('Could not get token to search users with keycloak_users_endpoint', 500);
	}

	# create request with right headers
	my $search_uri = $self->{users_endpoint} . '?exact=true&' . uri_escape($name) . '=' . uri_escape($value);
	my $search_user_request = HTTP::Request->new(GET => $search_uri);
	$search_user_request->header('Accept' => 'application/json');
	$search_user_request->header('Authorization' => $token->{token_type} . ' ' . $token->{access_token});
	# issue the request to keycloak
	my $search_user_response = LWP::UserAgent::Plugin->new->request($search_user_request);
	unless ($search_user_response->is_success) {
		display_error_and_exit($search_user_response->content, 500);
	}

	my $json_response = $search_user_response->decoded_content(charset => 'UTF-8');
	my $users = decode_json($json_response);
	return $$users[0];
}

1;
