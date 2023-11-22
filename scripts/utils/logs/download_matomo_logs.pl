#!/usr/bin/perl -w

use strict;

my $year = "2022";

for (my $month = 1; $month <= 12; $month++) {
	for (my $day = 1; $day <= 31; $day++) {
		my $date = sprintf("%d-%02d-%02d", $year, $month, $day);
		print STDERR "Downloading data for $date\n";
		system("wget -O matomo_app.log.scan.$date 'https://analytics.openfoodfacts.org/?module=API&method=Live.getLastVisitsDetails&idSite=2&period=day&date=$date&format=JSON&token_auth=[replace with token]&filter_limit=-1'");
	}
}
