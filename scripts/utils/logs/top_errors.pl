#!/usr/bin/perl -w

my %errors = ();

# [Tue Sep 13 11:03:23 2016] -e: Use of uninitialized value $tag in pattern match (m//) at /home/off/lib/ProductOpener/Tags.pm line 1811.

while(<STDIN>) {

	chomp;
	my $line = $_;
	$line =~ s/\[.*?\] //;
	$errors{$line}++;
}


foreach my $error ( sort { $errors{$a} <=> $errors{$b} } keys %errors) {

	print $errors{$error} . "\t" . $error . "\n";

}
