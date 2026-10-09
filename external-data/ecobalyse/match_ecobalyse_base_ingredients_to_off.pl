#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maurice, France
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

# This script resolves Ecobalyse baseIngredient names to OFF taxonomy tagids
# using canonicalize_taxonomy_tag(). It produces a TSV mapping file and
# prints statistics to STDOUT.

use Modern::Perl '2017';
use utf8;
use JSON;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# Hardcoded paths
my $base_ingredients_file = "external-data/ecobalyse/base_ingredients.json";
my $overrides_file = "external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv";
my $output_file = "external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv";

# Load base_ingredients.json (array of strings)
die "Cannot open $base_ingredients_file: $!" unless -f $base_ingredients_file;
my $raw_json;
{
	local $/;
	open my $json_fh, '<:encoding(UTF-8)', $base_ingredients_file
		or die "Cannot open $base_ingredients_file: $!";
	$raw_json = <$json_fh>;
	close $json_fh;
}
my $json = JSON->new->utf8->allow_nonref;
my $base_ingredients = $json->decode($raw_json);
die "base_ingredients.json is not an array" unless ref($base_ingredients) eq 'ARRAY';

my $total = scalar @$base_ingredients;
say STDERR "Loaded $total base ingredients from $base_ingredients_file";

# Load overrides if available
my %overrides;
if (-f $overrides_file) {
	open my $ofh, '<:encoding(UTF-8)', $overrides_file
		or die "Cannot open $overrides_file: $!";
	while (my $line = <$ofh>) {
		chomp $line;
		next if $line =~ /^#/ || $line =~ /^\s*$/;
		my ($base, $tagid) = split /[\t ]+/, $line, 2;
		$overrides{$base} = $tagid if defined $base && defined $tagid;
	}
	close $ofh;
	say STDERR "  Loaded " . scalar(keys %overrides) . " override mappings";
}

# Initialize taxonomies for canonicalize_taxonomy_tag
init_taxonomies(0);

my @matched;
my @matched_override;
my @missing;

for my $base (sort @$base_ingredients) {
	if (exists $overrides{$base}) {
		push @matched_override, [$base, $overrides{$base}, 'override'];
		next;
	}

	my $exists = 0;
	my $tagid = canonicalize_taxonomy_tag("en", "ingredients", $base, \$exists);
	if ($exists && defined $tagid) {
		push @matched, [$base, $tagid, 'taxonomy'];
	}
	else {
		# Try reordering: move the last word to the front
		# e.g. "parsley-fresh" -> "fresh-parsley"
		my @words = split /-/, $base;
		if (@words > 1) {
			my $reordered = join("-", $words[-1], @words[0 .. $#words - 1]);
			$exists = 0;
			$tagid = canonicalize_taxonomy_tag("en", "ingredients", $reordered, \$exists);
			if ($exists && defined $tagid) {
				push @matched, [$base, $tagid, 'reordered'];
			}
			else {
				push @missing, $base;
			}
		}
		else {
			push @missing, $base;
		}
	}
}

# Write output TSV
open my $out_fh, '>:encoding(UTF-8)', $output_file
	or die "Cannot open $output_file for writing: $!";
for my $row (@matched, @matched_override) {
	print $out_fh join("\t", $row->[0], $row->[1], $row->[2]) . "\n";
}
close $out_fh;

# Print statistics to STDOUT
say "Base ingredient matching statistics";
say "  Total base ingredients: $total";
say "  Matched via taxonomy: " . scalar(@matched);
say "  Matched via overrides: " . scalar(@matched_override);
say "  Missing (unmatched): " . scalar(@missing);
say "";

if (@missing) {
	say "Missing base ingredients (no match in taxonomy or overrides):";
	for my $base (@missing) {
		say "  $base";
	}
}

# Also write a missing list file for reference
my $missing_file = "external-data/ecobalyse/base_ingredients_to_off_ingredients_missing.tsv";
open my $mfh, '>:encoding(UTF-8)', $missing_file
	or die "Cannot open $missing_file for writing: $!";
for my $base (@missing) {
	print $mfh "$base\n";
}
close $mfh;

say STDERR "Wrote "
	. scalar(@matched)
	. " taxonomy matches + "
	. scalar(@matched_override)
	. " override matches to $output_file";
