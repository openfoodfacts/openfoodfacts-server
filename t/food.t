#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Food qw/:all/;

# Based on https://de.wikipedia.org/w/index.php?title=Wasserh%C3%A4rte&oldid=160348959#Einheiten_und_Umrechnung
is( mmoll_to_unit(1, 'mol/l'), 0.001 );
is( mmoll_to_unit('1', 'moll/l'), 1 );
is( mmoll_to_unit(1, 'mmol/l'), 1 );
is( mmoll_to_unit(1, 'mval/l'), 2 );
is( mmoll_to_unit(1, 'ppm'), 100 );
is( mmoll_to_unit(1, "\N{U+00B0}rH"), 40.080 );
is( mmoll_to_unit(1, "\N{U+00B0}fH"), 10.00 );
is( mmoll_to_unit(1, "\N{U+00B0}e"), 7.02 );
is( mmoll_to_unit(1, "\N{U+00B0}dH"), 5.6 );
is( mmoll_to_unit(1, 'gpg'), 5.847 );

is( unit_to_mmoll(1, 'mol/l'), 1000 );
is( unit_to_mmoll('1', 'mmol/l'), 1 );
is( unit_to_mmoll(1, 'mmol/l'), 1 );
is( unit_to_mmoll(1, 'mval/l'), 0.5 );
is( unit_to_mmoll(1, 'ppm'), 0.01 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}rH"), 0.025 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}fH"), 0.1 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}e"), 0.142 );
delta_ok( unit_to_mmoll(1, "\N{U+00B0}dH"), 0.1783 );
delta_ok( unit_to_mmoll(1, 'gpg'), 0.171 );

is( mmoll_to_unit(unit_to_mmoll(1, 'ppm'), "\N{U+00B0}dH"), 0.056 );

done_testing();
