#!/usr/bin/perl -w

use strict;

print STDERR "Delete broken image files\n";

foreach my $file (@ARGV) {

	my $name = $file;

	next if $file !~ /\.(png|jpg)/;

	# only check new files
	my $last_mod_time = (stat ($file))[9];
	if (time() - $last_mod_time > 86400 * 2) {
		print STDERR "skip old file $file\n";
		next;
	}

	my $result = `convert $file NULL 2>&1`;
	if ($result =~ /Corrupt/i) {
		print STDERR "$file seems broken:\nresult: $result\n\n";
		unlink($file);
	}
	else {
		#print STDERR "result for file $file: $file\nresult: $result\n";
	}
}
