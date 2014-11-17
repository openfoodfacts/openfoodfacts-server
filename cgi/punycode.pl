#!/usr/bin/perl -w

use strict;

use Net::IDN::Encode ':all';

use Encode;
use Encode::Punycode;

while(<STDIN>) {

	chomp();
#	print $_ . "\n" . to_ascii($_) . "\n";
	print "entered: " . $_ . "\nencoded: " . encode('Punycode',$_) . " -- done\n";
}
