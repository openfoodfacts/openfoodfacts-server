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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::GeoIP;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&get_country_for_ip
					&get_country_code_for_ip

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use experimental 'smartmatch';

use ProductOpener::Config qw/:all/;

use GeoIP2::Database::Reader;
use Log::Any qw($log);

my $gi = GeoIP2::Database::Reader->new(file => $geolite2_path);

sub get_country_for_ip {
	my $ip = shift;

	my $country;
	eval {
		my $country_mod = $gi->country(ip => $ip);
		my $country_rec = $country_mod->country();
		$country = $country_rec->name();
	};

	if ($@) {
		$log->warn("GeoIP error", { error => $@ }) if $log->is_warn();
		$country = undef;
	}

	return $country;
}


sub get_country_code_for_ip {
	my $ip = shift;

	my $country;
	eval {
		my $country_mod = $gi->country(ip => $ip);
		my $country_rec = $country_mod->country();
		$country = $country_rec->iso_code();
	};

	if ($@) {
		$log->warn("GeoIP error", { error => $@ }) if $log->is_warn();
		$country = undef;
	}

	return $country;
}


1;
