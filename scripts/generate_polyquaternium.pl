#!/usr/bin/perl -w

use Modern::Perl '2012';

my $entry_format = <<TXT
<en:polyquaternium
en:Polyquaternium-<i>
TXT
;

for (my $i = 1; $i <= 100 ; $i++) {

	my $entry = $entry_format;
	$entry =~ s/<i>/$i/g;
	print $entry . "\n";
}
