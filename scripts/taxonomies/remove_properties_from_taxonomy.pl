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

# This script removes all properties with a given prefix from a taxonomy file.
# For example, to remove all ecobalyse properties from ingredients.txt:
#   perl scripts/taxonomies/remove_properties_from_taxonomy.pl \
#     --taxonomy_file taxonomies/food/ingredients.txt \
#     --property_prefix ecobalyse_

use Modern::Perl '2017';
use utf8;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use Getopt::Long qw/GetOptions/;

my $taxonomy_file;
my $property_prefix;

GetOptions(
	"taxonomy_file=s"   => \$taxonomy_file,
	"property_prefix=s" => \$property_prefix,
) or die("Error in command line arguments\n");

if (not defined $taxonomy_file) {
	die("missing --taxonomy_file argument\n");
}
if (not defined $property_prefix) {
	die("missing --property_prefix argument\n");
}

# Read taxonomy file
open my $fh, '<:encoding(utf8)', $taxonomy_file or die "Cannot open $taxonomy_file: $!";
my @lines = <$fh>;
close $fh;

# Split into blocks separated by blank lines
my @blocks;
my $current_block = [];
foreach my $line (@lines) {
	if ($line =~ /^\s*$/) {
		if (@$current_block) {
			push @blocks, $current_block;
			$current_block = [];
		}
	}
	else {
		push @$current_block, $line;
	}
}
push @blocks, $current_block if @$current_block;

my $removed_count = 0;
my $modified = 0;

foreach my $block (@blocks) {
	my $block_modified = 0;
	@$block = grep {
		my $keep = 1;
		# Property lines have format "key:lang: value" at start of line
		if ($_ =~ /^(?:${property_prefix})/) {
			$keep = 0;
			$block_modified = 1;
			$removed_count++;
		}
		$keep;
	} @$block;
	if ($block_modified) {
		$modified = 1;
		# Remove trailing whitespace-only lines in the block
		while (@$block && $block->[-1] =~ /^\s*$/) {
			pop @$block;
		}
	}
}

# Write back if modified
if ($modified) {
	open $fh, '>:encoding(utf8)', $taxonomy_file or die "Cannot open $taxonomy_file for writing: $!";
	foreach my $block (@blocks) {
		foreach my $line (@$block) {
			print $fh $line;
		}
		print $fh "\n";
	}
	close $fh;
	print "Removed $removed_count $property_prefix* properties from $taxonomy_file\n";
}
else {
	print "No $property_prefix* properties found to remove.\n";
}
