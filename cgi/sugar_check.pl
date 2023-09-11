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

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;
use Encode;
use JSON::PP;
use ProductOpener::Display qw/single_param/;
use ProductOpener::Paths qw/:all/;

my $debug = 0;

my $code = decode utf8 => single_param('code');
my $product = decode utf8 => single_param('product');
my $name = decode utf8 => single_param('name');
my $answer = decode utf8 => single_param('answer');
my $actual = decode utf8 => single_param('actual');
my $points = decode utf8 => single_param('points');

my $current_year = (localtime())[5] + 1900;
open(my $OUT, ">>", $BASE_DIRS{PRIVATE_DATA} . "/${current_year}_sugar_log");
print $OUT remote_addr() . "\t"
	. time() . "\t"
	. $product . "\t"
	. $code . "\t"
	. $actual . "\t"
	. $answer . "\t"
	. $points . "\n";
close $OUT;

print header(-type => 'text/html', -charset => 'utf-8');
