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

package ProductOpener::Index;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&normalize
		&decode_html
		&decode_html_entities

		&normalize

		$lang_dir
		%texts

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

use CGI qw/:standard escape unescape/;
use Time::Local;
use Digest::MD5 qw(md5);
use URI::Escape;
use URI::Escape::XS;
use DateTime;
use Image::Magick;
use Log::Log4perl;
use Log::Any qw($log);

use Encode qw/from_to decode encode/;
require Encode::Detect;
use HTML::Entities qw(decode_entities);

#use POSIX qw(locale_h);
#use locale;
#setlocale(LC_CTYPE, "fr_FR");   # May need to be changed depending on system
# -> setting a locale makes unac_string fail to unaccent... :-(

# Load the texts from the /lang directory

# The /lang directory is not present in the openfoodfacts-server repository,
# it needs to be copied from the openfoodfacts-web repository.

# If the /lang directory does not exist, a minimal number of texts needed to run Product Opener
# are loaded from /lang_default directory

%texts = ();

$lang_dir = "$data_root/lang";

if (not -e $lang_dir) {
	$lang_dir = "$data_root/lang-default";
	$log->warn(
		"The $data_root/lang directory does not exist. It should be copied from the openfoodfacts-web repository. Using default texts from $lang_dir"
	) if $log->is_warn();
}

if (opendir DH2, $lang_dir) {

	$log->info("Reading texts from $lang_dir") if $log->is_info();

	foreach my $langid (readdir(DH2)) {
		next if $langid eq '.';
		next if $langid eq '..';
		#$log->trace("reading texts", { lang => $langid }) if $log->is_trace();
		next if ((length($langid) ne 2) and not($langid eq 'other'));

		if (-e "$lang_dir/$langid/texts") {
			opendir DH, "$lang_dir/$langid/texts" or die "Couldn't open $lang_dir/$langid/texts: $!";
			foreach my $textid (readdir(DH)) {
				next if $textid eq '.';
				next if $textid eq '..';
				my $file = $textid;
				$textid =~ s/(\.foundation)?(\.$langid)?\.html//;
				defined $texts{$textid} or $texts{$textid} = {};
				# prefer the .foundation version
				if ((not defined $texts{$textid}{$langid}) or (length($file) > length($texts{$textid}{$langid}))) {
					$texts{$textid}{$langid} = $file;
				}

				#$log->trace("text loaded", { langid => $langid, textid => $textid }) if $log->is_trace();
			}
			closedir(DH);
		}
	}
	closedir(DH2);
}
else {
	$log->error("Texts could not be loaded.") if $log->is_error();
	die("Texts could not be loaded from $data_root/lang or $data_root/lang-default");
}

# Initialize internal variables
# - using my $variable; is causing problems with mod_perl, it looks
# like inside subroutines below, they retain the first value they were
# called with. (but no "$variable will not stay shared" warning).
# Converting them to global variables.
# - better solution: create a class?

sub normalize ($s) {

	# Remove comments
	$s =~ s/(<|\&lt;)!--(.*?)--(>|\&gt;)//sg;
	$s =~ s/<style(.*?)<\/style>//sg;
	# Remove scripts
	$s =~ s/<script(.*?)<\/script>//isg;

	# Remove open comments
	$s =~ s/(<|\&lt;)!--(.*)//sg;

	# Add line feeds instead of </p> and </div> etc.
	$s =~ s/<\/(p|div|span|blockquote)>/\n\n/ig;
	$s =~ s/<\/(li|ul|ol)>/\n/ig;
	$s =~ s/<br( \/)?>/\n/ig;

	# Remove "<= blabla" on recettessimples.fr
	$s =~ s/<=//g;

	# Remove tags
	$s =~ s/<(([^>]|\n)*)>//g;

	$s =~ s/&nbsp;/ /g;
	$s =~ s/&#160;/ /g;

	$s =~ s/\s+/ /g;

	return $s;
}

sub decode_html_entities ($string) {

	# utf8::is_utf8($string) or $string = decode("UTF8", $string);

	utf8::is_utf8($string) or utf8::decode($string);

	my $utf8 = decode_entities($string);

	if (0 and ($utf8 =~ /Ã/)) {    # doesn't work
								   # double encoding?
		$utf8 =~ s/Ã©/é/g;
		$utf8 =~ s/Ã´/ô/g;
		$utf8 =~ s/Ã»/û/g;
		$utf8 =~ s/Ã¨/è/g;
		$utf8 =~ s/Ã®/î/g;
		$utf8 =~ s/Ãª/ê/g;
		$utf8 =~ s/Ã /à/g;
	}

	return $utf8;
}

1;
