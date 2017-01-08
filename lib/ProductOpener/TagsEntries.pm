package ProductOpener::TagsEntries;

######################################################################
#
#	Package	TagsEntries
#
#	Author:	Stephane Gigandet
#	Date:	06/08/10
#
######################################################################

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					%ingredients_classes
					%ingredients_classes_sorted

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;



1;
