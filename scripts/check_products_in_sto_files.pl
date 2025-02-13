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

fix_non_normalized_codes - A script to fix non normalized codes

=head1 DESCRIPTION

Products code needs to be normalized to avoid confusions in products (false distinct).
But there may be leaks in the code, or some other tools (eg import scripts)
that creates non normalized entries in the MongoDB or on the file system.

This scripts tries to check and fix this.

=cut

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Data qw/get_products_collection remove_documents_by_ids/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Store qw/retrieve sto_iter store/;
use Getopt::Long;

my $current_products_collection = get_products_collection(
	{
		obsolete => 0,
		timeout => 10000
	}
);
my $obsolete_products_collection = get_products_collection(
	{
		obsolete => 1,
		timeout => 10000
	}
);

# how many operations in bulk write
my $BULK_WRITE_SIZE = 100;

sub find_non_normalized_sto ($product_path) {
	# find all .sto files that have a non normalized code
	# we take a very brute force approach on filename
	# return a list with path, product_id and normalized_product_id
	my $iter = sto_iter($BASE_DIRS{PRODUCTS}, qr/product\.sto$/i);
	my @anomalous = ();
	my $i = 0;
	while (my $product_path = $iter->()) {
		my $product_ref = retrieve($product_path);
		if (defined $product_ref) {
			my $code = $product_ref->{code};
			my $product_id = $product_ref->{_id};
			my $normalized_code = normalize_code($code);
			my $normalized_product_id = product_id_for_owner(undef, $normalized_code);
			my $normalized_product_path = product_path_from_id($normalized_product_id);

			$product_path =~ s/.*\/products\///;
			$product_path =~ s/\/product\.sto$//;
			#print STDERR "code: $code - normalized_code: $normalized_code - product_id: $product_id - normalized_product_id: $normalized_product_id - product_path: $product_path - normalized_product_path: $normalized_product_path\n";

			if (   ($code ne $normalized_code)
				or ($product_id ne $normalized_product_id)
				or ($product_path ne $normalized_product_path))
			{
				push(
					@anomalous,
					[
						$product_path, $normalized_product_path, $code,
						$normalized_code, $product_id, $normalized_product_id
					]
				);
			}
		}
		$i++;
		($i % 1000 == 0) && print STDERR "Processed $i products - current path: $product_path\n";
	}
	return @anomalous;
}

sub fix_non_normalized_sto ($product_path, $fix, $out) {
	my @items = find_non_normalized_sto($product_path);

	foreach my $item (@items) {
		my ($product_path, $normalized_product_path, $code, $normalized_code, $product_id, $normalized_product_id)
			= @$item;

		my $is_duplicate = (-e "$BASE_DIRS{PRODUCTS}/$normalized_product_path") || 0;

		my $is_invalid = ($normalized_product_path eq "invalid") || 0;

		print STDERR
			"product_path: $product_path - normalized_product_path: $normalized_product_path - code: $code - normalized_code: $normalized_code - product_id: $product_id - normalized_product_id: $normalized_product_id - is_duplicate: $is_duplicate - is_invalid: $is_invalid\n";

		if ($fix) {
			if ((not $is_invalid) and ($product_path eq $normalized_product_path)) {

				# Delete the old code from MongoDB collections
				print STDERR "Deleting old product id $product_id (new one is $normalized_product_id)\n";
				$current_products_collection->delete_one({_id => $product_id});
				$obsolete_products_collection->delete_one({_id => $product_id});

				my $product_ref = retrieve_product($normalized_product_id, "include_deleted");
				if (defined $product_ref) {
					print STDERR "Product $normalized_product_id already exists with code: "
						. $product_ref->{code}
						. " - id: "
						. $product_ref->{id}
						. " -- saving it again with new code, id, _id\n";
					$product_ref->{code} = $normalized_code . '';
					$product_ref->{id} = $product_ref->{code} . '';    # treat id as string;
					$product_ref->{_id} = $normalized_product_id . '';    # treat id as string;

					# If the product is not deleted, store_product will add the new code to MongoDB
					store_product(
						"fix-code-bot", $product_ref, "changed code from $code to $normalized_code
"
					);
				}
				else {
					print STDERR "Product $normalized_product_id does not exist\n";
				}

			}
		}

	}

	print STDERR "Found " . scalar(@items) . " non normalized codes / ids / paths\n";
	return;
}

my $int_codes_query_ref = {'code' => {'$not' => {'$type' => 'string'}}};

sub search_int_codes() {
	# search for product with int code in mongodb

	# 2 mins, instead of 30s default, to not die as easily if mongodb is busy.
	my $socket_timeout_ms = 2 * 60000;
	my $products_collection = get_products_collection({timeout => $socket_timeout_ms});

	# find int codes
	my @int_ids = ();
	# it's better we do it with a specific queries as it's hard to keep "integer" as integers in perl
	my $cursor
		= $products_collection->query($int_codes_query_ref)->fields({_id => 1, code => 1});
	$cursor->immortal(1);
	while (my $product_ref = $cursor->next) {
		push(@int_ids, $product_ref->{_id});
	}

	return @int_ids;

}

### script
my $usage = <<TXT
check_products_in_sto_files.pl is a script that updates checks and fix for products with non normalized codes

Options:

--fix	fix products that have non normalized codes (only if they are on the right path)
TXT
	;

use Getopt::Long;

my $query_params_ref = {};    # filters for mongodb query
my $all_owners = '';
my $obsolete = 0;
my $fix = 0;

GetOptions(
	"query=s%" => $query_params_ref,
	"all-owners" => \$all_owners,
	"obsolete" => \$obsolete,
	"fix" => \$fix,

) or die("Error in command line arguments:\n\n$usage");

# fix errors on filesystem
my $product_path = $BASE_DIRS{PRODUCTS};
fix_non_normalized_sto($product_path, $fix, \*STDOUT);

