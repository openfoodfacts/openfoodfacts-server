#!/usr/bin/perl -w

use Modern::Perl '2012';

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Store qw/:all/;

is( get_fileid('Do not challenge me!'), 'do-not-challenge-me' );

my @tests = ("Bonjour !", "Café Olé! 3€ -10%", "No hablo Español, señor", "สำนักงานคณะกรรมการกลางอิสลามแห่งประเทศไทย, คณะกรรมการกลางอิสลามแห่งประเทศไทย", "예네버르", "ラム酒", "DLG Jährlich Prämiert", "fr:Bœuf");
foreach my $test (@tests) {
	ok( length get_fileid($test) > 0, "get_fileid(${test})" );
	ok( length get_urlid($test) > 0, "get_urlid(${test})" );
}

is(get_fileid("Café au lait, bœuf gros sel de Guérande", 0, 'fr'), "cafe-au-lait-boeuf-gros-sel-de-guerande");
is(get_fileid("ethic-advisor.UUID_in-MiXeD_CaSe"),"ethic-advisor.UUID-in-MiXeD-CaSe");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 0, 'fr'),"aaaaaaceeeeiiiinooooouuuuyy");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 1),"aaaaaaceeeeiiiinooooouuuuyy");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 0, 'de'),"àáâãäåçèéêëìíîïñòóôõöùúûüýÿ");
is(get_fileid("Farine de blé 56g *", 0, 'fr'),"farine-de-ble-56g");
is(get_fileid('ẞ'), 'ß');
is(get_fileid('ẞ', 1), 'ss');

is(get_string_id_for_lang("Café crème","no_language"),"cafe-creme");
is(get_string_id_for_lang("Café crème","fr"),"cafe-creme");
is(get_string_id_for_lang("Café crème","de"),"café-crème");
is(get_string_id_for_lang("Äpfel","de"),"äpfel"); 
is(get_string_id_for_lang("Äpfel","en"),"apfel"); 

done_testing();
