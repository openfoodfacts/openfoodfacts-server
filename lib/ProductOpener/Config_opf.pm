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

		$facets_kp_url
		$redis_url

		$mongodb
		$mongodb_host
		$mongodb_timeout_ms

		$memd_servers

		$google_analytics

		$thumb_size
		$crop_size
		$small_size
		$display_size
		$zoom_size

		$page_size

		%options
		%server_options

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
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;    # no 'my' keyword for these

use ProductOpener::Config2;

$flavor = "opf";

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

$options{product_type} = "product";

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

$google_cloud_vision_api_key = $ProductOpener::Config2::google_cloud_vision_api_key;
$google_cloud_vision_api_url = $ProductOpener::Config2::google_cloud_vision_api_url;

$crowdin_project_identifier = $ProductOpener::Config2::crowdin_project_identifier;
$crowdin_project_key = $ProductOpener::Config2::crowdin_project_key;

# Set this to your instance of https://github.com/openfoodfacts/robotoff/ to
# enable an in-site robotoff-asker in the product page
$robotoff_url = $ProductOpener::Config2::robotoff_url;
$query_url = $ProductOpener::Config2::query_url;

# Set this to your instance of https://github.com/openfoodfacts/openfoodfacts-events
# enable creating events for some actions (e.g. when a product is edited)
$events_url = $ProductOpener::Config2::events_url;
$events_username = $ProductOpener::Config2::events_username;
$events_password = $ProductOpener::Config2::events_password;

# server options

%server_options = %ProductOpener::Config2::server_options;

$build_cache_repo = $ProductOpener::Config2::build_cache_repo;

$reference_timezone = 'Europe/Paris';

$contact_email = 'contact@openfoodfacts.org';
$admin_email = 'stephane@openfoodfacts.org';
$producers_email = 'producers@openfoodfacts.org';

$thumb_size = 100;
$crop_size = 400;
$small_size = 200;
$display_size = 400;
$zoom_size = 800;

$page_size = 20;

$google_analytics = <<HTML
HTML
	;

#@product_image_fields = qw(front ingredients);

# fields for which we will load taxonomies

@taxonomy_fields
	= qw(units states countries languages labels categories additives allergens traces nutrient_levels ingredients periods_after_opening);

# tag types (=facets) that should be indexed by web crawlers, all other tag types are not indexable
@index_tag_types = qw(brands categories labels additives products);

# fields in product edit form, above ingredients and nutrition facts

#@product_fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link periods_after_opening expiration_date purchase_places stores countries  );
@product_fields
	= qw(quantity packaging brands categories labels origins manufacturing_places emb_codes link periods_after_opening expiration_date purchase_places stores countries  );

# fields currently not shown in the default edit form, can be used in imports or advanced edit forms

@product_other_fields = qw(
	producer_version_id
	net_weight_value net_weight_unit drained_weight_value drained_weight_unit volume_value volume_unit
	other_information conservation_conditions recycling_instructions_to_recycle recycling_instructions_to_discard
);

# fields shown on product page
# do not show purchase_places

@display_fields
	= qw(generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link periods_after_opening stores countries);

# fields displayed in a new section after the nutrition facts

@display_other_fields
	= qw(other_information conservation_conditions recycling_instructions_to_recycle recycling_instructions_to_discard);

# fields for drilldown facet navigation

@drilldown_fields = qw(
	brands
	categories
	labels
	packaging
	periods_after_opening
	origins
	manufacturing_places
	emb_codes
	ingredients
	ingredients_n
	additives
	allergens
	traces
	nutrition_grades
	languages
	users
	states
	entry_dates
	last_edit_dates
);

@export_fields = qw(
	code
	creator
	created_t
	last_modified_t
	product_name
	generic_name
	quantity
	packaging
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
	allergens
	traces
	serving_size
	serving_quantity
	additives_n
	additives
	states
);

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

# allow moving products to other instances of Product Opener on the same server
# e.g. OFF -> OBF

$options{current_server} = "opf";

$options{other_servers} = {
	obf => {
		name => "Open Beauty Facts",
		data_root => "/srv/obf",
		www_root => "/srv/obf/html",
		mongodb => "obf",
		domain => "openbeautyfacts.org",
	},
	off => {
		name => "Open Food Facts",
		data_root => "/srv/off",
		www_root => "/srv/off/html",
		mongodb => "off",
		domain => "openfoodfacts.org",
	},
	opff => {
		prefix => "opff",
		name => "Open Pet Food Facts",
		data_root => "/srv/opff",
		www_root => "/srv/opff/html",
		mongodb => "opff",
		domain => "openpetfoodfacts.org",
	}
};

$options{no_nutrition_table} = 1;

# Name of the Redis stream to which product updates are published
$options{redis_stream_name} = "product_updates_opf";

1;
