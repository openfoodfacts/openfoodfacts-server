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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


=head1 NAME

ProductOpener::URL - generates the URL of the product

=head1 SYNOPSIS

C<ProductOpener::URL> is used to generate a URL of the product according to the subdomain .

	use ProductOpener::URL qw/:all/;

	my $image = "$www_root/images/products/$path/$filename.full.jpg";
	my $image_url = format_subdomain('static') . "/images/products/$path/$filename.full.jpg";
	
	# subdomain format:
	# [2 letters country code or "world" or "static"]

=head1 DESCRIPTION

The module implements the URL generation 
on the basis of subdomain format which can be country code, world or static and on the basis of subdomain's support for https or http.

=cut

package ProductOpener::URL;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&format_subdomain
		&subdomain_supports_https

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use experimental 'smartmatch';

use ProductOpener::Config qw/:all/;

=head1 FUNCTIONS

=head2 format_subdomain( SUBDOMAIN )

C<format_subdomain()> returns URL on the basis of subdomain and scheme (http/https)

=head3 Arguments

A scalar variable to indicate the subdomain (e.g. "us" or "static") needs to be passed as an argument. 

=head3 Return Values

The function returns a URL by concatenating scheme, subdomain and server-domain.

=cut

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

=head2 subdomain_supports_https( SUBDOMAIN )

C<subdomain_supports_https()> determines if the subdomain supports https.

=head3 Arguments

A scalar variable to indicate the subdomain (e.g. "us" or "static") needs to be passed as an argument. 

=head3 Return Values

The function returns true after evaluating the true value for the regular expression using grep or subdomain, ssl_subdomains

=cut

sub subdomain_supports_https {

	my ($sd) = @_;
	
	return $sd unless $sd;
	return 1 if grep { $_ eq '*' } @ssl_subdomains;
	return grep { $_ eq $sd } @ssl_subdomains;

}

1;
