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

# define the normalization applied to change a string to a tag id (in particular for taxonomies)
# tag ids are also used in URLs.

# unaccent:
# - useful when accents are sometimes ommited (e.g. in French accents are often not present on capital letters),
# either in print, or when typed by users.
# - dangerous if different words (in the same context like ingredients or category names) have the same unaccented form
# lowercase:
# - useful when the same word appears in lowercase, with a first capital letter, or in all caps.

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
	ca => {
		unaccent => 1,
		lowercase => 1,
	},
	es => {
		unaccent => 1,
		lowercase => 1,
	},
	it => {
		unaccent => 1,
		lowercase => 1,
	},
	nl => {
		unaccent => 1,
		lowercase => 1,
	},
	pt => {
		unaccent => 1,
		lowercase => 1,
	},
	sk => {
		unaccent => 1,
		lowercase => 1,
	},
	# English has very few accented words, and they are very often not accented by users or in ingredients lists etc.
	en => {
		unaccent => 1,
		lowercase => 1,
	},
	# xx: language less entries, also deaccent
	xx => {
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

$options{export_limit} = 10000;

$options{users_who_can_upload_small_images} = {
	map {$_ => 1}
		qw(
		manoncorneille
		systeme-u
		stephane
		teolemon
		)
};

$options{product_type} = "food";

# edit rules
# see ProductOpener::Products::process_product_edit_rules for documentation
@edit_rules = (

	{
		name => "Edit Rules Testing",
		conditions => [["user_id", "editrulestest"],],
		actions => [
			["ignore_if_existing_ingredients_text_fr"],
			["warn_if_0_nutriment_fruits-vegetables-nuts"],
			["warn_if_greater_nutriment_fruits-vegetables-nuts", 0],
			["ignore_if_regexp_match_packaging", '\b(artikel|produit|producto|produkt|produkte)\b'],
		],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},

	{
		name => "Yuka",
		conditions => [["user_id", "kiliweb"],],
		actions => [
			["warn_if_existing_brands"],
			["ignore_if_existing_ingredients_text"],
			["ignore_if_existing_ingredients_text_fr"],
			["ignore_if_0_nutriment_fruits-vegetables-nuts"],
			["ignore_if_greater_nutriment_fruits-vegetables-nuts", 0],
		],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},

	{
		name => "Yuka - checked",
		conditions => [["user_id", "kiliweb"], ["in_states_tags", "en:checked"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},

	{
		name => "Yuka - systeme-u",
		conditions => [["user_id", "kiliweb"], ["in_editors_tags", "systeme-u"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Yuka - fleury michon",
		conditions => [["user_id", "kiliweb"], ["in_editors_tags", "fleury-michon"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Yuka - Casino",
		conditions => [["user_id", "kiliweb"], ["in_editors_tags", "casino"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Yuka - Carrefour",
		conditions => [["user_id", "kiliweb"], ["in_editors_tags", "carrefour"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Yuka - LDC",
		conditions => [["user_id", "kiliweb"], ["in_editors_tags", "ldc"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},

	{
		name => "Date Limite",
		conditions => [["user_id", "date-limite-app"],],
		actions => [["ignore_if_regexp_match_packaging", '\b(artikel|produit|producto|produkt|produkte)\b'],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},

	{
		name => "Fleury Michon",
		conditions => [["user_id_not", "fleury-michon"], ["in_brands_tags", "fleury-michon"],],
		actions => [["warn"]],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},

	# as of 2023-01-27 far too much errors in updates
	# No fix on the app
	{
		name => "Halal App Chakib",
		conditions => [["user_id", "halal-app-chakib"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Vegan App Chakib",
		conditions => [["user_id", "vegan-app-chakib"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Vegetarian App Chakib",
		conditions => [["user_id", "vegetarian-app-chakib"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Allergies App Chakib",
		conditions => [["user_id", "allergies-app-chakib"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},
	{
		name => "Additives App Chakib",
		conditions => [["user_id", "additives-app-chakib"],],
		actions => [["ignore"],],
		notifications => [
			qw (
				slack_channel_edit-alert
			)
		],
	},

);

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
$sftp_root = $ProductOpener::Config2::sftp_root;    # might be undef

$geolite2_path = $ProductOpener::Config2::geolite2_path;

$google_cloud_vision_api_key = $ProductOpener::Config2::google_cloud_vision_api_key;
$google_cloud_vision_api_url = $ProductOpener::Config2::google_cloud_vision_api_url;

$crowdin_project_identifier = $ProductOpener::Config2::crowdin_project_identifier;
$crowdin_project_key = $ProductOpener::Config2::crowdin_project_key;

# Set this to your instance of https://github.com/openfoodfacts/robotoff/ to
# enable an in-site robotoff-asker in the product page
$robotoff_url = $ProductOpener::Config2::robotoff_url;
$query_url = $ProductOpener::Config2::query_url;

# do we want to send emails
$log_emails = $ProductOpener::Config2::log_emails;

# Set this to your instance of https://github.com/openfoodfacts/openfoodfacts-events
# enable creating events for some actions (e.g. when a product is edited)
$events_url = $ProductOpener::Config2::events_url;
$events_username = $ProductOpener::Config2::events_username;
$events_password = $ProductOpener::Config2::events_password;

# Redis is used to push updates to the search server
$redis_url = $ProductOpener::Config2::redis_url;

# Facets knowledge panels url
$facets_kp_url = $ProductOpener::Config2::facets_kp_url;

# server options

%server_options = %ProductOpener::Config2::server_options;

$build_cache_repo = $ProductOpener::Config2::build_cache_repo;

$reference_timezone = 'Europe/Paris';

$contact_email = 'contact@openfoodfacts.org';
$producers_email = 'producers@openfoodfacts.org';
$admin_email = 'stephane@openfoodfacts.org';

$thumb_size = 100;
$crop_size = 400;
$small_size = 200;
$display_size = 400;
$zoom_size = 800;

$page_size = 24;

$google_analytics = <<HTML
<!-- Matomo -->
<script>
  var _paq = window._paq = window._paq || [];
  /* tracker methods like "setCustomDimension" should be called before "trackPageView" */
  _paq.push(["setDocumentTitle", document.domain + "/" + document.title]);
  _paq.push(["setCookieDomain", "*.openfoodfacts.org"]);
  _paq.push(["setDomains", ["*.openfoodfacts.org"]]);
  _paq.push(["setDoNotTrack", true]);
  _paq.push(["disableCookies"]);
  _paq.push(['trackPageView']);
  _paq.push(['enableLinkTracking']);
  (function() {
    var u="//analytics.openfoodfacts.org/";
    _paq.push(['setTrackerUrl', u+'matomo.php']);
    _paq.push(['setSiteId', '5']);
    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
    g.async=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);
  })();
</script>
<noscript><p><img src="//analytics.openfoodfacts.org/matomo.php?idsite=5&amp;rec=1" style="border:0;" alt="" /></p></noscript>
<!-- End Matomo Code -->

HTML
	;

my @icons = (
	{
		"type" => "image/png",
		"src" => "https://static.$server_domain/images/favicon/android-chrome-512x512.png",
		"sizes" => "512x512"
	},
	{
		"type" => "image/png",
		"src" => "https://static.$server_domain/images/favicon/android-chrome-192x192.png",
		"sizes" => "192x192"
	},
	{
		"type" => "image/png",
		"src" => "https://static.$server_domain/images/favicon/favicon-32x32.png",
		"sizes" => "32x32"
	},
	{
		"type" => "image/png",
		"src" => "https://static.$server_domain/images/favicon/favicon-16x16.png",
		"sizes" => "16x16"
	},
);

my @related_applications = (
	{
		'platform' => 'play',
		'id' => 'org.openfoodfacts.scanner',
		'url' => 'https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner'
	},
	{'platform' => 'ios', 'id' => 'id588797948', 'url' => 'https://apps.apple.com/app/id588797948'},
	{
		'platform' => 'windows',
		'id' => '9nblggh0dkqr',
		'url' => 'https://www.microsoft.com/p/openfoodfacts/9nblggh0dkqr'
	},
);

my $manifest = {
	icons => \@icons,
	related_applications => \@related_applications,
	theme_color => '#ffffff',
	background_color => '#ffffff',
};
$options{manifest} = $manifest;

$options{display_random_sample_of_products_after_edits} = 0;    # from MongoDB 3.2 onward

$options{favicons} = <<HTML
<link rel="apple-touch-icon" sizes="180x180" href="/images/favicon/apple-touch-icon.png">
<link rel="icon" type="image/png" sizes="32x32" href="/images/favicon/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/images/favicon/favicon-16x16.png">
<link rel="manifest" href="/images/favicon/site.webmanifest">
<link rel="mask-icon" href="/images/favicon/safari-pinned-tab.svg" color="#5bbad5">
<link rel="shortcut icon" href="/images/favicon/favicon.ico">
<meta name="msapplication-TileColor" content="#ffffff">
<meta name="msapplication-config" content="/images/favicon/browserconfig.xml">
<meta name="theme-color" content="#ffffff">

<meta name="apple-itunes-app" content="app-id=588797948">
<meta name="flattr:id" content="dw637l">
HTML
	;

$options{opensearch_image} = <<XML
<Image width="16" height="16" type="image/x-icon">https://static.$server_domain/images/favicon/favicon.ico</Image>
XML
	;

# Nutriscore: categories that are never considered beverages for Nutri-Score computation
$options{categories_not_considered_as_beverages_for_nutriscore_2021} = [
	qw(
		en:plant-milks
		en:milks
		en:meal-replacement
		en:plant-based-milk-alternatives
		en:chocolate-powders
		en:soups
	)
];

$options{categories_not_considered_as_beverages_for_nutriscore_2023} = [
	qw(
		en:meal-replacement
		en:soups
	)
];

# categories that are considered as beverages for Nutri-Score 2021
# unless they have 80% milk (which we will determine through ingredients analysis)
$options{categories_considered_as_beverages_for_nutriscore_2021} = [
	qw(
		en:tea-based-beverages
		en:iced-teas
		en:herbal-tea-beverages
		en:coffee-beverages
		en:coffee-drinks
		en:coffees
		en:herbal-teas
		en:teas
	)
];

# categories that are considered as beverages for Nutri-Score 2023
$options{categories_considered_as_beverages_for_nutriscore_2023} = [
	qw(
		en:milks
		en:plant-based-milk-alternatives
		en:dairy-drinks
		en:plant-based-beverages
		en:tea-based-beverages
		en:iced-teas
		en:herbal-tea-beverages
		en:coffee-beverages
		en:coffee-drinks
		en:coffees
		en:herbal-teas
		en:teas
	)
];

$options{categories_exempted_from_nutriscore} = [
	qw(
		en:alcoholic-beverages
		en:aromatic-herbs
		en:baby-foods
		en:baby-milks
		en:chewing-gum
		en:food-additives
		en:meal-replacements
		en:salts
		en:spices
		en:sugar-substitutes
		en:vinegars
		en:pet-food
		en:non-food-products
	)
];

#	Coffees, teas and herbal teas can have a Nutri-Score if they have
#	a nutrition facts table
#
#	en:coffees
#	en:herbal-teas
#	en:teas

# exceptions
$options{categories_not_exempted_from_nutriscore} = [
	qw(
		en:tea-based-beverages
		en:iced-teas
		en:herbal-tea-beverages
		en:coffee-beverages
		en:coffee-drinks
	)
];

$options{categories_exempted_from_nutrient_levels} = [
	qw(
		en:baby-foods
		en:baby-milks
		en:alcoholic-beverages
		en:coffees
		en:teas
		en:yeasts
		en:food-additives
	)
];

$options{replace_existing_values_when_importing_those_tags_fields} = {
	"allergens" => 1,
	"traces" => 1,
};

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
	labels food_groups categories
	ingredients_processing
	additives vitamins minerals amino_acids nucleotides other_nutritional_substances traces
	ingredients_analysis
	nutrients nutrient_levels misc nova_groups
	periods_after_opening
	data_quality data_quality_bugs data_quality_info data_quality_warnings data_quality_errors data_quality_warnings_producers data_quality_errors_producers
	improvements
);

# tag types (=facets) that should be indexed by web crawlers, all other tag types are not indexable
@index_tag_types = qw(brands categories labels additives nova_groups ecoscore nutrition_grades products);

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
	nutrition_grade_fr_producer
	nutriscore_score_producer
	nutriscore_grade_producer
	recipe_idea
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
	recipe_idea
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
	nutrition_grades
	nova_groups
	ecoscore
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
	amino_acids
	nucleotides
	other_nutritional_substances
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
	nutriscore_score
	nutriscore_grade
	nova_group
	pnns_groups_1
	pnns_groups_2
	food_groups
	states
	brand_owner
	ecoscore_score
	ecoscore_grade
	nutrient_levels_tags
	product_quantity
	owner
	data_quality_errors_tags
	unique_scans_n
	popularity_tags
	completeness
	last_image_t
);

# List of fields that can be imported on the producers platform
# and that are also exported from the producers platform to the public platform
$options{import_export_fields_groups} = [
	[
		"identification",
		[
			"code", "producer_product_id",
			"producer_version_id", "lc",
			"product_name", "abbreviated_product_name",
			"generic_name",
			"quantity_value_unit", "net_weight_value_unit",
			"drained_weight_value_unit", "volume_value_unit",
			"serving_size_value_unit", "packaging",
			"brands", "brand_owner",
			"categories", "categories_specific",
			"labels", "labels_specific",
			"countries", "stores",
			"obsolete", "obsolete_since_date",
			"periods_after_opening"    # included for OBF imports via the producers platform
		]
	],
	[
		"origins",
		["origins", "origin", "manufacturing_places", "producer", "emb_codes"]
	],
	["ingredients", ["ingredients_text", "allergens", "traces"]],
	["nutrition"],
	["nutrition_other"],
	["packaging"],
	[
		"other",
		[
			"conservation_conditions", "warning",
			"preparation", "nutriscore_score_producer",
			"nutriscore_grade_producer", "nova_group_producer",
			"recipe_idea", "customer_service",
			"link",
		]
	],
	[
		"images",
		[
			"image_front_url", "image_ingredients_url", "image_nutrition_url", "image_packaging_url",
			"image_other_url", "image_other_type",
		]
	],
];

# Secondary fields that are computed by OFF from primary data
# Those fields are only exported, they are not imported.
$options{off_export_fields_groups} = [
	[
		"off",
		[
			"food_groups",
			"nova_groups",
			"nutriscore_grade",
			"nutriscore_score",
			"ecoscore_grade",
			"ecoscore_score",
			"ecoscore_data.missing_key_data",
			"ecoscore_data.agribalyse.code",
			"ecoscore_data.adjustments.origins_of_ingredients.value",
			"ecoscore_data.adjustments.packaging.value",
			"ecoscore_data.adjustments.packaging.non_recyclable_and_non_biodegradable_materials",
			"ecoscore_data.adjustments.production_system.value",
			"ecoscore_data.adjustments.threatened_species.value",
		]
	],
];

# Used to generate the list of possible product attributes, which is
# used to display the possible choices for user preferences
$options{attribute_groups} = [
	["nutritional_quality", ["nutriscore", "low_salt", "low_sugars", "low_fat", "low_saturated_fat",],],
	["processing", ["nova", "additives"]],
	[
		"allergens",
		[
			"allergens_no_gluten", "allergens_no_milk",
			"allergens_no_eggs", "allergens_no_nuts",
			"allergens_no_peanuts", "allergens_no_sesame_seeds",
			"allergens_no_soybeans", "allergens_no_celery",
			"allergens_no_mustard", "allergens_no_lupin",
			"allergens_no_fish", "allergens_no_crustaceans",
			"allergens_no_molluscs", "allergens_no_sulphur_dioxide_and_sulphites",
		],
	],
	["ingredients_analysis", ["vegan", "vegetarian", "palm_oil_free",]],
	["labels", ["labels_organic", "labels_fair_trade"]],
	["environment", ["ecoscore", "forest_footprint",]],
];

# default preferences for attributes
$options{attribute_default_preferences} = {
	"nutriscore" => "very_important",
	"nova" => "important",
	"ecoscore" => "important",
};

# Used to generate the sample import file for the producers platform
# possible values: mandatory, recommended, optional.
# when not specified, fields are considered optional
$options{import_export_fields_importance} = {

	# default values for groups
	nutrition_group => "mandatory",
	images_group => "mandatory",
	ingredients_group => "mandatory",

	# values for fields
	code => "mandatory",
	lc => "mandatory",
	product_name => "mandatory",
	abbreviated_product_name => "optional",
	generic_name => "recommended",
	quantity => "mandatory",
	serving_size => "recommended",
	packaging => "recommended",
	packaging_text => "mandatory",
	brands => "mandatory",
	categories => "mandatory",
	labels => "mandatory",
	countries => "recommended",
	obsolete => "recommended",
	obsolete_since_date => "recommended",

	origins => "mandatory",
	emb_codes => "recommended",

	recycling_instructions_to_recycle => "recommended",
	recycling_instructions_to_discard => "recommended",

	image_other_url => "optional",

	alcohol_100g_value_unit => "optional",

};

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

$options{current_server} = "off";

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
	opf => {
		name => "Open Products Facts",
		data_root => "/srv/opf",
		www_root => "/srv/opf/html",
		mongodb => "opf",
		domain => "openproductsfacts.org",
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

# Name of the Redis stream to which product updates are published
$options{redis_stream_name} = "product_updates_off";

# used to rename texts and to redirect to the new name
$options{redirect_texts} = {
	"en/nova-groups-for-food-processing" => "nova",
	"fr/score-nutritionnel-france" => "nutriscore",
	"fr/score-nutritionnel-experimental-france" => "nutriscore",
	"fr/classification-nova-pour-la-transformation-des-aliments" => "nova",
};

$options{display_tag_additives} = [
	'@additives_classes',
	'wikipedia',
	#'title:efsa_evaluation_overexposure_risk_title',
	'efsa_evaluation',
	'efsa_evaluation_overexposure_risk',
	'efsa_evaluation_exposure_table',
	#'@efsa_evaluation_exposure_mean_greater_than_noael',
	#'@efsa_evaluation_exposure_95th_greater_than_noael',
	#'@efsa_evaluation_exposure_mean_greater_than_adi',
	#'@efsa_evaluation_exposure_95th_greater_than_adi',

];

# Used in the data_sources field (e.g. "App - Open Food Facts")
$options{apps_names} = {

	"elcoco" => "El CoCo",
	"ethic-advisor" => "Ethic-Advisor",
	"horizon" => "Horizon",
	"infood" => "InFood",
	"isve" => "IsVe",
	"labeleat" => "LabelEat",
	"off" => "Open Food Facts",
	"scanfood" => "Scanfood",
	"speisekammer" => "Speisekammer",
	"waistline" => "Waistline",
	"yuka" => "Yuka"
};

# Specific users used by apps
$options{apps_userids} = {

	"averment" => "isve",
	"elcoco" => "elcoco",
	"ethic-advisor" => "ethic-advisor",
	"inf" => "infood",
	"kiliweb" => "yuka",
	"labeleat" => "labeleat",
	"prepperapp" => "speisekammer",
	"scanfood" => "scanfood",
	"swipe-studio" => "horizon",
	"waistline-app" => "waistline",
};

$options{official_app_id} = "off";
$options{official_app_comment}
	= "(official (off|open food facts|openfoodfacts)|(off|open food facts|openfoodfacts) (official )?(android |ios )?(official )?app)";

# (app)Official Android app 3.1.5 ( Added by 58abc55ceb98da6625cee5fb5feaf81 )
# (app)Labeleat1.0-SgP5kUuoerWvNH3KLZr75n6RFGA0
# (app)Contributed using: OFF app for iOS - v3.0 - user id: 3C0154A0-D19B-49EA-946F-CC33A05E404A
# (app)EthicAdvisorApp-production-2.6.3-user_17cf91e3-52ee-4431-aebf-7d455dd610f0
# (app)El Coco - user b0e8d6a858034cc750136b8f19a8953d

# app_uuid_prefix must be present to recognize the uuid, if the comment starts with the uuid, put an empty string
$options{apps_uuid_prefix} = {

	"elcoco" => " user ",
	"ethic-advisor" => "user_",
	"labeleat" => "Labeleat([^-]*)-",
	"off" => "added by",
	"scanfood" => "",
	"waistline" => "Waistline:",
	"yuka" => "User :",
};

$options{apps_uuid_suffix} = {

	"scanfood" => "scanfood",
};

$options{nova_groups_tags} = {

	# start by assigning group 1

	# 1st try to identify group 2 processed culinary ingredients

	"categories/en:fats" => 2,
	"categories/en:salts" => 2,
	"categories/en:vinegars" => 2,
	"categories/en:sugars" => 2,
	"categories/en:honeys" => 2,
	"categories/en:maple-syrups" => 2,
	"categories/en:starches" => 2,

	# group 3 tags will not be applied to food identified as group 2

	# group 3 ingredients from nova paper

	"ingredients/en:preservative" => 3,
	"ingredients/en:anti-caking-agent" => 3,

	"ingredients/en:salt" => 3,
	"ingredients/en:sugar" => 3,
	"ingredients/en:vegetable-oil" => 3,
	"ingredients/en:vegetal-oil" => 3,
	"ingredients/en:vegetable-fat" => 3,
	"ingredients/en:butter" => 3,
	"ingredients/en:honey" => 3,
	"ingredients/en:maple-syrup" => 3,

	# other ingredients that we can consider to be at least group 3

	"ingredients/en:starch" => 3,
	"ingredients/en:whey" => 4,

	# group 3 categories from nova paper

	"categories/en:wines" => 3,
	"categories/en:beers" => 3,
	"categories/en:ciders" => 3,
	"categories/en:cheeses" => 3,

	# other categories that we can consider to be at least group 3

	"categories/en:prepared-meats" => 3,
	"categories/en:terrines" => 3,
	"categories/en:pates" => 3,
	#"categories/en:breakfast-cereals" => 3,
	"categories/en:tofu" => 3,
	"categories/en:alcoholic-beverages" => 3,
	"categories/en:meals" => 3,
	# yogurts can be group 1 according to NOVA paper
	#"categories/en:yogurts" => 3,

	# group 3 additives

	"additives/en:e202" => 3,    # potassium nitrite
	"additives/en:e249" => 3,    # potassium nitrite
	"additives/en:e250" => 3,    # sodium nitrite
	"additives/en:e251" => 3,    # potassium nitrate
	"additives/en:e252" => 3,    # sodium nitrite

	# tags only found in group 4

	"ingredients/en:anti-foaming-agent" => 4,
	"ingredients/en:bulking-agent" => 4,
	"ingredients/en:carbonating-agent" => 4,
	"ingredients/en:colour" => 4,
	"ingredients/en:colour-stabilizer" => 4,
	"ingredients/en:emulsifier" => 4,
	"ingredients/en:firming-agent" => 4,
	"ingredients/en:flavour-enhancer" => 4,
	"ingredients/en:gelling-agent" => 4,
	"ingredients/en:glazing-agent" => 4,
	"ingredients/en:sequestrant" => 4,
	"ingredients/en:sweetener" => 4,
	"ingredients/en:thickener" => 4,
	"ingredients/en:humectant" => 4,

	# group 4 ingredients from nova paper

	"ingredients/en:flavour" => 4,
	# is a synonym of en:flavour in the taxo aleene@2018-10-09
	"ingredients/en:flavouring" => 4,
	"ingredients/en:casein" => 4,
	"ingredients/en:gluten" => 4,
	# this is a milk protein, so covered by the taxo aleene@2018-10-09
	"ingredients/en:lactose" => 4,
	"ingredients/en:whey" => 4,
	# is already entered above aleene@2018-10-09
	"ingredients/en:hydrogenated-oil" => 4,
	"ingredients/en:hydrogenated-fat" => 4,
	"ingredients/en:hydrolysed-proteins" => 4,
	"ingredients/en:maltodextrin" => 4,
	"ingredients/en:invert-sugar" => 4,
	"ingredients/en:high-fructose-corn-syrup" => 4,
	"ingredients/en:glucose" => 4,
	"ingredients/en:glucose-syrup" => 4,
	# has glucose as parent, so can be removed aleene@2018-10-09

	# other ingredients that we can consider as ultra-processed

	"ingredients/en:dextrose" => 4,
	# This can be deleted, it is a synonym of en:glucose in the ingredients taxo aleene@2018-10-09
	"ingredients/en:milk-proteins" => 4,
	# could be changed to singular aleene@2018-10-09
	"ingredients/en:whey-proteins" => 4,
	# could be changed to singular aleene@2018-10-09
	# as whey is from milk, it is also part of milk-proteins aleene@2018-10-09
	"ingredients/en:lecithin" => 4,

	# group 4 categories from nova paper
	# categories are just examples, consider it is group 3 unless a specific ingredient makes them group 4

	"categories/en:sodas" => 3,
	"categories/en:ice-creams" => 3,
	"categories/en:chocolates" => 3,
	"categories/en:candies" => 3,
	"categories/en:sugary-snacks" => 3,
	"categories/en:salty-snacks" => 3,
	"categories/en:baby-milks" => 3,
	"categories/en:sausages" => 3,
	"categories/en:hard-liquors" => 3,

	# additives that we can consider as ultra-processed (or a sufficient marker of ultra-processed food)

	# colors (should already be detected by the "color" class if it is specified in the ingredient list (e.g. "color: some additive")

	"additives/en:e100" => 4,    #Curcumin" => 4, #Turmeric extract" => 4, #curcuma extract
	"additives/en:e106" => 4,    #flavin mononucleotide" => 4, #phosphate lactoflavina
	"additives/en:e101" => 4
	, #Riboflavin" => 4, #Vitamin B2" => 4, #Flavaxin" => 4, #Vitamin B 2" => 4, #Vitamin G" => 4, #Riboflavine" => 4, #Lactoflavine" => 4, #6\,7-Dimethyl-9-D-ribitylisoalloxazine" => 4, #7\,8-Dimethyl-10-ribitylisoalloxazine" => 4, #Lactoflavin" => 4, #7\,8-Dimethyl-10-(D-ribo-2\,3\,4\,5-tetrahydroxypentyl)isoalloxazine" => 4, #7\,8-Dimethyl-10-(D-ribo-2\,3\,4\,5-tetrahydroxypentyl)benzo[g]pteridine-2\,4(3H\,10H)-dione" => 4, #1-Deoxy-1-(7\,8-dimethyl-2\,4-dioxo-3\,4-dihydrobenzo[g]pteridin-10(2H)-yl)pentitol
	"additives/en:e101a" => 4,    #Riboflavin-5'-Phosphate
	"additives/en:e102" => 4
	, #Tartrazine" => 4, #Yellow 5" => 4, #Yellow number 5" => 4, #Yellow no 5" => 4, #Yellow no5" => 4, #FD&C Yellow 5" => 4, #FD&C Yellow no 5" => 4, #FD&C Yellow no5" => 4, #FD and C Yellow no. 5" => 4, #FD and C Yellow 5
	"additives/en:e103" => 4,    #Alkannin
	"additives/en:e104" => 4,    #Quinoline yellow" => 4, #Quinoline Yellow WS" => 4, #C.I. 47005" => 4, #Food Yellow 13
	"additives/en:e105" => 4,    #E105 food additive
	"additives/en:e107" => 4,    #Yellow 2G
	"additives/en:e110" => 4
	, #Sunset yellow FCF" => 4, #CI Food Yellow 3" => 4, #Orange Yellow S" => 4, #FD&C Yellow 6" => 4, #FD & C Yellow No.6" => 4, #FD and C Yellow No. 6" => 4, #Yellow No.6" => 4, #Yellow 6" => 4, #FD and C Yellow 6" => 4, #C.I. 15985
	"additives/en:e111" => 4,    #Orange GGN" => 4, #Alpha-naphthol" => 4, #Alpha-naphtol" => 4, #alpha-naphthol orange
	"additives/en:e120" =>
		4,    #Cochineal" => 4, #carminic acid" => 4, #carmines" => 4, #Natural Red 4" => 4, #Cochineal Red
	"additives/en:e121" => 4,    #Citrus Red 2
	"additives/en:e122" => 4
	, #Azorubine" => 4, #carmoisine" => 4, #Food Red 3" => 4, #Brillantcarmoisin O" => 4, #Acid Red 14" => 4, #Azorubin S" => 4, #C.I. 14720
	"additives/en:e123" => 4,    #Amaranth" => 4, #FD&C Red 2
	"additives/en:e124" => 4,    #Ponceau 4r" => 4, #cochineal red a" => 4, #CI Food Red 7" => 4, #Brilliant Scarlet 4R
	"additives/en:e125" =>
		4,    #Scarlet GN" => 4, #C.I. Food Red 1" => 4, #Ponceau SX" => 4, #FD&C Red No. 4" => 4, #C.I. 14700
	"additives/en:e126" => 4,    #Ponceau 6R
	"additives/en:e127" => 4
	, #Erythrosine" => 4, #FD&C Red 3" => 4, #FD & C Red No.3" => 4, #Red No. 3" => 4, #FD&C Red no3" => 4, #FD and C Red 3
	"additives/en:e128" => 4,    #Red 2G
	"additives/en:e129" => 4
	, #Allura red ac" => 4, #Allura Red AC" => 4, #FD&C Red 40" => 4, #FD and C Red 40" => 4, #Red 40" => 4, #Red no40" => 4, #Red no. 40" => 4, #FD and C Red no. 40" => 4, #Food Red 17" => 4, #C.I. 16035
	"additives/en:e130" => 4,    #Indanthrene blue RS" => 4, #Indanthrone blue" => 4, #indanthrene
	"additives/en:e131" => 4
	, #Patent blue v" => 4, #Food Blue 5" => 4, #Sulphan Blue" => 4, #Acid Blue 3" => 4, #L-Blau 3" => 4, #C-Blau 20" => 4, #Patentblau V" => 4, #Sky Blue" => 4, #C.I. 42051
	"additives/en:e132" => 4,    #Indigotine" => 4, #indigo carmine" => 4, #FD&C Blue 2" => 4, #FD and C Blue 2
	"additives/en:e133" =>
		4,    #Brilliant blue FCF" => 4, #FD&C Blue 1" => 4, #FD and C Blue 1" => 4, #Blue 1" => 4, #fd&c blue no. 1.
	"additives/en:e140" => 4,    #Chlorophylls and Chlorophyllins" => 4, #Chlorophyll c1
	"additives/en:e141" => 4
	,    #Copper complexes of chlorophylls and chlorophyllins" => 4, #Copper complexes of chlorophyll and chlorophyllins
	"additives/en:e142" => 4,    #Green s" => 4, #CI Food Green 4
	"additives/en:e143" => 4
	, #Fast Green FCF" => 4, #Food green 3" => 4, #C.I. 42053" => 4, #Solid Green FCF" => 4, #Green 1724" => 4, #FD&C Green No. 3
	"additives/en:e150" => 4,    #Caramel
	"additives/en:e150a" => 4,    #Plain caramel" => 4, #caramel color" => 4, #caramel coloring
	"additives/en:e150b" => 4,    #Caustic sulphite caramel
	"additives/en:e150c" => 4,    #Ammonia caramel
	"additives/en:e150d" => 4,    #Sulphite ammonia caramel" => 4, #Sulfite ammonia caramel
	"additives/en:e151" => 4
	, #Brilliant black bn" => 4, #black pn" => 4, #E 151" => 4, #C.I. 28440" => 4, #Brilliant Black PN" => 4, #Food Black 1" => 4, #Naphthol Black" => 4, #C.I. Food Brown 1" => 4, #Brilliant Black A
	"additives/en:e152" => 4,    #Black 7984" => 4, #Food Black 2" => 4, #carbon black
	"additives/en:e153" => 4,    #Vegetable carbon
	"additives/en:e154" => 4,    #Brown FK" => 4, #Kipper Brown
	"additives/en:e155" => 4,    #Brown ht" => 4, #Chocolate brown HT
	"additives/en:e15x" => 4,    #E15x food additive
	"additives/en:e160" => 4,    #carotene
	"additives/en:e160a" => 4,    #Alpha-carotene" => 4, #Beta-carotene" => 4, #Gamma-carotene" => 4, #carotene
	"additives/en:e160b" => 4,    #Annatto" => 4, #bixin" => 4, #norbixin" => 4, #roucou" => 4, #achiote
	"additives/en:e160c" => 4,    #Paprika extract" => 4, #capsanthin" => 4, #capsorubin" => 4, #Paprika oleoresin
	"additives/en:e160d" => 4,    #Lycopene
	"additives/en:e160e" => 4
	, #Beta-apo-8′-carotenal (c30)" => 4, #Apocarotenal" => 4, #Beta-apo-8'-carotenal" => 4, #C.I. Food orange 6" => 4, #E number 160E" => 4, #Trans-beta-apo-8'-carotenal" => 4, #C30H40O
	"additives/en:e160f" => 4
	, #Ethyl ester of beta-apo-8'-carotenic acid (C 30)" => 4, #Ethyl ester of beta-apo-8'-carotenic acid " => 4, #Food orange 7
	"additives/en:e161" => 4,    #Xanthophylls
	"additives/en:e161a" => 4,    #Flavoxanthin
	"additives/en:e161b" => 4,    #Lutein" => 4, #Mixed Carotenoids" => 4, #Xanthophyll" => 4, #SID548587
	"additives/en:e161c" => 4,    #Cryptoaxanthin" => 4, #Cryptoxanthin
	"additives/en:e161d" => 4,    #Rubixanthin
	"additives/en:e161e" => 4,    #Violaxanthin
	"additives/en:e161f" => 4,    #Rhodoxanthin
	"additives/en:e161g" => 4,    #Canthaxanthin
	"additives/en:e161h" => 4,    #Zeaxanthin
	"additives/en:e161i" => 4,    #Citranaxanthin
	"additives/en:e161j" => 4,    #Astaxanthin
	"additives/en:e162" => 4,    #Beetroot red" => 4, #betanin
	"additives/en:e163" => 4,    #Anthocyanins" => 4, #Anthocyanin
	"additives/en:e163a" => 4,    #Cyanidin
	"additives/en:e163b" => 4,    #Delphinidin
	"additives/en:e163c" => 4,    #Malvidin
	"additives/en:e163d" => 4,    #Pelargonidin
	"additives/en:e163e" => 4,    #Peonidin
	"additives/en:e163f" => 4,    #Petunidin
	"additives/en:e164" => 4,    #E164 food additive
	"additives/en:e165" => 4,    #E165 food additive
	"additives/en:e166" => 4,    #E166 food additive
	"additives/en:e170" => 4,    #Calcium carbonate" => 4, #CI Pigment White 18" => 4, #Chalk
	"additives/en:e171" => 4,    #Titanium dioxide
	"additives/en:e172" => 4,    #Iron oxides and iron hydroxides
	"additives/en:e173" => 4,    #Aluminium" => 4, #Aluminum" => 4, #element 13
	"additives/en:e174" => 4,    #Silver" => 4, #element 47
	"additives/en:e175" => 4,    #Gold" => 4, #Pigment Metal 3" => 4, #element 79
	"additives/en:e180" => 4
	,    #Litholrubine bk" => 4, #CI Pigment Red 57" => 4, #Rubinpigment" => 4, #Pigment Rubine" => 4, #Lithol rubine bk
	"additives/en:e181" => 4,    #Tannin
	"additives/en:e182" => 4,    #Orcein

	# emulsifiers
	"additives/en:e322" => 4,    # Lecithins
	"additives/en:e325" => 4,
	"additives/en:e326" => 4,
	"additives/en:e327" => 4,
	"additives/en:e328" => 4,
	"additives/en:e329" => 4,

	# flavour enhancers

	"additives/en:e620" => 4,    #Glutamic acid, L(+)-
	"additives/en:e621" => 4,    #Monosodium L-glutamate
	"additives/en:e622" => 4,    #Monopotassium L-glutamate
	"additives/en:e623" => 4,    #Calcium di-L-glutamate
	"additives/en:e624" => 4,    #Monoammonium L-glutamate
	"additives/en:e625" => 4,    #Magnesium di-L-glutamate
	"additives/en:e626" => 4,    #Guanylic acid, 5'-
	"additives/en:e627" => 4,    #Disodium 5'-guanylate
	"additives/en:e628" => 4,    #Dipotassium 5'-guanylate
	"additives/en:e629" => 4,    #Calcium 5'-guanylate
	"additives/en:e630" => 4,    #Inosinic acid, 5'-
	"additives/en:e631" => 4,    #Disodium 5'-inosinate
	"additives/en:e632" => 4,    #Potassium 5’-inosinate
	"additives/en:e633" => 4,    #Calcium 5'-inosinate
	"additives/en:e634" => 4,    #Calcium 5'-ribonucleotides
	"additives/en:e635" => 4,    #Disodium 5'-ribonucleotides
	"additives/en:e636" => 4,    #Maltol
	"additives/en:e637" => 4,    #Ethyl maltol
	"additives/en:e640" => 4,    # glycine
	"additives/en:e641" => 4,    # leucine
	"additives/en:e650" => 4,    # zinc acetatel
	"additives/en:e1104" => 4,    # lipase

	# sweeteners

	"additives/en:e950" => 4,    #Acesulfame potassium
	"additives/en:e951" => 4,    #Aspartame
	"additives/en:e952" => 4,    #Calcium cyclamate
	"additives/en:e953" => 4,    #Isomalt (Hydrogenated isomaltulose)
	"additives/en:e954" => 4,    #Calcium saccharin
	"additives/en:e955" => 4,    #Sucralose (Trichlorogalactosucrose)
	"additives/en:e956" => 4,    #Alitame
	"additives/en:e957" => 4,    #Thaumatin
	"additives/en:e959" => 4,    #neohesperidin dihydrochalcone
	"additives/en:e960" => 4,    #Steviol glycosides
	"additives/en:e961" => 4,    #Neotame
	"additives/en:e962" => 4,    #Aspartame-acesulfame salt
	"additives/en:e964" => 4,    #Polyglycitol syrup
	"additives/en:e965" => 4,    #Maltitol
	"additives/en:e966" => 4,    #Lactitol
	"additives/en:e967" => 4,    #Xylitol
	"additives/en:e968" => 4,    #Erythritol
	"additives/en:e969" => 4,    #Advantame

	# anti-foaming agents

	"additives/en:e551" => 4,
	"additives/en:e900a" => 4,
	"additives/en:e905c" => 4,
	"additives/en:e905d" => 4,
	"additives/en:e1521" => 4,

	# glazing agents

	"additives/en:e900" => 4,
	"additives/en:e901" => 4,
	"additives/en:e902" => 4,
	"additives/en:e903" => 4,
	"additives/en:e904" => 4,
	"additives/en:e905" => 4,
	"additives/en:e907" => 4,

	# propellants

	"additives/en:e938" => 4,
	"additives/en:e939" => 4,
	"additives/en:e941" => 4,
	"additives/en:e942" => 4,
	"additives/en:e943a" => 4,
	"additives/en:e943b" => 4,

	# bulking agents / thickeners / stabilizers / emulsifiers / gelling agents

	"additives/en:e400" => 4,
	"additives/en:e401" => 4,
	"additives/en:e402" => 4,
	"additives/en:e403" => 4,
	"additives/en:e404" => 4,
	"additives/en:e405" => 4,
	"additives/en:e406" => 4,
	"additives/en:e407" => 4,
	"additives/en:e407a" => 4,
	"additives/en:e409" => 4,
	"additives/en:e410" => 4,
	"additives/en:e412" => 4,
	"additives/en:e413" => 4,
	"additives/en:e414" => 4,
	"additives/en:e415" => 4,
	"additives/en:e416" => 4,
	"additives/en:e417" => 4,
	"additives/en:e418" => 4,
	"additives/en:e415" => 4,
	"additives/en:e416" => 4,
	"additives/en:e417" => 4,
	"additives/en:e418" => 4,
	"additives/en:e420" => 4,    #Sorbitol
	"additives/en:e421" => 4,    #Mannitol
	"additives/en:e422" => 4,
	"additives/en:e425" => 4,
	"additives/en:e428" => 4,
	"additives/en:e430" => 4,
	"additives/en:e431" => 4,
	"additives/en:e432" => 4,
	"additives/en:e433" => 4,
	"additives/en:e434" => 4,
	"additives/en:e435" => 4,
	"additives/en:e436" => 4,
	"additives/en:e440" => 4,
	"additives/en:e441" => 4,
	"additives/en:e442" => 4,
	"additives/en:e443" => 4,
	"additives/en:e444" => 4,
	"additives/en:e445" => 4,
	"additives/en:e450" => 4,
	"additives/en:e451" => 4,
	"additives/en:e452" => 4,
	"additives/en:e459" => 4,
	"additives/en:e460" => 4,
	"additives/en:e461" => 4,
	"additives/en:e463" => 4,
	"additives/en:e464" => 4,
	"additives/en:e465" => 4,
	"additives/en:e466" => 4,
	"additives/en:e468" => 4,
	"additives/en:e469" => 4,
	"additives/en:e470" => 4,
	"additives/en:e470a" => 4,
	"additives/en:e470b" => 4,
	"additives/en:e471" => 4,
	"additives/en:e472a" => 4,
	"additives/en:e472b" => 4,
	"additives/en:e472c" => 4,
	"additives/en:e472d" => 4,
	"additives/en:e472e" => 4,
	"additives/en:e472f" => 4,
	"additives/en:e473" => 4,
	"additives/en:e474" => 4,
	"additives/en:e475" => 4,
	"additives/en:e476" => 4,
	"additives/en:e477" => 4,
	"additives/en:e478" => 4,
	"additives/en:e479b" => 4,
	"additives/en:e480" => 4,
	"additives/en:e481" => 4,
	"additives/en:e482" => 4,
	"additives/en:e483" => 4,
	"additives/en:e491" => 4,
	"additives/en:e492" => 4,
	"additives/en:e493" => 4,
	"additives/en:e494" => 4,
	"additives/en:e495" => 4,

	"additives/en:e1400" => 4,
	"additives/en:e1401" => 4,
	"additives/en:e1402" => 4,
	"additives/en:e1403" => 4,
	"additives/en:e1404" => 4,
	"additives/en:e1405" => 4,
	"additives/en:e1410" => 4,
	"additives/en:e1412" => 4,
	"additives/en:e1413" => 4,
	"additives/en:e1414" => 4,
	"additives/en:e1420" => 4,
	"additives/en:e1422" => 4,
	"additives/en:e1440" => 4,
	"additives/en:e1442" => 4,
	"additives/en:e1450" => 4,
	"additives/en:e1451" => 4,
	"additives/en:e1505" => 4,

	"additives/en:e14xx" => 4,

	# carbonating agents

	"additives/en:e290" => 4,    # carbon dioxyde

};

# List of sources from which product data can be imported
# The product data is first imported on the producers platform
# If the organization for a product already exists, product data from the source
# will be imported only if the source is authorized (checkbox in org profile).
# Otherwise the org will be created and the source authorized for that org.

$options{import_sources} = {
	'agena3000' => "Agena3000",
	'codeonline' => "CodeOnline Food",
	'equadis' => "Equadis",
	'database-usda' => "USDA Global Branded Food Products Database",
};

# Configuration to receive GS1 notification messages and issue GS1 confirmation messages

$options{gs1} = {
	local_gln => "3770026870013",    # Open Food Facts GS1 GLN identifier
	agena3000 => {
		receiver_gln => "3034012285008",    # Agena 3000
		data_pool_gln => "3027000006006",    # GS1
	},
};

# Barcode of a sample product returned through the API when the requested code is "example"
$options{sample_product_code} = "093270067481501";    # A good product for you - fake good product

# We can also send back a different product based on country or language, with the following syntax:

#$options{sample_product_code_country_uk} = "5060042641000"; # Tyrrell's lighty salted chips
#$options{sample_product_code_language_de} = "20884680"; # Waffeln Sondey
#$options{sample_product_code_country_at_language_de} = "5411188119098"; # Natur miss kokosnuss Alpro

1;
