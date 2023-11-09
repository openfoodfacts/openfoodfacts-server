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

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Web qw/get_countries_options_list/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;
use JSON::PP;

# This script returns a list of countries in the language of the interface in a JSON format
# it is used to display the dropdown list of countries

ProductOpener::Display::init_request();

my $term = decode utf8 => single_param('term');

my @options = @{get_countries_options_list($lang, undef)};
if (defined $term and $term ne '') {
	# filter by term
	@options = grep {$_->{label} =~ /$term/i} @options;
}
my %result = ();
# transform to simple dict and use codes
foreach my $option (@options) {
	my $code = country_to_cc($option->{value});
	next if not defined $code;
	$result{$code} = $option->{prefixed};
}

my $data = encode_json(\%result);

print "Content-Type: application/manifest+json; charset=UTF-8\r\nCache-Control: max-age=86400\r\n\r\n" . $data;

