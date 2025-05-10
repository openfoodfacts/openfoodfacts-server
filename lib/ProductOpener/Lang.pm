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

=head1 NAME

ProductOpener::Lang - load and return translations

=head1 SYNOPSIS

C<ProductOpener::Lang> loads translations from .po files and return translated strings
through the lang() and lang_sprintf() functions.

=head1 DESCRIPTION



=cut

package ProductOpener::Lang;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		$lc

		%tag_type_singular
		%tag_type_from_singular
		%tag_type_plural
		%tag_type_from_plural
		%Lang
		%Langs
		@Langs

		&lang
		&f_lang
		&f_lang_in_lc
		&lang_in_other_lc
		%lang_lc

		&separator_before_colon

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;
use ProductOpener::I18N;
use ProductOpener::Store qw/get_string_id_for_lang retrieve/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;

use DateTime;
use DateTime::Locale;
use Encode;
use JSON::MaybeXS;

use Log::Any qw($log);

# Default values for $lc
$lc = "en";

=head1 FUNCTIONS

=head2 separator_before_colon( $l )

=head3 Arguments

=head4 language code $l

In some languages like French, colons have a space before them.
e.g. "Valeur : 500" in French, "Value: 500" in English

This function returns a non-breaking space character for those languages.

=cut

sub separator_before_colon ($l) {

	if ($l eq 'fr') {
		return "\N{U+00A0}";
	}
	else {
		return '';
	}
}

=head2 lang( $stringid )

Returns a translation for a specific string id in the language defined in the $lc global variable.

If a translation is not available, the function returns English.

=head3 Arguments

=head4 string id $stringid

In the .po translation files, we use the msgctxt field for the string id.

=cut

sub lang ($stringid) {
	return lang_in_other_lc($lc, $stringid);
}

=head2 f_lang( $stringid, $variables_ref )

Returns a translation for a specific string id with specific arguments
in the language defined in the $lc global variable.

The translation is stored using Python's f-string format with
named parameters between { }.

e.g. "This is a string with {a_variable} and {another_variable}."

Variables between { } are interpolated with the corresponding entry
in the $variables_ref hash reference.

If a translation is not available, the function returns English.

=head3 Arguments

=head4 string id $stringid

In the .po translation files, we use the msgctxt field for the string id.

=head4 variables hash reference $variables_ref

Reference to a hash that contains values for the variables that will be replaced.

=cut

sub f_lang ($stringid, $variables_ref) {

	return f_lang_in_lc($lc, $stringid, $variables_ref);
}

=head2 f_lang_in_lc ( $target_lc, $stringid, $variables_ref )

Returns a translation for a specific string id with specific arguments
in the language $target_lc.

The translation is stored using Python's f-string format with
named parameters between { }.

e.g. "This is a string with {a_variable} and {another_variable}."

Variables between { } are interpolated with the corresponding entry
in the $variables_ref hash reference.

If a translation is not available, the function returns English.

=head3 Arguments

 =head4 target language $target_lc
 
=head4 string id $stringid

In the .po translation files, we use the msgctxt field for the string id.

=head4 variables hash reference $variables_ref

Reference to a hash that contains values for the variables that will be replaced.

=cut

sub f_lang_in_lc ($target_lc, $stringid, $variables_ref) {

	my $translation = $Lang{$stringid}{$target_lc};
	if (defined $translation) {
		# look for string keys between { } and replace them with the corresponding
		# value in $variables_ref hash reference
		$translation =~ s/\{([^\{\}]+)\}/$variables_ref->{$1}/eg;
		return $translation;
	}
	else {
		return '';
	}
}

=head2 lang_in_other_lc( $target_lc, $stringid )

Returns a translation for a specific string id in a specific language.

If a translation is not available, the function returns English.

=head3 Arguments

=head4 target language code $target_lc

=head4 string id $stringid

In the .po translation files, we use the msgctxt field for the string id.

=cut

sub lang_in_other_lc ($target_lc, $stringid) {

	my $short_l = undef;
	if ($target_lc =~ /_/) {
		$short_l = $`;    # pt_pt
	}

	if (not defined $Lang{$stringid}) {
		return '';
	}
	elsif (defined $Lang{$stringid}{$target_lc}) {
		return $Lang{$stringid}{$target_lc};
	}
	elsif ((defined $short_l) and (defined $Lang{$stringid}{$short_l}) and ($Lang{$stringid}{$short_l} ne '')) {
		return $Lang{$stringid}{$short_l};
	}
	else {
		return '';
	}
}

$log->info("initialize", {data_root => $data_root}) if $log->is_info();

# Load stored %Lang from Lang.sto and Lang_tags.sto

my $path = "$BASE_DIRS{PRIVATE_DATA}/Lang.${server_domain}.sto";
if (-e $path) {

	$log->info("Loading \%Lang", {path => $path}) if $log->is_info();
	my $lang_ref = retrieve($path);
	%Lang = %{$lang_ref};
	$log->info("Loaded \%Lang", {path => $path}) if $log->is_info();

	# Initialize @Langs and $lang_lc
	# any existing key can be used, as %Lang should contain values for all languages for all keys
	my $msgctxt = "add";
	if (not defined $Lang{$msgctxt}) {
		$log->error("Language translation file does not contain the 'add' key, \%Lang will be empty.", {path => $path})
			if $log->is_error();
		die("Language translation file does not contain the 'add' key, \%Lang will be empty.");
	}
	@Langs = sort keys %{$Lang{$msgctxt}};
	%Langs = ();
	%lang_lc = ();
	foreach my $l (@Langs) {
		$lang_lc{$l} = $l;
		$Langs{$l} = $Lang{"language_" . $l}{$l};    # Name of the language in the language itself
	}

	$log->info("Loaded languages", {langs => (scalar @Langs)}) if $log->is_info();
}
else {
	$log->warn("Language translation file does not exist, \%Lang will be empty. Run scripts/build_lang.pm to fix this.",
		{path => $path})
		if $log->is_warn();
}

$path = "$data_root/data/Lang_tags.${server_domain}.sto";
if (-e $path) {

	$log->info("Loading tag types <=> singular and plural translated paths", {path => $path}) if $log->is_info();
	my $tag_type_data_ref = retrieve($path);
	$log->info("Loaded tag types <=> singular and plural translated paths", {path => $path}) if $log->is_info();

	%tag_type_singular = %{$tag_type_data_ref->{tag_type_singular}};
	%tag_type_plural = %{$tag_type_data_ref->{tag_type_plural}};
	%tag_type_from_singular = %{$tag_type_data_ref->{tag_type_from_singular}};
	%tag_type_from_plural = %{$tag_type_data_ref->{tag_type_from_plural}};
}
else {
	$log->warn("Language translation file for tags does not exist. Run scripts/build_lang.pm to fix this.",
		{path => $path})
		if $log->is_warn();
}

# Taxonomies that can have debug, prev, and next versions
# (older feature to generate tags using multiple versions of a taxonomy, currently not used)
my @debug_taxonomies = ("categories", "labels", "additives");

# Build hashes to map a translated tag type (e.g. "catégorie") in singular or plural to the tag type (e.g. "categories")

sub build_lang_tags() {

	# Tags types to path components in URLS: in ascii, lowercase, unaccented,
	# transliterated (in Roman characters)
	#
	# Note: a lot of plurals are currently missing below, commented-out are
	# the singulars that need to be changed to plurals
	my ($tag_type_singular_ref, $tag_type_plural_ref)
		= ProductOpener::I18N::split_tags(ProductOpener::I18N::read_po_files("$data_root/po/tags/"));
	%tag_type_singular = %{$tag_type_singular_ref};
	%tag_type_plural = %{$tag_type_plural_ref};

	foreach my $l (@Langs) {

		my $short_l = undef;
		if ($l =~ /_/) {
			$short_l = $`;    # pt_pt
		}

		foreach my $type (keys %tag_type_singular) {

			if (not defined $tag_type_singular{$type}{$l}) {
				if ((defined $short_l) and (defined $tag_type_singular{$type}{$short_l})) {
					$tag_type_singular{$type}{$l} = $tag_type_singular{$type}{$short_l};
				}
				else {
					$tag_type_singular{$type}{$l} = $tag_type_singular{$type}{en};
				}
			}
		}

		foreach my $type (keys %tag_type_plural) {
			if (not defined $tag_type_plural{$type}{$l}) {
				if ((defined $short_l) and (defined $tag_type_plural{$type}{$short_l})) {
					$tag_type_plural{$type}{$l} = $tag_type_plural{$type}{$short_l};
				}
				else {
					$tag_type_plural{$type}{$l} = $tag_type_plural{$type}{en};
				}
			}
		}

		$tag_type_from_singular{$l} or $tag_type_from_singular{$l} = {};
		$tag_type_from_plural{$l} or $tag_type_from_plural{$l} = {};

		foreach my $type (keys %tag_type_singular) {
			next if $type =~ /^:/;
			$tag_type_from_singular{$l}{$tag_type_singular{$type}{$l}} = $type;
		}

		foreach my $type (keys %tag_type_plural) {
			next if $type =~ /^:/;
			$tag_type_from_plural{$l}{$tag_type_plural{$type}{$l}} = $type;
		}

	}
	return (
		{
			tag_type_singular => \%tag_type_singular,
			tag_type_plural => \%tag_type_plural,
			tag_type_from_singular => \%tag_type_from_singular,
			tag_type_from_plural => \%tag_type_from_plural
		}
	);
}

# initialize languages values:
# - load .po files
# - compute missing values by assigning English values

sub build_lang ($Languages_ref) {
	# $Languages_ref is a hash of languages with translations initialized from the languages taxonomy by Tags.pm
	# Note: all .po files must have a corresponding entry in the languages.txt taxonomy

	# Load the strings from the .po files
	# UI strings, non-Roman characters can be used
	my $path = "$data_root/po/common/";
	$log->info("Loading common \%Lang", {path => $path});
	%Lang = %{ProductOpener::I18N::read_po_files($path)};

	# Load the .pot file
	my %common_keys = %{ProductOpener::I18N::read_pot_file($path . "common.pot")};

	# Initialize %Langs and @Langs and add language names to %Lang

	%Langs = %{$Languages_ref};
	@Langs = sort keys %{$Languages_ref};
	foreach my $l (@Langs) {
		$Lang{"language_" . $l} = $Languages_ref->{$l};
		$Langs{$l} = $Languages_ref->{$l}{$l};    # Name of the language in the language itself
	}

	# Save to file, for debugging and comparing purposes

	# use Data::Dumper::AutoEncode;
	# use Data::Dumper;
	# $Data::Dumper::Sortkeys = 1;
	# if (! -e "$data_root/po") {
	#	mkdir ("$data_root/po", 0755);
	# }
	# open my $fh, ">", "$data_root/po/translations.debug.${server_domain}" or die "can not create $data_root/po/translations.debug.${server_domain} : $!";
	# print $fh "Lang.pm - %Lang\n\n" . eDumper(\%Lang) . "\n";
	# close $fh;

	my $missing_english_translations = 0;

	foreach my $key (sort keys %common_keys) {
		if ((defined $Lang{$key}{en}) and ($Lang{$key}{en} ne '')) {
			foreach my $l (@Langs) {

				my $short_l = undef;
				if ($l =~ /_/) {
					$short_l = $`;    # pt_pt
				}

				if (not defined $Lang{$key}{$l}) {
					if ((defined $short_l) and (defined $Lang{$key}{$short_l})) {
						$Lang{$key}{$l} = $Lang{$key}{$short_l};
					}
					elsif (defined $Lang{$key}{en}) {
						$Lang{$key}{$l} = $Lang{$key}{en};
					}
					else {
						$Lang{$key}{$l} = $Lang{$key}{fr};
					}
				}

				my $tagid = get_string_id_for_lang($l, $Lang{$key}{$l});
			}
		}
		elsif ($key !~ /\__/) {
			$log->error("No English translation for $key") if $log->is_error();
			print STDERR "No English translation for $key\n";
			$missing_english_translations++;
		}
	}

	# Warn if some translations files are not defined in common.pot
	foreach my $key (sort keys %Lang) {
		if (
				(not defined $common_keys{$key})
			and not($key =~ /^__/)
			and (not $key =~ /^language_\w\w/)    # auto-generated language names
			and (not(($key eq "months") or ($key eq "weekdays")))    # auto-generated months and weekdays
			)
		{
			$log->warn("Translation file $key is not defined in common.pot") if $log->is_warn();
			print STDERR "Translation file $key is not defined in common.pot\n";
		}
	}

	if ($missing_english_translations) {
		$log->error("Missing English translations: $missing_english_translations") if $log->is_error();
		die("$missing_english_translations English translations are missing, please fix them in the .po files");
	}

	# Some translations have <<site_name>> in them, replace it with the site name
	my $site_name = $options{site_name};

	foreach my $l (@Langs) {
		foreach my $key (keys %Lang) {
			if (not defined $Lang{$key}{$l}) {
				next;
			}
			$Lang{$key}{$l} =~ s/\<\<site_name\>\>/$site_name/g;
		}
	}

	my $en_locale = DateTime::Locale->load('en');
	my @locale_codes = DateTime::Locale->codes;
	foreach my $l (@Langs) {
		my $locale;
		if (grep {$_ eq $l} @locale_codes) {
			$locale = DateTime::Locale->load($l);
		}
		else {
			$locale = $en_locale;
		}

		my @months = ();
		foreach my $month (1 .. 12) {
			push @months,
				DateTime->new(year => 2000, time_zone => 'UTC', month => $month, locale => $locale)->month_name;
		}

		$Lang{months}{$l} = encode_json(\@months);

		my @weekdays = ();
		foreach my $weekday (0 .. 6) {
			push @weekdays,
				DateTime->new(year => 2000, month => 1, day => (2 + $weekday), time_zone => 'UTC', locale => $locale)
				->day_name;
		}

		$Lang{weekdays}{$l} = encode_json(\@weekdays);
	}

	return;
}    # build_lang

sub build_json {
	$log->info("Building I18N JSON") if $log->is_info();

	my $i18n_root = "$BASE_DIRS{PUBLIC_DATA}/i18n";
	if (!-e $i18n_root) {
		mkdir($i18n_root, 0755) or die("Could not create target directory $i18n_root : $!\n");
	}

	foreach my $l (@Langs) {
		my $target_dir = "$i18n_root/$l";
		ensure_dir_created_or_die($target_dir);

		my $short_l = undef;
		if ($l =~ /_/) {
			$short_l = $`;    # pt_pt
		}

		my %result = ();
		foreach my $s (keys %Lang) {
			my $value;

			if (defined $Lang{$s}{$l}) {
				$value = $Lang{$s}{$l};
			}
			elsif ((defined $short_l) and (defined $Lang{$s}{$short_l}) and ($Lang{$s}{$short_l} ne '')) {
				$value = $Lang{$s}{$short_l};
			}
			elsif ((defined $Lang{$s}{en}) and ($Lang{$s}{en} ne '')) {
				$value = $Lang{$s}{en};
			}

			$result{$s} = $value if $value;
		}

		my $target_file = "$target_dir/lang.json";
		open(my $out, ">:encoding(UTF-8)", $target_file) or die "cannot open $target_file";
		print $out decode("utf8", encode_json(\%result));
		close($out);
	}

	$log->info("I18N JSON completed") if $log->is_info();

	return;
}

1;
