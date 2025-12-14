#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

# Function to count the number of strings in a .po or .pot file
sub count_strings {
	my ($file) = @_;
	open my $fh, '<', $file or die "Could not open '$file' $!";
	my $count = 0;
	while (my $line = <$fh>) {
		$count++ if $line =~ /^msgid\s+"/;
	}
	close $fh;
	return $count;
}

# File paths
my $common_pot = 'po/common/common.pot';
my $en_po = 'po/common/en.po';
my $fr_po = 'po/common/fr.po';

# Count the number of strings in each file
my $common_pot_count = count_strings($common_pot);
my $en_po_count = count_strings($en_po);
my $fr_po_count = count_strings($fr_po);

# Test if the number of strings are equal
is($common_pot_count, $en_po_count, 'common.pot has the same number of strings as en.po');
is($common_pot_count, $fr_po_count, 'common.pot has the same number of strings as fr.po');

done_testing();
