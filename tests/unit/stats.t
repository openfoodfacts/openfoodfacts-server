#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Stats qw/add_product_value_to_stats compute_stats_for_products/;

my $values_ref = {};
foreach my $value (7, 11, 2, 9, 1, 5, 10, 3, 8, 4, 6) {
	add_product_value_to_stats($values_ref, "sugars_100g", $value);
}

my $stats_ref = {};
compute_stats_for_products($stats_ref, $values_ref, 12, 11, 5, "en:test");

is(
	$stats_ref->{values}{sugars_100g},
	{
		n => 11,
		mean => 5.5,
		"100g" => 5.5,
		std => 2.87,
		min => 1,
		"10" => 2,
		"50" => 6,
		"90" => 10,
		max => 11,
	},
	"stats are computed on sorted values"
);

done_testing();
