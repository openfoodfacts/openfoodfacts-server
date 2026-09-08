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

use Text::CSV;

my $ciqual_2020 = 'external-data/ciqual/ciqual/CIQUAL2020_ENG_2020_07_07.csv';
my $ciqual_2025 = 'external-data/ciqual/ciqual/CIQUAL2025_ENG_2025_11_03.csv';

sub read_ciqual_csv {
	my ($file) = @_;
	my %data;
	my $csv = Text::CSV->new({sep_char => "\t", binary => 1, auto_diag => 1});
	open my $fh, '<:encoding(utf8)', $file or die "Cannot open $file: $!";
	my $header = $csv->getline($fh);
	while (my $row = $csv->getline($fh)) {
		my $code = $row->[6];
		my $name = $row->[7];
		next unless defined $code && $code =~ /^\d+$/;
		$data{$code} = {
			name => $name,
			nutrients => [@$row[9 .. $#{$row}]],
		};
	}
	close $fh;
	return \%data;
}

sub normalize_value {
	my ($value) = @_;
	return '' unless defined $value;
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
	$value =~ s/^-+$/-/;
	$value =~ s/< //g;
	$value =~ s/,/./g;
	return $value;
}

my $data_2020 = read_ciqual_csv($ciqual_2020);
my $data_2025 = read_ciqual_csv($ciqual_2025);

my %only_in_2020;
my %only_in_2025;
my %same_nutrients;
my %different_nutrients;

foreach my $code (sort keys %$data_2020) {
	if (exists $data_2025->{$code}) {
		my $nutrients_2020 = $data_2020->{$code}{nutrients};
		my $nutrients_2025 = $data_2025->{$code}{nutrients};
		my $same = 1;
		my $min_len
			= scalar(@$nutrients_2020) < scalar(@$nutrients_2025) ? scalar(@$nutrients_2020) : scalar(@$nutrients_2025);
		for my $i (0 .. $min_len - 1) {
			if (normalize_value($nutrients_2020->[$i]) ne normalize_value($nutrients_2025->[$i])) {
				$same = 0;
				last;
			}
		}
		if ($same) {
			$same_nutrients{$code} = $data_2020->{$code}{name};
		}
		else {
			$different_nutrients{$code} = $data_2020->{$code}{name};
		}
	}
	else {
		$only_in_2020{$code} = $data_2020->{$code}{name};
	}
}

foreach my $code (sort keys %$data_2025) {
	unless (exists $data_2020->{$code}) {
		$only_in_2025{$code} = $data_2025->{$code}{name};
	}
}

my $total_2020 = scalar keys %$data_2020;
my $total_2025 = scalar keys %$data_2025;
my $only_2020_count = scalar keys %only_in_2020;
my $only_2025_count = scalar keys %only_in_2025;
my $same_count = scalar keys %same_nutrients;
my $different_count = scalar keys %different_nutrients;

print "=== Ciqual version comparison: 2020 vs 2025 ===\n\n";
print "Total entries in 2020: $total_2020\n";
print "Total entries in 2025: $total_2025\n\n";
print "Only in 2020: $only_2020_count\n";
print "Only in 2025: $only_2025_count\n";
print "In both versions: " . ($same_count + $different_count) . "\n";
print "  - Same nutrient data: $same_count\n";
print "  - Different nutrient data: $different_count\n";

if ($only_2020_count > 0) {
	print "\n--- Only in 2020 ---\n";
	foreach my $code (sort {$a <=> $b} keys %only_in_2020) {
		printf "  %s\t%s\n", $code, $only_in_2020{$code};
	}
}

if ($only_2025_count > 0) {
	print "\n--- Only in 2025 ---\n";
	foreach my $code (sort {$a <=> $b} keys %only_in_2025) {
		printf "  %s\t%s\n", $code, $only_in_2025{$code};
	}
}

if ($different_count > 0) {
	print "\n--- Different nutrient data (sample) ---\n";
	my $count = 0;
	foreach my $code (sort {$a <=> $b} keys %different_nutrients) {
		last if $count++ >= 20;
		printf "  %s\t%s\n", $code, $different_nutrients{$code};
	}
	print "  ... and " . ($different_count - ($count > $different_count ? $different_count : $count)) . " more\n"
		if $different_count > $count;
}
