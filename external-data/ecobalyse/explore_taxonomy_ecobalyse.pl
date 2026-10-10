#!/usr/bin/perl -w

# This script explores the OFF ingredients taxonomy to check for ecobalyse properties
# on specific ingredients.

use Modern::Perl '2017';
use utf8;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::LoadData qw/load_data/;
use Data::Dumper;

# Load all taxonomies
load_data();

# List of ingredients to check (from top 10 missing ecobalyse ingredients)
my @ingredients_to_check = qw(
	en:cream
	en:chicken
	en:cocoa-paste
	en:almond
	en:wheat
	en:shrimp
	en:corn-syrup
	en:e330
	en:e375
);

print "=== Checking ecobalyse properties in OFF ingredients taxonomy ===\n\n";

for my $ingredient_id (@ingredients_to_check) {
	print "--- $ingredient_id ---\n";

	# Check if it exists in taxonomy
	my $exists = exists_taxonomy_tag("ingredients", $ingredient_id);
	print "  In taxonomy: " . ($exists ? "YES" : "NO") . "\n";

	if ($exists) {
		# Get all properties for this ingredient
		my $props_ref = $properties{ingredients}{$ingredient_id};

		if ($props_ref) {
			print "  All properties:\n";
			for my $prop (sort keys %$props_ref) {
				if ($prop =~ /ecobalyse/i) {
					print "    ECOLAB: $prop = $props_ref->{$prop}\n";
				}
				else {
					print "    $prop = $props_ref->{$prop}\n";
				}
			}
		}
		else {
			print "  No properties found\n";
		}

		# Check direct children/parents
		my $children_ref = $ProductOpener::Tags::direct_children{ingredients}{$ingredient_id};
		if ($children_ref && @$children_ref) {
			print "  Direct children: " . join(", ", @$children_ref) . "\n";
		}

		my $parents_ref = $ProductOpener::Tags::direct_parents{ingredients}{$ingredient_id};
		if ($parents_ref && @$parents_ref) {
			print "  Direct parents: " . join(", ", @$parents_ref) . "\n";
		}
	}
	print "\n";
}

# Also check canonicalization behavior
print "=== Canonicalization tests ===\n\n";
my @test_names = qw(
	cream
	chicken
	cocoa paste
	almond
	wheat
	shrimp
	corn syrup
	corn-syrup
	glucose syrup
	citric acid
	nicotinic acid
);

for my $name (@test_names) {
	my $exists = 0;
	my $canon = canonicalize_taxonomy_tag("en", "ingredients", $name, \$exists);
	print "  '$name' -> '$canon' (exists: " . ($exists ? "YES" : "NO") . ")\n";
}

print "\n=== Checking Ecobalyse base ingredients mappings ===\n\n";

# Check the matching files
my %matched_files = (
	'matched (taxonomy)' => 'external-data/ecobalyse/base_ingredients_to_off_ingredients.tsv',
	'overrides' => 'external-data/ecobalyse/base_ingredients_to_off_ingredients_overrides.tsv',
	'missing' => 'external-data/ecobalyse/base_ingredients_to_off_ingredients_missing.tsv',
	'proxies' => 'external-data/ecobalyse/base_ingredients_proxies_for_off_ingredients.tsv',
);

for my $desc (keys %matched_files) {
	my $file = $matched_files{$desc};
	print "--- $desc ($file) ---\n";
	if (-f $file) {
		open(my $fh, '<:encoding(UTF-8)', $file) or die "Cannot open $file: $!";
		while (my $line = <$fh>) {
			chomp $line;
			next if $line =~ /^#/ || $line =~ /^\s*$/;
			for my $ing (@ingredients_to_check) {
				if ($line =~ /\Q$ing\E/) {
					print "  $line\n";
				}
			}
		}
		close($fh);
	}
	print "\n";
}

# Check processes.json for relevant baseIngredients
print "=== Searching processes.json for relevant baseIngredients ===\n\n";
# We'll use a simple grep approach since jq might not be available
my @search_terms = qw(
	cream
	chicken
	cocoa
	almond
	wheat
	shrimp
	corn
	glucose
);

use JSON;
open(my $json_fh, '<:raw', 'external-data/ecobalyse/processes.json') or die "Cannot open processes.json: $!";
my $raw_json;
{
	local $/;
	$raw_json = <$json_fh>;
}
close($json_fh);

my $json = JSON->new->utf8->allow_nonref;
my $all_entries = $json->decode($raw_json);

my %found_base;
for my $item (@$all_entries) {
	my $meta = $item->{metadata};
	next unless $meta && $meta->{ingredient};
	my $base = $meta->{ingredient}{baseIngredient};
	next unless $base;

	my $scopes = $item->{scopes} // [];
	my $categories = $item->{categories} // [];
	my $visible = $item->{visible} // 1;

	my $is_food2 = grep {$_ eq 'food2'} @$scopes;
	my $is_ingredient = grep {$_ eq 'ingredient'} @$categories;

	for my $term (@search_terms) {
		if ($base =~ /\Q$term\E/i) {
			$found_base{$base} = 1;
			if ($is_food2 && $is_ingredient && $visible) {
				print "  MATCH (food2+ingredient+visible): $base\n";
			}
			else {
				print
					"  Found but filtered out: $base (food2:$is_food2, ingredient:$is_ingredient, visible:$visible)\n";
			}
		}
	}
}

print "\n=== Summary of baseIngredient matches in processes.json ===\n";
for my $base (sort keys %found_base) {
	print "  $base\n";
}
