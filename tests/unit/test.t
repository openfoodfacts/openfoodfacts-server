#!/usr/bin/perl -w

# Test some Test.pm utils

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Test qw/normalize_object_for_test_comparison normalize_product_for_test_comparison/;

sub get_obj() {
	return {
		"a" => {
			"b" => [
				{"c" => [{"e" => 1, "f" => 2}, {"e" => 3, "f" => 4}], "d" => 5},
				{"c" => [{"e" => 6, "f" => 7}], "d" => 8}
			]
		},
		"x" => {"y" => {"c" => [{"e" => 9, "f" => 10}]}, "z" => 11}
	};
}

my $obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["a", "x.y"]});
is(
	$obj,
	{
		"a" => "--ignore--",
		"x" => {"y" => "--ignore--", "z" => 11},
	}
);
# arrays with *
$obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["a.b.*.c.*.e"]});
is(
	$obj,
	{
		"a" => {
			"b" => [
				{"c" => [{"e" => "--ignore--", "f" => 2}, {"e" => "--ignore--", "f" => 4}], "d" => 5},
				{"c" => [{"e" => "--ignore--", "f" => 7}], "d" => 8}
			]
		},
		"x" => {"y" => {"c" => [{"e" => 9, "f" => 10}]}, "z" => 11},
	}
);
# hashmap with *
$obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["x.*.c"]});
is(
	$obj,
	{
		"a" => {
			"b" => [
				{"c" => [{"e" => 1, "f" => 2}, {"e" => 3, "f" => 4}], "d" => 5},
				{"c" => [{"e" => 6, "f" => 7}], "d" => 8}
			]
		},
		"x" => {"y" => {"c" => "--ignore--"}, "z" => 11},
	}
);
# consecutive *
$obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["a.*.*.*.*.e", "x.*.*.*.f"]});
is(
	$obj,
	{
		"a" => {
			"b" => [
				{"c" => [{"e" => "--ignore--", "f" => 2}, {"e" => "--ignore--", "f" => 4}], "d" => 5},
				{"c" => [{"e" => "--ignore--", "f" => 7}], "d" => 8}
			]
		},
		"x" => {"y" => {"c" => [{"e" => 9, "f" => "--ignore--"}]}, "z" => 11},
	}
);
# starting with *
$obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["*.b"]});
is(
	$obj,
	{
		"a" => {"b" => "--ignore--"},
		"x" => {"y" => {"c" => [{"e" => 9, "f" => 10}]}, "z" => 11}
	}
);
# non existing field should not be a problem
$obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["r.s.t"]});
is(
	$obj,
	{
		"a" => {
			"b" => [
				{"c" => [{"e" => 1, "f" => 2}, {"e" => 3, "f" => 4}], "d" => 5},
				{"c" => [{"e" => 6, "f" => 7}], "d" => 8}
			]
		},
		"x" => {"y" => {"c" => [{"e" => 9, "f" => 10}]}, "z" => 11}
	}
);
# final star for a hashmap
$obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["x.y.c.*.*"]});
is(
	$obj,
	{
		"a" => {
			"b" => [
				{"c" => [{"e" => 1, "f" => 2}, {"e" => 3, "f" => 4}], "d" => 5},
				{"c" => [{"e" => 6, "f" => 7}], "d" => 8},
			]
		},
		"x" => {"y" => {"c" => [{"e" => "--ignore--", "f" => "--ignore--"}]}, "z" => 11}
	}
);
# final star for an array
$obj = get_obj();
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["a.b.*"]});
is(
	$obj,
	{
		"a" => {
			"b" => ["--ignore--", "--ignore--",]
		},
		"x" => {"y" => {"c" => [{"e" => 9, "f" => 10}]}, "z" => 11}
	}
);

# {tags_sources}{allergens}{ingredients}{last_updated_t}
$obj = {
	tags_sources => {
		allergens => {
			ingredients => {
				last_updated_t => 1234567890
			}
		}
	}
};
normalize_object_for_test_comparison($obj, {fields_ignore_content => ["tags_sources.*.*.last_updated_t"]});
is(
	$obj,
	{
		tags_sources => {
			allergens => {
				ingredients => {
					last_updated_t => "--ignore--"
				}
			}
		}
	}
);

$obj = {
	tags_sources => {
		allergens => {
			ingredients => {
				last_updated_t => 1234567890
			}
		}
	}
};
normalize_product_for_test_comparison($obj);
is(
	$obj,
	{
		tags_sources => {
			allergens => {
				ingredients => {
					last_updated_t => "--ignore--"
				}
			}
		}
	}
);

done_testing();
