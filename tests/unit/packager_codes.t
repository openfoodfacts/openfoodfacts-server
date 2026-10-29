#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::PackagerCodes qw/localize_packager_code normalize_packager_codes/;

# initial tests
is(normalize_packager_codes("emb54253"), "EMB 54253");

is(normalize_packager_codes("ES 12.0664/C CE"), "ES 12.0664/C EC");
is(normalize_packager_codes("ES 12.0664/C EC"), "ES 12.0664/C EC");
is(normalize_packager_codes("ES 12.0664/C EC, ES 14.0434/A EC"), "ES 12.0664/C EC, ES 14.0434/A EC");

# normalize_fr_ce_code
is(normalize_packager_codes("france 69.238.010 ec"), "FR 69.238.010 EC", "FR: normalized code correctly");
is(
	normalize_packager_codes(normalize_packager_codes("france 69.238.010 ec")),
	"FR 69.238.010 EC",
	"FR: normalizing code twice does not change it any more than normalizing once"
);

# normalize_uk_ce_code
is(normalize_packager_codes("uk dz7131 eg"), "UK DZ7131 EC", "UK: normalized code correctly");
is(normalize_packager_codes(normalize_packager_codes("uk dz7131 eg")),
	"UK DZ7131 EC", "UK: normalizing code twice does not change it any more than normalizing once");

# normalize_es_ce_code
is(normalize_packager_codes("NO-RGSEAA-21-21552-SE"), "ES 21.21552/SE EC", "ES: normalized NO-code correctly");
is(normalize_packager_codes("ES 26.06854/T EC"), "ES 26.06854/T EC", "ES I: normalized code correctly");
is(normalize_packager_codes("ES 26.06854/T C EC"), "ES 26.06854/T C EC", "ES II: normalized code correctly");
is(
	normalize_packager_codes(normalize_packager_codes("ES 26.06854/T EC")),
	"ES 26.06854/T EC",
	"ES I: normalizing code twice does not change it any more than normalizing once"
);
is(
	normalize_packager_codes(normalize_packager_codes("ES 26.06854/T C EC")),
	"ES 26.06854/T C EC",
	"ES II: normalizing code twice does not change it any more than normalizing once"
);

# normalize_lu_ce_code - currently does not work as commented
# is (normalize_packager_codes("LU L-2"), "LU L2", "LU: normalized code correctly");
# is (normalize_packager_codes(normalize_packager_codes("LU L-2")), "LU L2", "LU: normalizing code twice does not change it any more than normalizing once");

# normalize_rs_ce_code
is(normalize_packager_codes("RS 731"), "RS 731 EC", "RS: normalized code correctly");
is(normalize_packager_codes(normalize_packager_codes("RS 731")),
	"RS 731 EC", "RS: normalizing code twice does not change it any more than normalizing once");
is(normalize_packager_codes("RS-1022"), "RS 1022 EC", "RS: normalized code correctly");
is(normalize_packager_codes("RS-40-004"), "RS 40-004 EC", "RS: normalized code correctly");
is(normalize_packager_codes("RS-1"), "RS 1 EC", "RS: normalized code correctly");

# normalize_ce_code - countries whose inner separators are insignificant are stripped,
# as done for UK codes, so that differently written variants of the same code
# are stored as one tag (https://github.com/openfoodfacts/openfoodfacts-server/issues/14961)
is(normalize_packager_codes("de by-718 ec"), "DE BY718 EC", "DE: normalized code correctly");
is(normalize_packager_codes(normalize_packager_codes("de by-718 ec")),
	"DE BY718 EC", "DE: normalizing code twice does not change it any more than normalizing once");

is(normalize_packager_codes("de by-777-23 ec"), "DE BY77723 EC", "DE: inner separators stripped");
is(normalize_packager_codes("de by77723 ec"), "DE BY77723 EC", "DE: inner separators stripped");
is(normalize_packager_codes("nl z-0160 eg"), "NL Z0160 EC", "NL: inner separators stripped");
is(normalize_packager_codes("nl z0160 eg"), "NL Z0160 EC", "NL: inner separators stripped");
is(normalize_packager_codes("pt c-249-1p ec"), "PT C2491P EC", "PT: inner separators stripped");
is(normalize_packager_codes("at 30-960 eg"), "AT 30960 EC", "AT: inner separators stripped");
is(normalize_packager_codes("pl 22-121-818 we"), "PL 22121818 EC", "PL: inner separators stripped");
is(normalize_packager_codes(normalize_packager_codes("at 30-960 eg")),
	"AT 30960 EC", "AT: normalizing code twice does not change it any more than normalizing once");

# countries whose inner separators are significant are left untouched
is(normalize_packager_codes("be m-322-a ec"), "BE M-322-A EC", "BE: inner separators preserved");
is(normalize_packager_codes("be m322-a ec"), "BE M322-A EC", "BE: inner separators preserved");
# These identifiers belong to distinct establishments in BE-merge-UTF-8.tsv.
foreach my $code ("1/11", "11/1", "13/1", "131", "1/31") {
	is(normalize_packager_codes("BE $code EC"), "BE $code EC", "BE: preserve distinct establishment $code");
}
is(normalize_packager_codes("it 180-1 ec"), "IT 180-1 EC", "IT: inner separators preserved");
is(normalize_packager_codes("it 1801 ec"), "IT 1801 EC", "IT: inner separators preserved");

is(normalize_packager_codes("PL 14281601 WE"), "PL 14281601 EC", "PL: normalized code correctly");
is(
	localize_packager_code(normalize_packager_codes("PL 14281601 WE")),
	"PL 14281601 WE",
	"PL: normalized code correctly"
);

is(normalize_packager_codes("FI 4201 EY"), "FI 4201 EC", "FI: normalized code correctly");
is(normalize_packager_codes("FI 305-1 EY"), "FI 305-1 EC", "FI: normalized code correctly");
is(normalize_packager_codes("FI F07551 EY"), "FI F07551 EC", "FI: normalized code correctly");
is(normalize_packager_codes("FI FI219 EY"), "FI FI219 EC", "FI: normalized code correctly");
is(normalize_packager_codes("FI S837106 EY"), "FI S837106 EC", "FI: normalized code correctly");
is(normalize_packager_codes(normalize_packager_codes("FI 4201 EY")),
	"FI 4201 EC", "FI: normalizing code twice does not change it any more than normalizing once");
is(localize_packager_code(normalize_packager_codes("FI 4201 EY")), "FI 4201 EY", "FI: round-tripped code correctly");

is(normalize_packager_codes("EE 110 EÜ"), "EE 110 EC", "EE: normalized code correctly");
is(normalize_packager_codes(normalize_packager_codes("EE 110 EÜ")),
	"EE 110 EC", "EE: normalizing code twice does not change it any more than normalizing once");
is(localize_packager_code(normalize_packager_codes("EE 110 EÜ")), "EE 110 EÜ", "EE: round-tripped code correctly");

done_testing();
