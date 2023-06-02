package ProductOpener::SiteLang;

######################################################################
#
#	Package	SiteLang
#
#	Author:	Stephane Gigandet
#	Date:	23/01/2015
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();	# symbols to export by default
	@EXPORT_OK = qw(
	
					%SiteLang				

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

# %SiteLang overrides the general %Lang in Lang.pm

%SiteLang = (

logo => {
	en => 'openpetfoodfacts-logo-en-178x150.png',
},

logo2x => {
	en => 'openpetfoodfacts-logo-en-356x300.png',
},

tagline => {

	en => "Open Food Facts gathers information and data on food products for pets from around the world.",
	fr => "Open Food Facts répertorie les produits alimentaires pour animaux de compagnie du monde entier.",

},

);


1;
