#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Log::Any qw($log);

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Images qw/:all/;

# get_code_and_imagefield_from_file_name tests

my @tests = (

["en", "12345678.jpg", "12345678", "front"],
["en", "12345678_photo.jpg", "12345678", "front"],
["en", "12345678_photo-3510.jpg", "12345678", "front"],
["en", "12345678_2.jpg", "12345678", "other"],

# date
["en", "20200201131743_2.jpg", undef, "other"],

);

foreach my $test_ref (@tests) {

	$log->debug($test_ref->[0] . " " . $test_ref->[1]);
	my ($code, $imagefield) = get_code_and_imagefield_from_file_name(
		$test_ref->[0], $test_ref->[1]);
	is ($code, $test_ref->[2]);
	is ($imagefield, $test_ref->[3]);
}

done_testing();
