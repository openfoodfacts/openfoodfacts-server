#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2021 Association Open Food Facts
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


use strict;
use warnings;
use utf8;

use Log::Any::Adapter 'TAP';

use Log::Any qw($log);

use JSON;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::GS1 qw/:all/;
use ProductOpener::Food qw/:all/;

my $usage = <<TXT
Converts multiple JSON files in the GS1 format to a single CSV file in the Open Food Facts format

Usage:

convert_gs1_json_to_off_csv.pl --input-dir [path to directory containing input JSON files] --output [path for the output CSV file]

TXT
;

my $input_dir;
my $output;

GetOptions ("input-dir=s"   => \$input_dir, "output=s" => \$output)
  or die("Error in command line arguments.\n\n" . $usage);
  
if ((not defined $input_dir) or (not defined $output)) {
	print $usage;
	exit();
}
  


my $json = JSON->new->allow_nonref->canonical;

my $dh;

opendir ($dh, $input_dir) or die("Could not open the $input_dir directory: $!\n");

init_csv_fields();
my $products_ref = [];

foreach my $file (sort(readdir($dh))) {
	
	next if $file !~ /\.json$/;
	
	my $product_ref = read_gs1_json_file("$input_dir/$file", $products_ref);
}

write_off_csv_file($output, $products_ref);

print_unknown_entries_in_gs1_maps();
