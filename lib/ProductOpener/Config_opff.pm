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

package ProductOpener::Config;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		%admins
		%moderators

		$server_domain
		@ssl_subdomains
		$data_root
		$www_root
		$geolite2_path
		$reference_timezone
		$contact_email
		$admin_email

		$facebook_app_id
		$facebook_app_secret

		$google_cloud_vision_api_key

		$crowdin_project_identifier
		$crowdin_project_key

		$robotoff_url

		$mongodb
		$mongodb_host

		$memd_servers

		$google_analytics

		$thumb_size
		$crop_size
		$small_size
		$display_size
		$zoom_size

		$page_size

		%options

		%wiki_texts

		@product_fields
		@product_other_fields
		@display_fields
		@display_other_fields
		@drilldown_fields
		@taxonomy_fields
		@export_fields

		%tesseract_ocr_available_languages

		%weblink_templates

		@edit_rules
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these

use ProductOpener::Config2;

%admins = map { $_ => 1 } qw(
agamitsudo
aleene
bcatelin
bojackhorseman
hangy
javichu
kyzh
lafel
lucaa
moon-rabbit
sebleouf
segundo
stephane
tacinte
tacite
teolemon
twoflower

);

%moderators = map { $_ => 1 } qw(

);

@edit_rules = ();

# server constants
$server_domain = $ProductOpener::Config2::server_domain;
@ssl_subdomains = @ProductOpener::Config2::ssl_subdomains;
$mongodb = $ProductOpener::Config2::mongodb;
$mongodb_host = $ProductOpener::Config2::mongodb_host;
$memd_servers = $ProductOpener::Config2::memd_servers;

# server paths
$www_root = $ProductOpener::Config2::www_root;
$data_root = $ProductOpener::Config2::data_root;

$geolite2_path = $ProductOpener::Config2::geolite2_path;

$facebook_app_id = $ProductOpener::Config2::facebook_app_id;
$facebook_app_secret = $ProductOpener::Config2::facebook_app_secret;

$google_cloud_vision_api_key = $ProductOpener::Config2::google_cloud_vision_api_key;

$crowdin_project_identifier = $ProductOpener::Config2::crowdin_project_identifier;
$crowdin_project_key = $ProductOpener::Config2::crowdin_project_key;

$robotoff_url = $ProductOpener::Config2::robotoff_url;

$reference_timezone = 'Europe/Paris';

$contact_email = 'contact@openfoodfacts.org';
$admin_email = 'stephane@openfoodfacts.org';


$thumb_size = 100;
$crop_size = 400;
$small_size = 200;
$display_size = 400;
$zoom_size = 800;

$page_size = 20;


$google_analytics = <<HTML
<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-31851927-1']);
  _gaq.push(['_setDomainName', 'openfoodfacts.org']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
HTML
;

$options{favicons} = <<HTML
<link rel="apple-touch-icon" sizes="57x57" href="/images/favicon/apple-touch-icon-57x57.png">
<link rel="apple-touch-icon" sizes="60x60" href="/images/favicon/apple-touch-icon-60x60.png">
<link rel="apple-touch-icon" sizes="72x72" href="/images/favicon/apple-touch-icon-72x72.png">
<link rel="apple-touch-icon" sizes="76x76" href="/images/favicon/apple-touch-icon-76x76.png">
<link rel="apple-touch-icon" sizes="114x114" href="/images/favicon/apple-touch-icon-114x114.png">
<link rel="apple-touch-icon" sizes="120x120" href="/images/favicon/apple-touch-icon-120x120.png">
<link rel="apple-touch-icon" sizes="144x144" href="/images/favicon/apple-touch-icon-144x144.png">
<link rel="apple-touch-icon" sizes="152x152" href="/images/favicon/apple-touch-icon-152x152.png">
<link rel="apple-touch-icon" sizes="180x180" href="/images/favicon/apple-touch-icon-180x180.png">
<link rel="icon" type="image/png" href="/images/favicon/favicon-32x32.png" sizes="32x32">
<link rel="icon" type="image/png" href="/images/favicon/android-chrome-192x192.png" sizes="192x192">
<link rel="icon" type="image/png" href="/images/favicon/favicon-96x96.png" sizes="96x96">
<link rel="icon" type="image/png" href="/images/favicon/favicon-16x16.png" sizes="16x16">
<link rel="manifest" href="/images/favicon/manifest.json">
<link rel="mask-icon" href="/images/favicon/safari-pinned-tab.svg" color="#5bbad5">
<link rel="shortcut icon" href="/images/favicon/favicon.ico">
<meta name="msapplication-TileColor" content="#da532c">
<meta name="msapplication-TileImage" content="/images/favicon/mstile-144x144.png">
<meta name="msapplication-config" content="/images/favicon/browserconfig.xml">
<meta name="theme-color" content="#ffffff">
HTML
;

$options{opensearch_image} = <<XML
<Image width="16" height="16" type="image/x-icon">https://static.$server_domain/images/favicon/favicon.ico</Image>
XML
;

%wiki_texts = (

"en/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_English?action=raw",
"es/descubrir" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Spanish?action=raw",
"fr/decouvrir" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_French?action=raw",
"he/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Hebrew?action=raw",
"ar/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Arabic?action=raw",
"pt/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Portuguese?action=raw",
"jp/discover" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Japanese?action=raw",

"de/contribute" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_German?action=raw",
"en/contribute" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_English?action=raw",
"es/contribuir" => "https://en.wiki.openfoodfacts.org/Translations_-_Discover_page_-_Spanish?action=raw",
"fr/contribuer" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_French?action=raw",
"nl/contribute" => "https://en.wiki.openfoodfacts.org/Translations_-_Contribute_page_-_Dutch?action=raw",

"en/press" => "https://en.wiki.openfoodfacts.org/Translations_-_Press_-_English?action=raw",
"fr/presse" => "https://en.wiki.openfoodfacts.org/Translations_-_Press_-_French?action=raw",
"el/press" => "https://en.wiki.openfoodfacts.org/Translations_-_Press_-_Greek?action=raw",

"en/code-of-conduct" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_English?action=raw",
"fr/code-de-conduite" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_French?action=raw",
"ja/code-of-conduct" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_Japanese?action=raw",
"de/code-of-conduct" => "https://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_German?action=raw",

"fr/notetondistrib" => "https://en.wiki.openfoodfacts.org/Translations_-_Vending_machines_-_French?action=raw",
"en/rateyourvendingmachine" => "https://en.wiki.openfoodfacts.org/Translations_-_Vending_machines_-_English?action=raw",

);


# fields for which we will load taxonomies

@taxonomy_fields = qw(states countries languages labels categories additives additives_classes vitamins minerals amino_acids nucleotides other_nutritional_substances allergens traces nutrient_levels misc ingredients nova_groups);


# fields in product edit form, above ingredients and nutrition facts

@product_fields = qw(quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

# fields currently not shown in the default edit form, can be used in imports or advanced edit forms

@product_other_fields = qw(
producer_version_id
net_weight_value net_weight_unit drained_weight_value drained_weight_unit volume_value volume_unit
other_information conservation_conditions recycling_instructions_to_recycle recycling_instructions_to_discard
nutrition_grade_fr_producer
);


# fields shown on product page
# do not show purchase_places

@display_fields = qw(generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link stores countries);

# fields displayed in a new section after the nutrition facts

@display_other_fields = qw(other_information conservation_conditions recycling_instructions_to_recycle recycling_instructions_to_discard);


# fields for drilldown facet navigation

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
amino_acids
nucleotides
other_nutritional_substances
allergens
traces
nova_groups
nutrition_grades
misc
languages
users
states
entry_dates
last_edit_dates
last_check_dates
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
no_nutriments
additives_n
additives
ingredients_from_palm_oil_n
ingredients_from_palm_oil
ingredients_that_may_be_from_palm_oil_n
ingredients_that_may_be_from_palm_oil
nutrition_grade_fr
nova_group
pnns_groups_1
pnns_groups_2
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

	'wikidata:en' => { href => 'https://www.wikidata.org/wiki/%s', text => 'Wikidata', parse => sub
	{
		my ($url) = @_;
		if ($url =~ /^https?:\/\/www.wikidata.org\/wiki\/(Q\d+)$/) {
			return $1
		}

		return;
	} },

);

# allow moving products to other instances of Product Opener on the same server
# e.g. OFF -> OBF
$options{other_servers} = {
obf =>
{
        name => "Open Beauty Facts",
        data_root => "/srv/obf",
        www_root => "/srv/obf/html",
        mongodb => "obf",
        domain => "openbeautyfacts.org",
},
off =>
{
        name => "Open Food Facts",
        data_root => "/srv/off",
        www_root => "/srv/off/html",
        mongodb => "off",
        domain => "openfoodfacts.org",
},
opf =>
{
        prefix => "opf",
        name => "Open Products Facts",
        data_root => "/srv/opf",
        www_root => "/srv/opf/html",
        mongodb => "opf",
        domain => "openproductsfacts.org",
}
};


1;
