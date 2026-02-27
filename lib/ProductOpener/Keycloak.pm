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

ProductOpener::Keycloak - Perl module for Keycloak user management

=head1 DESCRIPTION

This Perl module provides access to Keycloak specific functionality that goes beyond that of a standard OIDC authentication service.

This includes user management APIs and the user security settings forms.

=cut

package ProductOpener::Keycloak;

use ProductOpener::PerlStandards;

use Log::Any qw($log);

use ProductOpener::Auth qw/get_oidc_configuration get_token_using_client_credentials get_oidc_implementation_level/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/country_to_cc cc_to_country/;
use ProductOpener::Cache qw/$memd/;

use JSON;
use LWP::UserAgent;
use LWP::UserAgent::Plugin 'Retry';
use HTTP::Request;
use URI::Escape::XS qw/uri_escape/;

sub new($class) {
	my $self = {};
	bless $self, $class;

	my $oidc_configuration = get_oidc_configuration();
	unless (defined $oidc_configuration) {
		die 'oidc_discovery_url not configured or Keycloak is no available';
	}

	# Use the token_endpoint as the basis for the users endpoint as we access this over the back-channel
	$self->{users_endpoint} = $oidc_configuration->{token_endpoint} =~ s/\/realms\//\/admin\/realms\//r
		=~ s/\/protocol\/openid-connect\/token/\/users/r;

	# Use the issuer as the basis for the account URL as this is public facing
	$self->{account_service} = $oidc_configuration->{issuer} . '/account';

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
		if ($now > $cutoff) {
			$self->{token} = get_token_using_client_credentials();
			$self->{token}->{expires_at} = time() + $self->{token}->{expires_in};
		}
	}

	return $self->{token} // die 'Could not get token to manage users with users_endpoint';
}

sub convert_scrypt_password_to_keycloak_credentials ($hashed_password) {
	unless (defined $hashed_password) {
		return;
	}

	my $credential = {};
	my ($alg, $N, $r, $p, $salt, $hash) = ($hashed_password =~ /^(SCRYPT):(\d+):(\d+):(\d+):([^\:]+):([^\:]+)$/);
	if ((defined $alg) and ($alg eq 'SCRYPT')) {
		# Only migrate SCRYPT passwords. If there are still users that use MD5,
		# they haven't signed in in 8 years, and will have to change their
		# password, if they want to use the server again.
		$credential->{type} = 'password';

		my $secret_data = {
			value => $hash,
			salt => $salt
		};

		$credential->{secretData} = encode_json($secret_data);

		my $credential_data = {
			hashIterations => -1,
			algorithm => 'scrypt',
			additionalParameters => {
				N => [$N],
				r => [$r],
				p => [$p],
			}
		};

		$credential->{credentialData} = encode_json($credential_data);
		$credential->{temporary} = $JSON::false;
	}
	else {
		return;
	}

	return $credential;
}

=head2 create_or_update_user ($user_ref, $password)

Create use on keycloak side.

This is needed as we register new users via an old, undocumented API function.
We create the user properties file locally before, and we create the user in keycloak in this sub.

=head3 Arguments

=head4 User info hashmap reference $user_ref

=head4 String $password

=cut

sub create_or_update_user ($self, $user_ref, $password = undef) {
	my $credential = defined $password
		? {
		type => 'password',
		temporary => $JSON::PP::false,
		value => $password
		}
		# Note that encrypted_password can still be passed in if the user edits their password
		: convert_scrypt_password_to_keycloak_credentials($user_ref->{'encrypted_password'});

	# Need to sanitise user's name for Keycloak
	my $name = $user_ref->{name};
	# Inverted expression from: https://github.com/keycloak/keycloak/blob/2eae68010877c6807b6a454c2d54e0d1852ed1c0/services/src/main/java/org/keycloak/userprofile/validator/PersonNameProhibitedCharactersValidator.java#L42C63-L42C114
	$name =~ s/[<>&"$%!#?§;*~\/\\|^=\[\]{}()\x00-\x1F\x7F]+//g;

	# Sanitise email
	my $email = lc($user_ref->{email} || '');
	$email =~ s/\s+//g;

	# These are the Keycloak fields that we care about and want to cache
	my $userid = $user_ref->{userid};
	my $keycloak_user_ref = {
		userid => $userid,
		email => $email,
		# Truncate name more than 255 because of UTF-8 encoding. Could do this more precisely...
		name => substr($name, 0, 128),
		preferred_language => $user_ref->{preferred_language},
		# Note in Keycloak we store the country code (cc), e.g. "fr" whereas $user_ref->{country} is a canonical country tag, e.g. "en:france"
		country => $user_ref->{country}
	};

	# user creation payload
	my $api_request_ref = {
		email => $keycloak_user_ref->{email},
		emailVerified => $JSON::PP::true,    # TODO: Keep this for compat with current register endpoint?
		enabled => $JSON::PP::true,
		username => $userid,
		createdTimestamp => ($user_ref->{registered_t} // time()) * 1000,
		attributes => {
			name => $keycloak_user_ref->{name},
			locale => $keycloak_user_ref->{preferred_language},
			requested_org => $user_ref->{requested_org},
			newsletter => ($user_ref->{newsletter} ? 'subscribe' : undef)
		}
	};
	# Only supply credentials if set
	if ($credential) {
		$api_request_ref->{credentials} = [$credential];
	}
	# Only supply country if it is set
	if ($user_ref->{country}) {
		$api_request_ref->{attributes}->{country} = country_to_cc($keycloak_user_ref->{country});
	}
	if (get_oidc_implementation_level() < 2) {
		# Prevent Keycloak sending registration emails unless it is the primary source of truth
		$api_request_ref->{attributes}->{registered} = 'registered';
	}

	# issue the request to keycloak
	my $new_user_response = create_or_update_keycloak_user($self, $api_request_ref);
	unless ($new_user_response->is_success) {
		my $error_content = decode_json($new_user_response->content);
		if ($error_content->{errorMessage} eq 'User exists with same email') {
			$log->error('Duplicate user email not updated in Keycloak', {request => $api_request_ref});
			# Set the email to null and save the old email in an attribute
			$api_request_ref->{attributes}{old_email} = $api_request_ref->{email};
			$api_request_ref->{email} = undef;
			$api_request_ref->{emailVerified} = $JSON::PP::false;
			# Try again
			$new_user_response = create_or_update_keycloak_user($self, $api_request_ref);
		}
	}
	unless ($new_user_response->is_success) {
		die $new_user_response->content;
	}
	$memd->set("user/$userid", $keycloak_user_ref);

	return;
}

sub create_or_update_keycloak_user($self, $api_request_ref) {
	# use a special application authorization to handle creation
	my $token = $self->get_or_refresh_token();
	unless ($token) {
		die 'Could not get token to manage users with keycloak_users_endpoint';
	}

	# See if user already exists
	my $existing_user = $self->find_keycloak_user_by_username($api_request_ref->{username}, 1);

	my $json = encode_json($api_request_ref);
	$log->info('updating keycloak user', {existing_user => $existing_user, request => $api_request_ref})
		if $log->is_info();

	# create request with right headers
	my $upsert_user_request;
	if (defined $existing_user) {
		my $keycloak_id = $existing_user->{id};
		$upsert_user_request = HTTP::Request->new(PUT => $self->{users_endpoint} . '/' . $keycloak_id);
	}
	else {
		$upsert_user_request = HTTP::Request->new(POST => $self->{users_endpoint});
	}
	$upsert_user_request->header('Content-Type' => 'application/json');
	$upsert_user_request->header('Authorization' => $token->{token_type} . ' ' . $token->{access_token});
	$upsert_user_request->content($json);

	# issue the request to keycloak
	return LWP::UserAgent::Plugin->new->request($upsert_user_request);
}

sub delete_user ($self, $userid) {
	# See if user already exists
	my $existing_user = $self->find_keycloak_user_by_username($userid, 1);

	if (defined $existing_user) {
		# use a special application authorization to handle creation
		my $token = $self->get_or_refresh_token();
		unless ($token) {
			die 'Could not get token to manage users with keycloak_users_endpoint';
		}

		my $keycloak_id = $existing_user->{id};
		my $delete_user_request = HTTP::Request->new(DELETE => $self->{users_endpoint} . '/' . $keycloak_id);
		$delete_user_request->header('Authorization' => $token->{token_type} . ' ' . $token->{access_token});
		# issue the request to keycloak
		my $response = LWP::UserAgent::Plugin->new->request($delete_user_request);
		unless ($response->is_success) {
			die $response->content;
		}
		$memd->delete("user/$userid");
	}

	return;
}

=head2 find_user_by_username ($username)

Try to find a user in Keycloak by their username.

=head3 Arguments

=head4 User's user id $user_id

=head3 Return Value

A hashmap reference with user information from Keycloak mapped onto PO user fields

=cut

sub find_user_by_username ($self, $userid) {
	my $user_ref = $memd->get("user/$userid");
	if (not defined $user_ref) {
		$user_ref = keycloak_to_user_ref($self->find_keycloak_user_by_username($userid));
	}
	return $user_ref;
}

sub find_keycloak_user_by_username ($self, $username, $brief = 0) {
	return $self->_find_user_by_single_attribute_exact('username', $username, $brief);
}

=head2 find_user_by_email ($mail)

Try to find a user in Keycloak by their mail address.

=head3 Arguments

=head4 User's mail address $mail

=head3 Return Value

A hashmap reference with user information from Keycloak.

=cut

sub find_user_by_email ($self, $email) {
	return keycloak_to_user_ref($self->_find_user_by_single_attribute_exact('email', $email));
}

sub keycloak_to_user_ref ($keycloak_user_ref) {
	my $user_ref;
	if ($keycloak_user_ref) {
		my $userid = $keycloak_user_ref->{username};
		$user_ref = {
			userid => $userid,
			email => $keycloak_user_ref->{email},
			name => $keycloak_user_ref->{attributes}->{name}[0],
			preferred_language => $keycloak_user_ref->{attributes}->{locale}[0],
			country => cc_to_country($keycloak_user_ref->{attributes}->{country}[0])
			# Don't set requested_org and newsletter here as they are only relevant the first time a user registers
		};
		$memd->set("user/$userid", $user_ref);
	}
	return $user_ref;
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

sub _find_user_by_single_attribute_exact ($self, $name, $value, $brief = 0) {
	# use a special application authorization to handle search
	my $token = $self->get_or_refresh_token();
	unless ($token) {
		die 'Could not get token to search users with keycloak_users_endpoint';
	}

	# create request with right headers
	my $search_uri = $self->{users_endpoint} . '?exact=true&' . uri_escape($name) . '=' . uri_escape($value);
	if ($brief) {
		$search_uri .= "&briefRepresentation=true";
	}
	my $search_user_request = HTTP::Request->new(GET => $search_uri);
	$search_user_request->header('Accept' => 'application/json');
	$search_user_request->header('Authorization' => $token->{token_type} . ' ' . $token->{access_token});
	# issue the request to keycloak
	my $search_user_response = LWP::UserAgent::Plugin->new->request($search_user_request);
	unless ($search_user_response->is_success) {
		die $search_user_response->content;
	}

	my $json_response = $search_user_response->decoded_content(charset => 'UTF-8');
	my $users = decode_json($json_response);
	return $$users[0];
}

1;
