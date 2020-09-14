# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
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
use Encode;
use Encode::Punycode;
use URI::Escape::XS;
use Unicode::Normalize;
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

	my ($lc, $string) = @_;

	defined $lc or die("Undef \$lc in call to get_string_id_for_lang (string: $string)\n");

	if (not defined $string) {
		return "";
	}
	
	# Normalize Unicode characters
	# Form NFC
	$string = NFC($string); 

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

	if ($lowercase) {
		# do not lowercase UUIDs
		# e.g.
		# yuka.VFpGWk5hQVQrOEVUcWRvMzVETGU0czVQbTZhd2JIcU1OTXdCSWc9PQ
		# (app)Waistline: e2e782b4-4fe8-4fd6-a27c-def46a12744c
		if ($string !~ /^[a-z\-]+\.[a-zA-Z0-9-_]{8}[a-zA-Z0-9-_]+$/) {
			$string =~ tr/\N{U+1E9E}/\N{U+00DF}/; # Actual lower-case for capital ß
			$string = lc($string);
			$string =~ tr/./-/;
		}
	}

	if ($unaccent) {
		$string =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;
		$string =~ s/œ|Œ/oe/g;
		$string =~ s/æ|Æ/ae/g;
		$string =~ s/ß|\N{U+1E9E}/ss/g;
	}

	# turn special chars and zero width space to -
	$string =~ tr/\000-\037\x{200B}/-/;

	# avoid turning &quot; in -quot-
	$string =~ s/\&(quot|lt|gt);/-/g;

	$string =~ s/[\s!"#\$%&'()*+,\/:;<=>?@\[\\\]^_`{\|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿×ˆ˜–—‘’‚“”„†‡•…‰‹›€™\t]/-/g;
	$string =~ tr/-/-/s;

	if (index($string, '-') == 0) {
		$string = substr $string, 1;
	}

	my $l = length($string);
	if (rindex($string, '-') == $l - 1) {
		$string = substr $string, 0, $l - 1;
	}

	return $string;

}

sub get_fileid {

	my ($file, $unaccent, $lc) = @_;

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
	if ($file !~ /^[a-z\-]+\.[a-zA-Z0-9-_]{8}[a-zA-Z0-9-_]+$/) {
		$file =~ tr/\N{U+1E9E}/\N{U+00DF}/; # Actual lower-case for capital ß
		$file = lc($file);
		$file =~ tr/./-/;
	}

	if ($unaccent) {
		$file =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;
		$file =~ s/œ|Œ/oe/g;
		$file =~ s/æ|Æ/ae/g;
		$file =~ s/ß|\N{U+1E9E}/ss/g;
	}

	# turn special chars and zero width space to -
	$file =~ tr/\000-\037\x{200B}/-/;

	# avoid turning &quot; in -quot-
	$file =~ s/\&(quot|lt|gt);/-/g;

	$file =~ s/[\s!"#\$%&'()*+,\/:;<=>?@\[\\\]^_`{\|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿×ˆ˜–—‘’‚“”„†‡•…‰‹›€™\t]/-/g;
	$file =~ tr/-/-/s;

	if (index($file, '-') == 0) {
		$file = substr $file, 1;
	}

	my $l = length($file);
	if (rindex($file, '-') == $l - 1) {
		$file = substr $file, 0, $l - 1;
	}

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
		require Carp;
		Carp::carp("cannot retrieve $file : $@");
 	}

	return $return;
}

1;
