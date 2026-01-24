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
use ProductOpener::Data qw/:all/;
use ProductOpener::Orgs qw/list_org_ids retrieve_org/;
use ProductOpener::Users qw/retrieve_user/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Checkpoint;
use ProductOpener::Checkpoint;

my $orgs_collection = get_orgs_collection();

sub main {
	my $checkpoint = ProductOpener::Checkpoint->new;
	my $last_processed_id = $checkpoint->{value};
	my $can_process = $last_processed_id ? 0 : 1;
	
	my @orgs = list_org_ids();
	my $count = scalar @orgs;
	my $num_updated = 0;
	my $num_skipped = 0;
	my $num_errors = 0;
	
	print "Starting migration of $count organizations...\n";

	foreach my $org_id (@orgs) {
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
		if (not defined $org_ref) {
			print "WARNING: Skipping org $org_id (not found or deleted)\n";
			$num_skipped++;
			$checkpoint->update($org_id);
			next;
		}

		my $creator_username = $org_ref->{creator};
		if (not defined $creator_username) {
			$num_skipped++;
			$checkpoint->update($org_id);
			next;
		}

		my $creator_user_ref = retrieve_user($creator_username);
		if (not defined $creator_user_ref) {
			print "WARNING: Creator user $creator_username not found for org $org_id\n";
			$num_skipped++;
			$checkpoint->update($org_id);
			next;
		}

		my $creator_email = $creator_user_ref->{email};
		if (not defined $creator_email) {
			$num_skipped++;
			$checkpoint->update($org_id);
			next;
		}
		
		# Check if update is needed
		if (defined $org_ref->{creator_email} && $org_ref->{creator_email} eq $creator_email) {
			$num_skipped++;
			$checkpoint->update($org_id);
			next;
		}

		$org_ref->{creator_email} = $creator_email;
		
		eval {
			# Store to file first to avoid inconsistent state
			store("$BASE_DIRS{ORGS}/" . $org_ref->{org_id} . ".sto", $org_ref);
			
			# Then update MongoDB
			my $result = $orgs_collection->update_one({"org_id" => $org_ref->{org_id}},
				{'$set' => {"creator_email" => $creator_email}});
			
			if ($result->modified_count || $result->matched_count) {
				$num_updated++;
				print "Updated organization $org_id with creator's email $creator_email\n";
			}
			else {
				print "WARNING: MongoDB update didn't match any documents for org $org_id\n";
				$num_errors++;
			}
		};
		if ($@) {
			print "ERROR: Failed to update org $org_id: $@\n";
			$num_errors++;
		}
		
		$checkpoint->update($org_id);
		
		if (($num_updated + $num_skipped + $num_errors) % 100 == 0) {
			print "Progress: $num_updated updated, $num_skipped skipped, $num_errors errors\n";
		}
	}

	print "\nMigration complete:\n";
	print "  Total organizations: $count\n";
	print "  Updated: $num_updated\n";
	print "  Skipped: $num_skipped\n";
	print "  Errors: $num_errors\n";
	return;
}

main();

exit(0);
