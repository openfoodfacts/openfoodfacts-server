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

use Modern::Perl '2017';
use utf8;

my $usage = <<TXT
load_products_in_mongodb.pl --product_ids_file file_name

load_products_in_mongodb.pl is a script that loads products from a file containing a list of product ids (one per line) into MongoDB.

It is also possible to use _ids in JSON format from mongoexport:
{"_id":"3564700611494"}

e.g. mongoexport --host 10.1.0.102 --db=off --collection=products --query='{"\$expr": {"\$ne":["\$_id","\$id"]},"data_sources_tags":"producers"}' --fields=_id > off-pro-products-on-off.json
(remove the \ in \$)

The script goes through the list of product ids, retrieves the corresponding products from the file system, and loads them into MongoDB in the right database and collection.
TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve store/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Data qw/get_products_collection/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;

use Log::Any::Adapter 'TAP';

use Getopt::Long;

my $file = "";

GetOptions("product_ids_file=s" => \$file) or die("Error in command line arguments:\n\n$usage");

if (not -e $file) {
	die("The file $file does not exist.\n\n$usage");
}

my $loaded = 0;
my $products = 0;

# Open the file, go through the list of product ids, retrieve the corresponding products from the file system, and load them into MongoDB
open(my $fh, "<", $file) or die("Could not open file $file: $!");
while (my $product_id = <$fh>) {
	$products++;
	chomp($product_id);
	# Parse the product_id if we have a JSON object like {"_id":"3564700611494"}
	if ($product_id =~ m/^\{.*\}$/) {
		my $product_ref = decode_json($product_id);
		$product_id = $product_ref->{_id};
	}
	my $product_ref = retrieve_product($product_id);
	if (not defined $product_ref) {
		say "Product $product_id not found in the file system.";
		next;
	}
	# Get the server and collection for the product that we will write
	my $server = get_server_for_product($product_ref);
	my $products_collection = get_products_collection(
		{database => $options{other_servers}{$server}{mongodb}, obsolete => $product_ref->{obsolete}});
	if ($product_ref->{deleted}) {
		$products_collection->delete_one({"_id" => $product_ref->{_id}});
	}
	else {
		$products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
	}
	say "Product $product_id loaded into MongoDB.";
	$loaded++;
}

say "$loaded products loaded out of $products.";

exit(0);
