# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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
use Modern::Perl '2017';
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
		&get_string_id_for_lang
		&get_url_id_for_lang
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these

use ProductOpener::Config qw/:all/;

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
# 1. lowercase
# 2. unaccent: é -> è, + German umlauts: ä -> ae if $unaccent is 1 OR $lc is 'fr'
# 3. turn ascii characters that are not letters / numbers to -
# 4. keep other UTF-8 characters (e.g. Chinese, Japanese, Korean, Arabic, Hebrew etc.) untouched
# 5. remove leading and trailing -, turn multiple - to -

sub get_string_id_for_lang {

	my $lc = shift;
	my $string = shift;

	defined $lc or die("Undef \$lc in call to get_string_id_for_lang (string: $string)\n");

	my $unaccent = $string_normalization_for_lang{default}{unaccent};
	my $lowercase = $string_normalization_for_lang{default}{lowercase};

	if (defined $string_normalization_for_lang{$lc}) {
		if (defined $string_normalization_for_lang{$lc}{unaccent}) {
			$unaccent = $string_normalization_for_lang{$lc}{unaccent};
		}
		if (defined $string_normalization_for_lang{$lc}{lowercase}) {
			$lowercase = $string_normalization_for_lang{$lc}{lowercase};
		}
	}

	if (not defined $string) {
		return "";
	}

	if ($lowercase) {
		# do not lowercase UUIDs
		# e.g.
		# yuka.VFpGWk5hQVQrOEVUcWRvMzVETGU0czVQbTZhd2JIcU1OTXdCSWc9PQ
		# (app)Waistline: e2e782b4-4fe8-4fd6-a27c-def46a12744c
		if ($string !~ /^([a-z\-]+)\.([a-zA-Z0-9-_]{8})([a-zA-Z0-9-_]*)$/) {
			$string =~ s/\N{U+1E9E}/\N{U+00DF}/g; # Actual lower-case for capital ß
			$string = lc($string);
			$string =~ tr/./-/;
		}
	}

	if ($unaccent) {
		$string =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;
		$string =~ s/œ|Œ/oe/g;
		$string =~ s/æ|Æ/ae/g;
		$string =~ s/ß/ss/g;
		$string =~ s/\N{U+1E9E}/ss/g;
	}

	# turn special chars to -
	$string =~ s/[\000-\037]/-/g;

	# zero width space
	$string =~ s/\x{200B}/-/g;

	# avoid turning &quot; in -quot-
	$string =~ s/\&(quot|lt|gt);/-/g;

	$string =~ s/[\s!"#\$%&'()*+,\/:;<=>?@\[\\\]^_`{\|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿×ˆ˜–—‘’‚“”„†‡•…‰‹›€™\t]/-/g;
	$string =~ s/-+/-/g;
	$string =~ s/^-//;
	$string =~ s/-$//;

	return $string;
}


sub get_fileid {

	my $file = shift;
	my $unaccent = shift;
	my $lc = shift;

	if (not defined $file) {
		return "";
	}

	if ((defined $lc) and ($lc eq 'fr')) {
		$unaccent = 1;
	}

	# do not lowercase UUIDs
	# e.g.
	# yuka.VFpGWk5hQVQrOEVUcWRvMzVETGU0czVQbTZhd2JIcU1OTXdCSWc9PQ
	# (app)Waistline: e2e782b4-4fe8-4fd6-a27c-def46a12744c
	if ($file !~ /^([a-z\-]+)\.([a-zA-Z0-9-_]{8})([a-zA-Z0-9-_]*)$/) {
		$file =~ s/\N{U+1E9E}/\N{U+00DF}/g; # Actual lower-case for capital ß
		$file = lc($file);
		$file =~ tr/./-/;
	}

	if ((defined $unaccent) and ($unaccent eq 1)) {
		$file =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;

		$file =~ s/œ|Œ/oe/g;
		$file =~ s/æ|Æ/ae/g;
		$file =~ s/ß/ss/g;
		$file =~ s/\N{U+1E9E}/ss/g;
	}

	# turn special chars to -
	$file =~ s/[\000-\037]/-/g;

	# zero width space
	$file =~ s/\x{200B}/-/g;

	# avoid turning &quot; in -quot-
	$file =~ s/\&(quot|lt|gt);/-/g;

	$file =~ s/[\s!"#\$%&'()*+,\/:;<=>?@\[\\\]^_`{\|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿×ˆ˜–—‘’‚“”„†‡•…‰‹›€™\t]/-/g;
	$file =~ s/-+/-/g;
	$file =~ s/^-//;
	$file =~ s/-$//;

	return $file;
}


sub get_url_id_for_lang {

	my $lc = shift;
	my $input = shift;
	my $string = $input;

	$string = get_string_id_for_lang($lc, $string);

	if ($string =~ /[^a-zA-Z0-9-]/) {
		$string = URI::Escape::XS::encodeURIComponent($string);
	}

	$log->trace("get_urlid", { in => $input, out => $string }) if $log->is_trace();

	return $string;
}


sub get_urlid {

	my $input = shift;
	my $file = $input;
	my $unaccent = shift;
	my $lc = shift;

	$file = get_fileid($file, $unaccent, $lc);

	if ($file =~ /[^a-zA-Z0-9-]/) {
		$file = URI::Escape::XS::encodeURIComponent($file);
	}

	$log->trace("get_urlid", { in => $input, out => $file }) if $log->is_trace();

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
