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
use ProductOpener::Checkpoint;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Keycloak qw/:all/;
use ProductOpener::Tags qw/country_to_cc/;

use JSON;
use LWP::UserAgent;
use LWP::UserAgent::Plugin 'Retry';
use HTTP::Request;
use URI::Escape::XS qw/uri_escape/;
use List::MoreUtils qw/first_index/;

# Turn warnings into exceptions
local $SIG{__WARN__} = sub {
	my $message = shift;
	die $message;
};

my $keycloak = ProductOpener::Keycloak->new();

my $keycloak_partialimport_endpoint = $keycloak->{users_endpoint} =~ s/\/users/\/partialImport/r;

my $user_emails = undef;
my $checkpoint = ProductOpener::Checkpoint->new;
my $last_processed_email = $checkpoint->{value};
my $resume = defined $last_processed_email;

sub create_user_in_keycloak_with_scrypt_credential ($keycloak_user_ref) {
	my $json = encode_json($keycloak_user_ref);
	my $userid = $keycloak_user_ref->{username};

	my $request_token = $keycloak->get_or_refresh_token();
	my $get_user_request = HTTP::Request->new(
		GET => $keycloak->{users_endpoint} . '?briefRepresentation=true&exact=true&username=' . $userid);
	$get_user_request->header('Authorization' => $request_token->{token_type} . ' ' . $request_token->{access_token});
	my $get_user_response = LWP::UserAgent::Plugin->new->request($get_user_request);
	unless ($get_user_response->is_success) {
		$checkpoint->log("Error: $userid: " . $get_user_response->content);
		return;
	}
	my $existing_user = decode_json($get_user_response->content);
	my $upsert_user_request;
	if (scalar @$existing_user) {
		my $keycloak_id = $existing_user->[0]->{id};
		$upsert_user_request = HTTP::Request->new(PUT => $keycloak->{users_endpoint} . '/' . $keycloak_id);
	}
	else {
		$upsert_user_request = HTTP::Request->new(POST => $keycloak->{users_endpoint});
	}

	$upsert_user_request->header('Content-Type' => 'application/json');
	$upsert_user_request->header(
		'Authorization' => $request_token->{token_type} . ' ' . $request_token->{access_token});
	$upsert_user_request->content($json);
	my $upsert_user_response = LWP::UserAgent::Plugin->new->request($upsert_user_request);
	unless ($upsert_user_response->is_success) {
		$checkpoint->log(
			"Error: $userid: Keycloak error: " . $upsert_user_response->content . "\n$userid : Request: $json");
		return;
	}

	return;
}

sub migrate_user ($userid, $email, $anonymize) {
	my $keycloak_user_ref = convert_to_keycloak_user($userid, $email, $anonymize);
	if (defined $keycloak_user_ref) {
		create_user_in_keycloak_with_scrypt_credential($keycloak_user_ref);
	}

	return;
}

sub convert_to_keycloak_user ($userid, $email, $anonymize) {
	my $user_file = "$BASE_DIRS{USERS}/$userid.sto";
	my $user_ref;
	eval {$user_ref = retrieve($user_file);};
	if ($@) {
		$checkpoint->log("Warning: $userid : Error reading STO: $@");
		return;
	}
	if (not(defined $user_ref)) {
		$checkpoint->log("Warning: $userid : Empty STO file");
		return;
	}

	my $keycloak_user_ref;
	eval {
		# Use the existing password. Note in staging user will not be able to use "forgot password"
		my $credential = convert_scrypt_password_to_keycloak_credentials($user_ref->{'encrypted_password'});
		my $name = ($anonymize ? $userid : $user_ref->{name});
		# Inverted expression from: https://github.com/keycloak/keycloak/blob/2eae68010877c6807b6a454c2d54e0d1852ed1c0/services/src/main/java/org/keycloak/userprofile/validator/PersonNameProhibitedCharactersValidator.java#L42C63-L42C114
		$name =~ s/[<>&"$%!#?§;*~\/\\|^=\[\]{}()\x00-\x1F\x7F]+//g;

		$keycloak_user_ref = {
			enabled => $JSON::PP::true,
			username => $userid,
			attributes => {
				# Truncate name more than 255 because of UTF-8 encoding. Could do this more precisely...
				name => substr($name, 0, 128),
				locale => $user_ref->{preferred_language} || $user_ref->{initial_lc} || 'en',
				country => country_to_cc($user_ref->{country}) || $user_ref->{initial_cc} || 'world',
				registered => 'registered',    # The prevents welcome emails from being sent
				importTimestamp => time(),
				importSourceChangedTimestamp => (stat($user_file))[9]
			},
			createdTimestamp => ($user_ref->{registered_t} // time()) * 1000
		};
		if (defined $credential) {
			$keycloak_user_ref->{credentials} = [$credential];
		}

		if ($anonymize) {
			$keycloak_user_ref->{email} = 'off.' . $userid . '@openfoodfacts.org';
			$keycloak_user_ref->{emailVerified} = $JSON::PP::true;
		}
		elsif ($email) {
			$keycloak_user_ref->{email} = $email;
			# Currently, the assumption is that all users have verified their email address. This is not true, but it's better than forcing all existing users to verify their email address.
			$keycloak_user_ref->{emailVerified} = $JSON::PP::true;
		}
		else {
			# Explicitly set the email to null in case another user has it
			$keycloak_user_ref->{email} = undef;
			$keycloak_user_ref->{emailVerified} = $JSON::PP::false;
			$keycloak_user_ref->{attributes}{old_email} = $user_ref->{email};
		}
	};
	if ($@) {
		$checkpoint->log("Warning: $userid : Error converting user: $@\n$userid : User_ref: " . encode_json($user_ref));
		return;
	}
	return $keycloak_user_ref;
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

sub validate_user_emails() {
	$checkpoint->log("Starting email validation");
	open(my $invalid_user_file, '>:encoding(UTF-8)', "$BASE_DIRS{CACHE_TMP}/invalid_users.csv")
		or die "Could not open invalid_users file $!";

	my $all_emails = {};
	if (opendir(my $dh, "$BASE_DIRS{USERS}/")) {
		my @files = readdir($dh);
		closedir $dh;
		my $count = 0;
		foreach my $file (sort @files) {
			if (($file =~ /.+\.sto$/) and ($file ne 'users_emails.sto')) {
				my $user_ref;
				eval {$user_ref = retrieve("$BASE_DIRS{USERS}/$file");};
				if ($@) {
					$checkpoint->log("Warning: $file : Error reading STO: $@");
					$user_ref = undef;
				}

				if (defined $user_ref) {
					my $userid = substr($file, 0, -4);
					my $email = sanitise_email($user_ref->{email});
					my $last_login_t = $user_ref->{last_login_t} || 0;
					my $user_info = {userid => $userid, last_login_t => $last_login_t};
					my $user_infos = $all_emails->{$email};
					if (!defined $user_infos) {
						$all_emails->{$email}
							= {userid => $userid, last_login_t => $last_login_t, users => [$user_info]};
						if (
							not $email
							=~ /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
							or $email =~ /\.@/)
						{
							print $invalid_user_file "$userid,$email,invalid\n";
							$all_emails->{$email}->{invalid} = 1;
						}
					}
					else {
						if ($last_login_t < $user_infos->{last_login_t}) {
							print $invalid_user_file "$userid,$email,duplicate\n";
						}
						else {
							print $invalid_user_file $user_infos->{userid} . ",$email,duplicate\n";
							$user_infos->{userid} = $userid;
							$user_infos->{last_login_t} = $last_login_t;
						}
						push(@{$user_infos->{users}}, $user_info);
					}
				}
			}
			$count++;
			if ($count % 10000 == 0) {
				$checkpoint->log("Validated $count / " . scalar @files);
			}
		}

		$checkpoint->log("Validated $count / " . scalar @files);
		store("$BASE_DIRS{CACHE_TMP}/all_emails.sto", $all_emails);
	}

	close $invalid_user_file;

	return $all_emails;
}

sub sanitise_email($email) {
	$email = lc($email || '');
	$email =~ s/\s+//g;

	return $email;
}

my $anonymize = (first_index {$_ eq "anonymize"} @ARGV) + 1;
$user_emails = $resume ? retrieve("$BASE_DIRS{CACHE_TMP}/all_emails.sto") : validate_user_emails();

# Iterate over the user_emails list rather than the directory so that we can apply the null emails first
# before setting the valid ones. This caters for the preferred user for the email changing between migration runs
my @emails = sort keys %{$user_emails};
my $total = scalar @emails;
my $count = 0;
foreach my $email (@emails) {
	$count++;
	next if $resume and $email le $last_processed_email;
	if ($resume) {
		$checkpoint->log("Resuming from $email");
		$resume = 0;
	}
	my $user_infos = $user_emails->{$email};
	foreach my $user_info (@{$user_infos->{users}}) {
		# Do the null emails (not the favoured userid for the email) first
		if ($user_info->{userid} ne $user_infos->{userid}) {
			# $checkpoint->log("Invalid email $user_info->{userid}");
			migrate_user($user_info->{userid}, undef, $anonymize);
		}
	}
	# Now do the favoured user
	if ($user_infos->{userid}) {
		# $checkpoint->log("Valid email $user_infos->{userid}");
		migrate_user($user_infos->{userid}, $email, $anonymize);
	}
	if ($count % 10000 == 0) {
		$checkpoint->log("Migrated $count / $total");
	}
	$checkpoint->update($email);
}
$checkpoint->log("Migrated $count / $total");

