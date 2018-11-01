# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::Store;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		&get_urlid
		&get_fileid
		&get_fileid_punycode
		&get_ascii_fileid
		&store
		&retrieve
		&unac_string_perl
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);  
}
use vars @EXPORT_OK ; # no 'my' keyword for these

use Storable qw(lock_store lock_nstore lock_retrieve);
#use Text::Unaccent "unac_string";
use Encode;
use Encode::Punycode;
use URI::Escape::XS;
use Log::Any qw($log);

# Text::Unaccent unac_string causes Apache core dumps with Apache 2.4 and mod_perl 2.0.9 on jessie

sub unac_string_perl($) {
        my $s = shift;

        $s =~ s/à|á|â|ã|ä|å/a/ig;
        $s =~ s/ç/c/ig;
        $s =~ s/è|é|ê|ë/e/ig;
        $s =~ s/ì|í|î|ï/i/ig;
        $s =~ s/ñ/n/ig;
        $s =~ s/ò|ó|ô|õ|ö/o/ig;
        $s =~ s/ù|ú|û|ü/u/ig;
        $s =~ s/ý|ÿ/y/ig;
        $s =~ s/œ|Œ/oe/g;
        $s =~ s/æ|Æ/ae/g;

        return $s;
}

# Tags in European characters (iso-8859-1 / Latin-1 / Windows-1252) are canonicalized:
# 1. deaccent: é -> è, + German umlauts: ä -> ae
# 2. lowercase
# 3. turn ascii characters that are not letters / numbers to -
# 4. keep other UTF-8 characters (e.g. Chinese, Japanese, Korean, Arabic, Hebrew etc.) untouched
# 5. remove leading and trailing -, turn multiple - to -

sub get_fileid($) {

	my $file = shift;
	
	if (not defined $file) {
		return "";
	}
	
	$file =~ s/œ|Œ/oe/g;
	$file =~ s/æ|Æ/ae/g;
	
	$file =~ s/ß/ss/g;
	
	$file =~ s/ç/c/g;
	$file =~ s/ñ/n/g;
	
	$file = lc($file);
	
	#$file = decode("UTF-16", unac_string('UTF-16',encode("UTF-16", $file)));
	$file = unac_string_perl($file);
	
	# turn characters that are not letters and numbers to -
	# except extended UTF-8 characters
	# $file =~ s/[^a-z0-9-]/-/g;
	
	# avoid turning &quot; in -quot-
	$file =~ s/\&(quot|lt|gt);/-/g;	
	
	$file =~ s/[\s!"#\$%&'()*+,.\/:;<=>?@\[\\\]^_`{\|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿×ˆ˜–—‘’‚“”„†‡•…‰‹›€™\t]/-/g;
	$file =~ s/-+/-/g;
	$file =~ s/^-//;
	$file =~ s/-$//;
	
	return $file;	
}


sub get_urlid($) {

	my $input = shift;
	my $file = $input;
	
	$file = get_fileid($file);
	
	if ($file =~ /[^a-zA-Z0-9-]/) {
		$file = URI::Escape::XS::encodeURIComponent($file);
	}
	
	$log->trace("get_urlid", { in => $input, out => $file }) if $log->is_trace();
	
	return $file;
}


sub get_ascii_fileid($) {

	my $file = shift;
	
	$file = get_fileid($file);

	if ($file =~ /[^a-zA-Z0-9-]/) {
		$file = "xn--" .  encode('Punycode',$file);
	}
	
	$log->debug("get_ascii_fileid", { file => $file }) if $log->is_debug();

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
		return;
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
