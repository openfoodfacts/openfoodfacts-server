#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2026 Association Open Food Facts
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

=head1 NAME

2026_10_renormalize_packager_codes - Renormalize the packager codes of existing products

=head1 DESCRIPTION

When the normalization rules for packager codes change (see
lib/ProductOpener/PackagerCodes.pm), products already stored keep codes that were
normalized with the old rules, so that differently written variants of the same code
remain separate tags (e.g. "DE BY-718 EC" and "DE BY718 EC").

Example: https://github.com/openfoodfacts/openfoodfacts-server/issues/14961

This script iterates over all products stored on the file system, renormalizes the
tags in every tags_sources.emb_codes source with the current rules, refreshes
emb_codes_tags / cities_tags, and stores changed products (which also refreshes MongoDB).
retrieve_product() upgrades legacy products to the current tags schema before processing.

Use --dry-run to only print the products that would be modified, without saving anything.

=head1 DEPLOYMENT

Deploy the updated normalization and init_packager_codes() together, then reload the
application processes. The registry loader keeps existing keys and adds normalized
aliases, so both migrated and unmigrated products can resolve their packager details.

Run this migration with --dry-run, then without it. After the product migration,
rebuild the registry with scripts/update_packager_codes.pl (make build_packager_codes
in Docker) and reload the application processes to pick up the rebuilt data.

=cut

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::ProductsTags qw/renormalize_packager_codes_field/;
use Getopt::Long;

my $usage = <<TXT
2026_10_renormalize_packager_codes.pl is a script that renormalizes the packager
codes in all sources and the derived tags of stored products with the current normalization rules.

Options:

--dry-run	print the products that would be modified, without saving them
TXT
	;

my $dry_run = 0;
GetOptions("dry-run" => \$dry_run) or die("Error in command line arguments:\n\n$usage");

my $iter = product_iter();
my $products_count = 0;
my $updated_count = 0;

while (my $product_path = $iter->()) {
	$products_count++;
	print("$products_count products processed\n") if (not($products_count % 10000));

	my $product_id = product_id_from_path($product_path);
	my $product_ref = retrieve_product($product_id);
	next if not(defined $product_ref);
	next if $product_ref->{deleted};

	if (renormalize_packager_codes_field($product_ref)) {
		$updated_count++;
		if ($dry_run) {
			print("Would renormalize $product_id: " . join(", ", @{$product_ref->{emb_codes_tags}}) . "\n");
		}
		else {
			store_product("renormalize-packager-codes-script",
				$product_ref, "Renormalize packager codes (issue #14961)");
		}
	}
}

my $action = $dry_run ? "would be updated" : "updated";
print("Processed $products_count products, $updated_count products $action\n");

exit(0);
