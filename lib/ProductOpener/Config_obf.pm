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

package ProductOpener::Config;

use utf8;
use Modern::Perl '2017';
use Exporter qw< import >;

BEGIN {

	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		$flavor

		%string_normalization_for_lang
		%admins

		$server_domain
		@ssl_subdomains
		$conf_root
		$data_root
		$www_root
		$sftp_root
		$geolite2_path
		$reference_timezone
		$contact_email
		$admin_email
		$producers_email

		$tesseract_ocr_available
		$google_cloud_vision_api_key
		$google_cloud_vision_api_url

		$crowdin_project_identifier
		$crowdin_project_key

		$log_emails
		$robotoff_url
		$query_url
		$events_url
		$events_username
		$events_password

		$rate_limiter_blocking_enabled
		$facets_kp_url
		$redis_url
		$folksonomy_url
		$process_global_redis_events
		$mongodb
		$mongodb_host
		$mongodb_timeout_ms

		$recipe_estimator_url
		$recipe_estimator_scipy_url

		$memd_servers

		$analytics

		$thumb_size
		$crop_size
		$small_size
		$display_size
		$zoom_size

		%options
		%server_options
		%oidc_options

		@product_fields
		@product_other_fields
		@display_fields
		@display_other_fields
		@drilldown_fields
		@taxonomy_fields
		@index_tag_types
		@export_fields

		%tesseract_ocr_available_languages

		%weblink_templates

		@edit_rules

		$build_cache_repo
		$serialize_to_json
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;    # no 'my' keyword for these

use ProductOpener::Config2;

$flavor = 'obf';

# define the normalization applied to change a string to a tag id (in particular for taxonomies)
# tag ids are also used in URLs.

# unaccent:
# - useful when accents are sometimes ommited (e.g. in French accents are often not present on capital letters),
# either in print, or when typed by users.
# - dangerous if different words (in the same context like ingredients or category names) have the same unaccented form
# lowercase:
# - useful when the same word appears in lowercase, with a first capital letter, or in all caps.

# IMPORTANT: if you change it, you need to change $BUILD_TAGS_VERSION in Tags.pm

%string_normalization_for_lang = (
	# no_language is used for strings that are not in a specific language (e.g. user names)
	no_language => {
		unaccent => 1,
		lowercase => 1,
	},
	# default is used for languages that do not have specified values
	default => {
		unaccent => 0,
		lowercase => 1,
	},
	# German umlauts should not be converted (e.g. ä -> ae) as there are many conflicts
	de => {
		unaccent => 0,
		lowercase => 1,
	},
	# French has very few actual conflicts caused by unaccenting (one counter example is "pâtes" and "pâtés")
	# Accents or often not present in capital letters (beginning of word, or in all caps text).
	fr => {
		unaccent => 1,
		lowercase => 1,
	},
	# Same for Spanish, Italian and Portuguese
	es => {
		unaccent => 1,
		lowercase => 1,
	},
	it => {
		unaccent => 1,
		lowercase => 1,
	},
	pt => {
		unaccent => 1,
		lowercase => 1,
	},
	# English has very few accented words, and they are very often not accented by users or in ingredients lists etc.
	en => {
		unaccent => 1,
		lowercase => 1,
	},
);

%admins = map {$_ => 1} qw(
	alex-off
	cha-delh
	charlesnepote
	gala-nafikova
	hangy
	manoncorneille
	raphael0202
	stephane
	tacinte
	teolemon
);

%options = (
	site_name => "Open Beauty Facts",
	product_type => "beauty",
	og_image_url => "https://static.openfoodfacts.org/images/logos/obf-logo-vertical-white-social-media-preview.png",
	android_apk_app_link => "https://world.openbeautyfacts.org/images/apps/obf.apk?utm_source=obf&utf_medium=web",
	android_app_link =>
		"https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner&utm_source=obf&utf_medium=web",
	ios_app_link => "https://apps.apple.com/app/open-beauty-facts/id1122926380?utm_source=obf&utf_medium=web",
	facebook_page_url => "https://www.facebook.com/openfoodfacts?utm_source=obf&utf_medium=web",
	x_account => "OpenFoodFacts",
	# favicon HTML and images generated with https://realfavicongenerator.net/ using the SVG icon
	favicons => <<HTML
<link rel="apple-touch-icon" sizes="180x180" href="/images/favicon/obf/apple-touch-icon.png">
<link rel="icon" type="image/png" sizes="32x32" href="/images/favicon/obf/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/images/favicon/obf/favicon-16x16.png">
<link rel="manifest" href="/images/favicon/obf/site.webmanifest">
<link rel="mask-icon" href="/images/favicon/obf/safari-pinned-tab.svg" color="#5bbad5">
<link rel="shortcut icon" href="/images/favicon/obf/favicon.ico">
<meta name="msapplication-TileColor" content="#2b5797">
<meta name="msapplication-config" content="/images/favicon/obf/browserconfig.xml">
<meta name="theme-color" content="#ffffff">
HTML
	,
);

$options{export_limit} = 10000;

# Recent changes limits
$options{default_recent_changes_page_size} = 20;
$options{max_recent_changes_page_size} = 1000;

# List of products limits
$options{default_api_products_page_size} = 20;
$options{default_web_products_page_size} = 50;
$options{max_products_page_size} = 100;
$options{max_products_page_size_for_logged_in_users} = 1000;

# List of tags limits
$options{default_tags_page_size} = 100;
$options{max_tags_page_size} = 1000;

@edit_rules = ();

# server constants
$server_domain = $ProductOpener::Config2::server_domain;
@ssl_subdomains = @ProductOpener::Config2::ssl_subdomains;
$mongodb = $ProductOpener::Config2::mongodb;
$mongodb_host = $ProductOpener::Config2::mongodb_host;
$mongodb_timeout_ms = $ProductOpener::Config2::mongodb_timeout_ms;
$memd_servers = $ProductOpener::Config2::memd_servers;

# server paths
$www_root = $ProductOpener::Config2::www_root;
$data_root = $ProductOpener::Config2::data_root;
$conf_root = $ProductOpener::Config2::conf_root;

$geolite2_path = $ProductOpener::Config2::geolite2_path;

$tesseract_ocr_available = $ProductOpener::Config2::tesseract_ocr_available;
$google_cloud_vision_api_key = $ProductOpener::Config2::google_cloud_vision_api_key;
$google_cloud_vision_api_url = $ProductOpener::Config2::google_cloud_vision_api_url;

$crowdin_project_identifier = $ProductOpener::Config2::crowdin_project_identifier;
$crowdin_project_key = $ProductOpener::Config2::crowdin_project_key;

# Set this to your instance of https://github.com/openfoodfacts/robotoff/ to
# enable an in-site robotoff-asker in the product page
$robotoff_url = $ProductOpener::Config2::robotoff_url;
$query_url = $ProductOpener::Config2::query_url;

# recipe-estimator product service
# To test a locally running recipe-estimator with product opener in a docker dev environment:
# - run recipe-estimator with `uvicorn recipe_estimator.main:app --reload --host 0.0.0.0`
# $recipe_estimator_url = "http://host.docker.internal:8000/api/v3/estimate_recipe";

$recipe_estimator_url = $ProductOpener::Config2::recipe_estimator_url;
$recipe_estimator_scipy_url = $ProductOpener::Config2::recipe_estimator_scipy_url;

# Set this to your instance of https://github.com/openfoodfacts/openfoodfacts-events
# enable creating events for some actions (e.g. when a product is edited)
$events_url = $ProductOpener::Config2::events_url;
$events_username = $ProductOpener::Config2::events_username;
$events_password = $ProductOpener::Config2::events_password;

# Redis is used to push updates to the search server
$redis_url = $ProductOpener::Config2::redis_url;
$process_global_redis_events = $ProductOpener::Config2::process_global_redis_events;

# If $rate_limiter_blocking_enabled is set to 1, the rate limiter will block requests
# by returning a 429 error code instead of a 200 code
$rate_limiter_blocking_enabled = $ProductOpener::Config2::rate_limiter_blocking_enabled;

# Set this to your instance of https://github.com/openfoodfacts/folksonomy_api/ to
# enable folksonomy features
$folksonomy_url = $ProductOpener::Config2::folksonomy_url;

# server options

%server_options = %ProductOpener::Config2::server_options;

$build_cache_repo = $ProductOpener::Config2::build_cache_repo;

#11901: Remove once production is migrated
$serialize_to_json = $ProductOpener::Config2::serialize_to_json;

$reference_timezone = 'Europe/Paris';

$contact_email = 'contact@openfoodfacts.org';
$admin_email = 'stephane@openfoodfacts.org';
$producers_email = 'producers@openfoodfacts.org';

$thumb_size = 100;
$crop_size = 400;
$small_size = 200;
$display_size = 400;
$zoom_size = 800;

$analytics = <<HTML
<!-- Matomo -->
<script>
  var _paq = window._paq = window._paq || [];
  /* tracker methods like "setCustomDimension" should be called before "trackPageView" */
  _paq.push(["setDocumentTitle", document.domain + "/" + document.title]);
  _paq.push(["setCookieDomain", "*.openbeautyfacts.org"]);
  _paq.push(["setDomains", ["*.openbeautyfacts.org"]]);
  _paq.push(["setDoNotTrack", true]);
  _paq.push(["disableCookies"]);
  _paq.push(['trackPageView']);
  _paq.push(['enableLinkTracking']);
  (function() {
    var u="//analytics.openfoodfacts.org/";
    _paq.push(['setTrackerUrl', u+'matomo.php']);
    _paq.push(['setSiteId', '10']);
    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
    g.async=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);
  })();
</script>
<noscript><p><img src="//analytics.openfoodfacts.org/matomo.php?idsite=10&amp;rec=1" style="border:0;" alt="" /></p></noscript>
HTML
	;

# fields for which we will load taxonomies
# note: taxonomies that are used as properties of other taxonomies must be loaded first
# (e.g. additives_classes are referenced in additives)
# Below is a list of all of the taxonomies with other taxonomies that reference them
# If there are entries in () these are other taxonomies that are combined into this one
#
# additives
# additives_classes: additives, minerals
# allergens: ingredients, traces
# amino_acids
# categories
# countries:
# data_quality
# data_quality_bugs (data_quality)
# data_quality_errors (data_quality)
# data_quality_errors_producers (data_quality)
# data_quality_info (data_quality)
# data_quality_warnings (data_quality)
# data_quality_warnings_producers (data_quality)
# food_groups: categories
# improvements
# ingredients_analysis
# ingredients_processing:
# ingredients (additives_classes, additives, minerals, vitamins, nucleotides, other_nutritional_substances): labels
# labels: categories
# languages:
# minerals
# misc
# nova_groups
# nucleotides
# nutrient_levels
# nutrients
# origins (countries): categories, ingredients, labels
# other_nutritional_substances
# packaging_materials: packaging_recycling, packaging_shapes
# packaging_recycling
# packaging_shapes: packaging_materials, packaging_recycling
# packaging (packaging_materials, packaging_shapes, packaging_recycling, preservation): labels
# periods_after_opening:
# states:
# traces (allergens)
# vitamins

@taxonomy_fields = qw(
	units
	languages states countries
	allergens origins additives_classes ingredients
	packaging_shapes packaging_materials packaging_recycling packaging
	labels categories
	ingredients_processing
	additives vitamins minerals traces
	ingredients_analysis
	nutrients misc
	periods_after_opening
	data_quality data_quality_bugs data_quality_info data_quality_warnings data_quality_errors data_quality_warnings_producers data_quality_errors_producers
	improvements
	inci_functions
	brands
);

# tag types (=facets) that should be indexed by web crawlers, all other tag types are not indexable
@index_tag_types = qw(brands categories labels additives products);

# fields in product edit form, above ingredients and nutrition facts

@product_fields = qw(quantity packaging brands categories labels origins manufacturing_places
	emb_codes link expiration_date purchase_places stores countries  );

# fields currently not shown in the default edit form, can be used in imports or advanced edit forms

@product_other_fields = qw(
	producer_product_id
	producer_version_id
	brand_owner
	quantity_value
	quantity_unit
	serving_size_value
	serving_size_unit
	net_weight_value
	net_weight_unit
	drained_weight_value
	drained_weight_unit
	volume_value
	volume_unit
	other_information
	conservation_conditions
	recycling_instructions_to_recycle
	recycling_instructions_to_discard
	origin
	customer_service
	producer
	preparation
	warning
	data_sources
	obsolete
	obsolete_since_date
	periods_after_opening
);

# fields shown on product page
# do not show purchase_places

@display_fields = qw(
	generic_name
	quantity
	packaging
	brands
	brand_owner
	categories
	labels
	origin
	origins
	producer
	manufacturing_places
	emb_codes
	link stores
	countries
);

# fields displayed in a new section after the nutrition facts

@display_other_fields = qw(
	other_information
	preparation
	warning
	conservation_conditions
	periods_after_opening
	recycling_instructions_to_recycle
	recycling_instructions_to_discard
	customer_service
);

# fields for drilldown facet navigation
# If adding to this list ensure that the tables are being replicated to Postgres in the openfoodfacts-query repo

@drilldown_fields = qw(
	brands
	categories
	labels
	packaging
	origins
	manufacturing_places
	emb_codes
	ingredients
	additives
	vitamins
	minerals
	allergens
	traces
	misc
	languages
	users
	states
	data_sources
	entry_dates
	last_edit_dates
	last_check_dates
	teams
);

@export_fields = qw(
	code
	creator
	created_t
	last_modified_t
	last_modified_by
	last_updated_t
	product_name
	abbreviated_product_name
	generic_name
	quantity
	packaging
	packaging_text
	brands
	categories
	origins
	manufacturing_places
	labels
	emb_codes
	cities
	purchase_places
	stores
	countries
	ingredients_text
	ingredients_tags
	ingredients_analysis_tags
	allergens
	traces
	serving_size
	serving_quantity
	no_nutrition_data
	additives_n
	additives
	states
	brand_owner
	product_quantity
	owner
	data_quality_errors_tags
	unique_scans_n
	popularity_tags
	completeness
	last_image_t
);

# Used to generate the list of possible product attributes, which is
# used to display the possible choices for user preferences
$options{attribute_groups}
	= [["ingredients_analysis", ["vegan", "palm_oil_free",]], ["labels", ["labels_organic", "labels_fair_trade"]],];

# default preferences for attributes
$options{attribute_default_preferences} = {
	"labels_organic" => "important",
	"labels_fair_trade" => "important",
};

use JSON::MaybeXS;
$options{attribute_default_preferences_json}
	= JSON->new->utf8->canonical->encode($options{attribute_default_preferences});

# for ingredients OCR, we use tesseract-ocr
# on debian, dictionaries are in /usr/share/tesseract-ocr/tessdata
# %tesseract_ocr_available_languages provides mapping between OFF 2 letter language codes
# and the available tesseract dictionaries
# Tesseract uses 3-character ISO 639-2 language codes
# all dictionaries: apt-get install tesseract-ocr-all

%tesseract_ocr_available_languages = (
	en => "eng",
	de => "deu",
	es => "spa",
	fr => "fra",
	it => "ita",
	#	ja => "jpn", # not available with tesseract 2
	nl => "nld",
);

# weblink definitions for known tags, ie. wikidata:en:Q123 => https://www.wikidata.org/wiki/Q123

%weblink_templates = (

	'wikidata:en' => {
		href => 'https://www.wikidata.org/wiki/%s',
		text => 'Wikidata',
		parse => sub {
			my ($url) = @_;
			if ($url =~ /^https?:\/\/www.wikidata.org\/wiki\/(Q\d+)$/) {
				return $1;
			}

			return;
		}
	},

);

$options{display_tag_ingredients} = [

	'COSING',
	'CAS',
	'EINECS',
	'INN Name',
	'Ph Eur Name',
	'@inci_functions',
	'INCI Description',
	'INCI Restriction',

];

$options{no_nutrition_table} = 1;

# Name of the Redis stream to which product updates are published
$options{redis_stream_name} = "product_updates";

1;
