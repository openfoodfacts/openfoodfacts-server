#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Test::Files;
use ProductOpener::Products qw/:all/;
use File::Spec;
use Log::Any::Adapter 'TAP';

use Log::Any qw($log);
use Encode;
use JSON::PP;
use Getopt::Long;
use File::Basename "dirname";
use LWP::Simple "get";
use Data::Dumper;

my $tests_dir = dirname(__FILE__);
my $expected_dir = $tests_dir . "/expected/";

my $product_barcode = "8436019091142";
my $product_api_json = get("https://world.openfoodfacts.org/api/v0/product/$product_barcode.json");
my $product_api = decode_json($product_api_json);

my $expected_json;

open (my $fh, '<', "$expected_dir/product.json") or die "failed to open expected product file";
{
    local $/;
    $expected_json = <$fh>;
}
close ($fh);

my $expected = decode_json($expected_json);

is_deeply($expected, $product_api);

done_testing();

# my $product_id = product_id_for_owner($product_barcode);

# my $product_ref_internal = product_exists($product_id); 

# # returns the product_ref for this ID

# # print $product_ref_internal if ($product_ref_internal defined) else print "not defined";

# if (defined $product_ref_internal) {
#     print Dumper($product_ref_internal);
# } else {
#     print "unsuccessful :((("
# }

# todo save/create a new fake product in local product opener db
# - "get" $product_ref_internal for that product with an internal call to Product::get_product() (or equivalent method)
# - "get" $product_ref_JSON for that product with api call to local deployment of openfoodfacts: GET /api/{product_id}.json (or whatever URL it is)
# - deserialise/convert JSON to Perl object/hash -> $product_ref_API
# - compare contents of $product_ref_internal and $product_ref_API: they should be the same.

