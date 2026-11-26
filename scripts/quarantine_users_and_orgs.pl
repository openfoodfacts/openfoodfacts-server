#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

=head1 NAME

quarantine_users_and_orgs.pl - Quarantine (and later restore or purge) a list of users and orgs, e.g. spam accounts

=head1 SYNOPSIS

	# 1. Quarantine: dry run by default, add --execute to apply
	quarantine_users_and_orgs.pl --batch spam-bot --users userids.txt --orgs orgids.txt [--brevo-csv emails.csv] [--execute]

	# 2a. Undo a batch
	quarantine_users_and_orgs.pl --restore <batch dir> [--execute]

	# 2b. Or, some time later, delete the batch for good
	quarantine_users_and_orgs.pl --purge <batch dir> [--execute]

=head1 DESCRIPTION

Input files contain one user id or org id per line.

Quarantine:

- users: the Keycloak account is disabled (the user cannot log in anymore), and the user .sto file is moved to the batch directory
- orgs: the org .sto file is moved to the batch directory, and the org is removed from the orgs MongoDB collection

Users and orgs are skipped (unless --force is used) if they look like real users or orgs:
moderators and admins, users or orgs linked to the CRM, accepted orgs, users that are members of orgs that are not in the list,
orgs that have members that are not in the list, users who edited products, orgs that have products.
The products checks are done in the MongoDB database of the current flavor, and orgs are removed from the orgs collection
of the current flavor. As users and orgs files are shared between the public and producers platforms,
run the script for users on the public platform, and for orgs on the producers platform.

The batch directory is created in the quarantine/ directory, next to the users/ directory.
Every action is recorded in its manifest.tsv file, which is used by --restore and --purge.

Restore moves the files back and re-enables the Keycloak accounts.

Purge deletes the Keycloak accounts (which triggers the usual user deletion job) and the quarantined files.
Until it is done, the email addresses of quarantined users cannot be used to create new accounts.

=cut

use ProductOpener::PerlStandards;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve/;
use ProductOpener::Users qw/is_admin_user retrieve_user/;
use ProductOpener::Data qw/get_orgs_collection get_products_collection/;
use ProductOpener::Auth qw/get_oidc_implementation_level/;
use ProductOpener::Keycloak;

use File::Basename qw/dirname/;
use File::Copy qw/move/;
use File::Path qw/make_path/;
use Getopt::Long;
use POSIX qw/strftime/;

my ($batch, $users_file, $orgs_file, $brevo_csv, $restore_dir, $purge_dir);
my $execute = 0;
my $force = 0;

GetOptions(
	"batch=s" => \$batch,
	"users=s" => \$users_file,
	"orgs=s" => \$orgs_file,
	"brevo-csv=s" => \$brevo_csv,
	"restore=s" => \$restore_dir,
	"purge=s" => \$purge_dir,
	"execute" => \$execute,
	"force" => \$force,
) or die("Error in command line arguments, see the documentation with: perldoc $0\n");

(get_oidc_implementation_level() >= 2)
	or die("This script assumes that Keycloak is the source of truth for users (OIDC implementation level >= 2)\n");

my $keycloak = ProductOpener::Keycloak->new();

print STDERR ($execute ? "Executing\n" : "Dry run, use --execute to apply the changes\n");

my %count = ();

# Record an action in the manifest of the batch, and print it
sub record ($manifest_fh, $type, $id, $action, $status, $detail = '') {
	my $line = join("\t", strftime("%Y-%m-%d %H:%M:%S", localtime()), $type, $id, $action, $status, $detail);
	print "$line\n";
	print $manifest_fh "$line\n" if $manifest_fh;
	$count{"$type $action $status"}++;
	return;
}

sub read_ids ($file) {
	return () if not defined $file;
	open(my $in, "<:encoding(UTF-8)", $file) or die("Could not open $file: $!\n");
	my @ids = ();
	my %seen = ();
	while (my $id = <$in>) {
		$id =~ s/\s+//g;
		next if $id eq '';
		# ids are used in file paths
		($id =~ /^[a-z0-9][a-z0-9\-]*$/) or die("Invalid id in $file: $id\n");
		push @ids, $id if not $seen{$id}++;
	}
	close($in);
	return @ids;
}

# Read the actions that were done in a batch
sub read_manifest ($dir) {
	open(my $in, "<:encoding(UTF-8)", "$dir/manifest.tsv") or die("Could not open $dir/manifest.tsv: $!\n");
	my @entries = ();
	while (<$in>) {
		chomp;
		my ($time, $type, $id, $action, $status) = split(/\t/);
		push @entries, {type => $type, id => $id, action => $action, status => $status};
	}
	close($in);
	return @entries;
}

sub open_manifest ($dir) {
	return if not $execute;
	open(my $fh, ">>:encoding(UTF-8)", "$dir/manifest.tsv") or die("Could not open $dir/manifest.tsv: $!\n");
	$fh->autoflush(1);
	return $fh;
}

sub quarantine () {
	defined $batch or die("--batch is required\n");
	($batch =~ /^[a-zA-Z0-9\-_]+$/) or die("--batch can only contain letters, digits, - and _\n");

	my @userids = read_ids($users_file);
	my @orgids = read_ids($orgs_file);
	my %userids = map {$_ => 1} @userids;
	my %orgids = map {$_ => 1} @orgids;

	my $dir = dirname($BASE_DIRS{USERS}) . "/quarantine/" . strftime("%Y-%m-%d", localtime()) . "-$batch";
	if ($execute) {
		make_path("$dir/users", "$dir/orgs", {error => \my $errors});
		(@$errors == 0) or die("Could not create $dir\n");
	}
	print STDERR "Batch directory: $dir\n";
	my $manifest_fh = open_manifest($dir);

	my $brevo_fh;
	if (defined $brevo_csv) {
		open($brevo_fh, ">:encoding(UTF-8)", $brevo_csv) or die("Could not write $brevo_csv: $!\n");
		print $brevo_fh "EMAIL\n";
	}

	my $products_collection = get_products_collection();

	foreach my $userid (@userids) {
		my $file = "$BASE_DIRS{USERS}/$userid.sto";
		my $user_ref = (-e $file) ? retrieve($file) : undef;

		my @reasons = ();
		if (defined $user_ref) {
			foreach my $field (qw(moderator pro_moderator crm_user_id)) {
				push @reasons, $field if $user_ref->{$field};
			}
			if ((defined $user_ref->{org_id}) and ($user_ref->{org_id} ne '') and (not $orgids{$user_ref->{org_id}})) {
				push @reasons, "member of org $user_ref->{org_id}";
			}
		}
		push @reasons, "admin" if is_admin_user($userid);
		push @reasons, "edited products"
			if $products_collection->count_documents({editors_tags => $userid}, {limit => 1});

		if (@reasons and not $force) {
			record($manifest_fh, "user", $userid, "quarantine", "skipped", join(", ", @reasons));
			next;
		}

		if ($brevo_fh and (defined $user_ref) and $user_ref->{newsletter}) {
			# The email is not in the user file at OIDC level 3 and above: retrieve_user() gets it from Keycloak
			my $email = $user_ref->{email} || (retrieve_user($userid) // {})->{email};
			print $brevo_fh "$email\n" if $email;
		}

		if (not $execute) {
			record($manifest_fh, "user", $userid, "quarantine", "dry-run", (defined $user_ref) ? '' : "no user file");
			next;
		}

		# Disable the account first, so that the user cannot log in and recreate a user file
		my $in_keycloak = eval {$keycloak->set_user_enabled($userid, 0)};
		if ($@) {
			record($manifest_fh, "user", $userid, "quarantine", "error", "keycloak: $@" =~ s/\s+/ /gr);
			next;
		}
		if ((defined $user_ref) and (not move($file, "$dir/users/$userid.sto"))) {
			record($manifest_fh, "user", $userid, "quarantine", "error", "could not move user file: $!");
			next;
		}
		record($manifest_fh, "user", $userid, "quarantine", "done",
			join(", ", ($in_keycloak ? () : "not in keycloak"), ((defined $user_ref) ? () : "no user file")));
	}

	my $orgs_collection = get_orgs_collection();

	foreach my $orgid (@orgids) {
		my $file = "$BASE_DIRS{ORGS}/$orgid.sto";
		if (not -e $file) {
			record($manifest_fh, "org", $orgid, "quarantine", "skipped", "no org file");
			next;
		}
		my $org_ref = retrieve($file);

		my @reasons = ();
		push @reasons, "accepted" if (($org_ref->{valid_org} // '') eq 'accepted');
		push @reasons, "crm_org_id" if $org_ref->{crm_org_id};
		foreach my $group (qw(admins members)) {
			foreach my $member (sort keys %{$org_ref->{$group} || {}}) {
				push @reasons, "$group: $member" if not $userids{$member};
			}
		}
		push @reasons, "has products"
			if $products_collection->count_documents({owners_tags => "org-$orgid"}, {limit => 1});

		if (@reasons and not $force) {
			record($manifest_fh, "org", $orgid, "quarantine", "skipped", join(", ", @reasons));
			next;
		}

		if (not $execute) {
			record($manifest_fh, "org", $orgid, "quarantine", "dry-run");
			next;
		}

		if (not move($file, "$dir/orgs/$orgid.sto")) {
			record($manifest_fh, "org", $orgid, "quarantine", "error", "could not move org file: $!");
			next;
		}
		$orgs_collection->delete_one({org_id => $orgid});
		record($manifest_fh, "org", $orgid, "quarantine", "done");
	}

	close($brevo_fh) if $brevo_fh;
	close($manifest_fh) if $manifest_fh;
	return;
}

# Users and orgs that were quarantined in the batch, and not restored or purged since
sub quarantined_entries ($dir) {
	my %state = ();
	my @order = ();
	foreach my $entry (read_manifest($dir)) {
		next if $entry->{status} ne 'done';
		my $key = "$entry->{type}\t$entry->{id}";
		push @order, $key if not exists $state{$key};
		$state{$key} = $entry;
	}
	return grep {$_->{action} eq 'quarantine'} map {$state{$_}} @order;
}

sub restore ($dir) {
	my $manifest_fh = open_manifest($dir);
	my $orgs_collection = get_orgs_collection();

	foreach my $entry (quarantined_entries($dir)) {
		my ($type, $id) = ($entry->{type}, $entry->{id});
		my $source = "$dir/${type}s/$id.sto";
		my $target = ($type eq 'user') ? "$BASE_DIRS{USERS}/$id.sto" : "$BASE_DIRS{ORGS}/$id.sto";

		if (-e $target) {
			record($manifest_fh, $type, $id, "restore", "skipped", "$target already exists");
			next;
		}
		if (not $execute) {
			record($manifest_fh, $type, $id, "restore", "dry-run");
			next;
		}
		if ((-e $source) and (not move($source, $target))) {
			record($manifest_fh, $type, $id, "restore", "error", "could not move file back: $!");
			next;
		}
		if ($type eq 'user') {
			eval {$keycloak->set_user_enabled($id, 1)};
			if ($@) {
				record($manifest_fh, $type, $id, "restore", "error", "keycloak: $@" =~ s/\s+/ /gr);
				next;
			}
		}
		else {
			my $org_ref = retrieve($target);
			$orgs_collection->replace_one({org_id => $id}, $org_ref, {upsert => 1});
		}
		record($manifest_fh, $type, $id, "restore", "done");
	}

	close($manifest_fh) if $manifest_fh;
	return;
}

sub purge ($dir) {
	my $manifest_fh = open_manifest($dir);

	foreach my $entry (quarantined_entries($dir)) {
		my ($type, $id) = ($entry->{type}, $entry->{id});

		if (not $execute) {
			record($manifest_fh, $type, $id, "purge", "dry-run");
			next;
		}
		if ($type eq 'user') {
			# Triggers a user-deleted event, and the delete_user job
			eval {$keycloak->delete_user($id)};
			if ($@) {
				record($manifest_fh, $type, $id, "purge", "error", "keycloak: $@" =~ s/\s+/ /gr);
				next;
			}
		}
		unlink("$dir/${type}s/$id.sto");
		record($manifest_fh, $type, $id, "purge", "done");
	}

	close($manifest_fh) if $manifest_fh;
	return;
}

if (defined $restore_dir) {
	restore($restore_dir);
}
elsif (defined $purge_dir) {
	purge($purge_dir);
}
else {
	quarantine();
}

print STDERR "$_: $count{$_}\n" foreach sort keys %count;
