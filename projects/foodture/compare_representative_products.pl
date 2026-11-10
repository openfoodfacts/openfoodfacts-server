#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

use ProductOpener::PerlStandards;

use Text::CSV_XS;
use Getopt::Long;
use List::Util qw/sum0/;

# This script compares several outputs of extract_data_for_representative_products.pl
# (e.g. a selection made with off-query in February 2026, and selections made with
# select_representative_products.pl with 2025 scans, and with 2025 + 2026 scans).
# Rows are matched on L1, L2, L7, OFF segmentation and country. The first run is the reference.
#
# For each run, it computes: rows with a product, distinct products, products that still have complete data,
# products scanned in the country, and the total and median country scans for each year.
# For each other run, it compares with the reference: same product, other product, product added or lost.
#
# Scans are taken from the country_scans_<year> columns, which come from the scans.json files
# when the extraction is run, so they are comparable between runs extracted at the same time.

my $usage = <<TXT
compare_representative_products.pl --run <name>=<representative_products.csv> --run <name>=<file> [...]
	[--group-by <column> ...] [--summary-output <summary.csv>] [--pairs-output <pairs.csv>]

e.g. --group-by L1 --group-by Country
TXT
	;

my @runs_options = ();
my @group_by = ();
my $summary_file;
my $pairs_file;

GetOptions(
	"run=s" => \@runs_options,
	"group-by=s" => \@group_by,
	"summary-output=s" => \$summary_file,
	"pairs-output=s" => \$pairs_file,
) or die $usage;

(scalar @runs_options >= 2) or die $usage;

my @key_columns = ("L1", "L2", "Food Product L7", "Segmentation OFF", "off_country_id");

my @runs = ();    # names, in order
my %rows = ();    # $rows{run}{key} = row hash
my @keys = ();    # all keys, in the order of the first run where they appear
my %seen_keys = ();
my %years = ();    # $years{year} = number of runs that have country_scans_<year>

foreach my $run_option (@runs_options) {
	my ($run, $file) = split(/=/, $run_option, 2);
	defined $file or die "--run must be <name>=<file>\n";
	push @runs, $run;

	my $csv = Text::CSV_XS->new({binary => 1, auto_diag => 1});
	open(my $IN, '<:encoding(UTF-8)', $file) or die "Cannot read $file: $!\n";
	my $header_ref = $csv->getline($IN);
	$csv->column_names(@$header_ref);
	foreach my $column (@$header_ref) {
		$years{$1}++ if $column =~ /^country_scans_(\d+)$/;
	}

	# the same key can appear several times in the mapping list: number the occurrences
	my %occurrences = ();
	while (my $row_ref = $csv->getline_hr($IN)) {
		my $key = join("\t", map {$row_ref->{$_} // ''} @key_columns);
		$key .= "\t" . $occurrences{$key}++;
		$rows{$run}{$key} = $row_ref;
		push @keys, $key unless $seen_keys{$key}++;
	}
	close $IN;
	print STDERR "$run: " . (scalar keys %{$rows{$run}}) . " rows read from $file\n";
}

# only compare the years present in all runs
my @years = sort grep {$years{$_} == scalar @runs} keys %years;
my $reference = $runs[0];

sub has_product ($row_ref) {
	return ((defined $row_ref) and (($row_ref->{code} // '') ne '')) ? 1 : 0;
}

sub median (@values) {
	return '' if not @values;
	my @sorted = sort {$a <=> $b} @values;
	my $middle = int(@sorted / 2);
	return (@sorted % 2) ? $sorted[$middle] : ($sorted[$middle - 1] + $sorted[$middle]) / 2;
}

# Compute the metrics of a run for a list of keys
sub run_metrics ($run, $keys_ref) {
	my %metrics = (rows => scalar @$keys_ref, with_product => 0, complete => 0, map {("scanned_$_" => 0)} @years);
	if ($run ne $reference) {
		$metrics{$_} = 0 for qw/same changed added/;
	}
	my %codes = ();
	my %scans = map {$_ => []} @years;
	foreach my $key (@$keys_ref) {
		my $row_ref = $rows{$run}{$key};
		next if not has_product($row_ref);
		$metrics{with_product}++;
		$codes{$row_ref->{code}} = 1;
		$metrics{complete}++ if ($row_ref->{complete} // '') eq '1';
		foreach my $year (@years) {
			my $year_scans = $row_ref->{"country_scans_$year"} || 0;
			push @{$scans{$year}}, $year_scans;
			$metrics{"scanned_$year"}++ if $year_scans > 0;
		}

		next if $run eq $reference;
		my $reference_row_ref = $rows{$reference}{$key};
		if (not has_product($reference_row_ref)) {
			$metrics{added}++;
		}
		elsif ($reference_row_ref->{code} eq $row_ref->{code}) {
			$metrics{same}++;
		}
		else {
			$metrics{changed}++;
		}
	}
	if ($run ne $reference) {
		$metrics{lost}
			= scalar grep {has_product($rows{$reference}{$_}) and not has_product($rows{$run}{$_})} @$keys_ref;
	}
	$metrics{products} = scalar keys %codes;
	foreach my $year (@years) {
		$metrics{"scans_$year"} = sum0(@{$scans{$year}});
		$metrics{"median_scans_$year"} = median(@{$scans{$year}});
	}
	return \%metrics;
}

my @metrics = (
	"rows", "with_product", "products", "complete", (map {("scanned_$_", "scans_$_", "median_scans_$_")} @years),
	"same", "changed", "added", "lost"
);

# Summary: all rows, then each group
my @summary = ();    # [group column, group value, run, metrics]
foreach my $run (@runs) {
	push @summary, ["all", "all", $run, run_metrics($run, \@keys)];
}
foreach my $column (@group_by) {
	my %keys_by_group = ();
	foreach my $key (@keys) {
		my ($row_ref) = grep {defined} map {$rows{$_}{$key}} @runs;
		push @{$keys_by_group{$row_ref->{$column} // ''}}, $key;
	}
	foreach my $value (sort keys %keys_by_group) {
		foreach my $run (@runs) {
			push @summary, [$column, $value, $run, run_metrics($run, $keys_by_group{$value})];
		}
	}
}

# Print the summary for all rows
printf("%-20s" . (" %12s" x @runs) . "\n", "", @runs);
my %all_metrics = map {$_->[2] => $_->[3]} grep {$_->[0] eq 'all'} @summary;
foreach my $metric (@metrics) {
	printf("%-20s" . (" %12s" x @runs) . "\n", $metric, map {$all_metrics{$_}{$metric} // ''} @runs);
}

my $csv_out = Text::CSV_XS->new({binary => 1, eol => "\n"});

if (defined $summary_file) {
	open(my $OUT, '>:encoding(UTF-8)', $summary_file) or die "Cannot write $summary_file: $!\n";
	$csv_out->print($OUT, ["group_by", "group", "run", @metrics]);
	foreach my $summary_ref (@summary) {
		my ($column, $value, $run, $metrics_ref) = @$summary_ref;
		$csv_out->print($OUT, [$column, $value, $run, map {$metrics_ref->{$_} // ''} @metrics]);
	}
	close $OUT;
	print STDERR "Summary written to $summary_file\n";
}

# One row per country / category, with the product and scans of each run
if (defined $pairs_file) {
	open(my $OUT, '>:encoding(UTF-8)', $pairs_file) or die "Cannot write $pairs_file: $!\n";
	my @run_columns = ("code", "product_name", "complete", map {"country_scans_$_"} @years);
	$csv_out->print(
		$OUT,
		[
			@key_columns,
			"Country",
			(
				map {
					my $run = $_;
					map {"${run}_$_"} @run_columns
				} @runs
			),
			(map {"${_}_vs_$reference"} @runs[1 .. $#runs])
		]
	);
	foreach my $key (@keys) {
		my ($first_row_ref) = grep {defined} map {$rows{$_}{$key}} @runs;
		my @row = ((map {$first_row_ref->{$_} // ''} @key_columns), $first_row_ref->{Country} // '');
		foreach my $run (@runs) {
			my $row_ref = $rows{$run}{$key} // {};
			push @row, map {$row_ref->{$_} // ''} @run_columns;
		}
		my $reference_row_ref = $rows{$reference}{$key};
		foreach my $run (@runs[1 .. $#runs]) {
			my $row_ref = $rows{$run}{$key};
			my $change
				= (not has_product($row_ref)) ? (has_product($reference_row_ref) ? "lost" : "none")
				: (not has_product($reference_row_ref)) ? "added"
				: ($row_ref->{code} eq $reference_row_ref->{code}) ? "same"
				: "changed";
			push @row, $change;
		}
		$csv_out->print($OUT, \@row);
	}
	close $OUT;
	print STDERR "Pairs written to $pairs_file\n";
}
