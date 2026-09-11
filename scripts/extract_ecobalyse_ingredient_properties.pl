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

# This script reads ingredients.json from Ecobalyse and generates a TSV file
# of properties to add to the ingredients taxonomy (ingredients.txt).
#
# Property naming convention:
# - UUID properties: ecobalyse_id:en (default), ecobalyse_id_labels_en_organic:en, etc.
# - Global scalar properties: ecobalyse_density_g_per_ml:en, ecobalyse_crop_group:en, etc.
# - Variant-specific scalar properties: ecobalyse_id_name:fr, ecobalyse_id_labels_en_organic_name:fr, etc.
#
# Default entry selection uses defaultOrigin priority:
#   OutOfEuropeAndMaghrebByPlane -> OutOfEuropeAndMaghreb -> France -> EuropeAndMaghreb -> FranceOutreMer
# The 'location' field is LCA data source provenance only and is NOT used for variant selection.

use Modern::Perl '2017';
use utf8;
use JSON;
use Getopt::Long qw/GetOptions/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $ecobalyse_json_file;
my $output_file;
my $dry_run = 0;
my $tagids_file;

GetOptions(
    "input=s"       => \$ecobalyse_json_file,
    "output=s"      => \$output_file,
    "dry-run"       => \$dry_run,
    "tagids-file=s" => \$tagids_file,
) or die("Error in command line arguments\n");

die("missing --output argument\n") unless defined $output_file;

$ecobalyse_json_file //= "$BASE_DIRS{TAXONOMIES_SRC}/../external-data/ecobalyse/ingredients.json";
unless (defined $ecobalyse_json_file && -f $ecobalyse_json_file) {
    $ecobalyse_json_file = "/opt/product-opener/external-data/ecobalyse/ingredients.json";
}

$tagids_file //= "/tmp/kilo/base_ingredient_tagids.tsv";

if (defined $tagids_file && -f $tagids_file) {
    say STDERR "Using pre-built tagid mapping from $tagids_file";
}

# Read ingredients.json
open my $json_fh, '<:raw', $ecobalyse_json_file
    or die "Cannot open $ecobalyse_json_file: $!";
my $raw_json;
{
    local $/;
    $raw_json = <$json_fh>;
}
close $json_fh;

my $json = JSON->new->utf8->allow_nonref;
my $entries = $json->decode($raw_json);

say STDERR "Loaded " . scalar(@$entries) . " entries from ingredients.json";

# Build lookups
my %id_to_entry;        # UUID -> entry
my %alias_to_entry;     # alias -> entry
my %base_to_entries;    # baseIngredient -> [entries]
for my $item (@$entries) {
    $id_to_entry{$item->{id}} = $item;
    $alias_to_entry{$item->{alias}} = $item;
    push @{$base_to_entries{$item->{baseIngredient}}}, $item;
}

say STDERR "  Unique UUIDs: " . scalar(keys %id_to_entry);
say STDERR "  Unique aliases: " . scalar(keys %alias_to_entry);
say STDERR "  Unique baseIngredients: " . scalar(keys %base_to_entries);

# Load pre-built tagid mapping if available
my %base_to_tagid;
if (defined $tagids_file && -f $tagids_file) {
    open my $tfh, '<:encoding(UTF-8)', $tagids_file
        or die "Cannot open $tagids_file: $!";
    while (my $line = <$tfh>) {
        chomp $line;
        my ($base, $tagid) = split /\t/, $line, 2;
        $base_to_tagid{$base} = $tagid if defined $base && defined $tagid;
    }
    close $tfh;
    say STDERR "  Loaded " . scalar(keys %base_to_tagid) . " baseIngredient -> tagid mappings";
}

# Initialize taxonomies for canonicalization fallback (cache may not be built)
my $use_taxonomy_cache = 0;
eval {
    init_taxonomies(0);
    $use_taxonomy_cache = 1;
};
say STDERR "  Taxonomy cache: " . ($use_taxonomy_cache ? "available" : "not available (using pre-built mapping)") if $use_taxonomy_cache;

# UUID properties in internal format (no trailing colon)
my @uuid_props_list = (
    'ecobalyse_id:en',
    'ecobalyse_id_labels_en_organic:en',
    'ecobalyse_id_origins_en_france:en',
    'ecobalyse_id_origins_en_european_union:en',
    'ecobalyse_id_labels_en_organic_origins_en_france:en',
    'ecobalyse_id_labels_en_organic_origins_en_european_union:en',
    'ecobalyse_id_proxy:en',
    'ecobalyse_id_proxy_labels_en_organic:en',
);

# DefaultOrigin priority ranking (lower = higher priority)
my %default_origin_priority = (
    'OutOfEuropeAndMaghrebByPlane' => 0,
    'OutOfEuropeAndMaghreb'        => 1,
    'France'                       => 2,
    'EuropeAndMaghreb'             => 3,
    'FranceOutreMer'               => 4,
);

my %matched_tagids;     # baseIngredient -> canonical_tagid
my %seen_tagids;        # canonical_tagid -> 1 (skip if already processed)
my %existing_uuids;     # canonical_tagid -> {prefix => value}
my @output_rows;
my @warnings;
my $alias_upgrades = 0;
my $variant_props = 0;
my $global_props = 0;

BASE: for my $base (sort keys %base_to_entries) {
    my $canonical_id = resolve_tagid($base);
    next unless defined $canonical_id;

    $matched_tagids{$base} = $canonical_id;
    next if $seen_tagids{$canonical_id}++;

    my %uuid_props;
    for my $prop (@uuid_props_list) {
        my $val = get_property("ingredients", $canonical_id, $prop);
        if (defined $val) {
            $uuid_props{$prop} = $val;
        }
    }

    my $has_ecobalyse = 0;

    for my $prop (sort keys %uuid_props) {
        my $val = $uuid_props{$prop};
        next unless defined $val;

        # Determine prefix for variant-specific properties
        my $prefix = $prop;
        $prefix =~ s/:en$//;  # e.g. "ecobalyse_id", "ecobalyse_id_labels_en_organic", etc.

        my $entry;
        if ($val =~ /^[0-9a-f-]{36}$/ && exists $id_to_entry{$val}) {
            $entry = $id_to_entry{$val};
            $has_ecobalyse = 1;
        }
        elsif (exists $alias_to_entry{$val}) {
            $entry = $alias_to_entry{$val};
            $has_ecobalyse = 1;
            # Emit UUID upgrade
            push @output_rows, [$canonical_id, $prop, $entry->{id}];
            $alias_upgrades++;
        }
        else {
            push @warnings, "Stale UUID or unknown alias in $prop for $base ($canonical_id): $val";
            next;
        }

        # Emit variant-specific properties
        emit_variant_props($canonical_id, $prefix, $entry);
    }

    # Emit global properties from the default entry
    my $default_entry;
    if (exists $uuid_props{'ecobalyse_id:en'}) {
        my $val = $uuid_props{'ecobalyse_id:en'};
        if ($val =~ /^[0-9a-f-]{36}$/ && exists $id_to_entry{$val}) {
            $default_entry = $id_to_entry{$val};
        }
        elsif (exists $alias_to_entry{$val}) {
            $default_entry = $alias_to_entry{$val};
        }
    }

    if (defined $default_entry) {
        emit_global_props($canonical_id, $default_entry);
    }
    elsif (scalar(keys %uuid_props) == 0) {
        # No ecobalyse properties exist at all — select a default entry by defaultOrigin priority
        $default_entry = select_default_entry($base_to_entries{$base});
        if (defined $default_entry) {
            push @output_rows, [$canonical_id, 'ecobalyse_id:en', $default_entry->{id}];
            emit_global_props($canonical_id, $default_entry);

            # Emit variant-specific properties for other visible variants
            emit_new_variants($canonical_id, $base_to_entries{$base}, $default_entry);
        }
        else {
            push @warnings, "No visible entries found for $base";
        }
    }
}

# Write output
my $total_rows = scalar @output_rows;
say "Generated $total_rows property rows";
say "  Alias upgrades: $alias_upgrades";
say "  Variant-specific properties: $variant_props";
say "  Global properties: $global_props";

if ($dry_run) {
    say "Dry run — not writing to file";
    for my $row (@output_rows) {
        say join("\t", @$row);
    }
}
else {
    open my $out_fh, '>:encoding(utf8)', $output_file
        or die "Cannot open $output_file for writing: $!";
    for my $row (@output_rows) {
        print $out_fh join("\t", @$row) . "\n";
    }
    close $out_fh;
    say "Wrote $total_rows properties to $output_file";
}

for my $w (@warnings) {
    say STDERR "WARNING: $w";
}

say STDERR "Matched " . scalar(keys %matched_tagids) . " baseIngredients to taxonomy tagids";

# --- Subroutines ---

sub resolve_tagid {
    my ($base) = @_;

    # Try pre-built mapping first
    if (exists $base_to_tagid{$base}) {
        return $base_to_tagid{$base};
    }

    # Fall back to taxonomy canonicalization
    if ($use_taxonomy_cache) {
        my $exists = 0;
        my $canonical_id = canonicalize_taxonomy_tag("en", "ingredients", $base, \$exists);
        return $canonical_id if $exists;
    }

    return undef;
}

sub emit_global_props {
    my ($tagid, $entry) = @_;

    if (defined $entry->{density}) {
        push @output_rows, [$tagid, 'ecobalyse_density_g_per_ml:en', $entry->{density}];
        $global_props++;
    }
    if (defined $entry->{cropGroup}) {
        push @output_rows, [$tagid, 'ecobalyse_crop_group:en', $entry->{cropGroup}];
        $global_props++;
    }
    if (defined $entry->{categories} && ref($entry->{categories}) eq 'ARRAY' && @{$entry->{categories}}) {
        push @output_rows, [$tagid, 'ecobalyse_category:en', $entry->{categories}[0]];
        $global_props++;
    }
    if (defined $entry->{rawToCookedRatio}) {
        push @output_rows, [$tagid, 'ecobalyse_raw_to_cooked_ratio:en', $entry->{rawToCookedRatio}];
        $global_props++;
    }
    if (defined $entry->{inediblePart}) {
        push @output_rows, [$tagid, 'ecobalyse_inedible_part:en', $entry->{inediblePart}];
        $global_props++;
    }
    if (defined $entry->{transportCooling}) {
        push @output_rows, [$tagid, 'ecobalyse_transport_cooling:en', $entry->{transportCooling}];
        $global_props++;
    }
}

sub emit_variant_props {
    my ($tagid, $prefix, $entry) = @_;

    if (defined $entry->{scenario}) {
        push @output_rows, [$tagid, $prefix . '_scenario:en', $entry->{scenario}];
        $variant_props++;
    }
    if (defined $entry->{name}) {
        push @output_rows, [$tagid, $prefix . '_name:fr', $entry->{name}];
        $variant_props++;
    }
    if (defined $entry->{alias}) {
        push @output_rows, [$tagid, $prefix . '_alias:en', $entry->{alias}];
        $variant_props++;
    }
    if (defined $entry->{defaultOrigin}) {
        push @output_rows, [$tagid, $prefix . '_default_origin:en', $entry->{defaultOrigin}];
        $variant_props++;
    }
}

sub emit_new_variants {
    my ($tagid, $entries_ref, $default_entry) = @_;
    my %seen_prefixes;

    for my $entry (sort { ($a->{scenario} // '') cmp ($b->{scenario} // '') } @$entries_ref) {
        next unless ($entry->{visible} // 1);
        next if $entry->{id} eq $default_entry->{id};

        my $prefix = get_ecobalyse_prefix($entry);
        next if $prefix eq 'ecobalyse_id';
        next if $seen_prefixes{$prefix}++;

        emit_variant_props($tagid, $prefix, $entry);
    }
}

sub select_default_entry {
    my ($entries_ref) = @_;

    # Select by defaultOrigin priority:
    #   OutOfEuropeAndMaghrebByPlane -> OutOfEuropeAndMaghreb -> France -> EuropeAndMaghreb -> FranceOutreMer
    # Then prefer visible=true within the same priority.
    my @sorted = sort {
        ($default_origin_priority{$b->{defaultOrigin} // 'France'} // 99)
            <=> ($default_origin_priority{$a->{defaultOrigin} // 'France'} // 99)
        || ($b->{visible} // 1) <=> ($a->{visible} // 1)
    } @$entries_ref;

    for my $e (@sorted) {
        return $e if ($e->{visible} // 1);
    }
    return undef;
}

sub get_ecobalyse_prefix {
    my ($entry) = @_;
    my $scenario = $entry->{scenario} // 'unknown';
    my $default_origin = $entry->{defaultOrigin} // 'unknown';

    my $prefix = 'ecobalyse_id';

    # Organic scenario adds _labels_en_organic
    if ($scenario eq 'organic') {
        $prefix .= '_labels_en_organic';
    }

    # defaultOrigin determines the origin prefix component
    if ($default_origin eq 'France') {
        $prefix .= '_origins_en_france';
    }
    elsif ($default_origin eq 'EuropeAndMaghreb') {
        $prefix .= '_origins_en_european_union';
    }

    # defaultOrigin=OutOfEuropeAndMaghreb or OutOfEuropeAndMaghrebByPlane or FranceOutreMer
    # do NOT add an origin prefix — they use the bare or organic-only prefix

    return $prefix;
}
