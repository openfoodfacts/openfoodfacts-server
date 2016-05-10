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
		
		%options
		
		%wiki_texts
		
		@taxonomy_fields
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

"en/press" => "http://en.wiki.openfoodfacts.org/Translations_-_Press_-_English?action=raw",
"fr/presse" => "http://en.wiki.openfoodfacts.org/Translations_-_Press_-_French?action=raw",

"en/code-of-conduct" => "http://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_English?action=raw",
"fr/code-de-conduite" => "http://en.wiki.openfoodfacts.org/Translations_-_Code_of_conduct_-_French?action=raw",

"fr/notetondistrib" => "http://en.wiki.openfoodfacts.org/Translations_-_Vending_machines_-_French?action=raw",

);

@taxonomy_fields = qw(states countries labels categories additives allergens traces nutrient_levels );


1;
