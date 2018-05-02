#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use CGI qw/:all/;

use Modern::Perl '2012';

my $ip = remote_addr();

if (defined $ARGV[0]) {
	$ip = $ARGV[0];
}

        use Geo::IP;
        my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);
        # look up IP address '24.24.24.24'
        # returns undef if country is unallocated, or not defined in our database
        my $country = $gi->country_code_by_addr($ip);

print header();

print "IP: $ip - Country: $country\n";
