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

use strict;
use warnings;
use utf8;

use Log::Any::Adapter 'TAP';

use Log::Any qw($log);

use JSON;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::GS1 qw/:all/;
use ProductOpener::Food qw/:all/;

my $usage = <<TXT
Converts multiple JSON files in the GS1 format to a single CSV file in the Open Food Facts format

Usage:

convert_gs1_json_to_off_csv.pl --input-dir [path to directory containing input JSON files] --output [path for the output CSV file] [optional: --confirmation-dir [directory where confirmation messages should be created]]

TXT
	;

my $input_dir;
my $output;
my $confirmation_dir;

GetOptions("input-dir=s" => \$input_dir, "output=s" => \$output, "confirmation-dir=s" => \$confirmation_dir)
	or die("Error in command line arguments.\n\n" . $usage);

if ((not defined $input_dir) or (not defined $output)) {
	print $usage;
	exit();
}

if ((defined $confirmation_dir) and not(-e $confirmation_dir)) {
	mkdir($confirmation_dir, oct(755)) or die("Could not create $confirmation_dir : $!\n");
}

my $json = JSON->new->allow_nonref->canonical;

my $dh;

opendir($dh, $input_dir) or die("Could not open the $input_dir directory: $!\n");

init_csv_fields();
my $products_ref = [];
my $messages_ref = [];

foreach my $file (sort(readdir($dh))) {

	next if $file !~ /\.json$/;

	read_gs1_json_file("$input_dir/$file", $products_ref, $messages_ref);
}

write_off_csv_file($output, $products_ref);

# Generate confirmation messages if we were passed a confirmation dir (e.g. for Agena3000)
if (defined $confirmation_dir) {
	foreach my $message_ref (@$messages_ref) {
		my ($confirmation_instance_identifier, $xml) = generate_gs1_confirmation_message($message_ref, time());
		my $file = $confirmation_dir . '/' . 'CIC_' . $confirmation_instance_identifier . '.xml';

		open(my $result, ">:encoding(UTF-8)", $file) or die("Could not create $file: $!\n");
		print $result $xml;
		close $result;
	}
}

print_unknown_entries_in_gs1_maps();
