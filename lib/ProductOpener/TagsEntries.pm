package ProductOpener::TagsEntries;

######################################################################
#
#	Package	TagsEntries
#
#	Author:	Stephane Gigandet
#	Date:	06/08/10
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					%ingredients_classes
					%ingredients_classes_sorted

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;



1;
