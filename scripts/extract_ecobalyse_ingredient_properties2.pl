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

# This script reads processes.json from Ecobalyse (filtered to food2 scope +
# ingredient category) and generates a TSV file of properties to add to the
# ingredients taxonomy (ingredients.txt).
#
# Unlike extract_ecobalyse_ingredient_properties.pl (v1), this script does NOT
# read existing ecobalyse properties from the taxonomy — it is fully data-driven.
# It uses canonicalize_taxonomy_tag() exclusively for tagid resolution, with an
# optional overrides file for baseIngredients that cannot be resolved.
#
# Key behavior:
# - ALL visible variant entries are emitted as non-proxy properties (e.g.,
#   ecobalyse_labels_en_organic_origins_en_france_id:en).
# - The ecobalyse_proxy_ prefix is used ONLY for the base fallback entry
#   (no label, no origin). If no None+non-organic entry exists naturally,
#   we create one by copying values from the best available entry:
#   prefer non-organic, then origin priority (None > ROF > REM > FR, France last).
# - "Origin none does not mean proxy" — None origin entries are regular variants.

use Modern::Perl '2017';
use utf8;
use JSON;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# Hardcoded paths
my $processes_file = "external-data/ecobalyse/processes.json";
my $mapping_file = "external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv";
my $overrides_file = "external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv";
my $output_file = "external-data/ecobalyse/ecobalyse_ingredient_properties.csv";

# Load base_ingredients → tagid mapping (from Script 1 output + overrides)
my %base_to_tagid;
for my $file ($mapping_file, $overrides_file) {
	next unless defined $file && -f $file;
	open my $tfh, '<:encoding(UTF-8)', $file
		or die "Cannot open $file: $!";
	while (my $line = <$tfh>) {
		chomp $line;
		next if $line =~ /^#/ || $line =~ /^\s*$/;
		my ($base, $tagid, $source) = split /\t/, $line, 3;
		$base_to_tagid{$base} = $tagid if defined $base && defined $tagid;
	}
	close $tfh;
	say STDERR "  Loaded " . scalar(keys %base_to_tagid) . " baseIngredient -> tagid mappings";
}

# Initialize taxonomies for canonicalize_taxonomy_tag fallback
init_taxonomies(0);

# Load processes.json, filter: food2 in scopes AND ingredient in categories
die "Cannot open $processes_file: $!" unless -f $processes_file;
my $raw_json;
{
	local $/;
	open my $json_fh, '<:raw', $processes_file
		or die "Cannot open $processes_file: $!";
	$raw_json = <$json_fh>;
	close $json_fh;
}
my $json = JSON->new->utf8->allow_nonref;
my $all_entries = $json->decode($raw_json);
die "processes.json is not an array" unless ref($all_entries) eq 'ARRAY';
say STDERR "Loaded " . scalar(@$all_entries) . " entries from processes.json";

# Filter: food2 in scopes AND ingredient in categories
my @filtered;
ENTRY: for my $item (@$all_entries) {
	my $scopes = $item->{scopes};
	next unless defined $scopes && ref($scopes) eq 'ARRAY';
	next unless grep { $_ eq 'food2' } @$scopes;
	my $categories = $item->{categories};
	next unless defined $categories && ref($categories) eq 'ARRAY';
	next unless grep { $_ eq 'ingredient' } @$categories;
	push @filtered, $item;
}
say STDERR "Filtered to " . scalar(@filtered) . " entries (food2 + ingredient)";

# Build tagid -> [entries] lookup from filtered entries.
# Multiple baseIngredients can canonicalize to the same tagid (e.g. chard and
# swiss-chard both resolve to en:chard), so we merge by tagid.
my %tagid_to_entries;
my $has_metadata = 0;
my $missing_metadata = 0;
my %tagid_seen_base;
for my $item (@filtered) {
	my $meta = $item->{metadata};
	if (defined $meta && exists $meta->{ingredient}) {
		$has_metadata++;
		my $base = $meta->{ingredient}{baseIngredient};
		if (defined $base) {
			my $tagid = resolve_tagid($base);
			if (defined $tagid) {
				push @{$tagid_to_entries{$tagid}}, $item;
				$tagid_seen_base{$tagid} = [] unless exists $tagid_seen_base{$tagid};
				push @{$tagid_seen_base{$tagid}}, $base;
			}
		}
	} else {
		$missing_metadata++;
	}
}
say STDERR "  Entries with metadata.ingredient: $has_metadata";
say STDERR "  Entries missing metadata.ingredient: $missing_metadata";

# DefaultOrigin priority: None (proxy) highest, then ROF, REM, FR
#   None → rest of world (out of EU/Maghreb)
#   ROF  → France d'outre-mer
#   REM  → Région - Europe et Maghreb
#   FR   → France (lowest priority, selected last)
my %default_origin_priority = (
	''     => 0,    # None/undefined
	'None' => 0,    # explicit None string
	'ROF'  => 1,    # France d'outre-mer
	'REM'  => 2,    # Région - Europe et Maghreb
	'FR'   => 3,    # France (lowest priority, selected last)
);

my @output_rows;
my @warnings;
my $global_props = 0;
my $variant_props = 0;
my $matched_tags = 0;
my $unmatched_bases = 0;

TAGID: for my $tagid (sort keys %tagid_to_entries) {
	$matched_tags++;
	my $entries_ref = $tagid_to_entries{$tagid};

	# Filter to visible entries only
	my @visible = grep { $_->{visible} // 1 } @$entries_ref;
	unless (@visible) {
		my @unique_bases = do { my %seen; grep { !$seen{$_}++ } @{$tagid_seen_base{$tagid}} };
		my $bases = join(",", @unique_bases);
		push @warnings, "No visible entries for $bases ($tagid)";
		next TAGID;
	}

	# Find the "base default" entry: None origin + non-organic (no label, no origin)
	my @base_defaults = grep { is_none_origin($_) && !is_organic($_) } @visible;

	if (@base_defaults) {
		# Natural base default exists — emit as ecobalyse_id:en (non-proxy)
		my @sorted = sort {
			($a->{metadata}{ingredient}{scenario} // '') cmp ($b->{metadata}{ingredient}{scenario} // '')
		} @base_defaults;
		emit_global_props($tagid, $sorted[0], 'ecobalyse');
		emit_variant_entry($tagid, $sorted[0], 'ecobalyse', '');
	} else {
		# No natural base default — create fallback ecobalyse_proxy_id:en
		# by copying from the best available entry (non-organic preferred, France last)
		my @non_organic = grep { !is_organic($_) } @visible;
		my @candidates = @non_organic ? @non_organic : @visible;
		my @sorted = sort {
			($default_origin_priority{$a->{metadata}{defaultOrigin} // ''} // 99)
				<=> ($default_origin_priority{$b->{metadata}{defaultOrigin} // ''} // 99)
		} @candidates;
		emit_global_props($tagid, $sorted[0], 'ecobalyse');
		emit_variant_entry($tagid, $sorted[0], 'ecobalyse_proxy', '');
	}

	# Emit all OTHER visible entries as non-proxy variants
	my %seen_variants;
	for my $entry (sort {
		($default_origin_priority{$a->{metadata}{defaultOrigin} // ''} // 99)
			<=> ($default_origin_priority{$b->{metadata}{defaultOrigin} // ''} // 99)
			|| ($b->{visible} // 1) <=> ($a->{visible} // 1)
			|| ($a->{metadata}{ingredient}{scenario} // '') cmp ($b->{metadata}{ingredient}{scenario} // '')
	} @visible) {
		my $variant_key = get_variant_key($entry);
		next if $seen_variants{$variant_key}++;
		next if $variant_key eq '';    # skip base default (already emitted above)

		# "Origin none does not mean proxy" — always use ecobalyse_ prefix
		emit_variant_entry($tagid, $entry, 'ecobalyse', $variant_key);
	}
}

# Count unmatched baseIngredients (in mapping file but no entries in tagid_to_entries)
my %tagids_used;
for my $tagid (keys %tagid_to_entries) {
	for my $base (@{$tagid_seen_base{$tagid}}) {
		$tagids_used{$base} = 1;
	}
}
for my $base (sort keys %base_to_tagid) {
	$unmatched_bases++ unless exists $tagids_used{$base};
}

# Write output
my $total_rows = scalar @output_rows;
say "Generated $total_rows property rows";
say "  Matched tagids: $matched_tags";
say "  Unmatched baseIngredients: $unmatched_bases";
say "  Global properties: $global_props";
say "  Variant properties: $variant_props";

open my $out_fh, '>:encoding(UTF-8)', $output_file
	or die "Cannot open $output_file for writing: $!";
for my $row (@output_rows) {
	print $out_fh join("\t", @$row) . "\n";
}
close $out_fh;
say "Wrote $total_rows properties to $output_file";

for my $w (@warnings) {
	say STDERR "WARNING: $w";
}

say STDERR "Processed $matched_tags tagids";

# --- Subroutines ---

sub resolve_tagid {
	my ($base) = @_;

	# Use pre-built mapping file
	if (exists $base_to_tagid{$base}) {
		return $base_to_tagid{$base};
	}

	# Fallback: canonicalize_taxonomy_tag
	my $exists = 0;
	my $tagid = canonicalize_taxonomy_tag("en", "ingredients", $base, \$exists);
	return $tagid if $exists;
	return;
}

sub get_variant_key {
	my ($entry) = @_;
	my $meta = $entry->{metadata} // {};
	my $ing = $meta->{ingredient} // {};
	my $scenario = $ing->{scenario} // '';
	my $default_origin = $meta->{defaultOrigin};
	$default_origin = '' unless defined $default_origin;

	my $suffix = '';

	# Organic scenario adds _labels_en_organic
	if ($scenario eq 'organic') {
		$suffix .= '_labels_en_organic';
	}

	# defaultOrigin determines the origin prefix component
	if ($default_origin eq 'FR') {
		$suffix .= '_origins_en_france';
	}
	elsif ($default_origin eq 'REM') {
		$suffix .= '_origins_en_europe_and_maghreb';
	}
	# ROF (France d'outre-mer) and None do not add an origin suffix

	return $suffix;
}

sub is_none_origin {
	my ($entry) = @_;
	my $meta = $entry->{metadata} // {};
	my $default_origin = $meta->{defaultOrigin};
	$default_origin = '' unless defined $default_origin;
	return ($default_origin eq '' || $default_origin eq 'None');
}

sub is_organic {
	my ($entry) = @_;
	my $meta = $entry->{metadata} // {};
	my $ing = $meta->{ingredient} // {};
	return (($ing->{scenario} // '') eq 'organic');
}

sub emit_global_props {
	my ($tagid, $entry, $prefix) = @_;
	my $meta = $entry->{metadata} // {};
	my $ing = $meta->{ingredient} // {};

	if (defined $ing->{density}) {
		push @output_rows, [$tagid, "${prefix}_density_g_per_ml:en", $ing->{density}];
		$global_props++;
	}
	if (defined $ing->{cropGroup}) {
		push @output_rows, [$tagid, "${prefix}_crop_group:en", $ing->{cropGroup}];
		$global_props++;
	}
	if (defined $ing->{rawToCookedRatio}) {
		push @output_rows, [$tagid, "${prefix}_raw_to_cooked_ratio:en", $ing->{rawToCookedRatio}];
		$global_props++;
	}
	if (defined $ing->{inediblePart}) {
		push @output_rows, [$tagid, "${prefix}_inedible_part:en", $ing->{inediblePart}];
		$global_props++;
	}

	# transportCooling derived from "transported_cooled" in categories
	# category derived from "material_type:" in categories
	my $categories = $entry->{categories};
	if (defined $categories && ref($categories) eq 'ARRAY') {
		my $transport_cooling = grep({ $_ eq 'transported_cooled' } @$categories) ? 'always' : 'none';
		push @output_rows, [$tagid, "${prefix}_transport_cooling:en", $transport_cooling];
		$global_props++;

		for my $cat (@$categories) {
			if ($cat =~ /^material_type:(.+)$/) {
				push @output_rows, [$tagid, "${prefix}_category:en", $1];
				$global_props++;
				last;
			}
		}
	}

	return;
}

sub emit_variant_entry {
	my ($tagid, $entry, $prefix, $variant_key) = @_;
	if ($variant_key ne '') {
		$prefix .= $variant_key;
	}
	my $meta = $entry->{metadata} // {};
	my $ing = $meta->{ingredient} // {};

	# ID
	push @output_rows, [$tagid, "${prefix}_id:en", $entry->{id}];
	$variant_props++;

	# Scenario
	if (defined $ing->{scenario}) {
		push @output_rows, [$tagid, "${prefix}_scenario:en", $ing->{scenario}];
		$variant_props++;
	}

	# Name (displayName)
	if (defined $entry->{displayName}) {
		push @output_rows, [$tagid, "${prefix}_name:fr", $entry->{displayName}];
		$variant_props++;
	}

	# Alias
	if (defined $entry->{alias}) {
		push @output_rows, [$tagid, "${prefix}_alias:en", $entry->{alias}];
		$variant_props++;
	}

	# Default origin
	my $default_origin = $meta->{defaultOrigin};
	$default_origin = '' unless defined $default_origin;
	push @output_rows, [$tagid, "${prefix}_default_origin:en", $default_origin];
	$variant_props++;

	return;
}
