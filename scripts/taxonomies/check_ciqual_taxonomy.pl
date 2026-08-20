#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use Getopt::Long qw/GetOptions/;

my $taxonomy = 'ingredients';

GetOptions("taxonomy=s" => \$taxonomy,)
	or die("Error in command line arguments\n");

if ($taxonomy ne 'ingredients' and $taxonomy ne 'categories') {
	die("--taxonomy must be 'ingredients' or 'categories'\n");
}

my $ciqual_csv = 'external-data/ciqual/ciqual/CIQUAL2020_ENG_2020_07_07.csv';
my $ciqual_fr_csv = 'external-data/ciqual/ciqual/CIQUAL2020_FR_2020_07_07.csv';
my $taxonomy_file = "taxonomies/food/$taxonomy.txt";

my %ciqual;
my %food_lines;
my %proxy_lines;
my %food_commented;
my %proxy_commented;
my %taxonomy_codes;

open my $fh, '<:encoding(utf8)', $ciqual_csv or die "Cannot open $ciqual_csv: $!";
my $header = <$fh>;
while (my $line = <$fh>) {
	chomp $line;
	my @fields = split /\t/, $line, -1;
	my $code = $fields[6];
	my $name = $fields[7];
	next unless defined $code && $code =~ /^\d+$/;
	$ciqual{$code} = [$name, undef];
}
close $fh;

open $fh, '<:encoding(utf8)', $ciqual_fr_csv or die "Cannot open $ciqual_fr_csv: $!";
$header = <$fh>;
while (my $line = <$fh>) {
	chomp $line;
	my @fields = split /\t/, $line, -1;
	my $code = $fields[6];
	my $name = $fields[7];
	next unless defined $code && $code =~ /^\d+$/;
	if (exists $ciqual{$code}) {
		$ciqual{$code}[1] = $name;
	}
	else {
		$ciqual{$code} = [undef, $name];
	}
}
close $fh;

open $fh, '<:encoding(utf8)', $taxonomy_file or die "Cannot open $taxonomy_file: $!";
while (my $line = <$fh>) {
	chomp $line;
	if ($line =~ /^#?\s*ciqual_food_code:en:\s*(\d+)/i) {
		my $code = $1;
		if ($line =~ /^#/) {
			$food_commented{$code}++;
		}
		else {
			$food_lines{$code}++;
			$taxonomy_codes{$code} = 1;
		}
	}
	elsif ($line =~ /^#?\s*ciqual_proxy_food_code:en:\s*(\d+)/i) {
		my $code = $1;
		if ($line =~ /^#/) {
			$proxy_commented{$code}++;
		}
		else {
			$proxy_lines{$code}++;
			$taxonomy_codes{$code} = 1;
		}
	}
}
close $fh;

my $total = scalar keys %ciqual;
my $food_total_lines = scalar keys %food_lines;
my $proxy_total_lines = scalar keys %proxy_lines;
my $found = 0;
my @missing;
my @duplicates;

foreach my $code (sort keys %ciqual) {
	if (exists $taxonomy_codes{$code}) {
		$found++;
	}
	else {
		my ($en, $fr) = @{$ciqual{$code}};
		push @missing, [$code, $en // 'unknown', $fr // 'unknown'];
	}
}

foreach my $code (sort keys %food_lines) {
	push @duplicates, [$code, 'food', $food_lines{$code}] if $food_lines{$code} > 1;
}
foreach my $code (sort keys %proxy_lines) {
	push @duplicates, [$code, 'proxy', $proxy_lines{$code}] if $proxy_lines{$code} > 1;
}

my $missing_count = scalar @missing;
my $duplicate_count = scalar @duplicates;

print "=== Ciqual taxonomy analysis ($taxonomy) ===\n\n";

print "Ciqual entries in CSV: $total\n";
print "Ciqual codes found in $taxonomy.txt taxonomy: $found\n";
print "Ciqual codes MISSING from taxonomy: $missing_count\n\n";

print "--- Taxonomy ciqual_food_code lines ---\n";
print "Total lines (including duplicates): " . (scalar keys %food_lines) . "\n";
print "Unique codes: " . (scalar grep {$food_lines{$_} == 1} keys %food_lines) . "\n";
print "Commented-out lines: " . (scalar keys %food_commented) . "\n";

print "\n--- Taxonomy ciqual_proxy_food_code lines ---\n";
print "Total lines (including duplicates): " . (scalar keys %proxy_lines) . "\n";
print "Unique codes: " . (scalar grep {$proxy_lines{$_} == 1} keys %proxy_lines) . "\n";
print "Commented-out lines: " . (scalar keys %proxy_commented) . "\n";

if ($duplicate_count > 0) {
	print "\n--- Duplicate codes ---\n";
	foreach my $entry (@duplicates) {
		printf "%s\t%s\t%d occurrences\n", $entry->[0], $entry->[1], $entry->[2];
	}
}

if ($missing_count > 0) {
	print "\n--- Missing entries ---\n";
	foreach my $entry (sort {$a->[0] <=> $b->[0]} @missing) {
		my ($code, $en, $fr) = @$entry;
		printf "%s\t%s\t%s\n", $code, $en, $fr;
	}
	print "\n$missing_count ciqual codes are missing from the $taxonomy.txt taxonomy.\n";
}
