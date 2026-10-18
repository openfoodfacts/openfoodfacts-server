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
emb_codes field with the current rules, refreshes the emb_codes_tags / cities_tags,
and stores the products (which also refreshes MongoDB).

Use --dry-run to only print the products that would be modified, without saving anything.

=cut

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::ProductsTags qw/renormalize_packager_codes_field/;
use Getopt::Long;

my $usage = <<TXT
2026_10_renormalize_packager_codes.pl is a script that renormalizes the packager
codes (emb_codes) field and tags of all stored products with the current normalization rules.

Options:

--dry-run	do not do any processing, just print the products that would be modified
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
			print("Would renormalize $product_id: $product_ref->{emb_codes}\n");
		}
		else {
			store_product("renormalize-packager-codes-script", $product_ref,
				"Renormalize packager codes (issue #14961)");
		}
	}
}

print("Processed $products_count products, $updated_count products updated\n");

return 0;
