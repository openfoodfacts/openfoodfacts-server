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
update_all_products.pl is a script that updates the latest version of products in the file system and on MongoDB.
It is used in particular to re-run tags generation when taxonomies have been updated.

Usage:

update_all_products.pl --key some_string_value --fields categories,labels --index

The key is used to keep track of which products have been updated. If there are many products and field to updates,
it is likely that the MongoDB cursor of products to be updated will expire, and the script will have to be re-run.

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

# Collection that will be used to iterate products
my $products_collection = get_products_collection({obsolete => $obsolete, timeout => 10000});
my $obsolete_products_collection = get_products_collection({obsolete => 1, timeout => 10000});

my $code = "0000019337470";
my $normalized_code = "19337470";
my $new_code = $normalized_code;
my $old_product_id = $code;
my $new_product_id = product_id_for_owner(undef, $normalized_code);

my $product_ref = retrieve_product($new_product_id, "include_deleted");
$product_ref->{code} = $normalized_code . '';
$product_ref->{id} = $product_ref->{code} . '';    # treat id as string;
$product_ref->{_id} = $new_product_id . '';    # treat id as string;
													# Delete the old code from MongoDB collections
$products_collection->delete_one({_id => $old_product_id});
$obsolete_products_collection->delete_one({_id => $old_product_id});
													# If the product is not deleted, store_product will add the new code to MongoDB
store_product("fix-code-bot", $product_ref, "changed code from $code to $new_code");

exit(0);
