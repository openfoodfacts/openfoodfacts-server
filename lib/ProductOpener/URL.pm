﻿# This file is part of Product Opener.
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::URL;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&format_subdomain
					&subdomain_supports_https

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use experimental 'smartmatch';

use ProductOpener::Config qw/:all/;

sub format_subdomain {
	
	my ($sd) = @_;
	
	return $sd unless $sd;
	my $scheme;
	if (subdomain_supports_https($sd)) {
		$scheme = 'https';
	}
	else {
		$scheme = 'http';
	}

	return $scheme . '://' . $sd . '.' . $server_domain;
	
}

sub subdomain_supports_https {

	my ($sd) = @_;
	
	return $sd unless $sd;
	return 1 if grep $_ eq '*', @ssl_subdomains;
	return grep $_ eq $sd, @ssl_subdomains;

}

1;
