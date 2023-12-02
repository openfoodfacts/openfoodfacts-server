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
		$sftp_root
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
		%oidc_options
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
$sftp_root = "/mnt/podata/sftp";
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

%oidc_options = (
	client_id => 'ProductOpener',
	client_secret => 'Cf4NdSAjZsNO9HLcuXeuvukzFu00roQa',
	authorize_uri =>
		"http://accounts.$ENV{PRODUCT_OPENER_DOMAIN}:8080/realms/open-products-facts/protocol/openid-connect/auth",
	access_token_uri =>
		"http://accounts.$ENV{PRODUCT_OPENER_DOMAIN}:8080/realms/open-products-facts/protocol/openid-connect/token",
	userinfo_endpoint =>
		"http://accounts.$ENV{PRODUCT_OPENER_DOMAIN}:8080/realms/open-products-facts/protocol/openid-connect/userinfo",
	reset_password_endpoint =>
		"http://accounts.$ENV{PRODUCT_OPENER_DOMAIN}:8080/realms/open-products-facts/login-actions/reset-credentials",
	account_service_endpoint => "http://accounts.$ENV{PRODUCT_OPENER_DOMAIN}:8080/realms/open-products-facts/account",
	keys =>
		'{"keys":[{"kid":"QjEI5mLtUTqKx-AWHvv09nnmsWb-DHByMVhAvmJ4x4g","kty":"RSA","alg":"RSA-OAEP","use":"enc","n":"xPTIGKfwDb8TjuihTW8WS7lR2G9hNofPLfNo3eAVkJaEGwzouam_dEL6WwluP-QTNmWxY_Al9w4fulA7ybAFwFDVs2BDNQFlPlAEy6yRjERd4odw4D_Pn8Ekta_xJv_WhQjCAIBB1lQaIjPqnHnOuoE56Uso9QLcTHkG9wVUEBHyIQG9nAfOtj-mhFZXgMNtqIjr1XEawZbGUdT2rvIPC9I4C_JmiRqttxp7mhiVraylrgQB3Y4GigtSGgvgtWc1hWkHhXVpm3srwlr1AbQ-QdVYaIX_XiobtYhnxX6O9sndZeeOVKY4XGW3ITf8DizUKM6ayWzPd0V6-bhvDniolw","e":"AQAB","x5c":["MIICtTCCAZ0CBgGLfQLGIjANBgkqhkiG9w0BAQsFADAeMRwwGgYDVQQDDBNvcGVuLXByb2R1Y3RzLWZhY3RzMB4XDTIzMTAyOTE5NTUxNVoXDTMzMTAyOTE5NTY1NVowHjEcMBoGA1UEAwwTb3Blbi1wcm9kdWN0cy1mYWN0czCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMT0yBin8A2/E47ooU1vFku5UdhvYTaHzy3zaN3gFZCWhBsM6Lmpv3RC+lsJbj/kEzZlsWPwJfcOH7pQO8mwBcBQ1bNgQzUBZT5QBMuskYxEXeKHcOA/z5/BJLWv8Sb/1oUIwgCAQdZUGiIz6px5zrqBOelLKPUC3Ex5BvcFVBAR8iEBvZwHzrY/poRWV4DDbaiI69VxGsGWxlHU9q7yDwvSOAvyZokarbcae5oYla2spa4EAd2OBooLUhoL4LVnNYVpB4V1aZt7K8Ja9QG0PkHVWGiF/14qG7WIZ8V+jvbJ3WXnjlSmOFxltyE3/A4s1CjOmslsz3dFevm4bw54qJcCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAMIIDQmO2Cw3m7FltqZt9QoolwUEYg8n8ptbFJXbo+jeJasZ/ln9SxRaCrNlKJRomXR5Qe+jrHgFXjSI907zXNyD1kOVEUEwJHlg5W2va10YOlSy0vo8wYBVyvwSLmOGrNoRMUniumV/AxBO4edXAYYVaWkViRIAoK7wVM+ScJoKN/ltEOkbtNaXDcLLMEaqPnxKmgUaMrtmY0Y5s49zxRB5mHeO1LLsOQ89JZ2REW31F37IlEA3PxywfeIjh1Gt4mYvjNnDf27E9fDT2P8resWT2PLIrFRqD/P9Zh9IuiDZuHXvLFvyv/Vbeksed43WbjFHt6IHIva1VwFD5Kx7Psg=="],"x5t":"py_DqtcP28A4pkm0i6uqZfir4vA","x5t#S256":"c8Cvsmfbo948WPXBeR0Ma3uSrX6xkcXayVUk05-PXX0"},{"kid":"YXAXhfV5sYAARngF0K_hopF1fL4_CF_XCI5p2LR8v4E","kty":"RSA","alg":"RS256","use":"sig","n":"zpIWihaPCar6B966_4157c0OGObHDAwWvqnyJnVItiR2RaL_NLwAiJuYpu0twFNUyeYjZ4jq3etDgLfJ2MN8K5LezCwPTp8l0yK_PoBYkv2aarm8TXc0JvCHMXR6CgFrSI-fsrJGtQRce91WWa2s7Bkgzk7uXjIjCq5OyuElaaDuyHkXTdxJpxoMbEBSbfpmUz5J2QY62gr0uI6vvTkCHWYGNOX-jp3dhCMC2l8QkbuZvOqZpWvkdlzL6ld0uHTAWpG-qwCI92OJU6oBSiLtWB-RE_BFfgzshr9wt7ujmuJlNIK0ppQzaa3tdWjN6pUA2WeJ8B_CpRAjYVLWObs_Bw","e":"AQAB","x5c":["MIICtTCCAZ0CBgGLfQK9mTANBgkqhkiG9w0BAQsFADAeMRwwGgYDVQQDDBNvcGVuLXByb2R1Y3RzLWZhY3RzMB4XDTIzMTAyOTE5NTUxM1oXDTMzMTAyOTE5NTY1M1owHjEcMBoGA1UEAwwTb3Blbi1wcm9kdWN0cy1mYWN0czCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM6SFooWjwmq+gfeuv+Nee3NDhjmxwwMFr6p8iZ1SLYkdkWi/zS8AIibmKbtLcBTVMnmI2eI6t3rQ4C3ydjDfCuS3swsD06fJdMivz6AWJL9mmq5vE13NCbwhzF0egoBa0iPn7KyRrUEXHvdVlmtrOwZIM5O7l4yIwquTsrhJWmg7sh5F03cSacaDGxAUm36ZlM+SdkGOtoK9LiOr705Ah1mBjTl/o6d3YQjAtpfEJG7mbzqmaVr5HZcy+pXdLh0wFqRvqsAiPdjiVOqAUoi7VgfkRPwRX4M7Ia/cLe7o5riZTSCtKaUM2mt7XVozeqVANlnifAfwqUQI2FS1jm7PwcCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAtReOpRW30Dm4ku+TlHKFVKan2vhArahnGQKiM6ml8RVMfxqAlWsPLuBxKHrNy6ugcyjWNanim9oJgeDjizyB1Csq15WFHCDGJ9xHjZfs2zfxLKwX64CqvKLZnfEG6p0wbUg+Tn97gf/8S2m9cQcW5o8Pftwd1vZvDRGIqf48Zzxtokbat5/kTIuZs6ddsknn2VX7Vi1wdfdZelw8Q4aOFjJk7pbwyIKdMttX4RZNGOw59IXMml92QDIEwSz3tjrIKAWJ2lgquZHTAdHW/J+jfR2cl7X5/1qmM5Vp7ng/+AGL2phrc9P/RHcLUkt2njw0KxpuGBqkO7aNDe1trkWmhA=="],"x5t":"bTT84GaWzHx30aXp7ClH6OCCXrE","x5t#S256":"-UPtv0txI8tOL7ohz-wfHqomsthADK4xGl8zYO09TA4"}]}',
	# Keycloak specific endpoint used to create users. This is currently required for backwards compatibility with apps
	# that create users by POSTing to /cgi/user.pl
	keycloak_users_endpoint =>
		"http://accounts.$ENV{PRODUCT_OPENER_DOMAIN}:8080/admin/realms/open-products-facts/users"
);

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
