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
check_products_in_mongodb.pl - Check products in MongoDB
- verify that the code is normalized

Usage:

update_all_products.pl [--fix] [--query filters]

--fix		fix the non-normalized codes: delete the old code from MongoDB collections, and store the product again with the new code

Query filters:

--query some_field=some_value (e.g. categories_tags=en:beers)	filter the products (--query parameters can be repeated to have multiple filters)
--query some_field=-some_value	match products that don't have some_value for some_field
--query some_field=value1,value2	match products that have value1 and value2 for some_field (must be a _tags field)
--query some_field=value1\|value2	match products that have value1 or value2 for some_field (must be a _tags field)
TXT
	;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve store/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/process_image_crop/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Data qw/get_products_collection/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Redis qw/push_to_redis_stream/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Data::DeepAccess qw(deep_get deep_exists deep_set);
use Data::Compare;

use Log::Any::Adapter 'TAP';

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

# Get a list of all products
# Use query filters entered using --query categories_tags=en:plant-milks

# Build the mongodb query from the --query parameters
my $query_ref = {};

add_params_to_query($query_params_ref, $query_ref);

# On the producers platform, require --query owners_tags to be set, or the --all-owners field to be set.

if ((defined $server_options{private_products}) and ($server_options{private_products})) {
	if ((not $all_owners) and (not defined $query_ref->{owners_tags})) {
		print STDERR "On producers platform, --query owners_tags=... or --all-owners must be set.\n";
		exit();
	}
}

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);

my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

# Collection that will be used to iterate products
my $products_collection = get_products_collection({obsolete => $obsolete, timeout => $socket_timeout_ms});

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

my $products_count = "";

eval {
	$products_count = $products_collection->count_documents($query_ref);

	print STDERR "$products_count documents to check.\n";
};

# only retrieve important fields
my $cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});

$cursor->immortal(1);

my %codes_lengths = ();
my $code_different_than_id = 0;
my $not_normalized_code = 0;
my $invalid = 0;
my $exists_only_in_db = 0;
my $i = 0;

while (my $product_ref = $cursor->next) {

	my $productid = $product_ref->{_id};
	my $code = $product_ref->{code};
	my $path = product_path($product_ref);

	my $code_len = length($code);
	if (not defined $codes_lengths{$code_len}) {
		$codes_lengths{$code_len} = 0;
	}
	$codes_lengths{$code_len}++;

	my $to_be_fixed = 0;
	my $normalized_code = normalize_code($code);

	if ($code ne $productid) {
		$code_different_than_id++;
		print STDERR "Code different than productid. code: $code - productid: $productid\n";
		$to_be_fixed = 1;
	}
	elsif ($normalized_code eq 'invalid') {
		$invalid++;
		$to_be_fixed = 1;
		print STDERR "Invalid code: $code\n";
	}
	elsif ($code ne $normalized_code) {
		$not_normalized_code++;
		$to_be_fixed = 1;
		print STDERR "Not normalized code. code: $code - normalized: $normalized_code\n";
	}
	elsif (!-e "$data_root/products/$path/product.sto") {
		$to_be_fixed = 1;
		$exists_only_in_db++;
		print STDERR "Product $productid - data_root/products/$path/product.sto does not exist in the filesystem\n";
	}

	if ($fix and $to_be_fixed) {

		my $new_code = $normalized_code;
		my $old_product_id = $code;
		my $new_product_id = product_id_for_owner(undef, $normalized_code);

		# Delete the old code from MongoDB collections
		print STDERR "Deleting old product id $old_product_id (new one is $new_product_id)\n";
		$current_products_collection->delete_one({_id => $old_product_id});
		$obsolete_products_collection->delete_one({_id => $old_product_id});

		my $product_ref = retrieve_product($new_product_id, "include_deleted");
		if (defined $product_ref) {
			print STDERR "Product $new_product_id already exists with code: "
				. $product_ref->{code}
				. " - id: "
				. $product_ref->{id}
				. " -- saving it again with new code, id, _id\n";
			$product_ref->{code} = $normalized_code . '';
			$product_ref->{id} = $product_ref->{code} . '';    # treat id as string;
			$product_ref->{_id} = $new_product_id . '';    # treat id as string;

			# If the product is not deleted, store_product will add the new code to MongoDB
			store_product(
				"fix-code-bot", $product_ref, "changed code from $code to $new_code
"
			);
		}
		else {
			print STDERR "Product $new_product_id does not exist\n";
		}

	}

	$i++;
	($i % 1000 == 0) and print STDERR "$i products checked\n";
}

# Print the code lengths
print STDERR "Code lengths:\n";
foreach my $code_len (sort {$a <=> $b} keys %codes_lengths) {
	print STDERR "$code_len: $codes_lengths{$code_len}\n";
}

print STDERR "Code different than id: $code_different_than_id\n";
print STDERR "Not normalized code: $not_normalized_code\n";
print STDERR "Products that existed only in MongoDB: $exists_only_in_db\n";

exit(0);
