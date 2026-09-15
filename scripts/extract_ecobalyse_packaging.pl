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

use Modern::Perl '2017';
use utf8;
use Getopt::Long;
use JSON::MaybeXS;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# Options
my $scope;    # "food" or "food2"
my $format = "json";    # "json" or "tsv"
my $help;

GetOptions(
	'scope=s' => \$scope,
	'format=s' => \$format,
	'help' => \$help,
) or die "Invalid options\n";

if ($help) {
	print STDOUT <<EOF;
Usage: $0 [--scope food|food2] [--format json|tsv] [--help]

Extract per-item packaging processes from Ecobalyse processes.json.

  --scope   Only keep items whose "scopes" array contains the given value
            (e.g. "food" or "food2"). When omitted, all per-item entries are kept.
  --format  "json" (default) writes a JSON array, "tsv" writes a tab-separated
            view for quick inspection.
  --help    Show this help.

Output (json): external-data/ecobalyse/processes_packaging.json
              (or processes_packaging_<scope>.json when --scope is set)
EOF
	exit 0;
}

my $input_file = "external-data/ecobalyse/processes.json";
die "Could not open $input_file: $!" unless -e $input_file;

my $json_text = do {
	open(my $fh, '<:raw', $input_file) or die "Could not open $input_file: $!";
	local $/;
	<$fh>;
};

my $data = decode_json($json_text);
die "Expected a JSON array" unless ref($data) eq 'ARRAY';

my @output;

ITEM: foreach my $item (@$data) {
	# Keep only items with "packaging" in categories
	my $categories = $item->{categories};
	next ITEM unless defined $categories && ref($categories) eq 'ARRAY';
	next ITEM unless grep {$_ eq 'packaging'} @$categories;

	# Per-product-item materials only (unit == "item")
	# The unit == "kg" entries are generic per-kg material datasets with no
	# food category or quantity; they are excluded.
	next ITEM unless ($item->{unit} // '') eq 'item';

	# Optional scope filter
	if (defined $scope) {
		my $scopes = $item->{scopes};
		my $found = (defined $scopes && ref($scopes) eq 'ARRAY' && grep {$_ eq $scope} @$scopes);
		next ITEM unless $found;
	}

	push @output,
		{
		id => $item->{id},
		activityName => $item->{activityName},
		displayName => $item->{displayName},
		ecs => $item->{impacts}{ecs},
		scopes => $item->{scopes},
		massPerUnit => $item->{massPerUnit},
		unit => $item->{unit},
		location => $item->{location},
		categories => $item->{categories},
		};
}

# Determine output file
my $output_file;
if ($format eq 'tsv') {
	$output_file = "-";
}
else {
	if (defined $scope) {
		$output_file = "external-data/ecobalyse/processes_packaging_${scope}.json";
	}
	else {
		$output_file = "external-data/ecobalyse/processes_packaging.json";
	}
}

if ($format eq 'tsv') {
	print join("\t", qw(id activityName displayName ecs scopes massPerUnit unit location)), "\n";
	for my $item (@output) {
		my $scopes_str = ref($item->{scopes}) eq 'ARRAY' ? join(',', @{$item->{scopes}}) : '';
		print join("\t",
			$item->{id} // '',
			$item->{activityName} // '',
			$item->{displayName} // '',
			$item->{ecs} // '',
			$scopes_str,
			$item->{massPerUnit} // '',
			$item->{unit} // '',
			$item->{location} // '',
			),
			"\n";
	}
}
else {
	open(my $out, '>:raw', $output_file)
		or die "Could not write $output_file: $!";
	print $out JSON::MaybeXS->new->utf8->canonical->pretty->encode(\@output);
	close($out);
	print STDERR "Wrote " . scalar(@output) . " items to $output_file\n";
}

1;
