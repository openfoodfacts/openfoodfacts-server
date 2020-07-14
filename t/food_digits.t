#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Food qw/:all/;

my @tests = (
["1", "1"],
["1.001", "1.001"],
["0.000000000000000001", "0.000000000000000001"],
["0.00000001", "0.00000001"],
["0.00200001", "0.002"],
["1.00000001", "1"],
["310.00000001", "310"],
["2.9000000953674", "2.9"],
["0.089999997615814", "0.09"],
["0.89999997615814", "0.9"],
["2.5999999046326", "2.6"],
["2.999999046326", "3"],
["12.9999046326", "13"],
["2.0", "2.0"],
["10.00", "10.00"],
["13.200", "13.200"],
);

foreach my $test_ref (@tests) {

	my $input = $test_ref->[0];
	my $expected = $test_ref->[1];

	is(remove_insignificant_digits($input), $expected);
}


done_testing();
