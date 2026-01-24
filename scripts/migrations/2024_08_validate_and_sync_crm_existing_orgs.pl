#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;
use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw( $data_root );
use ProductOpener::Paths qw( %BASE_DIRS );
use ProductOpener::Users qw( $User_id retrieve_user );
use ProductOpener::Orgs qw( list_org_ids retrieve_org store_org send_rejection_email);
use ProductOpener::CRM qw( init_crm_data sync_org_with_crm );
use ProductOpener::Store qw( retrieve store );
use ProductOpener::Data qw( :all );
use ProductOpener::Checkpoint;
use Log::Any::Adapter 'TAP';
use Encode;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

init_crm_data();

# This file is used to:
# Set the validation status of existing orgs to 'accepted' for the ones in the list, and sync with the CRM.
# Reject all the others and send a rejection email notification to them.
# Set the org name if it is missing.

# Set Manon as the salesperson for the orgs
$User_id = 'manoncorneille';
# the date the dump was made to review the orgs manually
my $dump_t = 1721061880;    # 2024-07-15 16:40:00

# read the list of orgs to sync, one per line (stdin or file)
my %orgs_to_accept = map {chomp; $_ => 1} <>;

# load checkpoint. Add a "resume" argument to resume from the last checkpoint
my $checkpoint = ProductOpener::Checkpoint->new;
my $last_org_processed = $checkpoint->{value};
my $can_process = $last_org_processed ? 0 : 1;

my $num_accepted = 0;
my $num_rejected = 0;
my $num_skipped = 0;
my $num_errors = 0;
my @org_ids = sort(list_org_ids());
my $total = scalar @org_ids;

print "Starting migration of $total organizations...\n";

foreach my $org_id (@org_ids) {
	my $decoded_org_id = decode utf8 => $org_id;
	
	# Resume logic with string comparison
	if (not $can_process) {
		if ($decoded_org_id eq $last_org_processed) {
			$can_process = 1;
			# Don't skip - re-process the last item in case it failed
		}
		else {
			next;    # Skip items before the checkpoint
		}
	}

	$org_id = $decoded_org_id;
	my $org_ref = retrieve_org($org_id);
	
	if (!defined $org_ref) {
		print "ERROR: Failed to retrieve org: $org_id\n";
		$num_errors++;
		$checkpoint->update($org_id);
		next;
	}

	if ($org_ref->{created_t} > $dump_t) {
		$num_skipped++;
		$checkpoint->update($org_id);
		next;
	}

	my $org_name = $org_ref->{name};
	if (not $org_name) {
		$org_ref->{name} = $org_id =~ s/-/ /gr;
	}

	if (not exists $org_ref->{country} and exists $org_ref->{main_contact}) {
		my $user_ref = retrieve_user($org_ref->{main_contact});
		if (defined $user_ref) {
			$org_ref->{country} = $user_ref->{country} || 'en:world';
		}
		else {
			$org_ref->{country} = 'en:world';
		}
	}

	my $org_is_valid = exists $orgs_to_accept{$org_id};
	if ($org_is_valid) {
		$org_ref->{valid_org} = 'accepted';
		eval {
			sync_org_with_crm($org_ref, $User_id);
			print "$org_id synced\n";
			$num_accepted++;
		};
		if ($@) {
			print "ERROR: Failed to sync org $org_id with CRM: $@\n";
			$num_errors++;
		}
	}
	elsif ($org_ref->{valid_org} ne 'rejected' and $org_ref->{valid_org} ne 'accepted') {
		$org_ref->{valid_org} = 'rejected';
		eval {
			send_rejection_email($org_ref);
			print "$org_id rejected\n";
			$num_rejected++;
		};
		if ($@) {
			print "ERROR: Failed to send rejection email for org $org_id: $@\n";
			$num_errors++;
		}
	}
	else {
		$num_skipped++;
	}

	eval {
		# Store to file first
		store("$BASE_DIRS{ORGS}/" . $org_ref->{org_id} . ".sto", $org_ref);
		
		# Then update MongoDB
		my $orgs_collection = get_orgs_collection();
		$orgs_collection->replace_one({"org_id" => $org_ref->{org_id}}, $org_ref, {upsert => 1});
	};
	if ($@) {
		print "ERROR: Failed to store org $org_id: $@\n";
		$num_errors++;
	}

	$checkpoint->update($org_id);
	
	if (($num_accepted + $num_rejected + $num_skipped + $num_errors) % 100 == 0) {
		print "Progress: $num_accepted accepted, $num_rejected rejected, $num_skipped skipped, $num_errors errors\n";
	}
}

print "\nMigration complete:\n";
print "  Total organizations: $total\n";
print "  Accepted: $num_accepted\n";
print "  Rejected: $num_rejected\n";
print "  Skipped: $num_skipped\n";
print "  Errors: $num_errors\n";
