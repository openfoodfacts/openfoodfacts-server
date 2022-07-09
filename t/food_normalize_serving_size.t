#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

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
["43 someinvalidunit (430g)", "430"],
["1500ml", "1500"],
);

foreach my $test_ref (@serving_sizes) {
	is(normalize_serving_size($test_ref->[0]), $test_ref->[1]);
}

#TODO
# if (!defined(normalize_serving_size("20 someinvalidunit")))
# {
# 	return 1;
# }

# if (!defined(normalize_serving_size("15aug")))
# {
# 	return 1;
# }


done_testing();
