package ProductOpener::Cache;

######################################################################
#
#	Package		Cache
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
					&get_multi_objects
					
					$memd
					
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

use Cache::Memcached::Fast;


# Initialize exported variables

$memd = new Cache::Memcached::Fast {
	'servers' => [ "127.0.0.1:11211" ],
	'utf8' => 1,
};

# Initialize internal variables
# - using my $variable; is causing problems with mod_perl, it looks
# like inside subroutines below, they retain the first value they were
# called with. (but no "$variable will not stay shared" warning).
# Converting them to global variables.
# - better solution: create a class?

use vars qw(
);

my $debug = 0 ;	# Set to a non null value to get debug messages

sub get_multi_objects($)
{
	my $keys_ref = shift;
	my $values_ref = $memd->get_multi(keys %$keys_ref);

	foreach my $key (keys %$keys_ref) {
		if (not defined $values_ref->{$key}) {
			if ($key =~ /\/blogs\/(.*)$/) {
				my $blog_ref = retrieve("$data_root/index/blogs/$1/blog.sto");
				if (defined $blog_ref) {
					$values_ref->{$key} = {
						title => $blog_ref->{title},
						color => $blog_ref->{color2},
						url => $blog_ref->{url}
					};
					$debug and print STDERR "Cache::get_multi_objects - $key - retrieved from disk\n";
					$memd->set($key, $values_ref->{$key});
				}
			}
			elsif ($key =~ /\/tags\/(.*)$/) {
				my $tag_ref = retrieve("$data_root/index/tags/$1/tag.sto");
				if (defined $tag_ref) {
					$values_ref->{$key} = {
						canon_tag => $tag_ref->{canon_tag},
						color => $tag_ref->{color2},					
					};
					$debug and print STDERR "Cache::get_multi_objects - $key - retrieved from disk\n";
					$memd->set($key, $values_ref->{$key});
				}			
			}
		}
		else {
			$debug and print STDERR "Cache::get_multi_objects - $key - in cache\n";
		}
	}
	
	return $values_ref;
}

1;
