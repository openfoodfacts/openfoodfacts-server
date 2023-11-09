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
use ProductOpener::Data qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Store qw/:all/;
use Getopt::Long;

# how many operations in bulk write
my $BULK_WRITE_SIZE = 100;

sub find_non_normalized_sto ($product_path) {
	# find all .sto files that have a non normalized code
	# we take a very brute force approach on filename
	# return a list with path, product_id and normalized_id
	my $iter = sto_iter("$data_root/products", qr/product\.sto$/i);
	my @anomalous = ();
	while (my $product_path = $iter->()) {
		my $product_code = product_id_from_path($product_path);
		my $normalized_code = normalize_code($product_code);
		if ($product_code ne $normalized_code) {
			# we intentionally use a simple retrieve, to avoid processing
			my $product_ref = retrieve($product_path);
			# skip deleted
			next if $product_ref->{deleted};
			# item to normalize
			push(@anomalous, [$product_path, $product_code, $normalized_code]);
		}
	}
	return @anomalous;
}

sub move_product_to ($product_path, $product_id, $normalized_id) {
	my $product_ref = retrieve_product($product_id);
	$product_ref->{old_code} = $product_ref->{code};
	$product_ref->{code} = $normalized_id;
	$product_ref->{_id} = $normalized_id;
	# store updated (will move it)
	store_product("fix-non-normalized-codes-script", $product_ref, "Normalize barcode");
	return;
}

sub delete_product ($product_path) {
	# we must use retrieve because path might be invalid for retrieve_product
	my $product_ref = retrieve($product_path);
	$product_ref->{deleted} = "on";
	# and we use store, as we used retrieve
	store($product_path, $product_ref);
	return;
}

sub fix_non_normalized_sto ($product_path, $dry_run, $out) {
	my @actions = ();
	my @items = find_non_normalized_sto($product_path);
	foreach my $item (@items) {
		my ($product_path, $product_id, $normalized_id) = @$item;
		my $new_path = product_path_from_id($normalized_id);
		# handle a special case where previous id is higly broken …
		# and moving would not work
		my $path_from_old_id = product_path_from_id($product_id);
		my $is_duplicate = (-e "$data_root/products/$new_path");
		my $is_invalid = $path_from_old_id eq "invalid";
		if ($is_duplicate || $is_invalid) {
			# this is probably older data than the normalized one, we will ditch it !
			delete_product($product_path) unless $dry_run;
			my $msg = "Removed $product_id";
			if ($is_duplicate) {
				$msg .= " as duplicate of $normalized_id";
			}
			push(@actions, $msg);
		}
		else {
			# we do not have a product with same normalized code
			# move the product to it's normalized code
			move_product_to($product_path, $product_id, $normalized_id) unless $dry_run;
			push(@actions, "Moved $product_id to $normalized_id");
		}
		print($out ($actions[-1] . "\n")) unless !$out;
	}
	return \@actions;
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

sub fix_int_barcodes_sto ($int_ids_ref, $dry_run) {
	# fix int barcodes in sto
	my $removed = 0;
	my $refreshed = 0;
	my $products_collection = get_products_collection();

	foreach my $int_id (@$int_ids_ref) {
		# load
		my $str_code = "$int_id";
		my $product_ref = retrieve_product_or_deleted_product($str_code);
		if (defined $product_ref) {
			$product_ref->{_id} .= '';
			$product_ref->{code} .= '';
			my $path = product_path_from_id($product_ref->{code});
			if (!$dry_run) {
				# Silently replace values in sto (no rev)
				store("$data_root/products/$path/product.sto", $product_ref);
				# Refresh mongodb
				if ($product_ref->{deleted}) {
					$products_collection->delete_one({"_id" => $product_ref->{_id}});
				}
				else {
					$products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
				}

			}
			$refreshed++ if $product_ref->{deleted};
			$removed++ unless $product_ref->{deleted};
		}
		else {
			if (!$dry_run) {
				# remove for mongodb
				$products_collection->delete_one({"_id" => $product_ref->{_id}});
			}
			$removed++;
		}
	}

	return {removed => $removed, refreshed => $refreshed};
}

sub remove_int_barcode_mongo ($dry_run, $out) {
	# a product with a non int code should be removed or converted to str
	my @int_ids = search_int_codes();
	# re-index corresponding products, with a fix on id, just to be sure !
	my $result_ref = fix_int_barcodes_sto(\@int_ids, $dry_run);
	my $removed = $result_ref->{removed};
	my $refreshed = $result_ref->{refreshed};
	if ($removed || $refreshed) {
		print($out "Int codes: refresh $refreshed, removed $removed\n");
	}

	# remove them from mongodb
	# 2 mins, instead of 30s default, to not die as easily if mongodb is busy.
	my $socket_timeout_ms = 2 * 60000;
	my $products_collection = get_products_collection({timeout => $socket_timeout_ms});
	$products_collection->delete_many($int_codes_query_ref);

	return;
}

# remove non normalized codes in mongodb
# this is to be run after fix_non_normalized_sto so that we simply erase bogus entries
sub remove_non_normalized_mongo ($dry_run, $out) {
	# iterate all codes an verify they are normalized
	# we could try to find them with a query but that would mean changes if normalize_code changes
	# which would be a maintenance burden

	# we will first collect then erase
	my @ids_to_remove = ();
	# 2 mins, instead of 30s default, to not die as easily if mongodb is busy.
	my $socket_timeout_ms = 2 * 60000;
	my $products_collection = get_products_collection({timeout => $socket_timeout_ms});
	my $cursor = $products_collection->query({})->fields({_id => 1, code => 1});
	$cursor->immortal(1);
	while (my $product_ref = $cursor->next) {
		my $code = $product_ref->{code};
		my $normalized_code = normalize_code($code);
		if ($code ne $normalized_code) {
			push @ids_to_remove, $product_ref->{_id};
		}
	}

	my $count = scalar @ids_to_remove;
	my $removed = 0;

	if (scalar @ids_to_remove) {
		print($out "$count items with non normalized code will be removed from mongo.\n") unless !$out;
		if (!$dry_run) {
			my $result = remove_documents_by_ids(\@ids_to_remove, $products_collection);
			$removed = $result->{removed};
			if ($removed < $count) {
				my $missed = $count - $removed;
				print(STDERR "WARN: $missed deletions.\n");
			}
			if (scalar @{$result->{errors}}) {
				my $errs = join("\n  - ", @{$result->errors});
				print(STDERR "ERR: errors while removing items:\n  - $errs\n");
			}
		}
	}
	return $removed;
}

### script
my $usage = <<TXT
fix_non_normalized_codes.pl is a script that updates checks and fix for products with non normalized codes

Options:

--dry-run	do not do any processing just print what would be done
TXT
	;

my $dry_run = 0;
GetOptions("dry-run" => \$dry_run,)
	or die("Error in command line arguments:\n\n$usage");

# fix errors on filesystem
my $product_path = "$data_root/products";
fix_non_normalized_sto($product_path, $dry_run, \*STDOUT);
# now that we don't have any non normalized codes on filesystem, we can fix Mongodb
remove_int_barcode_mongo($dry_run, \*STDOUT);
remove_non_normalized_mongo($dry_run, \*STDOUT);
