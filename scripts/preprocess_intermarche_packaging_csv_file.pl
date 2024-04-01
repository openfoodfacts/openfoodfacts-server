#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

=head1 NAME


=head1 DESCRIPTION

The Excel file that contains packaging data for Intermarché / Les Mousquetaires products
has 1 line for each product / packaging component / packaging material combination.

Packaging components can have multiple materials (e.g. a lid may be 95% steel and 5% plastic),
which is currently not supported in the OFF packagings structure.

This script filters the CSV file corresponding to the Excel file in order to keep only
the dominant material of each packaging component.

=cut

use ProductOpener::PerlStandards;

use Text::CSV;
use Data::DeepAccess qw(deep_get deep_set deep_exists);

my $separator = "\t";

my $csv_options_ref
	= {binary => 1, sep_char => $separator, eol => "\n", quote_space => 0};    # should set binary attribute.

my $csv_file = $ARGV[0];

open my $in, "<:encoding(utf8)", $csv_file or die "cannot read $csv_file: $!";

$csv_file =~ s/\.csv$/.preprocessed.csv/;

open my $out, ">:encoding(utf8)", $csv_file or die "cannot write $csv_file: $!";

my $csv = Text::CSV->new($csv_options_ref)
	or die("Cannot use CSV: " . Text::CSV->error_diag());

my $header_row_ref = $csv->getline($in);

# We will create a hash with the hashing components
my %packaging_components = ();

while (my $row_ref = $csv->getline($in)) {

	# Columns names:
	# n°CDC	1= CDC à conserver  N/A = CDC d'un frn en partage de marché à ne pas conserver
	# Marque
	# Nom produit
	# GTIN
	# Usage de l'emballage
	# Type d'emballage
	# Poids unitaire vide en gramme
	# Nombre d’unités de composants
	# Matériau
	# % en poids

	# Build a key to identify unique packaging components
	# We start with barcode, as we will sort on this key in output
	# and want to keep one product's packaging components together
	my $key = $row_ref->[4]    # barcode
		. " - " . $row_ref->[6]    # shape
		. " - " . $row_ref->[7]    # total weight of unit
		. " - " . $row_ref->[8]    # number of units
		;

	my $material = $row_ref->[9];
	my $percent_weight = $row_ref->[10] || 0;    # some rows have no values for the weight
	$percent_weight =~ s/\%//;

	deep_set(\%packaging_components, ($key, $material), [$percent_weight, $row_ref]);
}

close $in;

# Output the packaging components, keeping only the material with the highest percent

$csv->print($out, $header_row_ref);

foreach my $key (sort keys %packaging_components) {
	# we are considering a unique packaging component
	# sort on percent_weight for each material
	my @materials = sort {$packaging_components{$key}{$b}[0] <=> $packaging_components{$key}{$a}[0]}
		keys %{$packaging_components{$key}};

	# only keep the most relevant material for sake of simplicity
	$csv->print($out, $packaging_components{$key}{$materials[0]}[1]);
}

close $out;
