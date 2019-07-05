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
	ok( length get_ascii_fileid($test) > 0, "get_ascii_fileid(${test})" );
}

is(get_fileid("Café au lait, bœuf gros sel de Guérande"), "cafe-au-lait-boeuf-gros-sel-de-guerande");
is(get_fileid("ethic-advisor.UUID_in-MiXeD_CaSe"),"ethic-advisor.UUID-in-MiXeD-CaSe");
is(get_fileid("àáâãäåçèéêëìíîïòóôõöùúûüýÿ"),"aaaaaaceeeeiiiiooooouuuuyy");
is(get_fileid("Farine de blé 56g *"),"farine-de-ble-56g");

done_testing();
