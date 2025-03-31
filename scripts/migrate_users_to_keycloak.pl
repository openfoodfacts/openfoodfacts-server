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
use ProductOpener::Keycloak qw/:all/;

use JSON;
use LWP::UserAgent;
use LWP::UserAgent::Plugin 'Retry';
use HTTP::Request;
use URI::Escape::XS qw/uri_escape/;

use Log::Any '$log', default_adapter => 'Stderr';

my $keycloak = ProductOpener::Keycloak->new();

my $keycloak_partialimport_endpoint
	= $oidc_options{keycloak_backchannel_base_url}
	. '/admin/realms/'
	. uri_escape($oidc_options{keycloak_realm_name})
	. '/partialImport';

my $user_emails = undef;
my ($checkpoint_file, $checkpoint) = open_checkpoint('migrate_users_to_keycloak_checkpoint.tmp');

sub create_user_in_keycloak_with_scrypt_credential ($keycloak_user_ref) {
	my $json = encode_json($keycloak_user_ref);
	my $userid = $keycloak_user_ref->{username};

	my $request_token = $keycloak->get_or_refresh_token();
	my $get_user_request = HTTP::Request->new(
		GET => $keycloak->{users_endpoint} . '?briefRepresentation=true&exact=true&username=' . $userid);
	$get_user_request->header('Authorization' => $request_token->{token_type} . ' ' . $request_token->{access_token});
	my $get_user_response = LWP::UserAgent::Plugin->new->request($get_user_request);
	unless ($get_user_response->is_success) {
		$log->error($userid . ": " . $get_user_response->content);
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
		print "$json\n";
		$log->error($userid . ": " . $upsert_user_response->content);
		return;
	}

	update_checkpoint($checkpoint_file, $userid);

	return;
}

sub import_users_in_keycloak ($users_ref) {
	my $request_data = {users => $users_ref};
	my $json = encode_json($request_data);

	my $request_token = $keycloak->get_or_refresh_token();
	$log->error($keycloak_partialimport_endpoint);
	my $import_users_request = HTTP::Request->new(POST => $keycloak_partialimport_endpoint);
	$import_users_request->header('Content-Type' => 'application/json');
	$import_users_request->header(
		'Authorization' => $request_token->{token_type} . ' ' . $request_token->{access_token});
	$import_users_request->content($json);
	my $import_users_response = LWP::UserAgent::Plugin->new->request($import_users_request);

	unless ($import_users_response->is_success) {
		$log->error(
			'There was an error importing users to Keycloak. Please ensure that the client has permission to manage the realm. This is not enabled by default and should only be a temporary permission.',
			{
				response => $import_users_response->content,
				client_id => $oidc_options{client_id},
				keycloak_realm_name => $oidc_options{keycloak_realm_name}
			}
		);
		return;
	}

	update_checkpoint($checkpoint_file, @{$users_ref}[-1]->{username});
	return;
}

sub migrate_user ($userid, $anonymize) {
	my $keycloak_user_ref = convert_to_keycloak_user($userid, $anonymize);
	if (not(defined $keycloak_user_ref)) {
		$log->warn('unable to convert user_ref');
		return;
	}

	create_user_in_keycloak_with_scrypt_credential($keycloak_user_ref);

	return;
}

sub convert_to_keycloak_user ($userid, $anonymize) {
	my $user_file = "$BASE_DIRS{USERS}/$userid.sto";
	my $user_ref = retrieve($user_file);
	if (not(defined $user_ref)) {
		$log->warn('undefined $user_ref');
		return;
	}

	my $credential
		= $anonymize ? undef : convert_scrypt_password_to_keycloak_credentials($user_ref->{'encrypted_password'});
	my $name = ($anonymize ? $userid : $user_ref->{name});
	# Inverted expression from: https://github.com/keycloak/keycloak/blob/2eae68010877c6807b6a454c2d54e0d1852ed1c0/services/src/main/java/org/keycloak/userprofile/validator/PersonNameProhibitedCharactersValidator.java#L42C63-L42C114
	$name =~ s/[<>&"$%!#?§;*~\/\\|^=\[\]{}()\x00-\x1F\x7F]+//g;

	my $keycloak_user_ref = {
		enabled => $JSON::PP::true,
		username => $userid,
		attributes => {
			# Truncate name more than 255 because of UTF-8 encoding. Could do this more precisely...
			name => substr($name, 0, 128),
			locale => $user_ref->{initial_lc},
			country => $user_ref->{initial_cc},
			registered => 'registered',    # The prevents welcome emails from being sent
			importTimestamp => time(),
			importSourceChangedTimestamp => (stat($user_file))[9]
		},
		createdTimestamp => ($user_ref->{registered_t} // time()) * 1000
	};
	if (defined $credential) {
		$keycloak_user_ref->{credentials} = [$credential];
	}

	my $email = sanitise_email($user_ref->{email});
	my $email_status = $user_emails->{$email};

	if ($anonymize) {
		$keycloak_user_ref->{email} = 'off.' . $userid;
		$keycloak_user_ref->{emailVerified} = $JSON::PP::true;
	}
	elsif (not defined $email_status or $email_status->{invalid} or $email_status->{userid} ne $userid) {
		$keycloak_user_ref->{attributes}{old_email} = $user_ref->{email};
	}
	else {
		$keycloak_user_ref->{email} = $email;
		# Currently, the assumption is that all users have verified their email address. This is not true, but it's better than forcing all existing users to verify their email address.
		$keycloak_user_ref->{emailVerified} = $JSON::PP::true;
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
	open(my $invalid_user_file, '>:encoding(UTF-8)', 'invalid_users.csv') or die "Could not open invalid_users file $!";

	my $all_emails = {};
	if (opendir(my $dh, "$BASE_DIRS{USERS}/")) {
		my @files = readdir($dh);
		closedir $dh;
		my $count = 0;
		foreach my $file (sort @files) {
			if (($file =~ /.+\.sto$/) and ($file ne 'users_emails.sto')) {
				my $user_ref = retrieve("$BASE_DIRS{USERS}/$file");
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
				print "Validated $count / " . scalar @files . "\n";
			}
		}

		store("all_emails.sto", $all_emails);
	}

	close $invalid_user_file;

	return $all_emails;
}

sub sanitise_email($email) {
	$email = lc($email || '');
	$email =~ s/\s+//g;

	return $email;
}

sub open_checkpoint($filename) {
	if (!-e $filename) {
		`touch $filename`;
	}
	open(my $checkpoint_file, '+<', $filename) or die "Could not open file '$filename' $!";
	seek($checkpoint_file, 0, 0);
	my $checkpoint = <$checkpoint_file>;
	chomp $checkpoint if $checkpoint;
	$checkpoint = '' if not defined $checkpoint;
	return ($checkpoint_file, $checkpoint);
}

sub update_checkpoint($checkpoint_file, $checkpoint) {
	seek($checkpoint_file, 0, 0);
	print $checkpoint_file "$checkpoint.sto";
	truncate($checkpoint_file, tell($checkpoint_file));
	return 1;
}

# Default to api-multi as realm-batch can be a bit flakey and can't do updates
my $importtype = 'api-multi';
if ((scalar @ARGV) > 0 and (length($ARGV[0]) > 0)) {
	$importtype = $ARGV[0];
}

my $anonymize = 0;
if ((scalar @ARGV) > 0 and ('anonymize' eq $ARGV[-1])) {
	# Anonymize the user data by removing the email address, name, and password.
	# This is useful for testing the migration script and for adding production data to the test server.
	$anonymize = 1;
}

if ($importtype eq 'validate') {
	validate_user_emails();
}
elsif ($importtype eq 'realm-batch') {
	$user_emails = (retrieve("all_emails.sto") or validate_user_emails());

	my @users = ();

	if (opendir(my $dh, "$BASE_DIRS{USERS}/")) {
		my @files = readdir($dh);
		closedir $dh;
		foreach my $file (sort @files) {
			next if $file le $checkpoint;

			if (($file =~ /.+\.sto$/) and ($file ne 'users_emails.sto')) {
				my $keycloak_user = convert_to_keycloak_user(substr($file, 0, -4), $anonymize);
				push(@users, $keycloak_user) if defined $keycloak_user;
			}

			if (scalar @users >= 2000) {
				import_users_in_keycloak(\@users);
				@users = ();
			}
		}
	}

	if (scalar @users) {
		import_users_in_keycloak(\@users);
	}
}
elsif ($importtype eq 'api-multi') {
	$user_emails = (retrieve("all_emails.sto") or validate_user_emails());

	if (opendir(my $dh, "$BASE_DIRS{USERS}/")) {
		my @files = readdir($dh);
		closedir $dh;
		my $count = 0;
		print '[' . localtime() . "] Starting migration\n";
		foreach my $file (sort @files) {
			$count++;
			next if $file le $checkpoint;

			if (($file =~ /.+\.sto$/) and ($file ne 'users_emails.sto')) {
				migrate_user(substr($file, 0, -4), $anonymize);
			}
			if ($count % 10000 == 0) {
				print '[' . localtime() . "] Migrated $count / " . scalar @files . "\n";
			}
		}
		print '[' . localtime() . "] Migrated $count / " . scalar @files . "\n";
	}
}
elsif ($importtype eq 'api-single') {
	if ((scalar @ARGV) == 2 and (length($ARGV[1]) > 0)) {
		$user_emails = (retrieve("all_emails.sto") or validate_user_emails());
		migrate_user($ARGV[1], $anonymize);
	}
}
else {
	die "Unknown import type: $importtype";
}

close $checkpoint_file;
