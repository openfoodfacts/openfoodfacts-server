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
use utf8;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products qw/product_iter/;
use ProductOpener::Data qw/get_collection/;
use ProductOpener::Store qw/retrieve_object store_object/;
use ProductOpener::Redis qw/push_product_update_to_redis/;
use ProductOpener::Checkpoint;

use experimental qw/switch smartmatch/;
use Time::HiRes qw/sleep/;

# This script recursively visits all products and checks that they are in the correct MongoDB collection
# removing them from all others
sub product_type_for_server($server) {
	return do {
		given ($server) {
			"food" when 'off';
			"beauty" when 'obf';
			"petfood" when 'opff';
			"product" when 'opf';
		}
	};
}

my $checkpoint = ProductOpener::Checkpoint->new;
my $last_processed_path = $checkpoint->{value};
my %collections;
foreach my $server (qw/off obf opff opf/) {
	foreach my $obsolete (qw/0 1/) {
		my $obsolete_suffix = $obsolete ? '_obsolete' : '';
		my $collection_name = "products$obsolete_suffix";

		my $product_type = product_type_for_server($server);

		my $collection_id = $product_type . $obsolete_suffix;
		$collections{$collection_id} = get_collection($server, $collection_name);
	}
}

my $next = product_iter($BASE_DIRS{PRODUCTS}, qr/product$/i, qr/^(conflicting|invalid)-codes$/, $last_processed_path);

my $count = 0;
while (my $path = $next->()) {
	if ($path eq $last_processed_path) {
		next;    # we don't want to process the product again
	}

	my $product_ref = retrieve_object($path);
	my $product_id = $product_ref->{_id};
	my $code = $product_ref->{code};
	if (not defined $product_id) {
		$product_id = $code . '';    # Ensure it is a string
		$product_ref->{_id} = $code . '';
		store_object($path, $product_ref);
		$checkpoint->log("$product_id had no id. Setting to code");
	}
	elsif ($product_id ne $code) {
		$checkpoint->log("$product_id has a different code: $code");
	}
	my $filter = {"_id" => $product_id};

	# See which collections the product exists in
	my @collection_ids = ();
	while (my ($collection_id, $collection) = each %collections) {
		if ($collection->count_documents($filter)) {
			push(@collection_ids, $collection_id);
		}
	}
	my $product_type = $product_ref->{product_type};
	if (not defined $product_type) {
		my $server = $product_ref->{server};
		if ($server) {
			$product_type = product_type_for_server($server);
			$checkpoint->log("$product_id has no product type. Assigned from server $server");
		}
		else {
			my $first_collection = $collection_ids[0];
			if (defined $first_collection) {
				$product_type = (split /_/, $first_collection)[0];
				$checkpoint->log("$product_id has no product type. Assigned $product_type from MongoDB");
			}
			else {
				$product_type = 'food';
				$checkpoint->log("$product_id has no product type. Defaulting to food");
			}
		}
		$product_ref->{product_type} = $product_type;
		# Bypass normal MongoDB logic in store product
		store_object($path, $product_ref);
	}

	my $obsolete_suffix = $product_ref->{obsolete} ? '_obsolete' : '';
	my $expected_collection = $product_type . '_deleted';
	if (not $product_ref->{deleted}) {
		$expected_collection = $product_type . $obsolete_suffix;

		if (not $expected_collection ~~ @collection_ids) {
			$collections{$expected_collection}->insert_one($product_ref);
			$checkpoint->log("$product_id not found in expected $expected_collection collection");
			# If we are adding to food then send an event for query
			if ($expected_collection eq 'food' or $expected_collection = 'food_obsolete') {
				push_product_update_to_redis($product_ref,
					{"userid" => 'fix_mongodb_collections', "comment" => 'Was missing from MongoDB'},
					"reprocessed");
			}
		}
	}
	foreach my $collection_id (@collection_ids) {
		if ($collection_id ne $expected_collection) {
			$collections{$collection_id}->delete_one($filter);
			$checkpoint->log("$product_id ($expected_collection) deleted from $collection_id");

			# If we are deleting from food then send an event for query
			if ($collection_id eq 'food' or $collection_id = 'food_obsolete') {
				push_product_update_to_redis($product_ref,
					{"userid" => 'fix_mongodb_collections', "comment" => "Should not have been in MongoDB"},
					"reprocessed");
			}
		}
	}

	$checkpoint->update($path);

	$count += 1;
	if ($count % 1000 == 0) {
		$checkpoint->log("Processed $count products. Up to $product_id");
	}

	# Sleep for a bit so we don't overwhelm the server
	sleep(0.002);
}
$checkpoint->log("Processed $count products.");
