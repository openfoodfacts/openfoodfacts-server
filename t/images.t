#!/usr/bin/perl -w

use strict;
use warnings;

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

# date
["en", "20200201131743_2.jpg", undef, "other"],

["en", "4 LR GROS LOUE_3 251 320 080 419_3D avant.png", "3251320080419", "other"],

);

foreach my $test_ref (@tests) {

	print STDERR $test_ref->[0] . " " . $test_ref->[1] . "\n";
	my ($code, $imagefield) = get_code_and_imagefield_from_file_name(
		$test_ref->[0], $test_ref->[1]);
	is ($code, $test_ref->[2]);
	is ($imagefield, $test_ref->[3]);
}

done_testing();
