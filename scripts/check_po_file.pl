#!/usr/bin/perl

use strict;
use utf8;
use warnings;

my $file = $ARGV[0];

if (not defined $file) {
	print STDERR "Pass path to .po file to test as first argument.\n";
	exit(1);
}

print STDERR "Testing $file .po file";


open (my $IN, "<:encoding(UTF-8)", "$file") or die("Could not read $file: $!");
my @lines = (<$IN>);
close ($IN);

my %vars = ();
my $key;

my $errors = 0;

foreach my $line (@lines) {

	if ($line =~ /^(msgctxt|msgstr|msgid) "(.*)"/) {
		$key = $1;
		my $value = $2;
		if ($key eq "msgctxt") {
		
			if (defined $vars{"msgctxt"}) {
			
				# check that we do not have an empty value for the previous msgctxt
				
				if ((not defined $vars{"msgstr"}) or ($vars{"msgstr"} eq "")) {
					print STDERR "Error: empty msgstr string for msgctxt " . $vars{"msgctxt"} . " - msgid " . $vars{"msgid"} . "\n";
					$errors++;
				}
			
			}
		
			%vars = ();
			
	
		}
		defined $vars{$key} or $vars{$key} = "";
		$vars{$key} .= $value;
	}

}

print STDERR "$errors errors\n";
exit($errors);