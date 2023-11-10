#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Units qw/:all/;

# Based on https://de.wikipedia.org/w/index.php?title=Wasserh%C3%A4rte&oldid=160348959#Einheiten_und_Umrechnung
is(mmoll_to_unit(1, 'mol/l'), 0.001);
is(mmoll_to_unit('1', 'mol/l'), 0.001);
is(mmoll_to_unit(1, 'mmol/l'), 1);
is(mmoll_to_unit(1, 'mval/l'), 2);
is(mmoll_to_unit(1, 'ppm'), 100);
delta_ok(mmoll_to_unit(1, "\N{U+00B0}rH"), 40.080);
delta_ok(mmoll_to_unit(1, "\N{U+00B0}fH"), 10.00);
delta_ok(mmoll_to_unit(1, "\N{U+00B0}e"), 7.02);
delta_ok(mmoll_to_unit(1, "\N{U+00B0}dH"), 5.6);
delta_ok(mmoll_to_unit(1, 'gpg'), 5.847);

is(unit_to_mmoll(1, 'mol/l'), 1000);
is(unit_to_mmoll('1', 'mmol/l'), 1);
is(unit_to_mmoll(1, 'mmol/l'), 1);
is(unit_to_mmoll(1, 'mval/l'), 0.5);
is(unit_to_mmoll(1, 'ppm'), 0.01);
delta_ok(unit_to_mmoll(1, "\N{U+00B0}rH"), 0.025);
delta_ok(unit_to_mmoll(1, "\N{U+00B0}fH"), 0.1);
delta_ok(unit_to_mmoll(1, "\N{U+00B0}e"), 0.142);
delta_ok(unit_to_mmoll(1, "\N{U+00B0}dH"), 0.1783);
delta_ok(unit_to_mmoll(1, 'gpg'), 0.171);

delta_ok(mmoll_to_unit(unit_to_mmoll(1, 'ppm'), "\N{U+00B0}dH"), 0.056);

# Chinese Measurements Source: http://www.new-chinese.org/lernwortschatz-chinesisch-masseinheiten.html
# kè - gram - 克
is(normalize_quantity("42\N{U+514B}"), 42);
is(normalize_serving_size("42\N{U+514B}"), 42);
is(unit_to_g(42, "\N{U+514B}"), 42);
is(g_to_unit(42, "\N{U+514B}"), 42);
# gōngkè - gram - 公克 (in use at least in Taïwan)
is(normalize_quantity("42\N{U+516C}\N{U+514B}"), 42);
is(normalize_serving_size("42\N{U+516C}\N{U+514B}"), 42);
is(unit_to_g(42, "\N{U+516C}\N{U+514B}"), 42);
is(g_to_unit(42, "\N{U+516C}\N{U+514B}"), 42);
# héokè - milligram - 毫克
is(normalize_quantity("42000\N{U+6BEB}\N{U+514B}"), 42);
is(normalize_serving_size("42000\N{U+6BEB}\N{U+514B}"), 42);
is(unit_to_g(42000, "\N{U+6BEB}\N{U+514B}"), 42);
is(g_to_unit(42, "\N{U+6BEB}\N{U+514B}"), 42000);
# jīn - pound 500 g - 斤
is(normalize_quantity("84\N{U+65A4}"), 42000);
is(normalize_serving_size("84\N{U+65A4}"), 42000);
is(unit_to_g(84, "\N{U+65A4}"), 42000);
is(g_to_unit(42000, "\N{U+65A4}"), 84);
# gōngjīn - kg - 公斤
is(normalize_quantity("42\N{U+516C}\N{U+65A4}"), 42000);
is(normalize_serving_size("42\N{U+516C}\N{U+65A4}"), 42000);
is(unit_to_g(42, "\N{U+516C}\N{U+65A4}"), 42000);
is(g_to_unit(42000, "\N{U+516C}\N{U+65A4}"), 42);
# háoshēng - milliliter - 毫升
is(normalize_quantity("42\N{U+6BEB}\N{U+5347}"), 42);
is(normalize_serving_size("42\N{U+6BEB}\N{U+5347}"), 42);
is(unit_to_g(42, "\N{U+6BEB}\N{U+5347}"), 42);
is(g_to_unit(42, "\N{U+6BEB}\N{U+5347}"), 42);
# gōngshēng - liter - 公升
is(normalize_quantity("42\N{U+516C}\N{U+5347}"), 42000);
is(normalize_serving_size("42\N{U+516C}\N{U+5347}"), 42000);
is(unit_to_g(42, "\N{U+516C}\N{U+5347}"), 42000);
is(g_to_unit(42000, "\N{U+516C}\N{U+5347}"), 42);

# Russian units

is(unit_to_g(1, "г"), 1);
is(unit_to_g(1, "мг"), 0.001);

# unit conversion tests
# TODO
# if (!defined(unit_to_g(1, "unknown")))
# {
# 	return 1;
# }
is(unit_to_g(1, "kj"), 1);
is(unit_to_g(1, "kcal"), 4);
is(unit_to_g(1000, "kcal"), 4184);
is(unit_to_g(1.2345, "kg"), 1234.5);
is(unit_to_g(1, "kJ"), 1);
is(unit_to_g(10, ""), 10);
is(unit_to_g(10, " "), 10);
is(unit_to_g(10, "% vol"), 10);
is(unit_to_g(10, "%"), 10);
is(unit_to_g(10, "% vol"), 10);
is(unit_to_g(10, "% DV"), 10);
is(unit_to_g(11, "mL"), 11);
is(g_to_unit(42000, "kg"), 42);
is(g_to_unit(28.349523125, "oz"), 1);
is(g_to_unit(29.5735, "fl oz"), 1);
is(g_to_unit(1, "mcg"), 1000000);
is(unit_to_g(1, "lb"), 453.59237);
is(unit_to_g(10, "pounds"), 4535.9237);
is(unit_to_g(10, "livres"), 4535.9237);

is(normalize_quantity("1 г"), 1);
is(normalize_quantity("1 мг"), 0.001);
is(normalize_quantity("1 кг"), 1000);
is(normalize_quantity("1 л"), 1000);
is(normalize_quantity("1 дл"), 100);
is(normalize_quantity("1 кл"), 10);
is(normalize_quantity("1 мл"), 1);

is(normalize_quantity("250G"), 250);
is(normalize_quantity("4 x 25g"), 100);
is(normalize_quantity("4 x25g"), 100);
is(normalize_quantity("4 * 25g"), 100);
is(normalize_quantity("4X2,5L"), 10000);
is(normalize_quantity("1 barquette de 40g"), 40);
is(normalize_quantity("2 barquettes de 40g"), 80);
is(normalize_quantity("6 bouteilles de 33cl"), 6 * 33 * 10);
is(normalize_quantity("10 unités de 170g"), 1700);
is(normalize_quantity("10 unites, 170g"), 170);
is(normalize_quantity("4 bouteilles en verre de 20cl"), 800);
is(normalize_quantity("5 bottles of 20cl"), 100 * 10);
is(normalize_quantity("10 lbs"), 4535.9237);

# Match non standard abbreviations + names in different languages
is(normalize_quantity("2 L"), 2000);
is(normalize_quantity("1 liter"), 1000);
is(normalize_quantity("2 liters"), 2000);
is(normalize_quantity("1 litre"), 1000);
is(normalize_quantity("2 litres"), 2000);
is(normalize_quantity("2 litros"), 2000);
is(normalize_quantity("2 kilograms"), 2000);
is(normalize_quantity("2 kilogrammes"), 2000);
is(normalize_quantity("1.5 gramme"), 1.5);
is(normalize_quantity("2.5 grammes"), 2.5);
is(normalize_quantity("2 kg"), 2000);
is(normalize_quantity("2 kgs"), 2000);
is(normalize_quantity("2 kgr"), 2000);
is(normalize_quantity("2 kilogramme"), 2000);
is(normalize_quantity("2 kilogrammes"), 2000);

# . without a 0 before
is(normalize_quantity(".33L"), 330);
is(normalize_quantity(".33 l"), 330);
is(normalize_serving_size(".33L"), 330);
is(normalize_serving_size("5 bottles (.33L)"), 330);
is(normalize_serving_size("5 bottles .33L"), 330);
is(normalize_serving_size("5 bottles2.33L"), undef);    # Broken string, missing word separator before number

my @serving_sizes = (
	["100g", "100"],
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
	is(normalize_serving_size($test_ref->[0]), $test_ref->[1]) or diag explain $test_ref;
}

done_testing();
