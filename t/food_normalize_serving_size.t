#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

my @serving_sizes = (
["100g","100"],
["250 g", "250"],
["1.5kg", "1500"],
["2,5g", "2.5"],
["1 plate (25g)", "25"],
["1 grilled link (82g)", "82"],
["2 buns = 20g", "20"],
);

foreach my $test_ref (@serving_sizes) {
	is(normalize_serving_size($test_ref->[0]), $test_ref->[1]);
}

done_testing();
