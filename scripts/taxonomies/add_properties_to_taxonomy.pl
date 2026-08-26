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

use Modern::Perl '2017';
use utf8;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use Getopt::Long qw/GetOptions/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

my $taxonomy_file;
my $properties_file;

GetOptions(
	"taxonomy_file=s" => \$taxonomy_file,
	"properties_file=s" => \$properties_file,
) or die("Error in command line arguments\n");

if (not defined $taxonomy_file) {
	die("missing --taxonomy_file argument\n");
}
if (not defined $properties_file) {
	die("missing --properties_file argument\n");
}

# Read properties.csv into a hash: canonical_id => [{property => value}, ...]
my %properties_to_add;

open my $fh, '<:encoding(utf8)', $properties_file or die "Cannot open $properties_file: $!";
while (my $line = <$fh>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	my ($canonical_id, $property, $value) = split /\t/, $line, 3;
	next unless defined $canonical_id && defined $property && defined $value;
	push @{$properties_to_add{$canonical_id}}, {property => $property, value => $value};
}
close $fh;

# Read taxonomy file
open $fh, '<:encoding(utf8)', $taxonomy_file or die "Cannot open $taxonomy_file: $!";
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

my $modified = 0;

foreach my $block (@blocks) {
	# Find first non-comment, non-parent line
	my $first_line;
	foreach my $line (@$block) {
		next if $line =~ /^\s*#/;
		next if $line =~ /^\s*</;
		$first_line = $line;
		last;
	}
	next unless defined $first_line;

	# Discard anything after first comma (synonyms)
	my $name = $first_line;
	$name =~ s/,.*//;

	# Extract language code and name
	my ($lc, $tag_name);
	if ($name =~ /^(\w\w):\s*(.*)/) {
		$lc = $1;
		$tag_name = $2;
	}
	else {
		next;
	}

	# Canonicalize
	my $exists = 0;
	my $canonical_id = canonicalize_taxonomy_tag($lc, "ingredients", $tag_name, \$exists);

	next unless $exists;
	next unless exists $properties_to_add{$canonical_id};

	my @props = @{$properties_to_add{$canonical_id}};

	# Remove any existing occurrences of these properties from the block
	my %props_to_add;
	foreach my $prop_entry (@props) {
		$props_to_add{$prop_entry->{property}} = $prop_entry->{value};
	}

	@$block = grep {
		my $keep = 1;
		foreach my $prop (keys %props_to_add) {
			if ($_ =~ /^\s*$prop\s*:\s*(.*)/i) {
				$keep = 0;
				last;
			}
		}
		$keep;
	} @$block;

	# Add all properties at the end of the block, below any comments
	foreach my $prop_entry (@props) {
		push @$block, "$prop_entry->{property}: $prop_entry->{value}\n";
	}

	$modified = 1;
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
	print "Taxonomy file updated.\n";
}
else {
	print "No changes made.\n";
}
