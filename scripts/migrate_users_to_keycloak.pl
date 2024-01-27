#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;

use ProductOpener::Auth qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;

use JSON;
use LWP::UserAgent;
use LWP::UserAgent::Plugin 'Retry';
use HTTP::Request;
use URI::Escape::XS qw/uri_escape/;

unless ((defined $oidc_options{keycloak_base_url}) and (defined $oidc_options{keycloak_realm_name})) {
	die 'keycloak_base_url and keycloak_realm_name not configured';
}

my $keycloak_users_endpoint
	= $oidc_options{keycloak_base_url} . '/admin/realms/' . uri_escape($oidc_options{keycloak_realm_name}) . '/users';

my $token;

sub get_token_if_we_dont_have_one_yet_or_it_is_expired () {
	if (not(defined $token)) {
		$token = get_token_using_client_credentials();
		$token->{expires_at} = time() + $token->{expires_in};
	}
	else {
		my $now = time();
		my $cutoff = $token->{expires_at} - 15;
		if ($now > $token->{expires_at}) {
			$token = get_token_using_client_credentials();
			$token->{expires_at} = time() + $token->{expires_in};
		}
	}

	return $token // die 'Could not get token to manage users with keycloak_users_endpoint';
}

sub create_user_in_keycloak_with_scrypt_credential ($user_ref, $credential) {
	my $api_request_ref = {
		email => $user_ref->{email},
		# Currently, the assumption is that all users have verified their email address. This is not true, but it's better than forcing all existing users to verify their email address.
		emailVerified => $JSON::PP::true,
		enabled => $JSON::PP::true,
		username => $user_ref->{userid},
		credentials => [$credential],
		attributes => [
			name => [$user_ref->{name}],
			locale => [$user_ref->{initial_lc}],
			country => [$user_ref->{initial_cc}],
		]
	};
	my $json = encode_json($api_request_ref);

	my $request_token = get_token_if_we_dont_have_one_yet_or_it_is_expired();
	my $create_user_request = HTTP::Request->new(POST => $keycloak_users_endpoint);
	$create_user_request->header('Content-Type' => 'application/json');
	$create_user_request->header(
		'Authorization' => $request_token->{token_type} . ' ' . $request_token->{access_token});
	$create_user_request->content($json);
	my $new_user_response = LWP::UserAgent::Plugin->new->request($create_user_request);
	unless ($new_user_response->is_success) {
		# TODO: Log?
		die $new_user_response->content;
	}

	$request_token = get_token_if_we_dont_have_one_yet_or_it_is_expired();
	my $get_user_request = HTTP::Request->new(GET => $new_user_response->header('location'));
	$get_user_request->header('Content-Type' => 'application/json');
	$get_user_request->header('Authorization' => $request_token->{token_type} . ' ' . $request_token->{access_token});
	my $get_user_response = LWP::UserAgent::Plugin->new->request($get_user_request);
	unless ($get_user_response->is_success) {
		# TODO: Log?
		die $get_user_response->content;
	}

	my $json_response = $get_user_response->decoded_content(charset => 'UTF-8');
	my @created_users = decode_json($json_response);
	return $created_users[0];
}

sub migrate_user ($user_file) {
	my $user_ref = retrieve($user_file);
	if (not(defined $user_ref)) {
		print STDERR 'defined $user_ref';
		return;
	}

	my $encrypted_password = $user_ref->{'encrypted_password'};
	if (not(defined $encrypted_password)) {
		print STDERR 'defined $encrypted_password';
		return;
	}

	my $credential = {};
	my ($alg, $N, $r, $p, $salt, $hash) = ($encrypted_password =~ /^(SCRYPT):(\d+):(\d+):(\d+):([^\:]+):([^\:]+)$/);
	if ((defined $alg) and ($alg eq 'SCRYPT')) {
		# Only migrate SCRYPT passwords. If there are still users that use MD5,
		# they haven't signed in in 8 years, and will have to change their
		# password, if they want to use the server again.
		$credential->{type} = 'password';

		my $secret_data = {};
		$secret_data->{value} = $hash;
		$secret_data->{salt} = $salt;
		$credential->{secretData} = encode_json($secret_data);

		my $credential_data = {};
		$credential_data->{hashIterations} = -1;
		$credential_data->{algorithm} = 'scrypt';
		$credential_data->{additionalParameters} = {};
		$credential_data->{additionalParameters}->{N} = [$N];
		$credential_data->{additionalParameters}->{r} = [$r];
		$credential_data->{additionalParameters}->{p} = [$p];
		$credential->{credentialData} = encode_json($credential_data);

		$credential->{temporary} = $JSON::false;
	}

	create_user_in_keycloak_with_scrypt_credential($user_ref, $credential);

	return;
}

if (opendir(my $dh, "$BASE_DIRS{USERS}/")) {
	foreach my $file (readdir($dh)) {
		if (($file =~ /.+\.sto$/) and ($file ne 'users_emails.sto')) {
			migrate_user("$BASE_DIRS{USERS}/$file");
		}
	}

	closedir $dh;
}
