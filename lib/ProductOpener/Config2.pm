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

package ProductOpener::Config2;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		$server_domain
		@ssl_subdomains
		$producers_platform
		$data_root
		$conf_root
		$www_root
		$geolite2_path
		$mongodb
		$mongodb_host
		$mongodb_timeout_ms
		$memd_servers
		$google_cloud_vision_api_key
		$crowdin_project_identifier
		$crowdin_project_key
		$robotoff_url
		%server_options
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these
use utf8;


# server constants
my $po_domain = $ENV{PRODUCT_OPENER_DOMAIN};
my $po_port = $ENV{PRODUCT_OPENER_PORT};
my $is_localhost = index($po_domain, 'localhost') != -1;

$server_domain = $is_localhost ? "$po_domain:$po_port" : $po_domain;
@ssl_subdomains = $is_localhost ? qw() : qw(*);
$producers_platform = $ENV{PRODUCERS_PLATFORM} || "0";

# server paths
$data_root = "/mnt/podata";
$www_root = "/opt/product-opener/html";
$conf_root = "/opt/product-opener/conf";
$geolite2_path = $ENV{GEOLITE2_PATH};

my $mongodb_url = $ENV{MONGODB_HOST} || "mongodb";
$mongodb_host = "mongodb://$mongodb_url:27017";
$mongodb = $producers_platform == "1" ? "off-pro" : "off";
$mongodb_timeout_ms = 50000; # config option max_time_ms/maxTimeMS

$memd_servers = [ "memcached:11211" ];

$google_cloud_vision_api_key = $ENV{GOOGLE_CLOUD_VISION_API_KEY};
$crowdin_project_identifier = $ENV{CROWDIN_PROJECT_IDENTIFIER};
$crowdin_project_key = $ENV{CROWDIN_PROJECT_KEY};

my $postgres_db = "postgres";
my $postgres_user = $ENV{POSTGRES_USER};
my $postgres_password = $ENV{POSTGRES_PASSWORD};
my $postgres_url = "postgresql://${postgres_user}:${postgres_password}\@${postgres_db}/minion";

# Set this to your instance of https://github.com/openfoodfacts/robotoff/ to
# enable an in-site robotoff-asker in the product page
$robotoff_url = $ENV{ROBOTOFF_URL};

%server_options = (
        private_products => $producers_platform,  # 1 to make products visible only to the owner (producer platform)
		producers_platform => $producers_platform,
		minion_backend => { Pg => $postgres_url},
		minion_local_queue => $producers_platform == "1" ? "pro.$server_domain" : $server_domain,
		minion_export_queue => $server_domain,
		cookie_domain => $po_domain,
		export_servers => { public => "off", experiment => "off-exp"},
		ip_whitelist_session_cookie => ["", ""]
);
1;
