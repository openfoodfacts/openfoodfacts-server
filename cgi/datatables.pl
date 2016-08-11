#!/usr/bin/perl

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

Blogs::Display::init();
use Blogs::Lang qw/:all/;

# https://datatables.net/manual/server-side#Example-data
my $draw = int(param('draw')); # Draw counter. This is used by DataTables to ensure that the Ajax returns from server-side processing requests are drawn in sequence by DataTables
my $start = int(param('start')); # Paging first record indicator. This is the start point in the current data set (0 index based - i.e. 0 is the first record).
my $length = int(param('length')); # Number of records that the table can display in the current draw. It is expected that the number of records returned will be equal to this number, unless the server has fewer records to return. Note that this can be -1 to indicate that all records should be returned.
my $search = param('search[value]'); # Global search value. To be applied to all columns which have searchable as true.

my @columns = ();
my @orders = ();
foreach my $i (0..100) {
	my $column = param('column[' . $i . '][name]');
	next if (undef $column);
	$columns[$i] = $column;
}

foreach my $i (0..100) {
	my $column_index = param('order[' . $i . '][column]');
	next if (undef $column_index);
	$column_index = int($column_index);
	my $dir = param('order[' . $i . '][dir]');
	next if (undef $dir);
	$orders[$i] = ( 'column' => $columns[$column_index], 'dir' => $dir );
}

my $recordsTotal = 42;
my $recordsFiltered = 42;

my $data = 1;

my %result = (
	'draw' => $draw,
	'recordsTotal' => $recordsTotal,
	'recordsFiltered' => $recordsFiltered,
	'data' => $data,
);

my $json = encode_json(\%result);

print "Content-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\n\r\n" . $json;
