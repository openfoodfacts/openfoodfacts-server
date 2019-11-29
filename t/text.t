#!/usr/bin/perl -w

use Modern::Perl '2017';

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Text qw/:all/;

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
is( normalize_percentages('test 1234% hi there', 'ur'), 'test 1,234% hi there' );
is( normalize_percentages('test 123,456.78% hi there', 'ur'), 'test 1,23,456.78% hi there' );

# de	#,##0\N{U+00A0}%
is( normalize_percentages('test 1234% hi there', 'de'), "test 1.234\N{U+00A0}% hi there" );
is( normalize_percentages('test 123.456,78% hi there', 'de'), "test 123.456,78\N{U+00A0}% hi there" );

# eu	% #,##0
is( normalize_percentages('test % 1234 hi there', 'eu'), "test %\N{U+00A0}1.234 hi there" );
is( normalize_percentages('test %1234 hi there', 'eu'), "test %\N{U+00A0}1.234 hi there" );
is( normalize_percentages('test % 123.456,78 hi there', 'eu'), "test %\N{U+00A0}123.456,78 hi there" );
is( normalize_percentages('test %123.456,78 hi there', 'eu'), "test %\N{U+00A0}123.456,78 hi there" );

# tr	%#,##0
is( normalize_percentages('test % 1234 hi there', 'tr'), 'test %1.234 hi there' );
is( normalize_percentages('test %1234 hi there', 'tr'), 'test %1.234 hi there' );
is( normalize_percentages('test % 123.456,78 hi there', 'tr'), 'test %123.456,78 hi there' );
is( normalize_percentages('test %123.456,78 hi there', 'tr'), 'test %123.456,78 hi there' );

done_testing();
