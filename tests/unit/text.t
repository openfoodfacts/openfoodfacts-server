#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;

use ProductOpener::Text
	qw/normalize_percentages regexp_escape remove_email normalize_unicode_letter_variants get_decimal_formatter get_percent_formatter/;
use Log::Any::Adapter 'TAP';

# Patterns according to Unicode CDLR v29
# Pattern	# Locales using it
# --------------------------------
# #,##,##0 %	1			=> used only in 'dz' locale
# #,##,##0%	9
# #,##0 %	25
# #,##0%	639
# % #,##0	1
# %#,##0	1

# There are some interesting cases to consider, asides from the pattern itself.
# - The decimal sign could be a '.' (most languages), or it could be a ',' (de - DECIMAL POINT IS COMMA ;-)).
# - The group sign (between groups of three) could be nothing, a ',' (ie. en_US), a '.' (de) or a non-breaking space (fr), even though for one locale it will most likely not be the same as the decimal sign.

# ur      #,##,##0%
is(normalize_percentages('test 1234% hi there', 'ur'), 'test 1,234% hi there');
is(normalize_percentages('test 123,456.78% hi there', 'ur'), 'test 1,23,456.78% hi there');
is(normalize_percentages('test 0,12,345.67% hi there', 'ur'), 'test 12,345.67% hi there');
is(normalize_percentages('test 1,002.34% hi there', 'ur'), 'test 1,002.34% hi there');
# de	#,##0\N{U+00A0}%
is(normalize_percentages('test 1234% hi there', 'de'), "test 1.234\N{U+00A0}% hi there");
is(normalize_percentages('test 123.456,78% hi there', 'de'), "test 123.456,78\N{U+00A0}% hi there");
is(normalize_percentages('test 1.023,45% hi there', 'de'), "test 1.023,45\N{U+00A0}% hi there");
is(normalize_percentages('test 1.23.045,67% hi there', 'de'), "test 123.045,67\N{U+00A0}% hi there");
is(normalize_percentages("test 1.23.045,67\N{U+00A0}% hi there", 'de'), "test 123.045,67\N{U+00A0}% hi there");
is(normalize_percentages("test 1.23.045,67 \N{U+00A0} % hi there", 'de'), "test 123.045,67\N{U+00A0}% hi there");

# eu	% #,##0
is(normalize_percentages('test % 1234 hi there', 'eu'), "test %\N{U+00A0}1.234 hi there");
is(normalize_percentages('test %1234 hi there', 'eu'), "test %\N{U+00A0}1.234 hi there");
is(normalize_percentages('test % 123.456,78 hi there', 'eu'), "test %\N{U+00A0}123.456,78 hi there");
is(normalize_percentages('test %123.456,78 hi there', 'eu'), "test %\N{U+00A0}123.456,78 hi there");
is(normalize_percentages("test %\N{U+00A0}123 hi there", 'eu'), "test %\N{U+00A0}123 hi there");
is(normalize_percentages("test %\N{U+00A0} 123,45 hi there", 'eu'), "test %\N{U+00A0}123,45 hi there");

# tr	%#,##0
is(normalize_percentages('test % 1234 hi there', 'tr'), 'test %1.234 hi there');
is(normalize_percentages('test %1234 hi there', 'tr'), 'test %1.234 hi there');
is(normalize_percentages('test % 123.456,78 hi there', 'tr'), 'test %123.456,78 hi there');
is(normalize_percentages('test %123.456,78 hi there', 'tr'), 'test %123.456,78 hi there');

#fr
is(normalize_percentages('2,50%', 'fr'), "2,5\N{U+00A0}%");
# 2.50 should be 2,50 in French, but the form with the . is very common too
is(normalize_percentages('2.50%', 'fr'), "2,5\N{U+00A0}%");
is(normalize_percentages('2.5%', 'fr'), "2,5\N{U+00A0}%");
is(normalize_percentages('2.500%', 'fr'), "2,5\N{U+00A0}%");
is(normalize_percentages('2500%', 'fr'), "2\N{U+00A0}500\N{U+00A0}%");

#en
is(normalize_percentages('2,50%', 'en'), "2.5%");
is(normalize_percentages('2.50%', 'en'), "2.5%");

# --- Additional i18n coverage: RTL and LTR with different symbols ---
# LTR: ja (same symbols as en but Asian locale), ru (NBSP group, comma decimal), hi (Indian grouping)
# RTL: ar (LRM-wrapped %), ar-SA (Arabic percent \N{U+066A}), he/fa (RTL but simple), ur already above

# ja - LTR Asian, standard symbols (., ,)
is(get_decimal_formatter('ja')->format(1234567.89), "1,234,567.89");
is(get_decimal_formatter('ja')->format(1234.56), "1,234.56");
is(get_percent_formatter('ja', 0)->format(0.025), "2%");
is(get_percent_formatter('ja', 2)->format(0.025), "2.5%");
is(normalize_percentages('test 1234% hi', 'ja'), "test 1,234% hi");

# ru - LTR Cyrillic, NBSP group, comma decimal (like fr but Russian)
is(get_decimal_formatter('ru')->format(1234567.89), "1\N{U+00A0}234\N{U+00A0}567,89");
is(get_decimal_formatter('ru')->format(1234.56), "1\N{U+00A0}234,56");
is(get_percent_formatter('ru', 0)->format(0.025), "2\N{U+00A0}%");
is(get_percent_formatter('ru', 2)->format(0.025), "2,5\N{U+00A0}%");
is(normalize_percentages('test 1234% hi', 'ru'), "test 1\N{U+00A0}234\N{U+00A0}% hi");
is(normalize_percentages('2.50%', 'ru'), "2,5\N{U+00A0}%");

# hi - LTR Indian grouping (like ur/dz)
is(get_decimal_formatter('hi')->format(1234567.89), "12,34,567.89");
is(get_decimal_formatter('hi')->format(1234.56), "1,234.56");
is(get_percent_formatter('hi', 0)->format(0.025), "2%");
is(get_percent_formatter('hi', 2)->format(0.025), "2.5%");
is(normalize_percentages('test 123,456.78% hi', 'hi'), "test 1,23,456.78% hi");

# ar - RTL, LRM-wrapped percent (latn numbers)
is(get_decimal_formatter('ar')->format(1234567.89), "1,234,567.89");
is(get_percent_formatter('ar', 0)->format(0.025), "2\N{U+200E}%\N{U+200E}");
is(get_percent_formatter('ar', 2)->format(0.025), "2.5\N{U+200E}%\N{U+200E}");
is(normalize_percentages('test 1234% hi', 'ar'), "test 1,234\N{U+200E}%\N{U+200E} hi");
is(normalize_percentages('2.50%', 'ar'), "2.5\N{U+200E}%\N{U+200E}");

# ar-SA - RTL, Arabic percent sign \N{U+066A} (distinct symbol)
is(get_percent_formatter('ar-SA', 0)->format(0.025), "2\N{U+066A}");
is(get_percent_formatter('ar-SA', 2)->format(0.025), "2.5\N{U+066A}");
is(normalize_percentages('test 1234% hi', 'ar-SA'), "test 1,234\N{U+066A} hi");
is(normalize_percentages('2.50%', 'ar-SA'), "2.5\N{U+066A}");

# he - RTL Hebrew, simple symbols (like en but RTL)
is(get_decimal_formatter('he')->format(1234567.89), "1,234,567.89");
is(get_percent_formatter('he', 0)->format(0.025), "2%");
is(normalize_percentages('test 1234% hi', 'he'), "test 1,234% hi");

# fa - RTL Persian, similar to he
is(get_decimal_formatter('fa')->format(1234567.89), "1,234,567.89");
is(normalize_percentages('test 1234% hi', 'fa'), "test 1,234% hi");

# Test regexp_escape
is(regexp_escape('incl.'), 'incl\\.');
is(regexp_escape('inclx'), 'inclx');

# Test remove_email
is(remove_email('test@example.com'), '');
is(remove_email('test string'), "test string");
is(remove_email('no email address'), 'no email address');

# Unicode bold normalization tests

# Test: no bold characters → unchanged
is(normalize_unicode_letter_variants('Whey Powder (Milk)', '_', '_'), 'Whey Powder (Milk)', 'plain text unchanged');

# Test: empty string
is(normalize_unicode_letter_variants('', '_', '_'), '', 'empty string returns empty string');

# Test: undefined input
is(normalize_unicode_letter_variants(undef, '_', '_'), undef, 'undefined input returns undefined');

is(
	normalize_unicode_letter_variants(
		"Wheat flour (𝐖𝐡𝐞𝐚𝐭), 𝑴𝒊𝒍𝒌 powder, 𝓢𝓸𝔂 lecithin, 𝔈𝔤𝔤 yolk, 𝔼𝕘𝕘 white, "
			. "𝗛𝗮𝘇𝗲𝗹𝗻𝘂𝘁 paste, 𝘊𝘢𝘴𝘩𝘦𝘸 𝘯𝘶𝘵𝘴, 𝙼𝚞𝚜𝚝𝚊𝚛𝚍 seed, Ｓｅｓａｍｅ seeds, "
			. "𝐒𝐨𝐮𝐫 𝐜𝐫𝐞𝐚𝐦, 𝐶𝑒𝑙𝑒𝑟𝑦, salt",
		'_',
		'_'
	),
	"Wheat flour (_Wheat_), _Milk_ powder, _Soy_ lecithin, _Egg_ yolk, _Egg_ white, "
		. "_Hazelnut_ paste, _Cashew nuts_, _Mustard_ seed, _Sesame_ seeds, "
		. "_Sour cream_, _Celery_, salt",
);

is(
	normalize_unicode_letter_variants(
		"Zutaten: 𝐖𝐞𝐢𝐳𝐞𝐧mehl, Voll𝐦𝐢𝐥𝐜𝐡pulver, 𝐇𝐚𝐬𝐞𝐥𝐧ü𝐬𝐬𝐞, Ｓｅｓａｍöl, " . "𝑆𝑜𝑗𝑎lecithin, Salz",
		'_', '_'
	),
	"Zutaten: _Weizen_mehl, Voll_milch_pulver, _Haselnüsse_, _Sesam_öl, " . "_Soja_lecithin, Salz",
);

done_testing();
