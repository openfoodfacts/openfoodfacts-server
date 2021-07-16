#!/usr/bin/perl -w

use strict;

my $entry_format = <<TXT
en:<i> minutes, <i>minutes, <i> min, <i>M, <i>
fr:<i> minutes, <i>min
cooking_duration_in_minutes:en:<i>
TXT
;

for (my $i = 1; $i <= 4 * 12; $i++) {

	my $entry = $entry_format;
	$entry =~ s/<i>/$i/g;
	print $entry . "\n";
}
