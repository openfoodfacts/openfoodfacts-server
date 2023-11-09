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
	use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
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
		$log_emails
		$mongodb
		$mongodb_host
		$mongodb_timeout_ms
		$memd_servers
		$google_cloud_vision_api_key
		$google_cloud_vision_api_url
		$crowdin_project_identifier
		$crowdin_project_key
		$robotoff_url
		$query_url
		$events_url
		$facets_kp_url
		$events_username
		$events_password
		$redis_url
		%server_options
		$build_cache_repo
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;    # no 'my' keyword for these
use utf8;

# Set PRODUCERS_PLATFORM to a non empty and non 0 value to enable the producers platform
# by default, the producers platform is not activated
$producers_platform = $ENV{PRODUCERS_PLATFORM} ? 1 : 0;

# server constants
# $po_domain and $server_domain are prefixed by pro. on the producers platform
my $po_domain = $producers_platform ? "pro." . $ENV{PRODUCT_OPENER_DOMAIN} : $ENV{PRODUCT_OPENER_DOMAIN};
my $po_port = $ENV{PRODUCT_OPENER_PORT};
my $is_localhost = index($po_domain, 'localhost') != -1;

$server_domain = $is_localhost && $po_port != '80' ? "$po_domain:$po_port" : $po_domain;
@ssl_subdomains = $is_localhost ? qw() : qw(*);

# server paths
$data_root = "/mnt/podata";
$www_root = "/opt/product-opener/html";
$conf_root = "/opt/product-opener/conf";
$geolite2_path = $ENV{GEOLITE2_PATH};

my $mongodb_url = $ENV{MONGODB_HOST} || "mongodb";
$mongodb_host = "mongodb://$mongodb_url:27017";
$mongodb = $producers_platform ? "off-pro" : "off";
$mongodb_timeout_ms = 50000;    # config option max_time_ms/maxTimeMS

$memd_servers = ["memcached:11211"];

$google_cloud_vision_api_key = $ENV{GOOGLE_CLOUD_VISION_API_KEY};
$google_cloud_vision_api_url = $ENV{GOOGLE_CLOUD_VISION_API_URL} || "https://vision.googleapis.com/v1/images:annotate";

$crowdin_project_identifier = $ENV{CROWDIN_PROJECT_IDENTIFIER};
$crowdin_project_key = $ENV{CROWDIN_PROJECT_KEY};

my $postgres_host = $ENV{POSTGRES_HOST} || "postgres";
my $postgres_user = $ENV{POSTGRES_USER};
my $postgres_password = $ENV{POSTGRES_PASSWORD};
my $postgres_db = $ENV{POSTGRES_DB} || "minion";
my $postgres_url = "postgresql://${postgres_user}:${postgres_password}\@${postgres_host}/${postgres_db}";

# do we want to log emails instead of sending them (dev environments)
$log_emails = $ENV{OFF_LOG_EMAILS} // 0;

# Set this to your instance of https://github.com/openfoodfacts/robotoff/ to
# enable an in-site robotoff-asker in the product page
$robotoff_url = $ENV{ROBOTOFF_URL};

# Set this to your instance of https://github.com/openfoodfacts/openfoodfacts-query/ to
# enable product counts and aggregations / facets
$query_url = $ENV{QUERY_URL};

# Set this to your instance of https://github.com/openfoodfacts/openfoodfacts-events
# enable creating events for some actions (e.g. when a product is edited)
$events_url = $ENV{EVENTS_URL};
$events_username = $ENV{EVENTS_USERNAME};
$events_password = $ENV{EVENTS_PASSWORD};

# Set this to your instance of https://github.com/openfoodfacts/facets-knowledge-panels
# Inject facet knowledge panels
$facets_kp_url = $ENV{FACETS_KP_URL};

# Set this to your instance of the search service to enable writes to it
$redis_url = $ENV{REDIS_URL};

%server_options = (
	private_products => $producers_platform,    # 1 to make products visible only to the owner (producer platform)
	producers_platform => $producers_platform,
	minion_backend => {Pg => $postgres_url},
	minion_local_queue => $server_domain,
	minion_export_queue => $ENV{PRODUCT_OPENER_DOMAIN},
	cookie_domain => $ENV{PRODUCT_OPENER_DOMAIN},
	export_servers => {public => "off", experiment => "off-exp"},
	ip_whitelist_session_cookie => ["", ""],
	export_data_root => "/mnt/podata/export",
	minion_daemon_server_and_port => "http://0.0.0.0:3001",
	# this one does not seems to be used
	minion_admin_server_and_port => "http://0.0.0.0:3003",
);

$build_cache_repo = $ENV{BUILD_CACHE_REPO};

1;
