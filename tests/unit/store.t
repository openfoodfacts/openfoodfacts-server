#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Storable qw(lock_store);

use ProductOpener::Store qw/get_fileid get_string_id_for_lang get_urlid store_object retrieve_object/;
use ProductOpener::Paths qw/%BASE_DIRS/;

is(get_fileid('Do not challenge me!'), 'do-not-challenge-me');

my @tests = (
	"Bonjour !",
	"Café Olé! 3€ -10%",
	"No hablo Español, señor",
	"สำนักงานคณะกรรมการกลางอิสลามแห่งประเทศไทย, คณะกรรมการกลางอิสลามแห่งประเทศไทย",
	"예네버르", "ラム酒", "DLG Jährlich Prämiert", "fr:Bœuf"
);
foreach my $test (@tests) {
	ok(length get_fileid($test) > 0, "get_fileid(${test})");
	ok(length get_urlid($test) > 0, "get_urlid(${test})");
}

is(get_fileid("Café au lait, bœuf gros sel de Guérande", 0, 'fr'), "cafe-au-lait-boeuf-gros-sel-de-guerande");
is(get_fileid("ethic-advisor.UUID_in-MiXeD_CaSe"), "ethic-advisor.UUID-in-MiXeD-CaSe");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 0, 'fr'), "aaaaaaceeeeiiiinooooouuuuyy");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 1), "aaaaaaceeeeiiiinooooouuuuyy");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 0, 'de'), "àáâãäåçèéêëìíîïñòóôõöùúûüýÿ");
is(get_fileid("Farine de blé 56g *", 0, 'fr'), "farine-de-ble-56g");
is(get_fileid('ẞ'), 'ß');
is(get_fileid('ẞ', 1), 'ss');

is(get_string_id_for_lang("no_language", "Café crème"), "cafe-creme");
is(get_string_id_for_lang("fr", "Café crème"), "cafe-creme");
is(get_string_id_for_lang("de", "Café crème"), "café-crème");
is(get_string_id_for_lang("de", "Äpfel"), "äpfel");
is(get_string_id_for_lang("en", "Äpfel"), "apfel");
is(get_string_id_for_lang("es", "Trazas : cacahuete, Trazas : huevo. frutos de cáscara."),
	"trazas-cacahuete-trazas-huevo-frutos-de-cascara");
is(get_string_id_for_lang("fr", "Pâte de cacao"), "pate-de-cacao");

# accents with one character, or unaccented character + unicode accent mark
is(get_string_id_for_lang("es", "arándanos, arándanos"), "arandanos-arandanos");

# Greek
is(get_string_id_for_lang("en", "string with spaces"), "string-with-spaces");
is(get_string_id_for_lang("el", "string with spaces"), "string-with-spaces");
is(get_string_id_for_lang("en", "E420 - Σορβιτολη"), "e420-σορβιτολη");
is(get_string_id_for_lang("el", "E420 - Σορβιτολη"), "e420-σορβιτολη");

# Test store object
# Make sure json file doesn't exist
if (-e "$BASE_DIRS{CACHE_TMP}/test.json") {
	unlink("$BASE_DIRS{CACHE_TMP}/test.json");
}
# Create an initial test file
lock_store({id => 1}, "$BASE_DIRS{CACHE_TMP}/test.sto");
# Verify retrieve copses with a sto file
is(retrieve_object("$BASE_DIRS{CACHE_TMP}/test.sto"), {id => 1});
# Use the new method to update it
store_object("$BASE_DIRS{CACHE_TMP}/test.sto", {id => 2});
# Verify that the json file has been created
ok((-e "$BASE_DIRS{CACHE_TMP}/test.json"), "$BASE_DIRS{CACHE_TMP}/test.json exists");
# The old sto file should be deleted
ok((not -e "$BASE_DIRS{CACHE_TMP}/test.sto"), "$BASE_DIRS{CACHE_TMP}/test.sto does not exist");
# Check data is saved
is(retrieve_object("$BASE_DIRS{CACHE_TMP}/test.sto"), {id => 2});

done_testing();
