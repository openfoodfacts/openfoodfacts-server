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

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;
use Encode;
use JSON::PP;

my $debug = 0;

my $code = decode utf8=>param('code');
my $product = decode utf8=>param('product');
my $name = decode utf8=>param('name');
my $answer = decode utf8=>param('answer');
my $actual = decode utf8=>param('actual');
my $points = decode utf8=>param('points');

open (my $OUT, ">>" , "/srv/sucres/logs/sugar_log");
print $OUT remote_addr() . "\t" . time() . "\t" . $product . "\t" . $code . "\t" . $actual . "\t" . $answer . "\t" . $points . "\n";
close $OUT;

print header( -type => 'text/html', -charset => 'utf-8' );
