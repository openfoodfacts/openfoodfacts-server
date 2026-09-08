#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::API qw/:all/;
use ProductOpener::APIProductWrite qw/update_product_fields update_components/;

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

my $request = {api_version => 3};

my $customized_components = ProductOpener::API::customize_components($request, $product);

is(
	$customized_components,
	$product->{components},
	"customize_components returns matching structure for multi-food components"
);

# Verify deep clone behavior (mutation of returned structure does not affect original product)
$customized_components->[0]{name} = "Modified Name";
isnt($product->{components}[0]{name}, "Modified Name", "customize_components returns cloned data structure");
$product->{components}[0]{name} = "Brussels Sprouts";

# Test customize_components with undefined components
my $product_no_components = {code => "000000000000"};
my $undef_components = ProductOpener::API::customize_components($request, $product_no_components);
is($undef_components, undef, "customize_components returns undef when components are not defined");

# Test customize_response_for_product requesting components field
my $customized_product = customize_response_for_product($request, $product, "components,code");

is(
	$customized_product->{components},
	$product->{components},
	"customize_response_for_product returns components array when requested"
);
is($customized_product->{code}, "055795740289", "customize_response_for_product returns code");

# Test customize_response_for_product NOT requesting components field
my $customized_product_without_components = customize_response_for_product($request, $product, "code");
is(
	exists $customized_product_without_components->{components},
	F(),
	"customize_response_for_product excludes components field when not requested"
);

# Test writing components data via update_product_fields
my $write_product = {code => "055795740289"};
my $write_request = {
	api_version => 3,
	api_response => ProductOpener::API::get_initialized_response(),
	body_json => {
		product => {
			components => [
				{
					name => "Item 1",
					quantity => "100g",
				},
				{
					name => "Item 2",
					quantity => "50g",
				},
			],
		},
	},
};

update_product_fields($write_request, $write_product, $write_request->{api_response});

is(
	$write_product->{components},
	[
		{
			name => "Item 1",
			quantity => "100g",
		},
		{
			name => "Item 2",
			quantity => "50g",
		},
	],
	"update_product_fields successfully saves components data"
);

# Test appending components via components_add
my $add_request = {
	api_version => 3,
	api_response => ProductOpener::API::get_initialized_response(),
	body_json => {
		product => {
			components_add => [
				{
					name => "Item 3",
					quantity => "25g",
				},
			],
		},
	},
};

update_product_fields($add_request, $write_product, $add_request->{api_response});

is(
	scalar @{$write_product->{components}},
	3,
	"update_product_fields with components_add appends to existing components"
);
is($write_product->{components}[2]{name}, "Item 3", "appended component has correct content");

# Test error handling when components field is not an array
my $invalid_type_product = {code => "055795740289"};
my $invalid_type_request = {
	api_version => 3,
	api_response => ProductOpener::API::get_initialized_response(),
	body_json => {
		product => {
			components => "invalid_string_not_array",
		},
	},
};
update_product_fields($invalid_type_request, $invalid_type_product, $invalid_type_request->{api_response});
is(exists $invalid_type_product->{components}, F(), "components field ignored when not an array");
is(scalar @{$invalid_type_request->{api_response}{errors}}, 1, "error generated for invalid components type");

# Test error handling when a component item is not a hash
my $invalid_item_product = {code => "055795740289"};
my $invalid_item_request = {
	api_version => 3,
	api_response => ProductOpener::API::get_initialized_response(),
	body_json => {
		product => {
			components => ["invalid_string_item"],
		},
	},
};
update_product_fields($invalid_item_request, $invalid_item_product, $invalid_item_request->{api_response});
is(scalar @{$invalid_item_product->{components}}, 0, "non-object component item is not added");
is(scalar @{$invalid_item_request->{api_response}{errors}}, 1, "error generated for non-object component item");

# Verify saved product components can be read back via customize_response_for_product
my $read_back = customize_response_for_product($request, $write_product, "components");
is($read_back->{components}, $write_product->{components}, "saved components are properly read back via API");

done_testing();
