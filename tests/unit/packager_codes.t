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

# Country-scoped ES suffix (CZ/HU/SI/SK) and EF suffix (DK)
foreach my $test_ref (
	["CZ 62870058 ES", "CZ 62870058 EC"],
	["HU 12345 ES", "HU 12345 EC"],
	["SI 917 ES", "SI 917 EC"],
	["SK 121 ES", "SK 121 EC"],
	["DK 1234 EF", "DK 1234 EC"],
	)
{
	my ($local_code, $ec_code) = @{$test_ref};
	my $normalized_code = normalize_packager_codes($local_code);

	# Check the canonical intermediate value, not just the localized round-trip.
	is($normalized_code, $ec_code, "$local_code: normalized to the canonical EC code");
	is(normalize_packager_codes($normalized_code), $ec_code, "$local_code: normalization is idempotent");
	is(localize_packager_code($normalized_code), $local_code, "$local_code: localized suffix is restored");
}

foreach my $test_ref (
	["cz-62870058-es", "CZ 62870058 EC"],
	["HU_12345_ES", "HU 12345 EC"],
	["SI.917.ES", "SI 917 EC"],
	["SK/121/ES", "SK 121 EC"],
	["dk-1234-ef", "DK 1234 EC"],
	["CZ 12-345 ES", "CZ 12-345 EC"],
	["DK 12-34 EF", "DK 12-34 EC"],
	)
{
	my ($input, $expected) = @{$test_ref};
	is(normalize_packager_codes($input), $expected, "$input: suffix separators normalize without changing the ID");
}

is(
	normalize_packager_codes("CZ 62870058 ES,DK 1234 EF, SK 121 ES, DE BY-718 EG"),
	"CZ 62870058 EC,DK 1234 EC, SK 121 EC, DE BY-718 EC",
	"Mixed country codes normalize independently, preserving existing suffix handling"
);

# ES and EF must not become generic suffixes for other countries.
foreach my $country (qw(FR DE UK IT LT US)) {
	foreach my $suffix (qw(ES EF)) {
		my $code = "$country 12345 $suffix";
		is(normalize_packager_codes($code), $code, "$country: unsupported $suffix suffix stays unchanged");
	}
}

# Reject mismatched suffixes and suffix-like letters without code boundaries.
foreach my $code (
	"CZ 12345 EF",
	"HU 12345 EF",
	"SI 917 EF",
	"SK 121 EF",
	"DK 1234 ES",
	"CZ 62870058ES",
	"HU 12345ES",
	"SI 917ES",
	"SK 121ES",
	"DK 1234EF",
	"CZE 121 ES",
	"DKFOO 1234 EF",
	"CZ 12345 ES EXTRA",
	"DK 1234 EF EXTRA",
	"ES 12.0664/C ES",
	"ES 12.0664/C EF",
	)
{
	is(normalize_packager_codes($code), $code, "$code: not a supported standalone country-specific suffix");
}

is(normalize_packager_codes("Les Mousquetaires"), "LES MOUSQUETAIRES", "Plural endings are not EC suffixes");
is(normalize_packager_codes("Lait des Alpes"), "LAIT DES ALPES", "ES inside ordinary text is not an EC suffix");

# Guards: suffix-less and collision-prone formats stay untouched
is(normalize_packager_codes("LT 12-345 A"), "LT 12-345 A", "LT: official suffix-less format stays unchanged");
is(normalize_packager_codes("IT 180-1 CE"), "IT 180-1 EC", "IT: body kept, only suffix normalized");

done_testing();
