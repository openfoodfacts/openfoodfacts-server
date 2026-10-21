#!/usr/bin/perl -w

use strict;
use warnings;

my %ip = ();

while (<STDIN>) {
	if ($_ =~ /(^\S+) /) {
		$ip{$1}++;
	}
}

foreach my $ip (sort {$ip{$a} <=> $ip{$b}} keys %ip) {
	print "$ip\t$ip{$ip}\n";
}

