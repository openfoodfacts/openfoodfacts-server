package ProductOpener::Config2;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		$server_domain
		@ssl_subdomains
		$data_root
		$www_root
		$mongodb
		$mongodb_host
		$facebook_app_id
	    $facebook_app_secret
		$csrf_secret
		
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these

# server constants
$server_domain = "productopener.localhost";

@ssl_subdomains = qw();

# server paths
$www_root = "/opt/product-opener/html";
$data_root = "/mnt/podata";

$mongodb = "off";
$mongodb_host = "mongodb://mongodb";

$facebook_app_id = "";
$facebook_app_secret = "";

$csrf_secret = "EYvfj3GDJnc2UPVqTwTGPgWC";

1;
