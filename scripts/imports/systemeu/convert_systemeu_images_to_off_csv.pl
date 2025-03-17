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

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/get_fileid get_string_id_for_lang/;
use ProductOpener::Paths qw/%BASE_DIRS/;

use Log::Any qw($log);
use Log::Any::Adapter 'TAP', filter => "none";

use Text::CSV;

# Systeme U sends us ZIP files containing images of products
# This script recursively explores the images in a directory and outputs a CSV file that can be imported with import_csv_file.pl

# Usage:
# ./convert_systemeu_images_to_off_csv.pl [input path containing images] [output CSV file in OFF format]

# Check we have an images path passed as argument and that it exists, and that we have an output CSV file name or print usage and exit
if (scalar @ARGV != 2) {
	print STDERR "Usage: $0 [input path containing images] [output CSV file in OFF format]\n";
	exit 1;
}

my $input_path = $ARGV[0];
my $output_csv_file = $ARGV[1];

my $output_csv = Text::CSV->new(
	{
		eol => "\n",
		sep => "\t",
		quote_space => 0,
		binary => 1
	}
) or die "Cannot use CSV: " . Text::CSV->error_diag();

# Images naming convention:

# older images:

# d : ingredients
# e : nutrition

# 3256225094547_0_d.jpg
# 3256225094547_0_e.jpg
# 3256225094547.jpg

#-rwx------ 1 root root   229339 avril 20 15:44 3256225425105_D.jpg
#-rwx------ 1 root root   320218 avril 20 15:44 3256225425105_E.jpg
#-rwx------ 1 root root   410014 avril 20 15:44 3256225425617_a_E.jpg
#-rwx------ 1 root root   374778 avril 20 15:44 3256225425617_b_E.jpg
#-rwx------ 1 root root   213484 avril 20 15:45 3256225426560_a_D.jpg

# newer images:
# S01: ingredients
# S02: nutrition

# 03368957378571_C0N1_S02_ETUI_USAV_SAUMO_ANETH_CITRO.jpg

my $images_ref = {};

sub explore_images_dir($dir) {

	my $dh;
	if (opendir($dh, $dir)) {
		foreach my $file (sort {$a cmp $b} readdir($dh)) {
			# systeme-u archives includes files starting with ._
			# that contain metadata, skip them

			next if ($file =~ /^\./);
			next if ($file eq "__MACOSX");

			# Sub-directory
			if (-d "$dir/$file") {
				explore_images_dir("$dir/$file");
				next;
			}

			if ($file =~ /(\d+)(.*)\.(jpg|jpeg|png)/i) {

				my $code = $1;
				my $suffix = $2;
				my $imagefield = "other";
				((not defined $suffix) or ($suffix eq "")) and $imagefield = "front";
				($suffix =~ /^(_mp)?(_(\d+))?_d(.*)$/i) and $imagefield = "ingredients";
				($suffix =~ /^(_mp)?(_(\d+))?_e(.*)$/i) and $imagefield = "nutrition";

				($suffix =~ /_S02_/i) and $imagefield = "ingredients";
				($suffix =~ /_S01_/i) and $imagefield = "nutrition";

				print "FOUND IMAGE FOR PRODUCT CODE ($code) - file ($file) - imagefield: ($imagefield)\n";

				(defined $images_ref->{$code}) or $images_ref->{$code} = {};

				$images_ref->{$code}{$imagefield} = $dir . "/" . $file;
			}
		}
	}

	close($dh);

	return;
}

explore_images_dir($input_path);

# Output the CSV file

open(my $output_csv_fh, ">:encoding(UTF-8)", $output_csv_file) or die "Could not open $output_csv_file: $!";

my @output_fields = qw(
	code
	lc
	countries
	image_front_fr_file
	image_ingredients_fr_file
	image_nutrition_fr_file
);

# Print the header line with fields names
$output_csv->print($output_csv_fh, \@output_fields);

foreach my $code (sort keys %{$images_ref}) {

	my @output_values = (
		$code, "fr", "en:france",
		$images_ref->{$code}{front},
		$images_ref->{$code}{ingredients},
		$images_ref->{$code}{nutrition},
	);

	$output_csv->print($output_csv_fh, \@output_values);
}

