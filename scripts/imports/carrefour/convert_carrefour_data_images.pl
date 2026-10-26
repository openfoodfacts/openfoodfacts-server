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

use Log::Any qw($log);

use Log::Any::Adapter ('Stderr');

use Text::CSV;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# read the CSV file passed as argument

my $file = $ARGV[0];

if (not defined $file) {
	die "Usage: $0 file.csv\n";
}

# CSV format:
# EAN;URL;ANGLE
# 3560071394806;[url];Front

my $csv = Text::CSV->new({sep_char => ';'});

# Read all lines from the CSV file, to gather image by product
# to build a new csv in OFF format (one line by barcode, with front image first)

my $io;
open($io, "<:encoding(UTF-8)", $file) or die "Could not open file $file: $!\n";
$csv->column_names($csv->getline($io));

# get all images for each product
# if we have more than one image type, we will suffix with a number
my %images = ();

while (my $image_ref = $csv->getline_hr($io)) {

	my $code = $image_ref->{EAN};
	my $url = $image_ref->{URL};
	my $angle = $image_ref->{ANGLE};

	if (not defined $images{$code}) {
		$images{$code} = {};
	}

	# if the angle already exists (e.g. 2 Other images), we suffix the angle with a number
	if (defined $images{$code}{$angle}) {
		my $i = 1;
		while (defined $images{$code}{"$angle.$i"}) {
			$i++;
		}
		$angle = "$angle.$i";
	}
	$images{$code}{$angle} = $url;
}

close($io);

# Output the images in the expected order, in OFF CSV format
# for each product code, we will output image_front_url if we have an image with the angle "Front", image_other_url with comma separated URLS for the other images

# header
print join("\t", qw(code image_front_url image_other_url)) . "\n";

foreach my $code (sort keys %images) {

	my $image_ref = $images{$code};
	my $image_front_url = '';

	# output the Front angle first if it exists
	if (defined $image_ref->{Front}) {
		$image_front_url = $image_ref->{Front};
		delete $image_ref->{Front};
	}

	# output the other images
	my $image_other_url = join(",", sort values %$image_ref);

	print join("\t", $code, $image_front_url, $image_other_url) . "\n";
}

