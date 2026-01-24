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

use ProductOpener::Orgs qw/:all/;
use ProductOpener::Checkpoint;

sub run_migration() {
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
		
		if (!((defined $org_ref->{protect_data}) && ($org_ref->{protect_data} eq "on"))) {
			$org_ref->{protect_data} = "on";
			eval {
				store_org($org_ref);
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
	return 1;
}

run_migration();
