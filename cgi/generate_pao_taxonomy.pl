#!/usr/bin/perl -w

use strict;

my $entry_format = <<TXT
en:<i> months, <i>months, <i> M, <i>M, <i>
fr:<i> mois, <i>mois
numeric_number_of_months_after_opening:en:<i>
TXT
;

for (my $i = 1; $i <= 4 * 12; $i++) {

	my $entry = $entry_format;
	$entry =~ s/<i>/$i/g;
	print $entry . "\n";
}