#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::PackagerCodes qw/localize_packager_code normalize_packager_codes %packager_codes/;
use ProductOpener::Display qw/get_packager_code_coordinates/;

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

# normalize_ce_code
is(normalize_packager_codes("de by-718 ec"), "DE BY-718 EC", "DE: normalized code correctly");
is(normalize_packager_codes(normalize_packager_codes("de by-718 ec")),
	"DE BY-718 EC", "DE: normalizing code twice does not change it any more than normalizing once");

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

# get_packager_code_coordinates
$packager_codes{"test-code-empty-coords"} = {cc => "fr", lat => "", lng => ""};
my ($empty_lat, $empty_lng) = get_packager_code_coordinates("test-code-empty-coords");
is($empty_lat, undef, "Empty latitude returns undef");
is($empty_lng, undef, "Empty longitude returns undef");

$packager_codes{"test-code-invalid-coords"} = {cc => "fr", lat => "invalid", lng => "not-a-number"};
my ($invalid_lat, $invalid_lng) = get_packager_code_coordinates("test-code-invalid-coords");
is($invalid_lat, undef, "Invalid non-numeric latitude returns undef");
is($invalid_lng, undef, "Invalid non-numeric longitude returns undef");

$packager_codes{"test-code-inf-coords"} = {cc => "fr", lat => "Inf", lng => "-Inf"};
my ($inf_lat, $inf_lng) = get_packager_code_coordinates("test-code-inf-coords");
is($inf_lat, undef, "Inf latitude returns undef");
is($inf_lng, undef, "-Inf longitude returns undef");

$packager_codes{"test-code-nan-coords"} = {cc => "fr", lat => "NaN", lng => "NaN"};
my ($nan_lat, $nan_lng) = get_packager_code_coordinates("test-code-nan-coords");
is($nan_lat, undef, "NaN latitude returns undef");
is($nan_lng, undef, "NaN longitude returns undef");

$packager_codes{"test-code-out-of-range-coords"} = {cc => "fr", lat => "95.0", lng => "-185.0"};
my ($oor_lat, $oor_lng) = get_packager_code_coordinates("test-code-out-of-range-coords");
is($oor_lat, undef, "Out of range latitude returns undef");
is($oor_lng, undef, "Out of range longitude returns undef");

$packager_codes{"test-code-valid-coords"} = {cc => "fr", lat => "48.12", lng => "-2.45"};
my ($valid_lat, $valid_lng) = get_packager_code_coordinates("test-code-valid-coords");
is($valid_lat, "48.12", "Valid latitude returned correctly");
is($valid_lng, "-2.45", "Valid longitude returned correctly");

done_testing();
