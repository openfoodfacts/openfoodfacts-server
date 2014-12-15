package Blogs::Store;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		&get_fileid
		&get_fileid_punycode
		&store
		&retrieve
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);  
}
use vars @EXPORT_OK ; # no 'my' keyword for these
use strict;
use utf8;

use Storable qw(lock_store lock_nstore lock_retrieve);
use Text::Unaccent "unac_string";
use Encode;
use Encode::Punycode;

sub get_fileid($)
{
	my $file = shift; # canon_blog or canon_tag
	
	#print STDERR "get_fileid : $file - 1 \n";
	
	# !!! commenting line below, because of possible double decoding
	#$file = decode("utf8",$file);
	
	#utf8::upgrade($file);
	
	#print STDERR "get_fileid : $file - 2 \n";
	
	$file =~ s/œ|Œ/oe/g;
	$file =~ s/æ|Æ/ae/g;
	
	$file =~ s/ß/ss/g;
	
	$file = lc($file);
	$file = unac_string('UTF-8',$file);
	#$file = unac_string_stephane($file);
	
	#print STDERR "get_fileid : $file - 3 \n";

	$file =~ s/[^a-zA-Z0-9-]/-/g;
	$file =~ s/-+/-/g;
	$file =~ s/^-//;
	$file =~ s/-$//;
	
	#print STDERR "get_fileid : $file \n";
	
	return $file;	
}

sub get_fileid_punycode($)
{
	my $file = shift; # canon_blog or canon_tag
	
	#print STDERR "get_fileid : $file - 1 \n";
	
	# !!! commenting line below, because of possible double decoding
	#$file = decode("utf8",$file);
	
	#utf8::upgrade($file);
	
	#print STDERR "get_fileid : $file - 2 \n";
	
	$file =~ s/œ|Œ/oe/g;
	$file =~ s/æ|Æ/ae/g;	
	
	$file = lc($file);
	$file = unac_string('UTF-8',$file);
	#$file = unac_string_stephane($file);
	
	#print STDERR "get_fileid : $file - 3 \n";
	
	$file =~ s/([_\.\/\\'\%\!\?\"\#\@\*\$\:\;\+]|\s)+/-/g;
	$file =~ s/-+/-/g;
	$file =~ s/^-//;
	$file =~ s/-$//;	
	
	if ($file =~/[^a-zA-Z0-9-]/) {
		$file = "xn--" .  encode('Punycode',$file);
	}

	
	#print STDERR "get_fileid : $file \n";
	
	return $file;	
}

sub store {
	my $file = shift @_;
	my $ref = shift @_;
	
	return lock_store($ref, $file);
}

sub retrieve {
	my $file = shift @_;
	# If the file does not exist, return undef.
	if (! -e $file) {
		return undef;
	}
	my $return = undef;
	eval {$return = lock_retrieve($file);};

	if ($@ ne '')
	{
		use Carp;
		carp "cannot retrieve $file : $@";
 	}

	return $return;
}

1;
