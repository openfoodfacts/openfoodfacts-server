#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Storable qw(dclone);

use ProductOpener::Products qw/prepare_product_for_fingerprint compute_product_fingerprint/;

# Fingerprints are deterministic for equivalent data with different hash key order.
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
	compute_product_fingerprint($product_a),
	compute_product_fingerprint($product_b),
	"deterministic fingerprint for identical content with different hash key order"
);

# A known ignored audit field should not affect the fingerprint.
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
	compute_product_fingerprint($ignored_field_a),
	compute_product_fingerprint($ignored_field_b),
	"ignored top-level fields do not affect fingerprint"
);

# Array order remains significant.
my $ordered_array_a = {
	code => "333",
	foo => ["a", "b"],
};
my $ordered_array_b = {
	code => "333",
	foo => ["b", "a"],
};

isnt(
	compute_product_fingerprint($ordered_array_a),
	compute_product_fingerprint($ordered_array_b),
	"array order affects fingerprint"
);

# Leading and trailing whitespace is ignored for scalar strings.
my $trimmed_a = {
	code => "444",
	foo => "  hello world\t",
};
my $trimmed_b = {
	code => "444",
	foo => "hello world",
};

is(
	compute_product_fingerprint($trimmed_a),
	compute_product_fingerprint($trimmed_b),
	"leading and trailing whitespace does not affect fingerprint for scalar strings"
);

# Numeric-looking scalars should be type-stable across Perl scalar flags.
my $numeric_string_a = {
	code => "448",
	images => {
		selected => {
			front => {
				en => {
					imgid => 3,
					rev => 19,
				},
			},
		},
	},
};
my $numeric_string_b = {
	code => "448",
	images => {
		selected => {
			front => {
				en => {
					imgid => "3",
					rev => "19",
				},
			},
		},
	},
};

is(
	compute_product_fingerprint($numeric_string_a),
	compute_product_fingerprint($numeric_string_b),
	"numeric and string scalar representations with same lexical value produce the same fingerprint"
);

# Lexical differences that carry information should still affect the fingerprint.
my $numeric_lexical_a = {
	code => "449",
	value => 3,
};
my $numeric_lexical_b = {
	code => "449",
	value => "03",
};

isnt(
	compute_product_fingerprint($numeric_lexical_a),
	compute_product_fingerprint($numeric_lexical_b),
	"lexically different scalar values remain fingerprint-significant"
);

# Meaningful content changes must affect the fingerprint.
my $content_a = {
	code => "555",
	product_name => "Alpha",
};
my $content_b = {
	code => "555",
	product_name => "Beta",
};

isnt(
	compute_product_fingerprint($content_a),
	compute_product_fingerprint($content_b),
	"meaningful content change affects fingerprint"
);

# prepare_product_for_fingerprint should not mutate input.
my $prepare_input = {
	code => "666",
	foo => ["en:z", "en:a"],
	nested => {k2 => "v2", k1 => "v1"},
};
my $prepare_input_before = dclone($prepare_input);
my $prepared = prepare_product_for_fingerprint($prepare_input);

is($prepare_input, $prepare_input_before, "prepare_product_for_fingerprint does not mutate input");
ok(ref($prepared) eq 'HASH', "prepare_product_for_fingerprint returns a hashref");

# compute_product_fingerprint should not mutate input.
my $compute_input = {
	code => "777",
	foo => ["x", "y"],
};
my $compute_input_before = dclone($compute_input);
my $digest = compute_product_fingerprint($compute_input);

is($compute_input, $compute_input_before, "compute_product_fingerprint does not mutate input");
ok(defined($digest) && ($digest ne ''), "compute_product_fingerprint returns a digest");

done_testing();
