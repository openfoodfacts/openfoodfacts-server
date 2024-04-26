#!/usr/bin/perl -w

use strict;

my @ips = qw(fixme);

my @keys = qw(fixme);

my @ids = ();

open (my $in, "<", "ids.txt");

my @scripts = ();

my $i = 0;

while (<$in>) {
	chomp;
	my $id = $_;
	$i++;

	my $j = int ($i / 10000);

	my $key = $keys[$j];
	my $ip = $ips[$j];

	$scripts[$j] .= <<SH
wget "http://api.nal.usda.gov/ndb/reports/?ndbno=$id&type=f&format=json&api_key=$key" -O products/$id.json --bind-address=$ip
sleep 4

SH
;
}

for (my $j = 0; $j < 20; $j++) {

	open (my $file, ">", "dl$j.sh");
	print $file <<SH
#!/bin/sh

$scripts[$j]
SH
;
	close($file);
}
