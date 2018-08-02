# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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
		
		$server_domain
		@ssl_subdomains
		$data_root
		$www_root
		$reference_timezone
		$contact_email
		$admin_email
		
		$facebook_app_id
		$facebook_app_secret
		
		$csrf_secret
		
		$google_cloud_vision_api_key
		
		$crowdin_project_identifier
		$crowdin_project_key
		
		$mongodb
		$mongodb_host
	
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
		@display_fields
		@drilldown_fields
		@taxonomy_fields
		
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
bcatelin
beniben
bojackhorseman
hangy
javichu
kyzh
lucaa
scanparty-franprix-05-2016
sebleouf
segundo
stephane
tacinte
tacite
teolemon
twoflower
scanparty-franprix-05-2016
);

$options{users_who_can_upload_small_images} = {
map { $_ => 1 } qw(
systeme-u
)
};

@edit_rules = (

{
	name => "Edit Rules Testing",
	conditions => [
		["user_id", "editrulestest"],
	],
	actions => [
		["ignore_if_existing_ingredients_text_fr"],
		["warn_if_0_nutriment_fruits-vegetables-nuts"],
		["warn_if_greater_nutriment_fruits-vegetables-nuts", 0],
		["ignore_if_regexp_match_packaging", '\b(artikel|produit|producto|produkt|produkte)\b'],
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},

{
	name => "Yuka",
	conditions => [
		["user_id", "kiliweb"],
	],
	actions => [
		["warn_if_existing_brands"],
		["ignore_if_existing_ingredients_text"],
		["ignore_if_existing_ingredients_text_fr"],
		["ignore_if_0_nutriment_fruits-vegetables-nuts"],
		["ignore_if_greater_nutriment_fruits-vegetables-nuts", 0],
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},
{
        name => "Yuka - systeme-u",
        conditions => [
                ["user_id", "kiliweb"],
                ["in_editors_tags", "systeme-u"],
        ],
        actions => [
                ["ignore"],
        ],
        notifications => [ qw (
                slack_channel_edit-alert
        )],
},
{
        name => "stephane - systeme-u",
        conditions => [
                ["user_id", "stephane2"],
                ["in_editors_tags", "systeme-u"],
        ],
        actions => [
                ["ignore"],
        ],
        notifications => [ qw (
                slack_channel_edit-alert
        )],
},



{
	name => "Date Limite",
	conditions => [
		["user_id", "date-limite-app"],
	],
	actions => [
		["ignore_if_regexp_match_packaging", '\b(artikel|produit|producto|produkt|produkte)\b'],
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},

{
	name => "Fleury Michon",
	conditions => [
		["user_id_not", "fleury-michon"],
		["in_brands_tags", "fleury-michon"],
	],
	actions => [
		["warn"]
	],
	notifications => [ qw (
		slack_channel_edit-alert
	)],
},

);


# server constants
$server_domain = $ProductOpener::Config2::server_domain;
@ssl_subdomains = @ProductOpener::Config2::ssl_subdomains;
$mongodb = $ProductOpener::Config2::mongodb;
$mongodb_host = $ProductOpener::Config2::mongodb_host;

# server paths
$www_root = $ProductOpener::Config2::www_root;
$data_root = $ProductOpener::Config2::data_root;

$facebook_app_id = $ProductOpener::Config2::facebook_app_id;
$facebook_app_secret = $ProductOpener::Config2::facebook_app_secret;

$csrf_secret = $ProductOpener::Config2::csrf_secret;
$google_cloud_vision_api_key = $ProductOpener::Config2::google_cloud_vision_api_key;

$crowdin_project_identifier = $ProductOpener::Config2::crowdin_project_identifier;
$crowdin_project_key = $ProductOpener::Config2::crowdin_project_key;

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

my @icons = (
	{ "platform" => "ios", "sizes" => "57x57", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-57x57.png" },
	{ "platform" => "ios", "sizes" => "60x60", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-60x60.png" },
	{ "platform" => "ios", "sizes" => "72x72", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-72x72.png" },
	{ "platform" => "ios", "sizes" => "76x76", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-76x76.png" },
	{ "platform" => "ios", "sizes" => "114x114", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-114x114.png" },
	{ "platform" => "ios", "sizes" => "120x120", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-120x120.png" },
	{ "platform" => "ios", "sizes" => "144x144", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-144x144.png" },
	{ "platform" => "ios", "sizes" => "152x152", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-152x152.png" },
	{ "platform" => "ios", "sizes" => "180x180", "src" => "https://static.$server_domain/images/favicon/apple-touch-icon-180x180.png" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/favicon-32x32.png", "sizes" => "32x32" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/android-chrome-192x192.png", "sizes" => "192x192" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/favicon-96x96.png", "sizes" => "96x96" },
	{ "type" => "image/png", "src" => "https://static.$server_domain/images/favicon/favicon-16x16.png", "sizes" => "16x16" },
);

my @related_applications = (
	{ 'platform' => 'play', 'id' => 'org.openfoodfacts.scanner', 'url' => 'https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner' },
	{ 'platform' => 'ios', 'id' => 'id588797948', 'url' => 'https://itunes.apple.com/app/id588797948' },
);

my $manifest;
$manifest->{icons} = \@icons;
$manifest->{related_applications} = \@related_applications;
$manifest->{theme_color} = '#ffffff';
$manifest->{background_color} = '#ffffff';
$options{manifest} = $manifest;

$options{mongodb_supports_sample} = 0;  # from MongoDB 3.2 onward
$options{display_random_sample_of_products_after_edits} = 0;  # from MongoDB 3.2 onward

$options{favicons} = <<HTML
<link rel="manifest" href="/cgi/manifest.pl">
<link rel="mask-icon" href="/images/favicon/safari-pinned-tab.svg" color="#5bbad5">
<link rel="shortcut icon" href="/images/favicon/favicon.ico">
<meta name="msapplication-TileColor" content="#da532c">
<meta name="msapplication-TileImage" content="/images/favicon/mstile-144x144.png">
<meta name="msapplication-config" content="/images/favicon/browserconfig.xml">
<meta name="_globalsign-domain-verification" content="2ku73dDL0bAPTj_s1aylm6vxvrBZFK59SfbH_RdUya" />

HTML
;

$options{opensearch_image} = <<XML
<Image width="16" height="16" type="image/x-icon">https://static.$server_domain/images/favicon/favicon.ico</Image>
XML
;

$options{categories_exempted_from_nutriscore} = [qw(
en:baby-foods
en:baby-milks
en:alcoholic-beverages
en:waters
en:coffees
en:teas
fr:levure
fr:levures
en:honeys
en:vinegars
)];

$options{categories_exempted_from_nutrient_levels} = [qw(
en:baby-foods
en:baby-milks
en:alcoholic-beverages
en:coffees
en:teas
fr:levure
fr:levures
)];


$options{nova_groups_tags} = {

# start by assigning group 1

# 1st try to identify group 2 processed culinary ingredients

"categories/en:fats" => 2,
"categories/en:salts" => 2,
"categories/en:vinegars" => 2,
"categories/en:sugars" => 2,
"categories/en:honeys" => 2,
"categories/en:maple-syrups" => 2,

# group 3 tags will not be applied to food identified as group 2

"ingredients/en:preservative" => 3,

"ingredients/en:salt" => 3,
"ingredients/en:sugar" => 3,
"ingredients/en:vegetal-oil" => 3,
"ingredients/en:butter" => 3,
"ingredients/en:honey" => 3,
"ingredients/en:maple-syrup" => 3,

# tags only found in group 4

"ingredients/en:colour" => 4,
"ingredients/en:colour-stabilizer" => 4,
"ingredients/en:flavour-enhancer" => 4,
"ingredients/en:sweetener" => 4,
"ingredients/en:carbonating-agent" => 4,
"ingredients/en:firming-agent" => 4,
"ingredients/en:bulking-agent" => 4,
"ingredients/en:anti-bulking-agent" => 4,
"ingredients/en:de-foaming-agent" => 4,
"ingredients/en:anti-caking-agent" => 4,
"ingredients/en:glazing-agent" => 4,
"ingredients/en:emulsifier" => 4,
"ingredients/en:sequestrant" => 4,
"ingredients/en:humectant" => 4,

"ingredients/en:flavour" => 4,
"ingredients/en:casein" => 4,
"ingredients/en:lactose" => 4,
"ingredients/en:whey" => 4,
"ingredients/en:hydrogenated-oil" => 4,
"ingredients/en:hydrolysed-proteins" => 4,
"ingredients/en:maltodextrin" => 4,
"ingredients/en:invert-sugar" => 4,
"ingredients/en:high-fructose-corn-syrup" => 4,

"categories/en:sodas" => 4,
"categories/en:ice-creams" => 4,
"categories/en:chocolates" => 4,
"categories/en:candies" => 4,
"categories/en:meals" => 4,
"categories/en:sugary-snacks" => 4,
"categories/en:salty-snacks" => 4,
"categories/en:baby-milks" => 4,
"categories/en:sausages" => 4,



};



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


# fields in product edit form

@product_fields = qw(quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );


# fields shown on product page
# do not show purchase_places

@display_fields = qw(generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link stores countries);


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
	data_root => "/home/obf",
	www_root => "/home/obf/html",
	mongodb => "obf",
	domain => "openbeautyfacts.org",
},
off =>
{
	name => "Open Food Facts",
	data_root => "/home/off",
	www_root => "/home/off/html",
	mongodb => "off",
	domain => "openfoodfacts.org",
},
opf =>
{
	name => "Open Products Facts",
	data_root => "/home/opf",
	www_root => "/home/opf/html",
	mongodb => "opf",
	domain => "openproductsfacts.org",
},
opff =>
{
	prefix => "opff",
	name => "Open Pet Food Facts",
	data_root => "/home/opff",
	www_root => "/home/opff/html",
	mongodb => "opff",
	domain => "openpetfoodfacts.org",
}
};

1;
