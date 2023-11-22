#!/usr//bin/perl -w

use strict;

my %subdomains = ();

# input for script: /home/off/logs/access_log

while (<STDIN>) {
	if ($_ =~ /\/([a-z-]+)\.openfoodfacts\.org/) {
		$subdomains{$1}++;
	}
}


foreach my $sd (sort { $subdomains{$b} <=> $subdomains{$a} } keys %subdomains) {
	print $sd . "\t" . $subdomains{$sd} . "\n";
}
