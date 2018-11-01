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

package ProductOpener::Index;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&get_fileid2
					&normalize
					&decode_html
					&decode_html_utf8
					&decode_html_entities
					
					
					&normalize
					
					$memd
					%texts
					
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;

use CGI qw/:standard escape unescape/;
use Time::Local;
use Cache::Memcached::Fast;
use Digest::MD5 qw(md5);
use URI::Escape;
use URI::Escape::XS;
#use Text::Unaccent::PurePerl "unac_string";
use Text::Unaccent "unac_string";
use DateTime;
use Image::Magick;
use Log::Any qw($log);

use Encode qw/from_to decode encode/;
require Encode::Detect;
use HTML::Entities qw(decode_entities);

#use POSIX qw(locale_h);
#use locale;
#setlocale(LC_CTYPE, "fr_FR");   # May need to be changed depending on system
# -> setting a locale makes unac_string fail to unaccent... :-(


# Initialize exported variables

$memd = new Cache::Memcached::Fast {
	'servers' => [ "127.0.0.1:11211" ],
	'utf8' => 1,
};

%texts = ();


opendir DH2, "$data_root/lang" or die "Couldn't open $data_root/lang : $!";
foreach my $langid (readdir(DH2)) {
	next if $langid eq '.';
	next if $langid eq '..';
	$log->trace("reading texts", { lang => $langid }) if $log->is_trace();
	next if ((length($langid) ne 2) and not ($langid eq 'other'));

	if (-e "$data_root/lang/$langid/texts") {
		opendir DH, "$data_root/lang/$langid/texts" or die "Couldn't open the current directory: $!";
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
			
			$log->trace("text loaded", { langid => $langid, textid => $textid }) if $log->is_trace();
		}
		closedir(DH);
	}
}
closedir(DH2);

# Initialize internal variables
# - using my $variable; is causing problems with mod_perl, it looks
# like inside subroutines below, they retain the first value they were
# called with. (but no "$variable will not stay shared" warning).
# Converting them to global variables.
# - better solution: create a class?

use vars qw(
);

sub unac_string_stephane($) {
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

sub normalize($) {

	my $s = shift;
	
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

	$s =~ s/&nbsp;/ /g ;
	$s =~ s/&#160;/ /g ;
	
	$s =~ s/\s+/ /g;

	return $s;
}


sub get_fileid2($)
{
	my $file = shift; # canon_blog or canon_tag

	# !!! commenting line below, because of possible double decoding
	#$file = decode("utf8",$file);
		
	$file = decode("utf8", $file);

	#$file = unac_string('UTF-8',$file);
	$file = unac_string_stephane($file);
	
	$file = lc($file);	

	$file =~ s/[^a-zA-Z0-9-]/-/g;
	$file =~ s/-+/-/g;
	$file =~ s/^-//;
	$file =~ s/-$//;
	
	return $file;	
}


sub decode_html($)
{
	my $string = shift;
	
	my $encoding = "windows-1252";
	if ($string =~ /charset=(.?)utf(-?)8/i) {
		$encoding = "UTF-8";
	}
	
	my $utf8 = $string;
	if (not utf8::is_utf8($string)) {
		$utf8 = decode($encoding, $string);
	}
	
	$log->debug("decoding", { encoding => $encoding }) if $log->is_debug();
	$utf8 = decode_entities($utf8);	
	
	return $utf8;
}

sub decode_html_utf8($)
{
	my $utf8 = shift;
	
	$utf8 = decode_entities($utf8);	
	
	return $utf8;
}

sub decode_html_entities($)
{
	my $string = shift;
	
	# utf8::is_utf8($string) or $string = decode("UTF8", $string);
	
	utf8::is_utf8($string) or utf8::decode($string);
	
	my $utf8 = decode_entities($string);
	
	if (0 and ($utf8 =~ /Ã/)) { # doesn't work
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
