#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();

my $short_l = undef;
if ($lang =~ /_/) {
	$short_l = $`,  # pt_pt
}

my %result = ();
foreach my $s (keys %Lang) {
	my $value;

	if (defined $Lang{$s}{$lang}) {
		$value = $Lang{$s}{$lang};
	}
	elsif ((defined $short_l) and (defined $Lang{$s}{$short_l}) and ($Lang{$s}{$short_l} ne '')) {
		$value = $Lang{$s}{$short_l};
	}
	elsif ((defined $Lang{$s}{en}) and ($Lang{$s}{en} ne '')) {
		$value = $Lang{$s}{en};
	}
	elsif (defined $Lang{$s}{fr}) {
		$value = $Lang{$s}{fr};
	}

	$result{$s} = $value if $value;
}

my $data = encode_json(\%result);

print "Content-Type: application/manifest+json; charset=UTF-8\r\nCache-Control: max-age=86400\r\n\r\n" . $data;

