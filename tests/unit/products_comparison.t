#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use JSON::PP qw(decode_json);
use Test2::V0;
use Storable qw(dclone);
use boolean qw/:all/;

use ProductOpener::Products ();

# Equivalent products must compare the same way regardless of key order.
my $product_a = {
	code => "1234567890123",
	name => {default => "Example", localized => {fr => "Exemple", en => "Example"}},
	nutrition => {energy_kj => 1000, fat => 10},
};

my $product_b = {
	nutrition => {fat => 10, energy_kj => 1000},
	name => {localized => {en => "Example", fr => "Exemple"}, default => "Example"},
	code => "1234567890123",
};

is(
	ProductOpener::Products::serialize_product_for_comparison($product_a),
	ProductOpener::Products::serialize_product_for_comparison($product_b),
	"equivalent products have the same comparison payload"
);

# Ignored audit fields must not affect the comparison payload.
my $ignored_field_a = {
	code => "111",
	product_name => "Example",
	rev => 1,
};
my $ignored_field_b = {
	code => "111",
	product_name => "Example",
	rev => 99,
};

is(
	ProductOpener::Products::serialize_product_for_comparison($ignored_field_a),
	ProductOpener::Products::serialize_product_for_comparison($ignored_field_b),
	"ignored audit fields do not affect the comparison payload"
);

# Blessed booleans must compare like plain scalar values.
my $boolean_field_a = {
	code => "112",
	nutrition => {
		no_nutrition_data_on_packaging => true,
	},
};
my $boolean_field_b = {
	code => "112",
	nutrition => {
		no_nutrition_data_on_packaging => 1,
	},
};

is(
	ProductOpener::Products::serialize_product_for_comparison($boolean_field_a),
	ProductOpener::Products::serialize_product_for_comparison($boolean_field_b),
	"blessed booleans do not change the comparison payload"
);

# JSON booleans must compare like plain scalar values.
my $json_boolean_field = {
	code => "112",
	nutrition => {
		no_nutrition_data_on_packaging => decode_json('[true]')->[0],
	},
};

is(
	ProductOpener::Products::serialize_product_for_comparison($json_boolean_field),
	ProductOpener::Products::serialize_product_for_comparison($boolean_field_b),
	"JSON booleans do not change the comparison payload"
);

# Array order must remain significant.
my $ordered_array_a = {
	code => "333",
	foo => ["a", "b"],
};
my $ordered_array_b = {
	code => "333",
	foo => ["b", "a"],
};

isnt(
	ProductOpener::Products::serialize_product_for_comparison($ordered_array_a),
	ProductOpener::Products::serialize_product_for_comparison($ordered_array_b),
	"array order affects the comparison payload"
);

# Numeric scalars and numeric strings with the same lexical value must compare the same way.
my $typed_scalar_a = {
	code => "444",
	nutriments => {
		salt_100g => "3",
	},
};
my $typed_scalar_b = {
	code => "444",
	nutriments => {
		salt_100g => 3,
	},
};

is(
	ProductOpener::Products::serialize_product_for_comparison($typed_scalar_a),
	ProductOpener::Products::serialize_product_for_comparison($typed_scalar_b),
	"numeric scalars and numeric strings with the same lexical value have the same comparison payload"
);

# Leading and trailing whitespace must not create a new comparison payload.
my $trimmed_a = {
	code => "445",
	foo => "  hello world\t",
};
my $trimmed_b = {
	code => "445",
	foo => "hello world",
};

is(
	ProductOpener::Products::serialize_product_for_comparison($trimmed_a),
	ProductOpener::Products::serialize_product_for_comparison($trimmed_b),
	"leading and trailing whitespace does not affect the comparison payload"
);

# Meaningful content changes must change the comparison payload.
my $content_a = {
	code => "555",
	product_name => "Alpha",
};
my $content_b = {
	code => "555",
	product_name => "Beta",
};

isnt(
	ProductOpener::Products::serialize_product_for_comparison($content_a),
	ProductOpener::Products::serialize_product_for_comparison($content_b),
	"meaningful content changes affect the comparison payload"
);

# Comparison helpers must not mutate their input.
my $prepare_input = {
	code => "666",
	foo => ["x", "y"],
	nested => {k2 => "v2", k1 => "v1"},
};
my $prepare_input_before = dclone($prepare_input);
my $prepared = ProductOpener::Products::prepare_product_for_comparison($prepare_input);
my $comparison_json = ProductOpener::Products::serialize_product_for_comparison($prepare_input);

is($prepare_input, $prepare_input_before, "comparison helpers do not mutate input");
ok(ref($prepared) eq 'HASH', "prepare_product_for_comparison returns a product structure");
ok($comparison_json ne '', "serialize_product_for_comparison returns a comparison payload for supported input");
is(decode_json($comparison_json),
	$prepared, "serialize_product_for_comparison returns the prepared payload as canonical JSON");

# Unsupported refs must fail open instead of producing a comparable payload.
my $scalar_value = 'test';
my $unsupported_input = {
	code => "888",
	unsupported => \$scalar_value,
};
my $unsupported_prepared = ProductOpener::Products::prepare_product_for_comparison($unsupported_input);

is($unsupported_prepared, {}, "unsupported refs collapse the prepared payload");
is(ProductOpener::Products::serialize_product_for_comparison($unsupported_input),
	'', "unsupported refs return an empty comparison payload");

done_testing();
