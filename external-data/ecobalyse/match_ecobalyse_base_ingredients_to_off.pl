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
my $proxies_file = "external-data/ecobalyse/base_ingredients_proxies_for_off_ingredients.tsv";

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
my @unmatched;
my @auto_proxy_candidates;    # [target_tagid, source_baseIngredient]
my @auto_proxies;    # [target_tagid, source_baseIngredient]

for my $base (sort @$base_ingredients) {
	if (exists $overrides{$base}) {
		push @matched_override, [$base, $overrides{$base}, 'override'];
		next;
	}

	my $matched_tagid;

	my $exists = 0;
	my $tagid = canonicalize_taxonomy_tag("en", "ingredients", $base, \$exists);
	if ($exists && defined $tagid) {
		push @matched, [$base, $tagid, 'taxonomy'];
		$matched_tagid = $tagid;
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
				$matched_tagid = $tagid;
			}
		}
	}

	# For dried baseIngredients, also add a proxy on the non-dried OFF ingredient.
	# This applies even if the dried ingredient matched directly (e.g. "dried-apple"
	# may match "en:dried-apple", but we also want a proxy on "en:apple").
	my $non_dried;
	if ($base =~ /^(.+)-dried$/) {
		$non_dried = $1;
	}
	elsif ($base =~ /^dried-(.+)$/) {
		$non_dried = $1;
	}

	# Candidates are filtered after the loop, once all direct matches are known
	if (defined $non_dried && $non_dried ne '') {
		$exists = 0;
		$tagid = canonicalize_taxonomy_tag("en", "ingredients", $non_dried, \$exists);
		if ($exists && defined $tagid && (!defined $matched_tagid || $tagid ne $matched_tagid)) {
			push @auto_proxy_candidates, [$tagid, $base];
		}
	}

	push @unmatched, $base unless defined $matched_tagid;
}

# Filter auto proxy candidates:
# - skip OFF tagids that already have an exact Ecobalyse match (taxonomy, reordered or override)
#   e.g. Ecobalyse has both onion and onion-dried: en:onion does not need a proxy
# - skip OFF tagids that already have a manual proxy
# - keep only one proxy per OFF tagid
my %tagid_has_ecobalyse_data;
$tagid_has_ecobalyse_data{$_->[1]} = 'match' for (@matched, @matched_override);
if (-f $proxies_file) {
	open my $pfh, '<:encoding(UTF-8)', $proxies_file
		or die "Cannot open $proxies_file: $!";
	while (my $line = <$pfh>) {
		chomp $line;
		next if $line =~ /^#/ || $line =~ /^\s*$/;
		my ($target_tagid) = split /\t/, $line;
		$tagid_has_ecobalyse_data{$target_tagid} //= 'manual proxy' if defined $target_tagid;
	}
	close $pfh;
}

my %proxied_bases;
for my $candidate (@auto_proxy_candidates) {
	my ($tagid, $base) = @$candidate;
	if (exists $tagid_has_ecobalyse_data{$tagid}) {
		say STDERR "  Skipping auto proxy $base -> $tagid (already has $tagid_has_ecobalyse_data{$tagid})";
		next;
	}
	push @auto_proxies, $candidate;
	$tagid_has_ecobalyse_data{$tagid} = "auto proxy $base";
	$proxied_bases{$base} = 1;
}

my @missing = grep {!$proxied_bases{$_}} @unmatched;

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
say "  Dried -> non-dried proxies: " . scalar(@auto_proxies);
say "  Missing (unmatched): " . scalar(@missing);
say "";

if (@missing) {
	say "Missing base ingredients (no match in taxonomy or overrides):";
	for my $base (@missing) {
		say "  $base";
	}
}

# Write auto-generated proxies (dried -> non-dried) to a separate file
my $auto_proxies_file = "external-data/ecobalyse/base_ingredients_auto_proxies.tsv";
open my $apfh, '>:encoding(UTF-8)', $auto_proxies_file
	or die "Cannot open $auto_proxies_file for writing: $!";
print $apfh "# Auto-generated proxy mappings: dried baseIngredient -> non-dried OFF tagid\n";
print $apfh "# Generated by match_ecobalyse_base_ingredients_to_off.pl\n";
print $apfh "# Format: target_tagid<TAB>source_baseIngredient\n";
for my $row (@auto_proxies) {
	print $apfh join("\t", @$row) . "\n";
}
close $apfh;

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
	. " override matches + "
	. scalar(@auto_proxies)
	. " auto proxies to $output_file and $auto_proxies_file";
