# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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

## no critic (RequireFilenameMatchesPackage);

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
		$sftp_root
		$www_root
		$geolite2_path
		$log_emails
		$mongodb
		$mongodb_host
		$mongodb_timeout_ms
		$memd_servers
		$tesseract_ocr_available
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
		$folksonomy_url
		$recipe_estimator_url
		$recipe_estimator_scipy_url
		$process_global_redis_events
		%server_options
		$build_cache_repo
		$rate_limiter_blocking_enabled
		$crm_url
		$crm_api_url
		$crm_username
		$crm_db
		$crm_pwd
		$serialize_to_json
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
$sftp_root = "/mnt/podata/sftp";
$geolite2_path = $ENV{GEOLITE2_PATH};

$mongodb_host = $ENV{MONGODB_HOST} || "mongodb";
$mongodb = $producers_platform ? "off-pro" : "off";
$mongodb_timeout_ms = 50000;    # config option max_time_ms/maxTimeMS

$memd_servers = ["memcached:11211"];

$tesseract_ocr_available = $ENV{TESSERACT_OCR_AVAILABLE} // 1;    # Set to 0 to disable Tesseract OCR
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
$process_global_redis_events = $ENV{PROCESS_GLOBAL_REDIS_EVENTS};

# Set this to your instance of https://github.com/openfoodfacts/folksonomy_api/ to
# enable folksonomy features
$folksonomy_url = $ENV{FOLKSONOMY_URL};
# recipe-estimator product service
# To test a locally running recipe-estimator with product opener in a docker dev environment:
# - run recipe-estimator with `uvicorn recipe_estimator.main:app --reload --host 0.0.0.0`
# $recipe_estimator_url = "http://host.docker.internal:8000/api/v3/estimate_recipe";
$recipe_estimator_url = $ENV{RECIPE_ESTIMATOR_URL};
$recipe_estimator_scipy_url = $ENV{RECIPE_ESTIMATOR_SCIPY_URL};

#$recipe_estimator_url = "http://host.docker.internal:8000/api/v3/estimate_recipe";
#$recipe_estimator_scipy_url = "http://host.docker.internal:8000/api/v3/estimate_recipe";

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

$rate_limiter_blocking_enabled = $ENV{RATE_LIMITER_BLOCKING_ENABLED} // "0";

# Odoo CRM
$crm_url = $ENV{ODOO_CRM_URL};
$crm_api_url = $crm_url . '//xmlrpc/2/' if $crm_url;
$crm_username = $ENV{ODOO_CRM_USER};
$crm_db = $ENV{ODOO_CRM_DB};
$crm_pwd = $ENV{ODOO_CRM_PASSWORD};

#11901: Remove once production is migrated
$serialize_to_json = $ENV{SERIALIZE_TO_JSON};
1;
