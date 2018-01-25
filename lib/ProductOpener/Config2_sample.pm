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
$server_domain = "openfoodfacts.org";

@ssl_subdomains = qw(
ssl-api
);

# server paths
$www_root = "/home/off/html";
$data_root = "/home/off";

$mongodb = "off";
$mongodb_host = "mongodb://localhost";

$facebook_app_id = "";
$facebook_app_secret = "";

$csrf_secret = "SWMAqq4znqqaHN9q7UWM5xQ5aJqKqPsekcwSuvjkkTmTtTXvPpyZxXkY25kqgaXQbLFVEaqZ";

1;
