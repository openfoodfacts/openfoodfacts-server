#!/usr/bin/env -S perl -w

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

# pre-requisites:
# - from the Croatian ministry of agriculture website,
#   download the actual list of "Register of approved establishments dealing with
#   food of animal origin - all establishments" http://veterinarstvo.hr/default.aspx?id=2423
# - convert xls file into csv:
# $ ssconvert '07-08-2023. svi odobreni objekti.xls'  hr_07082023_svi_odobreni_objekti.csv
# - remove first lines before header:
# $ sed '1,4d' hr_07082023_svi_odobreni_objekti.csv > hr-export_truncated.csv
# - csv file is expected to be semi-colons separed but file already contains semi-colons
#   we will reaplace all semi-colons by a default text temporarily
#   convert separators to semi-colons
#   finally convert default text to commas
# $ rpl ";" "<semi-colon>" hr-export_crop.csv
# $ csvtool -t ',' -u ';' col 1- hr-export_crop.csv > hr-export.csv
# $ rpl "<semi-colon>" "," hr-export.csv
# - remove all quotes, not necessary anymore
# $ rpl "\"" "" hr-export.csv
# - remove spaces before and after semi-colons
# $ rpl " ;" ";" hr-export.csv
# $ rpl "; " ";" hr-export.csv

use Time::HiRes;    # sleep less than a second
use HTTP::CookieJar::LWP;
use LWP::UserAgent;
use JSON qw(from_json);
use Encode qw( encode );
use Text::CSV qw( csv );
use strict;
use warnings;

my $jar = HTTP::CookieJar::LWP->new;
my $ua = LWP::UserAgent->new(cookie_jar => $jar);

my $csv_file = 'hr-export.csv';    # this file should be in the same folder as this script
my $csv_encoding = 'utf-8';
my $outfile = 'HR-merge-UTF-8.csv';
my %known_locations = ();

my $csv = Text::CSV->new(
	{
		allow_loose_quotes => 1,
		auto_diag => 1,
		binary => 1,
		empty_is_undef => 1,
		sep_char => q{;},
		quote_char => undef,
		escape_char => undef,
		strict => 1,
		allow_whitespace => 1,    # strip whitespace around separator
	}
);

sub read_csv {
	open my $in_fh, "<:encoding($csv_encoding)", $csv_file;
	read $in_fh, my $csv_string, -s $in_fh;
	close $in_fh;

	open my $string_fh, '<:encoding(utf-8)', \(encode('utf-8', $csv_string));

	return $string_fh;
}

sub prepare_url {
	my ($row) = shift;

	my $street = $row->[3];

	my $town_and_postalcode = $row->[4];
	$town_and_postalcode =~ s/"//g;    # remove quotes "
	$town_and_postalcode =~ s/\s+$//g;    # remove trailing whitespace
	my ($town, $postalcode) = split(", ", $town_and_postalcode);
	my $municipality = $row->[5];
	my $county = $row->[6];

	my $url
		= "https://geocode.maps.co/search?street=$street&town=$town&postalcode=$postalcode&municipality=$municipality&county=$county&country=Croatia&country_code=hr\n";

	$url =~ s/[ \t]/+/g;
	return $url;
}

sub get_lat_lon_sub {
	my ($url_get) = shift;
	my $lt = "";
	my $ln = "";

	my $search_coordinates = $ua->get($url_get);
	if ($search_coordinates->is_success) {
		my ($search_coordinates_result) = $search_coordinates->decoded_content;
		# convert to json
		my $json_data = from_json($search_coordinates_result);

		for my $hashref (@{$json_data}) {
			$lt = $hashref->{lat};
			$ln = $hashref->{lon};
			last;
		}
	}
	else {
		die $search_coordinates->status_line;
	}
	Time::HiRes::sleep(0.5);    # 2 requests per second limitation

	return ($lt, $ln);
}

sub get_lat_lon {
	my ($url) = shift;
	my $lat = "";
	my $lon = "";

	# if already know, update direclty lat lon
	if (exists $known_locations{$url}) {
		($lat, $lon) = split(",", $known_locations{$url});
	}
	else {
		($lat, $lon) = get_lat_lon_sub($url);

		if ($lat eq "" || $lon eq "") {
			# street name not recognized (example: "V. Cecelje 6" -> Ulica Vilima Cecelja)
			# remove street name (first parameter) from the search
			$url =~ s/\?(.*?)&/\?/;
			($lat, $lon) = get_lat_lon_sub($url);
			if ($lat eq "" || $lon eq "") {
				# county prevents to get results (example: Petkovec Toplički 42C Varaždinske Toplice, 42223)
				$url =~ s/\&county=(.*?)&/\&/;
				($lat, $lon) = get_lat_lon_sub($url);
				if ($lat eq "" || $lon eq "") {
					# postalcode prevents to get results (example: Vrh Visočki 21	Visoko, 42224)
					$url =~ s/\&postalcode=(.*?)&/\&/;
					($lat, $lon) = get_lat_lon_sub($url);
					if ($lat eq "" || $lon eq "") {
						die "Error, got empty coordinate for $url.\n";
					}
				}
			}
		}
	}
	$known_locations{$url} = "$lat,$lon";
	return ($lat, $lon);
}

sub write_csv {
	my $rows_ref = shift;

	open my $out_fh, '>:encoding(utf-8)', $outfile;
	my $csv_out = Text::CSV->new(
		{
			eol => "\n",
			sep => ";",
			quote_space => 0,
			binary => 1
		}
	) or die "Cannot use CSV: " . Text::CSV->error_diag();

	foreach my $row_ref (@$rows_ref) {
		$csv_out->print($out_fh, $row_ref);
	}
	close $out_fh;

	return;
}

sub main {
	my $in_fh = read_csv;

	my @header = (
		'number', 'app_number', 'approved_establishment', 'street_address',
		'town_and_postal_code', 'municipality', 'county', 'remark',
		'sante', 'sante_activity', 'species'
	);

	push(@header, 'lat', 'lng');

	my @rows = (\@header);

	# Skip header
	$csv->getline($in_fh);

	while (defined(my $row = $csv->getline($in_fh))) {
		my $row_url = prepare_url($row);
		my ($lattitude, $longitude) = get_lat_lon($row_url);
		push(@{$row}, $lattitude, $longitude);
		push @rows, $row;
	}

	write_csv(\@rows);

	return;
}

exit main();
