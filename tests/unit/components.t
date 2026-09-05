#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::API qw/:all/;

# Test customize_components function directly
my $product = {
    code => "055795740289",
    components => [
        {
            name => "Brussels Sprouts",
            quantity => "85g",
            serving_size => "1 cup (85 g)",
            nutriments => {
                "energy-kcal" => 45,
                fat => 0,
                sodium => 10,
                fiber => 4,
                sugars => 4,
            },
        },
        {
            name => "Liquid Gold Glaze",
            quantity => "14g",
            serving_size => "1 tbsp (14 g)",
            nutriments => {
                "energy-kcal" => 70,
                fat => 6,
                sodium => 270,
                fiber => 0,
                sugars => 4,
            },
        },
    ],
};

my $request = { api_version => 3 };

my $customized_components = ProductOpener::API::customize_components($request, $product);

is($customized_components, $product->{components}, "customize_components returns matching structure for multi-food components");

# Test customize_response_for_product requesting components field
my $customized_product = customize_response_for_product($request, $product, "components,code");

is($customized_product->{components}, $product->{components}, "customize_response_for_product returns components array when requested");
is($customized_product->{code}, "055795740289", "customize_response_for_product returns code");

done_testing();
