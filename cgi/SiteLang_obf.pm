package Blogs::SiteLang;

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

site_name => {
	en => 'Open Beauty Facts',
},

twitter_account => {
	en => 'OpenBeautyFacts',
},

logo => {
	en => 'openbeautyfacts-logo-en-178x150.png',
	fr => 'openbeautyfacts-logo-fr-178x150.png',
},

logo2x => {
	en => 'openbeautyfacts-logo-en-356x300.png',
	fr => 'openbeautyfacts-logo-fr-356x300.png',
},


);


1;