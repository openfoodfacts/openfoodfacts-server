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

# Script used to download Matomo events from the Matomo API
# day by day, as we otherwise get timeouts

# A Matomo API token needs to be passed as parameter
my $year = $ARGV[0];
my $token = $ARGV[1];

if ((not defined $year) or ($year !~ /^20\d\d$/) or (not defined $token)) {
	print STDERR ("Usage: download_matomo_logs.pl [year] [token]");
	exit;
}

for (my $month = 1; $month <= 12; $month++) {
	for (my $day = 1; $day <= 31; $day++) {
		my $date = sprintf("%d-%02d-%02d", $year, $month, $day);
		my $file = "matomo_app.log.scan.$date";
		# Sometime matomo timesout and we get a file with a 0 byte size
		# If we already have a file with a non 0 size, assume we already
		# successfully retrieved the file in a previous run, and skip it
		if ((-e $file) and (-s $file > 1000)) {
			print STDERR "Skipping $date (already downloaded)\n";
			next;
		}
		print STDERR "Downloading data for $date\n";
		system(
			"wget -O $file 'https://analytics.openfoodfacts.org/?module=API&method=Live.getLastVisitsDetails&idSite=2&period=day&date=$date&format=JSON&token_auth=$token&filter_limit=-1'"
		);
	}
}
