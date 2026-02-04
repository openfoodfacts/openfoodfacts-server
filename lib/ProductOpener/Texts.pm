# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

package ProductOpener::Texts;

=head1 NAME

ProductOpener::Texts - Load and manage texts in different languages

=head1 DESCRIPTION

=head2 Text pages translations

The openfoodfacts-web repostory contains a /lang directory with texts in different languages.

For instance https://github.com/openfoodfacts/openfoodfacts-web/blob/main/lang/fr/texts/terms-of-use.html
is the French translation of the "Terms of use" page.

=head2 Text pages routes

In English the route for the "Terms of use" page is /terms-of-use

In other languages, we use a translated route, for instance in French: /conditions-d-utilisation

The translations for the routes are stored in the common/*.po files:

# Do not translate without having the same exact string in the Tags template. Do not use spaces, special characters, only alphanumeric characters separated by hyphens
msgctxt "footer_terms_link"
msgid "/terms-of-use"
msgstr "/conditions-d-utilisation"

=head2 Routing

This module generates the mapping from translated routes to text ids.

=cut

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&normalize

		$lang_dir
		%texts
		%texts_translated_route_to_text_id
		%texts_text_id_to_translated_route

		&init_translated_text_routes_for_all_languages
		&load_texts_from_lang_directory

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Lang qw/@Langs lang_in_other_lc/;

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

# In the common/*.po files we have URLs that can be translated.
# For instance in common/fr.po we have:
#
# Do not translate without having the same exact string in the Tags template. Do not use spaces, special characters, only alphanumeric characters separated by hyphens
# msgctxt "footer_terms_link"
# msgid "/terms-of-use"
# msgstr "/conditions-d-utilisation"
#
#  https://github.com/openfoodfacts/openfoodfacts-web/blob/main/lang/fr/texts/terms-of-use.html

my %texts_text_id_to_translation_id = (
	'add-a-product' => 'menu_add_a_product_link',
	'blog' => 'footer_blog_link',
	'code-of-conduct' => 'footer_code_of_conduct_link',
	'contribute' => 'menu_contribute_link',
	'data' => 'footer_data_link',
	'discover' => 'menu_discover_link',
	'donate' => 'donate_link',
	'faq' => 'footer_faq_link',
	'import-products' => 'import_products_link',
	'legal' => 'footer_legal_link',
	'open-beauty-facts-mobile-app' => 'get_the_app_link_obf',
	'open-food-facts-mobile-app' => 'get_the_app_link_off',
	'open-pet-food-facts-mobile-app' => 'get_the_app_link_opff',
	'open-products-facts-mobile-app' => 'get_the_app_link_opf',
	'partners' => 'footer_partners_link',
	'press' => 'footer_press_link',
	'privacy' => 'footer_privacy_link',
	'terms-of-use' => 'footer_terms_link',
	'open-food-facts-vision-mission-values-and-programs' => 'footer_vision_link',
	'who-we-are' => 'footer_who_we_are_link',
	'wiki' => 'footer_wiki_link',
);

%texts_translated_route_to_text_id = ();
%texts_text_id_to_translated_route = ();

# Called from load_routes() in ProductOpener::Routing.pm

sub init_translated_text_routes_for_all_languages () {
	# return if already initialized
	return 1 if %texts_translated_route_to_text_id;

	foreach my $text_id (sort keys %texts_text_id_to_translation_id) {

		my $translation_id = $texts_text_id_to_translation_id{$text_id};

		foreach my $target_lc (@Langs) {

			my $translated_route = lang_in_other_lc($target_lc, $translation_id);

			# Remove leading slash if present
			$translated_route =~ s|^/||;

			# $translated_route must be a slug
			die("$translated_route (translation of $translation_id in $target_lc) is not a slug while it should")
				unless ($translated_route =~ /[A-Za-z-]+/);
			# We assume that a specific translated route maps to a single text id, regardless of language
			# That means that two different text ids should not have the same translated route in different languages
			# This is done because in routing, we match the route against a hash of routes that is not language specific
			if (    (defined $texts_translated_route_to_text_id{$translated_route})
				and ($texts_translated_route_to_text_id{$translated_route} ne $text_id))
			{
				die(      "Already got "
						. $texts_translated_route_to_text_id{$translated_route}
						. " for $translated_route while trying to insert $text_id - lc: $target_lc - translation_id: $translation_id"
				);
			}
			$texts_translated_route_to_text_id{$translated_route} = $text_id;
			$texts_text_id_to_translated_route{$text_id}{$target_lc} = $translated_route;
		}
	}
	return;
}

# Load the texts from the /lang directory

# The /lang directory is not present in the openfoodfacts-server repository,
# it needs to be copied from the openfoodfacts-web repository.

# If the /lang directory does not exist, a minimal number of texts needed to run Product Opener
# are loaded from /lang_default directory

# Called from load_routes() in ProductOpener::Routing.pm

%texts = ();

$lang_dir = $BASE_DIRS{LANG};

if (not -e $lang_dir) {
	$lang_dir = "$BASE_DIRS{LANG}-default";
	$log->warn(
		"The $BASE_DIRS{LANG} directory does not exist. It should be copied from the openfoodfacts-web repository. Using default texts from $lang_dir"
	) if $log->is_warn();
}

sub load_texts_from_lang_directory () {

	# only load if not already done
	return 1 if (%texts);

	# Check both $lang_dir + flavor specific directory

	foreach my $dir ($lang_dir, "$lang_dir/$flavor") {

		if (opendir DH2, $dir) {

			$log->info("Reading texts from $lang_dir") if $log->is_info();

			foreach my $langid (readdir(DH2)) {
				next if $langid eq '.';
				next if $langid eq '..';
				#$log->trace("reading texts", { lang => $langid }) if $log->is_trace();
				next if ((length($langid) ne 2) and not($langid eq 'other'));

				if (-e "$dir/$langid/texts") {
					opendir DH, "$dir/$langid/texts" or die "Couldn't open $dir/$langid/texts: $!";
					foreach my $textid (readdir(DH)) {
						next if $textid eq '.';
						next if $textid eq '..';
						my $file = $textid;
						$textid =~ s/(\.foundation)?(\.$langid)?\.html//;
						defined $texts{$textid} or $texts{$textid} = {};
						# prefer the .foundation version
						if (   (not defined $texts{$textid}{$langid})
							or (length($file) > length($texts{$textid}{$langid})))
						{
							$texts{$textid}{$langid} = $file;
						}

						#$log->trace("text loaded", { langid => $langid, textid => $textid }) if $log->is_trace();
					}
					closedir(DH);
				}
			}
			closedir(DH2);
		}
	}
	if (scalar keys %texts == 0) {
		$log->error("Texts could not be loaded.") if $log->is_error();
		die("Texts could not be loaded from $BASE_DIRS{LANG} or $BASE_DIRS{LANG}-default");
	}
	return;
}

=head2 normalize ($string)

Normalize a string by removing HTML tags, comments, scripts, and extra spaces.

=cut

sub normalize ($string) {

	# Remove comments
	$string =~ s/(<|\&lt;)!--(.*?)--(>|\&gt;)//sg;
	$string =~ s/<style(.*?)<\/style>//sg;
	# Remove scripts
	$string =~ s/<script(.*?)<\/script>//isg;

	# Remove open comments
	$string =~ s/(<|\&lt;)!--(.*)//sg;

	# Add line feeds instead of </p> and </div> etc.
	$string =~ s/<\/(p|div|span|blockquote)>/\n\n/ig;
	$string =~ s/<\/(li|ul|ol)>/\n/ig;
	$string =~ s/<br( \/)?>/\n/ig;

	# Remove "<= blabla" on recettessimples.fr
	$string =~ s/<=//g;

	# Remove tags
	$string =~ s/<(([^>]|\n)*)>//g;

	$string =~ s/&nbsp;/ /g;
	$string =~ s/&#160;/ /g;

	$string =~ s/\s+/ /g;

	return $string;
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
