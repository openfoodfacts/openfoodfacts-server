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

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Display qw/$cc $nutriment_table $subdomain search_and_export_products/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Food qw/%cc_nutriment_table/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;
use Getopt::Long;
use CGI qw(:cgi :cgi-lib);

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $usage = <<TXT
export_data.pl exports product data from the database of Product Opener.

The default fields exported are specified in \@export_fields in Config.pm

If the --fields argument is specified, only the corresponding fields are exported,
otherwise all populated input fields (provided by users or producers) are exported.

The --extra_fields parameter allows to specify other fields to export (e.g fields
that are computed from other fields).

The --query-codes-from-file parameter allows to specify a file containing barcodes (one barcode per line).

Usage:

export_csv_file.pl --query field_name=field_value --query other_field_name=other_field_value
[--fields code,ingredients_texts_fr,categories_tags] [--extra_fields nova_group,nutrition_grade_fr]
[--include-images-paths] [--query-codes-from-file codes]
TXT
	;

my %query_fields_values = ();
my $fields;
my $extra_fields;
my $separator = ",";
my $include_images_paths;
my $query_codes_from_file;
my $format = "csv";
$cc = "world";
$lc = "en";

GetOptions(
	"cc=s" => \$cc,
	"lc=s" => \$lc,
	"format=s" => \$format,
	"fields=s" => \$fields,
	"extra_fields=s" => \$extra_fields,
	"query=s%" => \%query_fields_values,
	"separator=s" => \$separator,
	"include-images-paths" => \$include_images_paths,
	"query-codes-from-file=s" => \$query_codes_from_file,
) or die("Error in command line arguments:\n$\nusage");

print STDERR "export_data.pl
- format: $format
- cc: $cc
- lc: $lc
- fields: $fields
- extra_fields: $extra_fields
- separator: $separator
- include_images_paths : $include_images_paths
- query fields values:
";

my $query_ref = {};
my $request_ref = {};
$request_ref->{skip_http_headers} = 1;
$request_ref->{batch} = 1;

foreach my $field (sort keys %query_fields_values) {
	print STDERR "-- $field: $query_fields_values{$field}\n";
	param($field, $query_fields_values{$field});
}

# Construct the MongoDB query

use boolean;

foreach my $field (sort keys %{$query_ref}) {
	if ($query_ref->{$field} eq 'null') {
		# $query_ref->{$field} = { '$exists' => false };
		$query_ref->{$field} = undef;
	}
	if ($query_ref->{$field} eq 'exists') {
		$query_ref->{$field} = {'$exists' => true};
	}
}

if (defined $query_codes_from_file) {
	my @codes = ();
	open(my $in, "<", "$query_codes_from_file") or die("Cannot read $query_codes_from_file: $!\n");
	while (<$in>) {
		if ($_ =~ /^(\d+)/) {
			push @codes, $1;
		}
	}
	close($in);
	$query_ref->{"code"} = {'$in' => \@codes};
}

use Data::Dumper;
print STDERR "MongoDB query:\n" . Dumper($query_ref);

# CSV export

$request_ref->{format} = $format;
if (defined $separator) {
	$request_ref->{separator} = $separator;
}

if ((defined $fields) and ($fields ne "")) {
	$request_ref->{fields} = [split(/,/, $fields)];
}

if ((defined $extra_fields) and ($extra_fields ne "")) {
	$request_ref->{extra_fields} = [split(/,/, $extra_fields)];
}

# select the nutriment table format according to the country
$nutriment_table = $cc_nutriment_table{default};
if (exists $cc_nutriment_table{$cc}) {
	$nutriment_table = $cc_nutriment_table{$cc};
}
$subdomain = $cc;

search_and_export_products($request_ref, $query_ref, undef);

