#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

# This script operates on nginx log files that contain API product requests
# (of the form /api/[version]/.../[barcode])
#
# The log files must be filtered first to keep only the API requests and the
# apps you care about.
#
# e.g.
# grep "Official Android" api.20200716 > api.20200716.android
# -> the user agent has changed, it used to be "Official Android App"
# and is now "Open Food Facts Official Android App" 
# for ios, grep org.openfoodfacts.scanner
# old app in 2018:
# grep "nutrition_data_per" api.20200716 | grep "okhttp" > api.20200716.android-old-app
#
# cat api.20200716.ios api.20200928.ios | ./api_stats.pl

use strict;

my %months_ips = ();
my %months_scans = ();

my %month =( 
'Jan'=>'01',
'Feb'=>'02',
'Mar'=>'03',
'Apr'=>'04',
'May'=>'05',
'Jun'=>'06',
'Jul'=>'07',
'Aug'=>'08',
'Sep'=>'09',
'Oct'=>'10',
'Nov'=>'11',
'Dec'=>'12',
);

while (<STDIN>) {

	# 185.31.40.13 - - [03/Nov/2018:22:29:15 +0100] "GET /api/v0/product/148306001237.json HTTP/1.0" 200 71 "-" "-"

	if ($_ =~ /^(.*) .*\[\d\d\/(\w\w\w)\/(\d\d\d\d):.*\/api\/\w+\/\w+\/(\d+)/) {
		my $ip = $1;
		my $month = $month{$2};
		my $year = $3;
		my $code = $4;
		$month = $year . "-" . $month;

		

		#	print "ip: " . $ip . " - month: " . $month . " - code: " . $code . "\n";
		
		defined $months_ips{$month} or $months_ips{$month} = {};
		defined $months_scans{$month} or $months_scans{$month} = {};
		$months_ips{$month}{$ip} = 1;
		$months_scans{$month}{$ip . " " . $code} = 1;
	}
}

print "Active ips per month:\n";
foreach my $m (sort keys %months_ips) {
	print "$m\t" . scalar(keys %{$months_ips{$m}}) . "\n";
}

print "\nScans per month:\n";
foreach my $m (sort keys %months_scans) {
        print "$m\t" . scalar(keys %{$months_scans{$m}}) . "\n";
}


