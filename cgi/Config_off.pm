package Blogs::Config;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		%admins
		
		$server_domain
		$data_root
		$www_root
		$reference_timezone
		$contact_email
		$admin_email
		
		$facebook_app_id
		$facebook_app_secret
		
		$mongodb
	
		$google_analytics
		
		$thumb_size
		$crop_size
		$small_size
		$display_size
		$zoom_size
		
		$page_size
		
		$adsense
		
		%options
		
		%wiki_texts

		@product_fields
		@display_fields
		@drilldown_fields
		
		%tesseract_ocr_available_languages
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these
use strict;
use utf8;

use Blogs::Config2;
use Blogs::Lang;


%admins = ('stephane' => 1);


# server constants
$server_domain = $Blogs::Config2::server_domain;
$mongodb = $Blogs::Config2::mongodb;

# server paths
$www_root = $Blogs::Config2::www_root;
$data_root = $Blogs::Config2::data_root;

$facebook_app_id = $Blogs::Config2::facebook_app_id;
$facebook_app_secret = $Blogs::Config2::facebook_app_secret;

$reference_timezone = 'Europe/Paris';

$contact_email = 'contact@openfoodfacts.org';
$admin_email = 'biz@joueb.com';


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


%wiki_texts = (

"en/press" => "http://en.wiki.openfoodfacts.org/index.php?title=Translations_-_Press_-_English&action=raw",
"fr/presse" => "http://en.wiki.openfoodfacts.org/index.php?title=Translations_-_Press_-_French&action=raw",

"en/code-of-conduct" => "http://en.wiki.openfoodfacts.org/index.php?title=Translations_-_Code_of_conduct_-_English&action=raw",
"fr/code-de-conduite" => "http://en.wiki.openfoodfacts.org/index.php?title=Translations_-_Code_of_conduct_-_French&action=raw",

);


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

1;
