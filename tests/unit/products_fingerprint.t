#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use JSON::PP qw(decode_json);
use Test2::V0;
use Storable qw(dclone);
use boolean qw/:all/;

use ProductOpener::Products ();

# Equivalent hashes must fingerprint the same way regardless of key order.
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
	ProductOpener::Products::compute_product_fingerprint($product_a),
	ProductOpener::Products::compute_product_fingerprint($product_b),
	"equivalent hashes have the same fingerprint"
);

# Ignored audit fields must not affect the fingerprint.
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
	ProductOpener::Products::compute_product_fingerprint($ignored_field_a),
	ProductOpener::Products::compute_product_fingerprint($ignored_field_b),
	"ignored audit fields do not affect the fingerprint"
);

# Blessed booleans must fingerprint like plain scalar values.
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
	ProductOpener::Products::compute_product_fingerprint($boolean_field_a),
	ProductOpener::Products::compute_product_fingerprint($boolean_field_b),
	"blessed booleans do not change the fingerprint"
);

# JSON booleans must fingerprint like plain scalar values.
my $json_boolean_field = {
	code => "112",
	nutrition => {
		no_nutrition_data_on_packaging => decode_json('[true]')->[0],
	},
};

is(
	ProductOpener::Products::compute_product_fingerprint($json_boolean_field),
	ProductOpener::Products::compute_product_fingerprint($boolean_field_b),
	"JSON booleans do not change the fingerprint"
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
	ProductOpener::Products::compute_product_fingerprint($ordered_array_a),
	ProductOpener::Products::compute_product_fingerprint($ordered_array_b),
	"array order affects the fingerprint"
);

# Leading and trailing whitespace must not create a new fingerprint.
my $trimmed_a = {
	code => "444",
	foo => "  hello world\t",
};
my $trimmed_b = {
	code => "444",
	foo => "hello world",
};

is(
	ProductOpener::Products::compute_product_fingerprint($trimmed_a),
	ProductOpener::Products::compute_product_fingerprint($trimmed_b),
	"leading and trailing whitespace does not affect the fingerprint"
);

# Meaningful content changes must change the fingerprint.
my $content_a = {
	code => "555",
	product_name => "Alpha",
};
my $content_b = {
	code => "555",
	product_name => "Beta",
};

isnt(
	ProductOpener::Products::compute_product_fingerprint($content_a),
	ProductOpener::Products::compute_product_fingerprint($content_b),
	"meaningful content changes affect the fingerprint"
);

# Fingerprint helpers must not mutate their input.
my $prepare_input = {
	code => "666",
	foo => ["x", "y"],
	nested => {k2 => "v2", k1 => "v1"},
};
my $prepare_input_before = dclone($prepare_input);
my $prepared = ProductOpener::Products::prepare_product_for_fingerprint($prepare_input);
my $digest = ProductOpener::Products::compute_product_fingerprint($prepare_input);

is($prepare_input, $prepare_input_before, "fingerprint helpers do not mutate input");
ok(ref($prepared) eq 'HASH', "prepare_product_for_fingerprint returns a hashref");
ok($digest ne '', "compute_product_fingerprint returns a digest for supported input");

# Unsupported refs must fail open instead of producing a comparable fingerprint.
my $scalar_value = 'test';
my $unsupported_input = {
	code => "888",
	unsupported => \$scalar_value,
};
my $unsupported_prepared = ProductOpener::Products::prepare_product_for_fingerprint($unsupported_input);

is($unsupported_prepared, {}, "unsupported refs collapse the prepared payload");
is(ProductOpener::Products::compute_product_fingerprint($unsupported_input),
	'', "unsupported refs return an empty fingerprint");

done_testing();
