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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use warnings;
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Lang qw/:all/;

foreach my $country (sort keys %{$properties{countries}}) {
	next if not $country;
	my $cc = $properties{countries}{$country}{"country_code_2:en"};
	if ($country eq 'en:world') {
		$cc = 'world';
	}
	else {
		next if not $cc;
		$cc = lc($cc);
	}

	print "$cc.$server_domain\n";
	foreach my $l (sort values %lang_lc) {
		next if not $l;
		print "$cc-$l.$server_domain\n";
        }
}

exit(0);

