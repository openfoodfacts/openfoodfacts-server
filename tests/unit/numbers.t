#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Numbers
	qw/convert_string_to_number remove_insignificant_digits $fraction_regexp convert_fraction_to_number/;

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

@tests = (
	["1", "1"],
	["1.0", "1.0"],
	["2,2", "2.2"],
	["2,20", "2.20"],
	["100 000", "100000"],
	["33,000,000", "33000000"],
	["3,760,00", "3760"],
	["1,000.22", "1000.22"],
);

foreach my $test_ref (@tests) {

	my $input = $test_ref->[0];
	my $expected = $test_ref->[1];

	is(convert_string_to_number($input), $expected + 0);
}

# Fractions
@tests = (
	["½", 0.5],
	["¼", 0.25],
	["¾", 0.75],
	["⅓", 1 / 3],
	["⅞", 0.875],
	["1½", 1.5],
	["2 ¼", 2.25],
	["1/2", 0.5],
	["3/4", 0.75],
	["2/3", 2 / 3],
	["1 / 8", 0.125],
	["1 1/2", 1.5],
	["3⁄4", 0.75],    # Unicode fraction slash
					  # Not proper fractions or not fractions
	["3/2", undef],
	["2/2", undef],
	["1/0", undef],
	["12", undef],
	["1.5", undef],
	["abc", undef],
	["", undef],
	[undef, undef],
);

foreach my $test_ref (@tests) {

	my ($input, $expected) = @$test_ref;

	is(convert_fraction_to_number($input), $expected, "convert_fraction_to_number(" . ($input // 'undef') . ")");
}

# $fraction_regexp matches fractions in a text
@tests = (
	["½ litre de lait", "½"],
	["1 1/2 tasse de farine", "1 1/2"],
	["1½ kg de pommes de terre", "1½"],
	["3/4 cup sugar", "3/4"],
	["1/12 cake", "1/12"],
	["2 eggs", undef],
	["E322/E333", undef],
);

foreach my $test_ref (@tests) {

	my ($input, $expected) = @$test_ref;

	my $match = ($input =~ /^($fraction_regexp)/) ? $1 : undef;
	is($match, $expected, "fraction_regexp on $input");
}

done_testing();
