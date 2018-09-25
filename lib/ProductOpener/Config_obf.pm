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
		
		@taxonomy_fields	
		@product_image_fields
		@product_fields
		@display_fields
		@drilldown_fields
		
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
hangy
javichu
kyzh
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

@edit_rules = ();


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

$contact_email = 'contact@openbeautyfacts.org';
$admin_email = 'biz@joueb.com';


$thumb_size = 100;
$crop_size = 400;
$small_size = 200;
$display_size = 400;
$zoom_size = 800;

$page_size = 20;


$google_analytics = <<HTML
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-31851927-5', 'auto');
  ga('send', 'pageview');

</script>
HTML
;



%wiki_texts = (

"en/whatsinmyshampoo" => "http://en.wiki.openbeautyfacts.org/Translations/whatsinmyshampoo.com/English?action=raw",

"en/index.foundation" => "http://en.wiki.openbeautyfacts.org/Translations/Index_page/English?action=raw",
"fr/index.foundation" => "http://en.wiki.openbeautyfacts.org/Translations/Index_page/French?action=raw",

"en/contribute.foundation" => "http://en.wiki.openbeautyfacts.org/Translations/Contribute_page/English?action=raw",
"fr/contribute.foundation" => "http://en.wiki.openbeautyfacts.org/Translations/Contribute_page/French?action=raw",

"en/discover.foundation" => "http://en.wiki.openbeautyfacts.org/Translations/Discover_page/English?action=raw",
"fr/discover.foundation" => "http://en.wiki.openbeautyfacts.org/Translations/Discover_page/French?action=raw",

"en/press" => "http://en.wiki.openbeautyfacts.org/Translations_-_Press_-_English?action=raw",
"fr/presse" => "http://en.wiki.openbeautyfacts.org/Translations_-_Press_-_French?action=raw",

"en/code-of-conduct" => "http://en.wiki.openbeautyfacts.org/Translations_-_Code_of_conduct_-_English?action=raw",
"fr/code-de-conduite" => "http://en.wiki.openbeautyfacts.org/Translations_-_Code_of_conduct_-_French?action=raw",

"en/data" => "http://en.wiki.openbeautyfacts.org/Translations/Data/English?action=raw",
"fr/data" => "http://en.wiki.openbeautyfacts.org/Translations/Data/French?action=raw",

);

@product_image_fields = qw(front ingredients);

#fields that have a taxonomy

@taxonomy_fields = qw(states countries languages labels categories additives allergens traces nutrient_levels ingredients periods_after_opening);

# fields in product edit form

#@product_fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link periods_after_opening expiration_date purchase_places stores countries  );
@product_fields = qw(quantity packaging brands categories labels origins manufacturing_places emb_codes link periods_after_opening expiration_date purchase_places stores countries  );

# fields shown on product page
# do not show purchase_places

@display_fields = qw(generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link periods_after_opening stores countries);


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

$options{display_tag_ingredients} = [

	'COSING',
	'CAS',
	'EINECS',
	'INN Name',
	'Ph Eur Name',
	'@INCI Function',
	'INCI Description',
	'INCI Restriction',

];


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
opff =>
{
	prefix => "opff",
	name => "Open Pet Food Facts",
	data_root => "/srv/opff",
	www_root => "/srv/opff/html",
	mongodb => "opff",
	domain => "openpetfoodfacts.org",
},
opf =>
{
	name => "Open Products Facts",
	data_root => "/srv/opf",
	www_root => "/srv/opf/html",
	mongodb => "opf",
	domain => "openproductsfacts.org",
},

};


$options{no_nutrition_table} = 1;

1;
