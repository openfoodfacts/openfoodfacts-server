# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_urlid
		&get_fileid
		&store
		&retrieve
		&store_json
		&retrieve_json
		&unac_string_perl
		&get_string_id_for_lang
		&get_url_id_for_lang
		&sto_iter
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;    # no 'my' keyword for these

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;

use Storable qw(lock_store lock_nstore lock_retrieve);
use Encode;
use Encode::Punycode;
use URI::Escape::XS;
use Unicode::Normalize;
use Log::Any qw($log);
use JSON::Create qw(write_json);
use JSON::Parse qw(read_json);

# Text::Unaccent unac_string causes Apache core dumps with Apache 2.4 and mod_perl 2.0.9 on jessie

sub unac_string_perl ($s) {

	$s
		=~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŸ/aaaaaaceeeeiiiinooooouuuuyyaaaaaaceeeeiiiinooooouuuuyy/;

	# alternative methods, slower than above, but more readable and still faster than s///.

	#$s =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;
	#$s =~ tr/ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŸ/aaaaaaceeeeiiiinooooouuuuyy/;

	#$s =~ tr/àáâãäåÀÁÂÃÄÅ/a/;
	#$s =~ tr/çÇ/c/;
	#$s =~ tr/èéêëÈÉÊË/e/;
	#$s =~ tr/ìíîïÌÍÎÏ/i/;
	#$s =~ tr/ñÑ/n/;
	#$s =~ tr/òóôõöÒÓÔÕÖ/o/;
	#$s =~ tr/ùúûüÙÚÛÜ/u/;
	#$s =~ tr/ýÿÝŸ/y/;

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

sub get_string_id_for_lang ($lc, $string) {

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
			$string =~ tr/\N{U+1E9E}/\N{U+00DF}/;    # Actual lower-case for capital ß
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

sub get_fileid ($file, $unaccent = undef, $lc = undef) {

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
		$file =~ tr/\N{U+1E9E}/\N{U+00DF}/;    # Actual lower-case for capital ß
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

sub get_url_id_for_lang ($lc, $input) {

	my $string = $input;

	$string = get_string_id_for_lang($lc, $string);

	if ($string =~ /[^a-zA-Z0-9-]/) {
		$string = URI::Escape::XS::encodeURIComponent($string);
	}

	$log->trace("get_urlid", {in => $input, out => $string}) if $log->is_trace();

	return $string;
}

sub get_urlid ($input, $unaccent = undef, $lc = undef) {

	my $file = $input;

	$file = get_fileid($file, $unaccent, $lc);

	if ($file =~ /[^a-zA-Z0-9-]/) {
		$file = URI::Escape::XS::encodeURIComponent($file);
	}

	$log->trace("get_urlid", {in => $input, out => $file}) if $log->is_trace();

	return $file;
}

sub store ($file, $ref) {

	return lock_store($ref, $file);
}

sub retrieve ($file) {

	# If the file does not exist, return undef.
	if (!-e $file) {
		return;
	}
	my $return = undef;
	eval {$return = lock_retrieve($file);};

	if ($@ ne '') {
		require Carp;
		Carp::carp("cannot retrieve $file : $@");
	}

	return $return;
}

sub store_json ($file, $ref) {

	# we sort hash keys so that the same object results in the same file
	# we do not indent as it can easily multiply the size by 2 or more with deep nested structures
	return write_json($file, $ref, (sort => 1));
}

sub retrieve_json ($file) {

	# If the file does not exist, return undef.
	if (!-e $file) {
		return;
	}
	my $return = undef;
	eval {$return = read_json($file);};

	if ($@ ne '') {
		require Carp;
		Carp::carp("cannot retrieve $file : $@");
	}

	return $return;
}

=head2  sto_iter($initial_path, $pattern=qr/\.sto$/i)

iterate all the files corresponding to $pattern starting from $initial_path

use it as an iterator:
my $iter = sto_iter(".");
while (my $path = $iter->()) {
	# do stuff
}

=cut

sub sto_iter ($initial_path, $pattern = qr/\.sto$/i) {
	my @dirs = ($initial_path);
	my @files = ();
	my %seen;
	return sub {
		if (scalar @files == 0) {
			# explore a new dir until we get some file
			while ((scalar @files == 0) && (scalar @dirs > 0)) {
				my $current_dir = shift @dirs;
				opendir(DIR, $current_dir) or die "Cannot open $current_dir\n";
				# Sort files so that we always explore them in the same order (useful for tests)
				my @candidates = sort readdir(DIR);
				closedir(DIR);
				foreach my $file (@candidates) {
					# avoid ..
					next if $file =~ /^\.\.?$/;
					my $path = "$current_dir/$file";
					if (-d $path) {
						# explore sub dirs
						next if $seen{$path};
						$seen{$path} = 1;
						push @dirs, $path;
					}
					next if ($path !~ $pattern);
					push(@files, $path);
				}
			}
		}
		# if we still have files, return a file
		if (scalar @files > 0) {
			return shift @files;
		}
		else {
			# or end iteration
			return;
		}
	};
}

1;
