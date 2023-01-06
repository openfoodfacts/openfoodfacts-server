#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

fix_non_ronalized_codes - A script to fix non normalized codes

=head1 DESCRIPTION

Products code needs to be normalized to avoid confusions in products (false distinct).
But there may be leaks in the code, or some other tools (eg import scripts) 
that creates non normalized entries in the MongoDB or on the file system.

This scripts tries to check and fix this.

=cut

my $usage = <<TXT
fix_non_normalized_codes.pl is a script that updates checks and fix for products with non normalized codes

Options:

--dry-run	do not do any processing just print what would be done
TXT
;

use ProductOpener::PerlStandards;

use ProductOpener::Products qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use Getopt::Long;

sub find_non_normalized_sto($product_path) {
    # find all .sto files that have a non normalized code
    # we take a very brute force approach on filename
    # return a list with path, product_id and normalized_id
    my $iter = sto_iter("$data_root/products", qr/product\.sto$/i);
    my @anomalous = ();
    while (my $product_path = $iter->()) {
        my $product_id = product_id_from_path($product_path);
        my $normalized_id = normalize_code($product_id);
        if ($product_id ne $normalized_id) {
            # verify it's not deleted
            my $product_ref = retrieve_product($product_id);
            next unless $product_ref;
            # item to normalize
            push (@anomalous, [$product_id, $normalized_id]);
        }
    }
    return @anomalous;
}


sub move_product_to($product_id, $normalized_id) {
    my $product_ref = retrieve_product($product_id);
    $product_ref->{old_code} = $product_ref->{code};
    $product_ref->{code} = $normalized_id;
    store_product("fix-non-normalized-codes-script", $product_ref, "Normalize barcode");
    return;
}

sub delete_product($product_id, $normalized_id) {
    my $product_ref = retrieve_product($product_id);
    $product_ref->{deleted} = "on";
    store_product("fix-non-normalized-codes-script", $product_ref, "Delete as duplicate of $normalized_id");
    return;
}

sub fix_non_normalized_sto($product_path, $dry_run, $out) {
    my @actions = ();
    my @items = find_non_normalized_sto($product_path);
    foreach my $item  (@items) {
        my ($product_id, $normalized_id) = @$item;
        if (product_exists($normalized_id)) {
            # we do not have a product with same normalized code
            # move the product to it's normalized code
            move_product_to($product_id, $normalized_id) unless $dry_run;
            push (@actions, "Moved $product_id to $normalized_id");
        } else {
            # this is probably older data than the normalized one, we will ditch it !
            delete_product($product_id, $normalized_id) unless $dry_run;
            push (@actions, "Removed $product_id as duplicate of $normalized_id");
        }
        print ($out ($actions[-1]. "\n")) unless !$out;
    }
    return \@actions;
}


### script
my $dry_run = 0;
GetOptions(
	"dry-run" => \$dry_run,
) or die("Error in command line arguments:\n\n$usage");

my $product_path = "$data_root/products";
fix_non_normalized_sto($product_path, $dry_run, \*STDOUT);
