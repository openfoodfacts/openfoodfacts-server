#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
#use Log::Any::Adapter 'TAP', filter => "none";
use Log::Any::Adapter 'TAP', filter => "info";

use ProductOpener::Images qw/:all/;

# get_code_and_imagefield_from_file_name tests

my @tests = (

	["en", "12345678.jpg", "12345678", "front"],
	["en", "12345678_photo.jpg", "12345678", "front"],
	["en", "12345678_photo-3510.jpg", "12345678", "front"],
	["en", "12345678_2.jpg", "12345678", "other"],
	["en", "12345678901234.jpg", "12345678901234", "front"],
	["en", "12345678901234.ingredients_fr.jpg", "12345678901234", "ingredients_fr"],

	# regexps
	["es", "12345678-Valores_Nutricionales-423.jpg", "12345678", "nutrition"],
	["fr", "12345678.informations nutritionnelles.jpg", "12345678", "nutrition"],
	["fr", "liste-des-ingrédients-12345678jpg", "12345678", "ingredients"],

	# date
	["en", "20200201131743_2.jpg", undef, "other"],

	["en", "4 LR GROS LOUE_3 251 320 080 419_3D avant.png", "3251320080419", "other"],

);

foreach my $test_ref (@tests) {

	print STDERR $test_ref->[0] . " " . $test_ref->[1] . "\n";
	my ($code, $imagefield) = get_code_and_imagefield_from_file_name($test_ref->[0], $test_ref->[1]);
	is($code, $test_ref->[2]);
	is($imagefield, $test_ref->[3]);
}

done_testing();
