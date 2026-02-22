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
use ProductOpener::Checkpoint;

# This script converts all product sto files to json depending on the SERIALIZE_TO_JSON environment variable
# If we are at level 1 then both files will exist afterwards. At level 2 the STO file will be deleted
# If the STO file has been deleted running at level 0 or 1 will re-create the STO file from the JSON file

# Add a "resume" argument to resume from the last checkpoint
my $checkpoint = ProductOpener::Checkpoint->new;
my $last_processed_path = $checkpoint->{value};

my $count = 0;
# Note intentionally use object_iter here rather than product_iter so we get all excluded paths too
my $next = object_iter($BASE_DIRS{PRODUCTS}, undef, undef, $last_processed_path);
while (my $path = $next->()) {
	if ($path eq $last_processed_path) {
		next;    # we don't want to process the product again
	}
	next if ($path =~ /.*scans$/);    # We expect scans to not have an STO file
									  # print "$path\n";

	store_object($path, retrieve_object($path));

	# Sleep for a bit so we don't overwhelm the server
	select(undef, undef, undef, 0.002);
	$count++;
	if ($count % 1000 == 0) {
		$checkpoint->log("Updated $count files. Just did $path");
	}

	# Update checkpoint only after successful processing
	$checkpoint->update($path);
}

$checkpoint->log("Updated $count files.");
