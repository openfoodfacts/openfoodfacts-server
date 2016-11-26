package ProductOpener::Config2;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		$server_domain
		@ssl_subdomains
		$data_root
		$www_root
		$mongodb
		$facebook_app_id
	    $facebook_app_secret
		$csrf_secret
		
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these
use strict;
use utf8;

# server constants
$server_domain = "openfoodfacts.org";

@ssl_subdomains = qw(
ssl-api
);

# server paths
$www_root = "/home/off/html";
$data_root = "/home/off";

$mongodb = "off";

$facebook_app_id = "";
$facebook_app_secret = "";

$csrf_secret = "SWMAqq4znqqaHN9q7UWM5xQ5aJqKqPsekcwSuvjkkTmTtTXvPpyZxXkY25kqgaXQbLFVEaqZ";

1;
