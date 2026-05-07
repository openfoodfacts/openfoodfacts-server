#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use JSON::PP qw(decode_json);
use Test2::V0;
use Storable qw(dclone);
use boolean qw/:all/;

use ProductOpener::ProductSchemaChanges qw/$current_schema_version/;
use ProductOpener::Products ();

{

	package Local::JsonBlessed;

	sub TO_JSON {
		my ($self) = @_;
		return {value => $self->{value}};
	}
}

# Changing key order alone should not look like a product change.
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

# These ignored fields should not create a difference by themselves.
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
	"non-meaningful fields do not affect the comparison payload"
);

# A true value should look the same here whether it comes from an object or plain 1.
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
	"boolean objects and plain 1 give the same comparison payload"
);

# A true value from JSON should look the same here as plain 1.
my $json_boolean_field = {
	code => "112",
	nutrition => {
		no_nutrition_data_on_packaging => decode_json('[true]')->[0],
	},
};

is(
	ProductOpener::Products::serialize_product_for_comparison($json_boolean_field),
	ProductOpener::Products::serialize_product_for_comparison($boolean_field_b),
	"JSON booleans and plain values give the same comparison payload"
);

# A supported object should compare through its JSON form.
my $json_blessed_field_a = {
	code => "112b",
	custom => bless({value => "x"}, 'Local::JsonBlessed'),
};
my $json_blessed_field_b = {
	code => "112b",
	custom => {value => "x"},
};

is(
	ProductOpener::Products::serialize_product_for_comparison($json_blessed_field_a),
	ProductOpener::Products::serialize_product_for_comparison($json_blessed_field_b),
	"objects with TO_JSON give the same comparison payload as their JSON form"
);

# A false value should look the same here as plain 0.
my $false_boolean_field = {
	code => "113",
	nutrition => {
		no_nutrition_data_on_packaging => false,
	},
};

my $false_scalar_field = {
	code => "113",
	nutrition => {
		no_nutrition_data_on_packaging => 0,
	},
};

is(
	ProductOpener::Products::serialize_product_for_comparison($false_boolean_field),
	ProductOpener::Products::serialize_product_for_comparison($false_scalar_field),
	"false booleans and plain 0 give the same comparison payload"
);

# Changing the order in an array should still count as a change.
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

# A number should look the same here whether it comes as text or as a number.
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

# Extra spaces at the start or end should not create a difference.
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

# A real text change should still show up.
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
	"meaningful revision changes affect the comparison payload"
);

# These helpers should not change the product we pass in.
my $prepare_input = {
	code => "666",
	foo => ["x", "y"],
	nested => {k2 => "v2", k1 => "v1"},
};
my $prepare_input_before = dclone($prepare_input);
my $prepared = ProductOpener::Products::prepare_product_for_comparison($prepare_input);
my $comparison_json = ProductOpener::Products::serialize_product_for_comparison($prepare_input);

is($prepare_input, $prepare_input_before, "comparison helpers do not mutate input");
is(decode_json($comparison_json), $prepared, "serialize_product_for_comparison returns the prepared payload as JSON");

# Missing values should still be there after we turn the product into JSON and back.
my $undef_scalar_input = {
	code => "777",
	optional_field => undef,
};

is(
	decode_json(ProductOpener::Products::serialize_product_for_comparison($undef_scalar_input)),
	ProductOpener::Products::prepare_product_for_comparison($undef_scalar_input),
	"undefined values stay representable in the comparison payload"
);

# If a value is not safe to compare, the helper should give up.
my $scalar_value = 'test';
my $unsupported_input = {
	code => "888",
	unsupported => \$scalar_value,
};
my $unsupported_prepared = ProductOpener::Products::prepare_product_for_comparison($unsupported_input);

is($unsupported_prepared, {}, "unsupported refs collapse the prepared payload");
is(ProductOpener::Products::serialize_product_for_comparison($unsupported_input),
	'', "unsupported refs return an empty comparison payload");
ok(!ProductOpener::Products::_products_are_equivalent_for_revision($unsupported_input, $trimmed_b),
	"unsupported refs make the revision check false");

# Other objects should still fail open if JSON cannot serialize them.
my $unsupported_blessed_input = {
	code => "889",
	unsupported => bless({}, 'Local::UnsupportedBlessed'),
};

is(ProductOpener::Products::serialize_product_for_comparison($unsupported_blessed_input),
	'', "unsupported blessed values return an empty comparison payload");
ok(!ProductOpener::Products::_products_are_equivalent_for_revision($unsupported_blessed_input, $trimmed_b),
	"unsupported blessed values make the revision check false");

# Bad input should make the helper give up too.
is(ProductOpener::Products::prepare_product_for_comparison(undef),
	{}, "invalid top-level input collapses the prepared payload");

# If JSON encoding is impossible here, the helper should give up.
my $non_serializable_prepared_payload = {code => "890", fh => *STDOUT};
is(ProductOpener::Products::_serialize_prepared_product_for_comparison($non_serializable_prepared_payload),
	undef, "non-serializable payloads return an undefined comparison payload");

# If JSON encoding fails, the revision check should not skip anything.
{
	my $products_module = mock 'ProductOpener::Products' => (
		override => [
			_serialize_prepared_product_for_comparison => sub {undef},
		]
	);

	ok(!ProductOpener::Products::_products_are_equivalent_for_revision($trimmed_a, $trimmed_b),
		"serialization failures make the revision check false");
}

# Restoring the stored product should replace the current one.
my $restore_target = {
	code => "901",
	product_name => "Current",
	rev => 2,
};
my $restore_latest = {
	code => "901",
	product_name => "Persisted",
	rev => 1,
};

ok(ProductOpener::Products::_restore_product_state_from_latest_product($restore_target, $restore_latest),
	"restoring the latest product state succeeds for a stored hash");
is($restore_target, $restore_latest, "restoring the latest product state replaces the local product ref");

# If the stored product cannot be copied safely, restoring it should fail.
ok(
	!ProductOpener::Products::_restore_product_state_from_latest_product({}, []),
	"restoring the latest product state returns false on non-hash data"
);

# A no-op save should still report success and restore the stored state in the local product ref.
{
	my $stored_product_ref = {
		_id => "2999999999199",
		code => "2999999999199",
		complete => 0,
		created_t => 1,
		creator => "test-user",
		last_modified_t => 1,
		last_updated_t => 1,
		popularity_key => 0,
		product_name => "Persisted product",
		product_type => "food",
		rev => 1,
		schema_version => $current_schema_version,
	};
	my $product_ref = dclone($stored_product_ref);
	my $changes_ref = [
		{
			comment => "initial",
			rev => 1,
			t => 1,
			userid => "test-user",
		}
	];
	my $product_path = ProductOpener::Products::product_path($product_ref);
	my $stored_product_path = "$ProductOpener::Products::BASE_DIRS{PRODUCTS}/$product_path/product";
	my $changes_path = "$ProductOpener::Products::BASE_DIRS{PRODUCTS}/$product_path/changes";
	my $noop = sub {return;};
	my $empty = sub {return '';};

	{
		my $products_module = mock 'ProductOpener::Products' => (
			override => [
				add_user_teams => $noop,
				compute_codes => $noop,
				compute_data_sources => $noop,
				compute_keywords => $noop,
				compute_languages => $noop,
				compute_main_countries => $noop,
				compute_product_history_and_completeness => sub {
					my ($product_ref, $changes_ref, $blame_ref) = @_;
					$changes_ref->[-1]{diffs} = {};
					return;
				},
				compute_sort_keys => $noop,
				get_products_collection => sub {return bless({}, 'Local::DummyCollection');},
				get_server_for_product => sub {return 'off';},
				remote_addr => $empty,
				retrieve_object => sub {
					my ($path) = @_;
					if ($path eq $changes_path) {
						return dclone($changes_ref);
					}
					if ($path eq $stored_product_path) {
						return dclone($stored_product_ref);
					}
					return;
				},
				single_param => $empty,
				user_agent => $empty,
			]
		);

		$product_ref->{product_name} = "  Persisted product  ";

		ok(ProductOpener::Products::store_product("test-user", $product_ref, "unit no-op"),
			"no-op saves still report success");
	}

	is($product_ref, $stored_product_ref, "no-op saves restore the stored product in the local product ref");
}

done_testing();
