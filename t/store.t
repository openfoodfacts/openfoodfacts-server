#!/usr/bin/perl -w

use Modern::Perl '2012';

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

done_testing();
