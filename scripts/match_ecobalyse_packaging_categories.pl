#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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
use Getopt::Long;
use JSON::MaybeXS;

use ProductOpener::Tags qw(canonicalize_taxonomy_tag);
use ProductOpener::Store qw(get_string_id_for_lang);

# Script 2: Parse packaging fields from Ecobalyse processes and match the
# food category to the OFF categories taxonomy.
#
# Input  : external-data/ecobalyse/processes_packaging.json
#          (or processes_packaging_<scope>.json )
# Output : external-data/ecobalyse/processes_packaging_matched.json

my $input_file;
my $output_file;
my $help;

GetOptions(
	'input=s' => \$input_file,
	'output=s' => \$output_file,
	'help' => \$help,
) or die "Invalid options\n";

if ($help) {
	print <<EOF;
Usage: $0 [--input FILE] [--output FILE] [--help]

Parse packaging shape/material/food-category/quantity from Ecobalyse
per-item packaging processes and match the food category to the OFF
categories taxonomy (via ProductOpener::Tags::canonicalize_taxonomy_tag).

  --input   Input JSON file from extract_ecobalyse_packaging.pl
            (default: external-data/ecobalyse/processes_packaging.json)
  --output  Output JSON file
            (default: external-data/ecobalyse/processes_packaging_matched.json)
  --help    Show this help.
EOF
	exit 0;
}

$input_file //= "external-data/ecobalyse/processes_packaging.json";
$output_file //= "external-data/ecobalyse/processes_packaging_matched.json";

# ---------------------------------------------------------------------------
# Read input
# ---------------------------------------------------------------------------
my $json_text = do {
	open(my $fh, '<:raw', $input_file) or die "Could not open $input_file: $!";
	local $/;
	<$fh>;
};
my $items = decode_json($json_text);
die "Expected a JSON array" unless ref($items) eq 'ARRAY';

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Extract the food-category prefix and quantity from the activityName.
# ActivityName pattern:
#   <food category>[, <variant>], <qty> | Packaging System, ... {FR} U
sub parse_activity_name {
	my ($activity_name) = @_;

	my %part = (
		food_category_en => undef,
		food_category_full => undef,
		variant => undef,
		quantity => undef,
		quantity_unit => undef,
		pack_description => undef
	);

	if ($activity_name !~ /^(.*?)\s*\|\s*Packaging System,\s*(.+)$/) {
		return \%part;
	}

	my $foodpart = $1;
	my $pack_part = $2;

	# --- pack description: everything up to " {FR}" ---
	# e.g. "N0, All, OPP bag {FR} U" -> "OPP bag"
	#      "Proxy Pack, Rigid plastic, other than bottles {FR} U"
	$pack_part =~ s/\s*\{FR\}.*$//;
	$part{pack_description} = $pack_part;

	# --- quantity: trailing ", <number><unit>" ---
	# Handles European decimal comma (e.g. "0,75L").
	# Use capture group $1 for food_category_full instead of `$`` to avoid
	# Perl global match-variable overwrites by the s/// below.
	if ($foodpart =~ /^(.*?),\s*(\d+(?:[.,]\d+)?)\s*(cl|g|L)\s*$/i) {
		$part{food_category_full} = $1;
		$part{quantity} = $2;
		$part{quantity_unit} = lc($3);
		# normalise European decimal comma -> dot and force numeric
		$part{quantity} =~ s/,/./;
		$part{quantity} = 0 + $part{quantity};
	}
	else {
		$part{food_category_full} = $foodpart;
	}

	# --- food category: first comma-separated segment of food_category_full ---
	# "Baby food, Powder" -> "Baby food", variant "Powder"
	if (defined $part{food_category_full} && $part{food_category_full} =~ /,\s*/) {
		my $idx = index($part{food_category_full}, ',');
		$part{food_category_en} = substr($part{food_category_full}, 0, $idx);
		$part{variant} = substr($part{food_category_full}, $idx + 1);
		$part{variant} =~ s/^\s+//;
		$part{variant} =~ s/\s+$//;
	}
	else {
		$part{food_category_en} = $part{food_category_full};
	}
	$part{food_category_en} =~ s/^\s+// if defined $part{food_category_en};
	$part{food_category_en} =~ s/\s+$// if defined $part{food_category_en};

	return {
		food_category_en => $part{food_category_en},
		food_category_full => $part{food_category_full},
		variant => $part{variant},
		quantity => $part{quantity},
		quantity_unit => $part{quantity_unit},
		pack_description => $part{pack_description},
	};
}

# Extract French food category + quantity from displayName.
# Format: "<Material> (<code>) pour <food category> - <quantity>[- Proxy]"
sub parse_display_name {
	my ($display_name) = @_;

	my %part = (food_category_fr => undef, quantity => undef, quantity_unit => undef);

	# Split on " pour "
	if ($display_name !~ /pour\s+/i) {
		return \%part;
	}
	# Everything after the first " pour "
	# Use a capture group instead of `$'` to avoid Perl global match-variable
	# side effects from subsequent s/// operations.
	my $after;
	if ($display_name =~ /pour\s+(.+)/i) {
		$after = $1;
	}
	else {
		return \%part;
	}
	# Remove trailing " - Proxy" / " - Sans marque"
	$after =~ s/\s*-\s*(Proxy|Sans marque)\s*$//i;
	# Remove trailing quantity " - <number><unit>" or range " - <n><u> à <n><u>"
	# Handles formats like " - 250g", " - 0,5L", " - 0,5L à 1L", " - 250g à 350g"
	if ($after =~ s/\s*-\s*(\d+(?:[.,]\d+)?)\s*(cl|g|L)(?:\s*[àa]\s*\d+(?:[.,]\d+)?\s*(cl|g|L))?\s*$//i) {
		$part{quantity} = $1;
		$part{quantity_unit} = lc($2);
		$part{quantity} =~ s/,/./;
		$part{quantity} = 0 + $part{quantity};
	}
	$after =~ s/^\s+//;
	$after =~ s/\s+$//;
	$part{food_category_fr} = $after;

	return \%part;
}

# Extract packaging shape from the categories array (packaging_type:*)
sub extract_packaging_shape {
	my ($categories) = @_;
	if (defined $categories && ref($categories) eq 'ARRAY') {
		for my $cat (@$categories) {
			if ($cat =~ /^packaging_type:(.+)$/) {
				return $1;
			}
		}
	}
	return undef;
}

# Extract packaging material from the pack description in activityName.
sub extract_packaging_material {
	my ($pack_description) = @_;
	return undef unless defined $pack_description;

	my $desc = lc($pack_description);

	# Ordered: check compound / specific materials before generic ones
	my @patterns = (
		[qr/(?:apet\/pe|pe\/evoh\/pe|pp\/pe\/evoh\/pe|apet\/pe\/evoh\/pe|psx)/, "multi-layer plastic"],
		[qr/\bmultimaterial\b|\bmultimat.riau[lx]?\b/, "multi-material"],
		[qr/\bopp\b/, "OPP"],
		[qr/\bkraft\b/, "kraft paper"],
		[qr/\bapet\b/, "APET"],
		[qr/\bpet\b/, "PET"],
		[qr/\bpp\b/, "PP"],
		[qr/\beps\b|\bpse\b/, "PS"],
		[qr/\bpsex\b/, "PS"],
		[qr/\bpehd\b/, "HDPE"],
		[qr/\bhdpe\b/, "HDPE"],
		[qr/\bpeld\b/, "PELD"],
		[qr/\bldpe\b/, "LDPE"],
		[qr/\bpe\b/, "PE"],
		[qr/\bevoh\b/, "EVOH"],
		[qr/\baluminium\b|\balu(?:minum)?\b/, "aluminium"],
		[qr/\bverre\b|\bglass\b/, "glass"],
		[qr/\bcardboard\b|\bcarton\b/, "cardboard"],
		[qr/\bpaper\b|\bpapper\b/, "paper"],
		[qr/\bsteel\b/, "steel"],
		[qr/\bwood\b|\bwooden\b/, "wood"],
		[qr/\bplastic\b/, "plastic"],
		[qr/\bfoil\b/, "foil"],
		[qr/\bbag in box\b/, "bag in box"],
		[qr/\bwine box\b/, "bag in box"],
		[qr/\bfeuille\b/, "sheet"],
		[qr/\bgr?s\b/, "stoneware"],
		[qr/\bsold by weight\b/, "sheet"],
	);

	for my $pat (@patterns) {
		if ($desc =~ $pat->[0]) {
			return $pat->[1];
		}
	}
	return undef;
}

# Extract packaging material from the displayName's parenthetical code or
# material keyword, e.g. "Barquette en plastique (APET) pour ..." -> "APET"
#                  "Lot de briques (multimatériaux) pour ..." -> "multi-material"
sub extract_material_from_display_name {
	my ($display_name) = @_;
	return undef unless defined $display_name;

	# Try parenthetical material codes like (APET), (PP), (OPP), (multimatériaux)
	if ($display_name =~ /\(([^)]+)\)/) {
		my $code = $1;
		my $material = extract_packaging_material($code);
		return $material if defined $material;
	}

	# Fall back to keyword matching on the whole displayName
	my $material = extract_packaging_material($display_name);
	return $material;
}

# Canonicalize a food category against the categories taxonomy.
# Try order:
#   1. English full food category
#   2. English with " - cat X" / descriptor suffix stripped
#   3. English last word (e.g. "wine" from "Still wine")
#   4. French full food category
#   5. French first comma segment (e.g. "anchois" from "anchois, ambiant")
#   6. French with parentheticals stripped + first comma segment
sub match_food_category {
	my ($en, $fr) = @_;
	my $exists;
	my $tagid;

	# Helper: try canonicalize and return ($tagid, 1) on success
	my $try = sub {
		my ($lang, $tag) = @_;
		return 0 unless defined $tag && $tag ne '';
		$tagid = canonicalize_taxonomy_tag($lang, "categories", $tag, \$exists);
		return 1 if $exists;
		return 0;
	};

	# 1. English full food category
	return ($tagid, 1) if $try->("en", $en);

	# 2. English with " - cat X" / descriptor suffix stripped
	my $en_short;
	if (defined $en && $en =~ /-/) {
		$en_short = $en;
		$en_short =~ s/\s*-\s*.*//;
		$en_short =~ s/^\s+//;
		$en_short =~ s/\s+$//;
		return ($tagid, 1) if $try->("en", $en_short);
	}

	# 3. English last word (from original or stripped form)
	#    e.g. "wine" from "Still wine", "cheeses" from "Semihard cheeses - cat A"
	my @last_words;
	if (defined $en && $en =~ /\s+/) {
		push @last_words, (split(/\s+/, $en))[-1];
	}
	if (defined $en_short && $en_short =~ /\s+/) {
		my $lw = (split(/\s+/, $en_short))[-1];
		push @last_words, $lw if $lw ne ($last_words[0] // '');
	}
	for my $word (@last_words) {
		return ($tagid, 1) if $try->("en", $word);
	}

	# 4. French full food category
	return ($tagid, 1) if $try->("fr", $fr);

	# 5. French first comma-separated segment
	if (defined $fr && $fr =~ /^([^,]+)/) {
		(my $fr_short = $1) =~ s/^\s+//;
		$fr_short =~ s/\s+$//;
		if ($fr_short ne $fr) {
			return ($tagid, 1) if $try->("fr", $fr_short);
		}

		# 6. Strip parentheticals and try again
		(my $fr_noparen = $fr_short) =~ s/\s*\([^)]*\)//g;
		$fr_noparen =~ s/^\s+//;
		$fr_noparen =~ s/\s+$//;
		if ($fr_noparen ne $fr_short && $fr_noparen ne '') {
			return ($tagid, 1) if $try->("fr", $fr_noparen);
		}
	}

	return ("", 0);
}

# ---------------------------------------------------------------------------
# Main processing loop
# ---------------------------------------------------------------------------

my @results;

for my $item (@$items) {
	my $activity_name = $item->{activityName} // '';
	my $display_name = $item->{displayName} // '';

	# Parse activityName for food category, quantity, pack description
	my $an = parse_activity_name($activity_name);

	# Parse displayName for French food category (fallback)
	my $dn = parse_display_name($display_name);

	# Packaging shape from categories tags
	my $shape = extract_packaging_shape($item->{categories});

	# Packaging material from pack description (activityName), then displayName
	my $material = extract_packaging_material($an->{pack_description});
	unless (defined $material) {
		$material = extract_material_from_display_name($display_name);
	}

	# Food category: try English first, then French fallback
	my ($tagid, $matched) = match_food_category($an->{food_category_en}, $dn->{food_category_fr});

	# Use displayName quantity if activityName quantity is missing
	my $quantity = $an->{quantity};
	my $quantity_unit = $an->{quantity_unit};
	unless (defined $quantity) {
		$quantity = $dn->{quantity};
		$quantity_unit = $dn->{quantity_unit};
	}

	push @results,
		{
		id => $item->{id},
		activityName => $activity_name,
		displayName => $display_name,
		ecs => $item->{ecs},
		scopes => $item->{scopes},
		massPerUnit => $item->{massPerUnit},
		packaging_shape => $shape,
		packaging_material => $material,
		food_category_en => $an->{food_category_en} // '',
		food_category_fr => $dn->{food_category_fr} // '',
		quantity => $quantity,
		quantity_unit => $quantity_unit,
		categories_tagid => $tagid,
		categories_taxonomy_match => $matched ? 1 : 0,
		};
}

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------
open(my $out, '>:raw', $output_file) or die "Could not write $output_file: $!";
print $out JSON::MaybeXS->new->utf8->canonical->pretty->encode(\@results);
close($out);

my $matched = scalar(grep {$_->{categories_taxonomy_match}} @results);
my $unmatched = scalar(@results) - $matched;
print STDERR "Wrote " . scalar(@results) . " items to $output_file\n";
print STDERR "Matched: $matched, Unmatched: $unmatched\n";
print STDERR "Shapes: " . join(", ", sort keys %{+{map {$_->{packaging_shape} => 1} @results}}) . "\n";
print STDERR "Materials: "
	. join(", ", sort keys %{+{map {($_->{packaging_material} // 'undef') => 1} @results}}) . "\n";
print STDERR "Quantities: " . join(", ", sort keys %{+{map {($_->{quantity_unit} // 'undef') => 1} @results}}) . "\n";

1;
