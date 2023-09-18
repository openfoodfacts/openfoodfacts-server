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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::GeoIP - finds the country name and iso code from the given IP address.

=head1 SYNOPSIS

C<ProductOpener::GeoIP> is used to find the country name and iso code from the IP address using GeoIP2 API.

    use ProductOpener::GeoIP qw/:all/;

    $geolite2_path = '/usr/local/share/GeoLite2-Country/GeoLite2-Country.mmdb';
    $geolite2_path is a path to geo IP location max mind database file.

    Max Mind DataBase file(.mmdb) is a database format that maps the given IP addresses to their geolocation.

=head1 DESCRIPTION

The module implements the functionality to find the country name, and iso code by using the GeoIP2 API.
The functions used in this module take the IP address and return the geolocation.

=cut

package ProductOpener::GeoIP;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_country_for_ip
		&get_country_code_for_ip

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use experimental 'smartmatch';

use ProductOpener::Config qw/:all/;

use GeoIP2::Database::Reader;
use Log::Any qw($log);

my $gi;
if (-e $geolite2_path) {
	$gi = GeoIP2::Database::Reader->new(file => $geolite2_path);
}

=head1 FUNCTIONS

=head2 get_country_for_ip()

C<get_country_for_ip()> takes the IP address as an input parameter and returns the country name where the IP address is located.

=head3 Arguments

One scalar variable ip is passed as an argument.

=head3 Return values

If the function executes successfully it returns the country name. On the other hand, if it throws an exception, it simply returns undefined.

=cut

sub get_country_for_ip ($ip) {
	return unless $gi;

	my $country;
	eval {
		my $country_mod = $gi->country(ip => $ip);
		my $country_rec = $country_mod->country();
		$country = $country_rec->name();
	};

	if ($@) {
		$log->warn("GeoIP error", {error => $@}) if $log->is_warn();
		$country = undef;
	}

	return $country;
}

=head1 FUNCTIONS

=head2 get_country_code_for_ip()

C<get_country_code_for_ip()> takes the IP address as input parameter and returns the country iso code where IP address is located.

=head3 Arguments

One scalar variable ip is passed as an argument.

=head3 Return values

If the function executes successfully it returns the two-character ISO 3166-1 (http://en.wikipedia.org/wiki/ISO_3166-1) alpha code for the country where the IP address is located (eg. "AF" for Afghanistan).
On the other hand, if it throws an exception, it simply returns undefined.

=cut

sub get_country_code_for_ip ($ip) {
	return unless $gi;

	my $country;
	eval {
		my $country_mod = $gi->country(ip => $ip);
		my $country_rec = $country_mod->country();
		$country = $country_rec->iso_code();
	};

	if ($@) {
		$log->warn("GeoIP error", {error => $@}) if $log->is_warn();
		$country = undef;
	}

	return $country;
}

1;
