#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Booleans qw/normalize_boolean/;

use boolean qw/:all/;

my @tests = (
	[undef, false],
	[true, true],
	[false, false],
	[1, true],
	[0, false],
	["true", true],
	["false", false],
	["1", true],
	["0", false],
	["on", true],
	["off", false],
	["", false],
	["checked", true],
);

foreach my $test_ref (@tests) {

	my $input = $test_ref->[0];
	my $expected = $test_ref->[1];

	is(normalize_boolean($input), $expected);
}

done_testing();
