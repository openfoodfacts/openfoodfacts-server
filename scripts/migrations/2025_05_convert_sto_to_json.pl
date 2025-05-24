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

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/object_iter retrieve_object store_object/;

# This script converts all product sto files to json

my ($checkpoint_file, $last_processed_path) = open_checkpoint('2025_05_convert_sto_to_json.tmp');
my $can_process = $last_processed_path ? 0 : 1;

sub open_checkpoint($filename) {
	if (!-e $filename) {
		`touch $filename`;
	}
	open(my $checkpoint_file, '+<', $filename) or die "Could not open file '$filename' $!";
	seek($checkpoint_file, 0, 0);
	my $checkpoint = <$checkpoint_file>;
	chomp $checkpoint if $checkpoint;
	my $last_processed_path;
	if ($checkpoint) {
		$last_processed_path = $checkpoint;
	}
	return ($checkpoint_file, $last_processed_path);
}

sub update_checkpoint($checkpoint_file, $dir) {
	seek($checkpoint_file, 0, 0);
	print $checkpoint_file $dir;
	truncate($checkpoint_file, tell($checkpoint_file));
	return 1;
}

my $count = 0;
my $next = object_iter($BASE_DIRS{PRODUCTS});
while (my $path = $next->()) {
	if (not $can_process) {
		if ($path eq $last_processed_path) {
			$can_process = 1;
			print "Resuming from '$last_processed_path'\n";
		}
		next;    # we don't want to process the product again
	}
	# print "$path\n";
	store_object($path, retrieve_object($path));
	$count++;
	if ($count % 1000 == 0) {
		print "Updated $count files.\n";
		update_checkpoint($checkpoint_file, $path);
	}

	update_checkpoint($checkpoint_file, $path);
}
print "Updated $count files.\n";

close $checkpoint_file;
