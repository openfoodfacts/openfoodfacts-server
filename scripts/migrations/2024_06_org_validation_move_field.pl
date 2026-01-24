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

use Modern::Perl '2017';
use utf8;

# This file is used
# - to change the old valid_org (''/on) field
#   into a field that can have one of these 3 states: unreviewed, accepted, rejected
# - to add a main_contact field if it does not exist
# - to add a crm_opportunity_id field if it does not exist

use ProductOpener::Store qw/store/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Checkpoint;

my $checkpoint = ProductOpener::Checkpoint->new;
my $last_processed_id = $checkpoint->{value};
my $can_process = $last_processed_id ? 0 : 1;

my $num_migrated = 0;
my $num_skipped = 0;
my $num_errors = 0;
my @org_ids = list_org_ids();

print("Starting migration of " . scalar(@org_ids) . " organizations...\n");

foreach my $org_id (@org_ids) {
	# Resume logic
	if (not $can_process) {
		if ($org_id eq $last_processed_id) {
			$can_process = 1;
			# Don't skip - re-process the last item in case it failed
		}
		else {
			next;    # Skip items before the checkpoint
		}
	}
	
	my $org_ref = retrieve_org($org_id);
	if (!defined $org_ref) {
		print("ERROR: Failed to retrieve org: $org_id\n");
		$num_errors++;
		$checkpoint->update($org_id);
		next;
	}
	
	my $needs_update = 0;
	
	# Migrate valid_org field
	if (exists $org_ref->{valid_org}) {
		if ($org_ref->{valid_org} eq 'on') {
			$org_ref->{valid_org} = 'accepted';
			$needs_update = 1;
		}
		elsif ($org_ref->{valid_org} eq '' || !$org_ref->{valid_org}) {
			$org_ref->{valid_org} = 'unreviewed';
			$needs_update = 1;
		}
		# Handle other unexpected values
		elsif ($org_ref->{valid_org} ne 'accepted' && $org_ref->{valid_org} ne 'rejected' && $org_ref->{valid_org} ne 'unreviewed') {
			print("WARNING: Unexpected valid_org value '$org_ref->{valid_org}' for org $org_id, setting to unreviewed\n");
			$org_ref->{valid_org} = 'unreviewed';
			$needs_update = 1;
		}
	}
	else {
		# Field doesn't exist, default to unreviewed
		$org_ref->{valid_org} = 'unreviewed';
		$needs_update = 1;
	}
	
	# Add main_contact field if missing
	if (not exists $org_ref->{main_contact}) {
		if (exists $org_ref->{creator} && defined $org_ref->{creator}) {
			$org_ref->{main_contact} = $org_ref->{creator};
		}
		else {
			$org_ref->{main_contact} = '';
		}
		$needs_update = 1;
	}
	
	# Add crm_opportunity_id field if missing
	if (not exists $org_ref->{crm_opportunity_id}) {
		$org_ref->{crm_opportunity_id} = '';
		$needs_update = 1;
	}
	
	if ($needs_update) {
		eval {
			# not using store_org to avoid triggering the odoo sync
			store("$BASE_DIRS{ORGS}/" . $org_ref->{org_id} . ".sto", $org_ref);
			$num_migrated++;
			print("Migrated org: $org_id\n");
		};
		if ($@) {
			print("ERROR: Failed to store org: $org_id - $@\n");
			$num_errors++;
		}
	}
	else {
		$num_skipped++;
	}
	
	$checkpoint->update($org_id);
	
	if (($num_migrated + $num_skipped + $num_errors) % 100 == 0) {
		print("Progress: $num_migrated migrated, $num_skipped skipped, $num_errors errors\n");
	}
}

print("\nMigration complete:\n");
print("  Migrated: $num_migrated\n");
print("  Skipped: $num_skipped\n");
print("  Errors: $num_errors\n");

