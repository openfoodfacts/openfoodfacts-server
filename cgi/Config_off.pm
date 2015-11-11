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




1;
