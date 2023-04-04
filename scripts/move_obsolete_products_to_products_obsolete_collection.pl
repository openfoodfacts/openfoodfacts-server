#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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
use ProductOpener::Products qw/:all/;
use ProductOpener::Data qw/:all/;

use Log::Any::Adapter 'TAP';

my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.
my $products_collection = get_products_collection({timeout => $socket_timeout_ms});
my $obsolete_products_collection = get_products_collection({obsolete => 1, timeout => $socket_timeout_ms});

my $products_count = "";

my $query_ref = {obsolete => 'on'};

eval {
	$products_count = $products_collection->count_documents($query_ref);

	print STDERR "$products_count documents to update.\n";
};

my $cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});

$cursor->immortal(1);

my $n = 0;    # number of products updated

while (my $product_ref = $cursor->next) {

	my $productid = $product_ref->{_id};
	my $code = $product_ref->{code};
	my $path = product_path($product_ref);

	my $owner_info = "";
	if (defined $product_ref->{owner}) {
		$owner_info = "- owner: " . $product_ref->{owner} . " ";
	}

	if (not defined $code) {
		print STDERR "code field undefined for product id: "
			. $product_ref->{id}
			. " _id: "
			. $product_ref->{_id} . "\n";
	}
	else {
		print STDERR "updating product code: $code $owner_info ($n / $products_count)\n";
	}

	$product_ref = retrieve_product($productid);

	if ((defined $product_ref) and ($productid ne '')) {

		$product_ref->{_id} .= '';
		$product_ref->{code} .= '';
		$products_collection->delete_one({"_id" => $product_ref->{_id}});
		$obsolete_products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});

		$n++;
	}
	else {
		print STDERR "Unable to load product file for product code $code\n";
	}

}

print "$n products updated\n";

exit(0);
