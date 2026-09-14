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
# - Global properties: ecobalyse_<field>:en (exact match) or ecobalyse_proxy_<field>:en (fallback)
# - Variant-specific properties: <prefix>_<variant>_<field>:en
#   where prefix = ecobalyse (exact match) or ecobalyse_proxy (fallback)
#   variant = one of:
#     _labels_en_organic_origins_en_france (organic + French)
#     _labels_en_organic_origins_en_european_union (organic + EU)
#     _labels_en_organic (organic)
#     _origins_en_france (French origin)
#     _origins_en_european_union (EU origin)
#     (empty for default)
#   field = id:en, name:fr, alias:en, default_origin:en, scenario:en
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

# Existing UUID property names in taxonomy (without trailing colon)
my @existing_uuid_props = (
    'ecobalyse_id:en',
    'ecobalyse_labels_en_organic_id:en',
    'ecobalyse_origins_en_france_id:en',
    'ecobalyse_origins_en_european_union_id:en',
    'ecobalyse_labels_en_organic_origins_en_france_id:en',
    'ecobalyse_proxy_id:en',
    'ecobalyse_proxy_labels_en_organic_id:en',
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
    for my $prop (@existing_uuid_props) {
        my $val = get_property("ingredients", $canonical_id, $prop);
        if (defined $val) {
            $uuid_props{$prop} = $val;
        }
    }

    my $has_ecobalyse = 0;

    # Process existing UUID properties - upgrade aliases to UUIDs and emit variant-specific props
    for my $prop (sort keys %uuid_props) {
        my $val = $uuid_props{$prop};
        next unless defined $val;

        # Determine prefix for variant-specific properties from existing property name
        my $prefix = $prop;
        $prefix =~ s/_id:en$//;  # e.g. "ecobalyse", "ecobalyse_labels_en_organic", etc.

        my $entry;
        my $is_proxy = ($prefix =~ /^ecobalyse_proxy/);
        if ($val =~ /^[0-9a-f-]{36}$/ && exists $id_to_entry{$val}) {
            $entry = $id_to_entry{$val};
            $has_ecobalyse = 1;
        }
        elsif (exists $alias_to_entry{$val}) {
            $entry = $alias_to_entry{$val};
            $has_ecobalyse = 1;
            # Emit UUID upgrade
            my $new_prop = $prop;
            $new_prop =~ s/^ecobalyse_proxy/ecobalyse_proxy/;  # keep proxy prefix
            $new_prop =~ s/^ecobalyse/ecobalyse/;  # keep ecobalyse prefix
            push @output_rows, [$canonical_id, $new_prop, $entry->{id}];
            $alias_upgrades++;
        }
        else {
            push @warnings, "Stale UUID or unknown alias in $prop for $base ($canonical_id): $val";
            next;
        }

# Emit variant-specific properties
    emit_variant_props($canonical_id, $prefix, $entry, $is_proxy, 0);  # don't re-emit id for existing variants
    }

    # Determine default entry and whether it's a proxy
    my ($default_entry, $default_is_proxy);
    if (exists $uuid_props{'ecobalyse_id:en'}) {
        my $val = $uuid_props{'ecobalyse_id:en'};
        if ($val =~ /^[0-9a-f-]{36}$/ && exists $id_to_entry{$val}) {
            $default_entry = $id_to_entry{$val};
            $default_is_proxy = 0;
        }
        elsif (exists $alias_to_entry{$val}) {
            $default_entry = $alias_to_entry{$val};
            $default_is_proxy = 0;
        }
    }
    elsif (exists $uuid_props{'ecobalyse_proxy_id:en'}) {
        my $val = $uuid_props{'ecobalyse_proxy_id:en'};
        if ($val =~ /^[0-9a-f-]{36}$/ && exists $id_to_entry{$val}) {
            $default_entry = $id_to_entry{$val};
            $default_is_proxy = 1;
        }
        elsif (exists $alias_to_entry{$val}) {
            $default_entry = $alias_to_entry{$val};
            $default_is_proxy = 1;
        }
    }

    if (defined $default_entry) {
        emit_global_props($canonical_id, $default_entry, $default_is_proxy);
    }
    elsif (scalar(keys %uuid_props) == 0) {
        # No ecobalyse properties exist at all — select a default entry by defaultOrigin priority
        $default_entry = select_default_entry($base_to_entries{$base});
        if (defined $default_entry) {
            # Determine if this is a proxy based on defaultOrigin
            my $is_proxy = is_proxy_entry($default_entry);
            push @output_rows, [$canonical_id, $is_proxy ? 'ecobalyse_proxy_id:en' : 'ecobalyse_id:en', $default_entry->{id}];
            emit_global_props($canonical_id, $default_entry, $is_proxy);

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
    my ($tagid, $entry, $is_proxy) = @_;
    my $prefix = $is_proxy ? 'ecobalyse_proxy' : 'ecobalyse';

    if (defined $entry->{density}) {
        push @output_rows, [$tagid, "${prefix}_density_g_per_ml:en", $entry->{density}];
        $global_props++;
    }
    if (defined $entry->{cropGroup}) {
        push @output_rows, [$tagid, "${prefix}_crop_group:en", $entry->{cropGroup}];
        $global_props++;
    }
    if (defined $entry->{categories} && ref($entry->{categories}) eq 'ARRAY' && @{$entry->{categories}}) {
        push @output_rows, [$tagid, "${prefix}_category:en", $entry->{categories}[0]];
        $global_props++;
    }
    if (defined $entry->{rawToCookedRatio}) {
        push @output_rows, [$tagid, "${prefix}_raw_to_cooked_ratio:en", $entry->{rawToCookedRatio}];
        $global_props++;
    }
    if (defined $entry->{inediblePart}) {
        push @output_rows, [$tagid, "${prefix}_inedible_part:en", $entry->{inediblePart}];
        $global_props++;
    }
    if (defined $entry->{transportCooling}) {
        push @output_rows, [$tagid, "${prefix}_transport_cooling:en", $entry->{transportCooling}];
        $global_props++;
    }
}

sub emit_variant_props {
    my ($tagid, $prefix, $entry, $is_proxy, $emit_id) = @_;
    $emit_id //= 1;  # default to true for new variants

    # prefix already includes ecobalyse or ecobalyse_proxy
    my $use_prefix = $is_proxy ? $prefix : $prefix;
    # If prefix is just "ecobalyse" or "ecobalyse_proxy", that's the base prefix for default variant
    # For variants, prefix already has the variant suffix (e.g., ecobalyse_labels_en_organic)

    # Emit the UUID (id) for this variant (only for new variants not already in taxonomy)
    if ($emit_id) {
        push @output_rows, [$tagid, "${use_prefix}_id:en", $entry->{id}];
        $variant_props++;
    }
    if (defined $entry->{scenario}) {
        push @output_rows, [$tagid, "${use_prefix}_scenario:en", $entry->{scenario}];
        $variant_props++;
    }
    if (defined $entry->{name}) {
        push @output_rows, [$tagid, "${use_prefix}_name:fr", $entry->{name}];
        $variant_props++;
    }
    if (defined $entry->{alias}) {
        push @output_rows, [$tagid, "${use_prefix}_alias:en", $entry->{alias}];
        $variant_props++;
    }
    if (defined $entry->{defaultOrigin}) {
        push @output_rows, [$tagid, "${use_prefix}_default_origin:en", $entry->{defaultOrigin}];
        $variant_props++;
    }
}

sub emit_new_variants {
    my ($tagid, $entries_ref, $default_entry) = @_;
    my %seen_variant_keys;

    for my $entry (sort { ($a->{scenario} // '') cmp ($b->{scenario} // '') } @$entries_ref) {
        next unless ($entry->{visible} // 1);
        next if $entry->{id} eq $default_entry->{id};

        my $variant_key = get_variant_key($entry);
        next if $seen_variant_keys{$variant_key}++;
        next if $variant_key eq '';  # skip default variant

        my $is_proxy = is_proxy_entry($entry);
        my $prefix = $is_proxy ? 'ecobalyse_proxy' : 'ecobalyse';
        $prefix .= $variant_key;

        emit_variant_props($tagid, $prefix, $entry, $is_proxy);
    }
}

sub get_variant_key {
    my ($entry) = @_;
    my $scenario = $entry->{scenario} // 'unknown';
    my $default_origin = $entry->{defaultOrigin} // 'unknown';

    my $suffix = '';

    # Organic scenario adds _labels_en_organic
    if ($scenario eq 'organic') {
        $suffix .= '_labels_en_organic';
    }

    # defaultOrigin determines the origin prefix component
    if ($default_origin eq 'France') {
        $suffix .= '_origins_en_france';
    }
    elsif ($default_origin eq 'EuropeAndMaghreb') {
        $suffix .= '_origins_en_european_union';
    }

    # defaultOrigin=OutOfEuropeAndMaghreb or OutOfEuropeAndMaghrebByPlane or FranceOutreMer
    # do NOT add an origin suffix — they use the bare or organic-only suffix

    return $suffix;
}

sub is_proxy_entry {
    my ($entry) = @_;
    my $default_origin = $entry->{defaultOrigin} // '';
    # Proxy entries are those with defaultOrigin = OutOfEuropeAndMaghreb or OutOfEuropeAndMaghrebByPlane
    # These are "import" variants used as fallback
    return ($default_origin eq 'OutOfEuropeAndMaghreb' || $default_origin eq 'OutOfEuropeAndMaghrebByPlane');
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