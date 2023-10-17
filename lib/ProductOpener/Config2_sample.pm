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

package ProductOpener::Config2;

use utf8;
use Modern::Perl '2017';
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		$server_domain
		@ssl_subdomains
		$data_root
		$conf_root
		$www_root
		$sftp_root
		$geolite2_path
		$mongodb
		$mongodb_host
		$mongodb_timeout_ms
		$memd_servers
		$crowdin_project_identifier
		$crowdin_project_key
		$robotoff_url
		$query_url
		$events_url
		$events_username
		$events_password
		$redis_url
		%server_options

	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;    # no 'my' keyword for these

# server constants
$server_domain = "openfoodfacts.org";

@ssl_subdomains = qw(
	*
);

# server paths
$www_root = "/home/off/html";
$conf_root = "/home/off";
$data_root = "/home/off";
$sftp_root = "/home/sftp";

$geolite2_path = '/usr/local/share/GeoLite2-Country/GeoLite2-Country.mmdb';

$mongodb = "off";    # MongoDB database name
$mongodb_host = "mongodb://localhost";
$mongodb_timeout_ms = 50000;    # config option max_time_ms/maxTimeMS

$memd_servers = ["127.0.0.1:11211"];

$crowdin_project_identifier = '';
$crowdin_project_key = '';

# Set this to your instance of https://github.com/openfoodfacts/robotoff/ to
# enable an in-site robotoff-asker in the product page
$robotoff_url = '';
$query_url = '';

# Set this to your instance of https://github.com/openfoodfacts/openfoodfacts-events
# enable creating events for some actions (e.g. when a product is edited)
$events_url = '';
$events_username = '';
$events_password = '';

$redis_url = '';

%server_options = (

	cookie_domain => "openfoodfacts.dev",    # if not set, default to $server _domain
	private_products => 1,    # Make products visible only to the owner
	export_servers => {public => "off", experiment => "off-exp"},
	ip_whitelist_session_cookie => ["172.19.0.1"],
);

1;
