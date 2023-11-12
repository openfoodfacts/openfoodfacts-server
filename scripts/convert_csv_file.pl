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
use ProductOpener::Store qw/:all/;
use ProductOpener::Producers qw/:all/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;
use Getopt::Long;

use Log::Any::Adapter 'TAP', filter => "none";

my $usage = <<TXT
convert_csv_file.pl converts a CSV file with product data into a CSV file in the Product Opener format.

Usage:

convert_csv_file.pl --csv_file path_to_csv_file --images_dir path_to_directory_containing_images --user_id user_id --comment "Systeme U import"
 --define lc=fr --define stores="Magasins U"

--define	: allows to define field values that will be applied to all products.

TXT
	;

my $csv_file;
my $converted_csv_file;
my $columns_fields_file;
my $source_id;
my %global_values = ();

GetOptions(
	"csv_file=s" => \$csv_file,
	"converted_csv_file=s" => \$converted_csv_file,
	"columns_fields_file=s" => \$columns_fields_file,
	"define=s%" => \%global_values,
	"source_id=s" => \$source_id,
) or die("Error in command line arguments:\n$\nusage");

if (defined $source_id) {
	$global_values{source_id} = $source_id;
}

print STDERR "convert_csv_file.pl
- csv_file: $csv_file
- converted_csv_file: $converted_csv_file
- columns_fields_file: $columns_fields_file
- source_id: $source_id
- global fields values:
";

foreach my $field (sort keys %global_values) {
	print STDERR "-- $field: $global_values{$field}\n";
}

my $missing_arg = 0;
if (not defined $csv_file) {
	print STDERR "missing --csv_file parameter\n";
	$missing_arg++;
}
if (not defined $converted_csv_file) {
	print STDERR "missing --converted_csv_file parameter\n";
	$missing_arg++;
}

convert_file(\%global_values, $csv_file, $columns_fields_file, $converted_csv_file);
