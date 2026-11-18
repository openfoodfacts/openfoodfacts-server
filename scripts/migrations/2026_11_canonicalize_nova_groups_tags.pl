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

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::ProductsFeatures qw/feature_enabled/;
use ProductOpener::Data qw/get_products_collection/;

use Getopt::Long;
use Log::Any qw($log);

my $usage = <<TXT;
Usage:
  perl 2026_11_canonicalize_nova_groups_tags.pl [options]

Options:
  --pretend          Report matching documents and planned updates without writing to MongoDB.
  --batch-size=N     Number of documents to process per batch (default: 1000).
  --limit=N          Maximum number of documents to process in total (default: unlimited).
  --help             Show this help message.

Description:
  This migration purges confusing duplicates and uncanonicalized tags in nova_groups_tags (issue #15405):
  1. For food products: normalizes raw 'unknown' to 'en:unknown' and 'not-applicable' to 'en:not-applicable'.
  2. For non-food products (beauty, product): removes obsolete NOVA fields (nova_group, nova_groups,
     nova_groups_tags, nova_group_tags, nova_groups_markers, nova_group_debug, nova_group_error).
  3. Preserves all other product fields and is fully idempotent.
TXT

my $pretend    = 0;
my $batch_size = 1000;
my $limit      = 0;
my $help       = 0;

GetOptions(
	"pretend"      => \$pretend,
	"batch-size=i" => \$batch_size,
	"limit=i"      => \$limit,
	"help"         => \$help,
) or die $usage;

if ($help) {
	print $usage;
	exit 0;
}

print "Starting NOVA groups tags canonicalization migration (Issue #15405)\n";
print "Mode: " . ($pretend ? "PRETEND (read-only, no database modifications)" : "LIVE EXECUTION") . "\n";
print "Batch size: $batch_size\n";
print "Limit: " . ($limit > 0 ? $limit : "Unlimited") . "\n\n";

my $products_collection = get_products_collection();

# Part 1: Normalize uncanonicalized tags on food products
print "--- Phase 1: Normalizing legacy 'unknown' and 'not-applicable' tags ---\n";

my $query_legacy_tags = {
	"nova_groups_tags" => {
		'$in' => ["unknown", "not-applicable"]
	}
};

my $cursor_legacy = $products_collection->find($query_legacy_tags)->batch_size($batch_size);

my $legacy_scanned  = 0;
my $legacy_modified = 0;
my $legacy_errors   = 0;

while ($cursor_legacy->has_next) {
	last if ($limit > 0 && $legacy_scanned >= $limit);

	my $product_ref;
	eval {
		$product_ref = $cursor_legacy->next;
	};
	if ($@ || !defined $product_ref) {
		warn "Error retrieving document: $@\n" if $@;
		$legacy_errors++;
		next;
	}

	$legacy_scanned++;

	my $code = $product_ref->{code} // $product_ref->{_id};
	my $tags = $product_ref->{nova_groups_tags} // [];

	my $needs_update = 0;
	my @new_tags     = ();
	my %seen         = ();

	foreach my $tag (@$tags) {
		my $canonical_tag = $tag;
		if ($tag eq "unknown") {
			$canonical_tag = "en:unknown";
			$needs_update  = 1;
		}
		elsif ($tag eq "not-applicable") {
			$canonical_tag = "en:not-applicable";
			$needs_update  = 1;
		}

		if (!$seen{$canonical_tag}++) {
			push @new_tags, $canonical_tag;
		}
	}

	if ($needs_update) {
		$legacy_modified++;
		if ($pretend) {
			if ($legacy_modified <= 10 || $legacy_modified % 1000 == 0) {
				print "[PRETEND] Would update product $code nova_groups_tags: ["
					. join(", ", @$tags) . "] -> ["
					. join(", ", @new_tags) . "]\n";
			}
		}
		else {
			eval {
				$products_collection->update_one(
					{ "_id" => $product_ref->{_id} },
					{ '$set' => { "nova_groups_tags" => \@new_tags } }
				);
			};
			if ($@) {
				warn "Failed to update product $code: $@\n";
				$legacy_errors++;
			}
		}
	}

	if ($legacy_scanned % 5000 == 0) {
		print "Phase 1 Progress: $legacy_scanned scanned, $legacy_modified updated...\n";
	}
}

print "Phase 1 Complete: $legacy_scanned scanned, $legacy_modified updated, $legacy_errors errors.\n\n";

# Part 2: Purge obsolete NOVA fields on non-food products
print "--- Phase 2: Purging obsolete NOVA fields from non-food products ---\n";

my $query_non_food = {
	"product_type"     => { '$in' => ["beauty", "product"] },
	"nova_groups_tags" => { '$exists' => 1 }
};

my $cursor_non_food = $products_collection->find($query_non_food)->batch_size($batch_size);

my $non_food_scanned  = 0;
my $non_food_modified = 0;
my $non_food_errors   = 0;

while ($cursor_non_food->has_next) {
	last if ($limit > 0 && ($legacy_scanned + $non_food_scanned) >= $limit);

	my $product_ref;
	eval {
		$product_ref = $cursor_non_food->next;
	};
	if ($@ || !defined $product_ref) {
		warn "Error retrieving document: $@\n" if $@;
		$non_food_errors++;
		next;
	}

	$non_food_scanned++;
	$non_food_modified++;

	my $code = $product_ref->{code} // $product_ref->{_id};
	my $type = $product_ref->{product_type} // "unknown";

	if ($pretend) {
		if ($non_food_modified <= 10 || $non_food_modified % 1000 == 0) {
			print "[PRETEND] Would purge NOVA fields from $type product $code\n";
		}
	}
	else {
		eval {
			$products_collection->update_one(
				{ "_id" => $product_ref->{_id} },
				{
					'$unset' => {
						"nova_group"         => "",
						"nova_groups"        => "",
						"nova_groups_tags"   => "",
						"nova_group_tags"    => "",
						"nova_groups_markers"=> "",
						"nova_group_debug"   => "",
						"nova_group_error"   => "",
					}
				}
			);
		};
		if ($@) {
			warn "Failed to unset NOVA fields on product $code: $@\n";
			$non_food_errors++;
		}
	}

	if ($non_food_scanned % 5000 == 0) {
		print "Phase 2 Progress: $non_food_scanned scanned, $non_food_modified purged...\n";
	}
}

print "Phase 2 Complete: $non_food_scanned scanned, $non_food_modified purged, $non_food_errors errors.\n\n";

print "========================================================\n";
print "MIGRATION SUMMARY " . ($pretend ? "(PRETEND MODE - NO WRITES PERFORMED)" : "(LIVE)") . "\n";
print "Phase 1 (Legacy tags normalized): $legacy_modified / $legacy_scanned\n";
print "Phase 2 (Non-food NOVA purged)  : $non_food_modified / $non_food_scanned\n";
print "Total Errors                    : " . ($legacy_errors + $non_food_errors) . "\n";
print "========================================================\n";
