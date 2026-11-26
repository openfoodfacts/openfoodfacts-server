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

use ProductOpener::PerlStandards;
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

# Qualifiers in baseIngredient names that we can remove to find a matching OFF ingredient.
#
# Neutral qualifiers do not change the ingredient: if the baseIngredient has no direct match,
# the OFF ingredient without the qualifiers is a direct match (e.g. dill-fresh -> en:dill,
# millet-whole -> en:millet, pea-shelled-raw -> en:pea), unless the OFF ingredient already
# has a direct match from another baseIngredient (e.g. comte-aop and comte-cheese -> en:comte).
# "in-shell" is not a neutral qualifier: the shell is an inedible part that changes the mass.
#
# Transforming qualifiers change the ingredient (e.g. mass, processing): the baseIngredient is
# a proxy for the OFF ingredient without the qualifiers (e.g. onion-dried -> en:onion,
# refined-peanut-oil -> en:peanut-oil, red-berries-frozen-raw -> en:red-berries).
# This applies even if the baseIngredient matched directly (e.g. "dried-apple" may match
# "en:dried-apple", but we also want a proxy on "en:apple").
#
# Multi-word qualifiers are listed before the single-word qualifiers they contain.
my @neutral_qualifiers = qw(
	with-skin
	fresh raw whole shelled husked dehusked cut uncooked aop
);
my @transforming_qualifiers = qw(
	dried dehydrated frozen refined cooked canned drained
);

# Remove qualifiers from a baseIngredient name.
# Returns the name without the qualifiers, and whether a transforming qualifier was removed.
# Returns undef if no qualifier was found or if nothing is left.
sub remove_qualifiers {
	my ($base) = @_;
	my $name = $base;
	my $found = 0;
	my $transforming = 0;
	for my $qualifier (@neutral_qualifiers, @transforming_qualifiers) {
		my $is_transforming = grep {$_ eq $qualifier} @transforming_qualifiers;
		while ($name =~ s/(^|-)\Q$qualifier\E(-|$)/$1 && $2 ? '-' : ''/e) {
			$found = 1;
			$transforming = 1 if $is_transforming;
		}
	}
	return if not $found or $name eq '';
	return ($name, $transforming);
}

my @matched;
my @matched_override;
my @unmatched;
my @qualifier_match_candidates;    # [baseIngredient, tagid, source]
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

	# Try removing qualifiers (see @neutral_qualifiers and @transforming_qualifiers above)
	my ($without_qualifiers, $transforming) = remove_qualifiers($base);
	if (defined $without_qualifiers) {
		$exists = 0;
		$tagid = canonicalize_taxonomy_tag("en", "ingredients", $without_qualifiers, \$exists);
		if ($exists && defined $tagid && (!defined $matched_tagid || $tagid ne $matched_tagid)) {
			if ($transforming) {
				# Candidates are filtered after the loop, once all direct matches are known
				push @auto_proxy_candidates, [$tagid, $base];
			}
			elsif (!defined $matched_tagid) {
				# Candidates are filtered after the loop, once all direct matches are known
				push @qualifier_match_candidates, [$base, $tagid, 'qualifiers'];
			}
		}
	}

	# "-cheese" suffix: e.g. beaufort-cheese -> en:beaufort
	# Only if the OFF ingredient is a cheese (e.g. not goat-cheese -> en:goat)
	if (   !defined $matched_tagid
		&& !(@qualifier_match_candidates && $qualifier_match_candidates[-1][0] eq $base)
		&& $base =~ /^(.+)-cheese$/)
	{
		$exists = 0;
		$tagid = canonicalize_taxonomy_tag("en", "ingredients", $1, \$exists);
		if ($exists && defined $tagid && is_a("ingredients", $tagid, "en:cheese")) {
			push @qualifier_match_candidates, [$base, $tagid, 'cheese'];
		}
	}

	push @unmatched, $base unless defined $matched_tagid;
}

# Filter qualifier match candidates: skip OFF tagids that already have a direct match
# from another baseIngredient (taxonomy, reordered or override), or from another qualifier match.
# Merging several baseIngredients in one OFF tagid would change its default entry.
my %directly_matched_tagids = map {$_->[1] => $_->[0]} (@matched, @matched_override);
my %matched_by_qualifiers;
for my $candidate (@qualifier_match_candidates) {
	my ($base, $tagid, $source) = @$candidate;
	if (exists $directly_matched_tagids{$tagid}) {
		say STDERR "  Skipping $source match $base -> $tagid (already matched by $directly_matched_tagids{$tagid})";
		next;
	}
	push @matched, $candidate;
	$directly_matched_tagids{$tagid} = $base;
	$matched_by_qualifiers{$base} = 1;
}
@unmatched = grep {!$matched_by_qualifiers{$_}} @unmatched;

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
		my ($target_tagid) = split /[\t ]+/, $line;
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
for my $source (qw(taxonomy reordered qualifiers cheese)) {
	say "    $source: " . scalar(grep {$_->[2] eq $source} @matched);
}
say "  Matched via overrides: " . scalar(@matched_override);
say "  Auto proxies (transforming qualifiers): " . scalar(@auto_proxies);
say "  Missing (unmatched): " . scalar(@missing);
say "";

if (@missing) {
	say "Missing base ingredients (no match in taxonomy or overrides):";
	for my $base (@missing) {
		say "  $base";
	}
}

# Write auto-generated proxies (transforming qualifiers) to a separate file
my $auto_proxies_file = "external-data/ecobalyse/base_ingredients_auto_proxies.tsv";
open my $apfh, '>:encoding(UTF-8)', $auto_proxies_file
	or die "Cannot open $auto_proxies_file for writing: $!";
print $apfh
	"# Auto-generated proxy mappings: baseIngredient with transforming qualifiers (e.g. dried, frozen, refined)\n";
print $apfh "# -> OFF tagid without the qualifiers\n";
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
