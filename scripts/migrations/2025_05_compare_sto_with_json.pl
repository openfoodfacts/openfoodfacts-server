#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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
use utf8;

use Test2::Compare qw/compare convert/;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/object_iter retrieve_config retrieve/;
use ProductOpener::Checkpoint;

# This script compares any JSON documents with the corresponding STO file
# Will be used during the transition to check all is being kept in sync
$ENV{TS_MAX_DELTA} = 10;

my $checkpoint = ProductOpener::Checkpoint->new;
my $last_processed_path = $checkpoint->{value};
my $can_process = $last_processed_path ? 0 : 1;

sub remove_extension($path) {
	return substr $path, 0, rindex($path, '.');
}

my $count = 0;
my $json_count = 0;

# Note intentionally use object_iter here rather than product_iter so we get all excluded paths too
my $next = object_iter($BASE_DIRS{PRODUCTS});
while (my $path = $next->()) {
	$count++;
	if ($count % 1000 == 0) {
		print STDERR '.';
	}
	if (not $can_process) {
		if ($path eq $last_processed_path) {
			$can_process = 1;
		}
		next;    # we don't want to process the product again
	}
	next if ($path =~ /.*scans$/);    # We expect scans to not have an STO file

	my $json_path = "$path.json";
	my $sto_path = "$path.sto";
	if (-e $json_path) {
		# First, see if there is a corresponding sto file
		$json_count++;
		if (!-e $sto_path) {
			print STDERR "\n$path: JSON file found without STO file";
			next;
		}
		# If files are symlinks then just check they are pointing to the same file
		if (-l $json_path) {
			if (!-l $sto_path) {
				print STDERR "\n$path: JSON is a symlink but STO is not";
			}
			else {
				my $json_link = readlink($json_path);
				my $sto_link = readlink($sto_path);
				if (remove_extension($json_link) ne remove_extension($sto_link)) {
					print STDERR "\n$path: JSON symlink points to $json_link but STO points to $sto_link";
				}
			}
			next;
		}
		if (-l $sto_path) {
			print STDERR "\n$path: STO is a symlink but JSON is not";
			next;
		}

		# Retrieve config will always use the JSON file as a preference, irrespective of the SERIALIZE_TO_JSON flag
		my $json_ref = retrieve_config($path);
		my $sto_ref = retrieve($sto_path);
		my $delta = compare($sto_ref, $json_ref, \&convert);
		if ($delta) {
			print STDERR "\n$path: JSON file is different from STO file:\n" . $delta->diag()->as_string();
		}
	}
	# Update checkpoint only after all processing for this path has completed
	$checkpoint->update($path);
}
print STDERR "\nChecked $json_count files out of $count.\n";
