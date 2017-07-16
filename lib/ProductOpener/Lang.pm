# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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

package ProductOpener::Lang;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();	# symbols to export by default
	@EXPORT_OK = qw(
					$lang
					$langlang

					$lc
					$lclc

					%tag_type_singular
					%tag_type_from_singular
					%tag_type_plural
					%tag_type_from_plural
					%Lang
					%CanonicalLang
					%Langs
					@Langs

					&lang
					%lang_lc

					&init_languages

					&separator_before_colon

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use ProductOpener::I18N;
use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;


sub separator_before_colon($) {

	my $l = shift;

	if ($l eq 'fr') {
		return "\N{U+00A0}";
	}
	else {
		return '';
	}
}


# same logic can be implemented by creating the missing values for all keys
sub lang($) {

	my $s = shift;

	my $short_l = undef;
	if ($lang =~ /_/) {
		$short_l = $`,  # pt_pt
	}

	if ((defined $langlang) and (defined $Lang{$s}{$langlang})) {
		return $Lang{$s}{$langlang};
	}
	elsif (defined $Lang{$s}{$lang}) {
		return $Lang{$s}{$lang};
	}
	elsif ((defined $short_l) and (defined $Lang{$s}{$short_l}) and ($Lang{$s}{$short_l} ne '')) {
		return $Lang{$s}{$short_l};
	}
	elsif ((defined $Lang{$s}{en}) and ($Lang{$s}{en} ne '')) {
		return $Lang{$s}{en};
	}
	elsif (defined $Lang{$s}{fr}) {
		return $Lang{$s}{fr};
	}
	else {
		return '';
	}
}

print STDERR "Lang.pm - data_root: $data_root\n";

# generate po files from %Lang or %Site_lang
# 18/01/2017: this function is used to generate .po files
# from the translations that are currently in Lang.pm and SiteLang.pm
# going forward, all translations will be in .po files
# can be run like this: perl ProductOpener/Lang.pm

sub generate_po_files($$) {

	my $dir = shift;
	my $lang_ref = shift;
	
	if (! -e "$data_root/po_from_lang") {
		 mkdir("$data_root/po_from_lang", 0755) or die ("cannot create $data_root/po_from_lang");
	}
	if (! -e "$data_root/po_from_lang/$dir") {
		 mkdir("$data_root/po_from_lang/$dir", 0755);
	}	

	my %po = ();
	
	# the English values will be used as the msgid
	# store them so that we can use them for .po files for other languages
	my %en_values = ();
	
	foreach my $key (sort keys %{$lang_ref}) {
	
		my $en = 0;
	
		foreach my $l ("en", keys %{$lang_ref->{$key}}, "pot") {
		
			my $value;

			if ($l eq "pot") {
				$value = "";
			}
			else {
				$value = $lang_ref->{$key}{$l};
			}
			
			# escape \ and "
			$value =~ s/\\/\\\\/g;
			$value =~ s/"/\\"/g;
			# multiline values
			$value =~ s/\n/\\n"\n"/g;
			$value = '"' . $value . '"';
			
			# store the English value
			if (($l eq 'en') and ($en == 0)) {
				$en_values{$key} = $value;
				$en = 1;
				next;
			}
			
			next if $en_values{$key} eq '""'; # only for "sep", will need to get it out of .po and hardcode it somewhere else
			
			$po{$l} .= <<PO
msgctxt "$key"
msgid $en_values{$key}
msgstr $value

PO
;		
		}
	
	}
	
	# Generate .po files for all languages found
	foreach my $l (keys %po) {
	
		open (my $fh, ">:encoding(UTF-8)", "$data_root/po_from_lang/$dir/$l.po");
		
		my $langname = $Lang{"lang_$l"}{en};
		
		not defined $langname and print STDERR "lang_$l not defined\n";

		$po{$l} =~ s/\n$//;
		
		print $fh <<PO
msgid  ""
msgstr ""
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Language: $l\\n"
"Project-Id-Version: \\n"
"PO-Revision-Date: \\n"
"Language-Team: \\n"
"Last-Translator: \\n"

msgctxt ":langtag"
msgid   ":langtag"
msgstr  "$l"

msgctxt ":langname"
msgid   ":langname"
msgstr  "$langname"

$po{$l}
PO
;

		
		close ($fh);
	
	}
	

}

#generate_po_files("common", \%Lang);


# Load stored %Lang from Lang.sto


if (-e "$data_root/Lang.${server_domain}.sto") {

	print STDERR "Loading \%Lang from $data_root/Lang.${server_domain}.sto\n";
	my $lang_ref = retrieve("$data_root/Lang.${server_domain}.sto");
	%Lang = %{$lang_ref};
	print STDERR "Loaded \%Lang from $data_root/Lang.${server_domain}.sto\n";
	
	# Initialize @Langs and $lang_lc
	@Langs = sort keys %{$Lang{site_name}};	# any existing key can be used, as %Lang should contain values for all languages for all keys
	%Langs = ();
	%lang_lc = ();
	foreach my $lc (@Langs) {
		$lang_lc{$lc} = $lc;
		$Langs{$lc} = $Lang{"language_" . $lc}{$lc};	# Name of the language in the language itself
	}
	print STDERR "Loaded " . (scalar @Langs) . " languages.\n";
	sleep(1);
}
else {
	print STDERR "Warning - Lang.pm - $data_root/Lang.${server_domain}.sto does not exist, and %Lang will be empty.\nRun scripts/build_lang.pm\n";
	print STDERR "Sleeping for 5 seconds so that this message is seen.\n\n";
	sleep(5);
}


# Tags types to path components in URLS: in ascii, lowercase, unaccented,
# transliterated (in Roman characters)
#
# Note: a lot of plurals are currently missing below, commented-out are
# the singulars that need to be changed to plurals
my ($tag_type_singular_ref, $tag_type_plural_ref)
    = ProductOpener::I18N::split_tags(
        ProductOpener::I18N::read_po_files("$data_root/po/tags/"));
%tag_type_singular = %$tag_type_singular_ref;
%tag_type_plural   = %$tag_type_plural_ref;


my @debug_taxonomies = ("categories", "labels", "additives");

{

	foreach my $taxonomy (@debug_taxonomies) {

		foreach my $suffix ("prev", "next", "debug") {
		
			foreach my $field ("", "_s", "_p") {
				$Lang{$taxonomy . "_$suffix" . $field } = { en => get_fileid($taxonomy) . "-$suffix" };
			}
			
			$tag_type_singular{$taxonomy . "_$suffix"} = { en => get_fileid($taxonomy) . "-$suffix" };
			$tag_type_plural{$taxonomy . "_$suffix"} = { en => get_fileid($taxonomy) . "-$suffix" };
		}
	}
	
	foreach my $l (@Langs) {

		my $short_l = undef;
		if ($l =~ /_/) {
			$short_l = $`;  # pt_pt
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
				$tag_type_from_singular{$l}{$tag_type_singular{$type}{$l}} = $type;
		}

		foreach my $type (keys %tag_type_plural) {
				$tag_type_from_plural{$l}{$tag_type_plural{$type}{$l}} = $type;
		}

	}	
	
}	
	




# initialize languages values:
# - load .po files
# - compute missing values by assigning English values

sub build_lang($) {

	# Hash of languages with translations initialized from the languages taxonomy by Tags.pm
	my $Languages_ref = shift;	
		
	# Load the strings from the .po files
	# UI strings, non-Roman characters can be used
	print STDERR "Load %Lang from $data_root/po/common/\n";
	%Lang = %{ ProductOpener::I18N::read_po_files("$data_root/po/common/") };	
	
	# Initialize %Langs and @Langs and add language names to %Lang
	
	%Langs = %$Languages_ref;
	@Langs = sort keys %{$Languages_ref};
	foreach my $l (@Langs) {
		$Lang{"language_" . $l} = $Languages_ref->{$l};
		$Langs{$l} = $Languages_ref->{$l}{$l}; # Name of the language in the language itself
	}	
	
	
	# use Data::Dumper::AutoEncode;
	# use Data::Dumper;
	# $Data::Dumper::Sortkeys = 1;
	# open my $fh, ">", "$data_root/po/languages.debug.${server_domain}" or die "can not create $data_root/po/languages.debug.${server_domain} : $!";
	# print $fh "Lang.pm - %Lang\n\n" . eDumper(\%Lang) . "\n";
	# close $fh;		

	# copy strings for debug taxonomies

	foreach my $taxonomy (@debug_taxonomies) {

		foreach my $suffix ("prev", "next", "debug") {
		
			foreach my $field ("", "_s", "_p") {
				$Lang{$taxonomy . "_$suffix" . $field } = { en => get_fileid($taxonomy) . "-$suffix" };
			}
		}
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
    

	# Load site specific overrides
	# the site-specific directory can be a symlink to openfoodfacts or openbeautyfacts
	if (-e "$data_root/po/site-specific/") {
	
		# Load overrides from %SiteLang
		# %SiteLang overrides the general %Lang in Lang.pm

		print STDERR "build_lang() - Load override strings from $data_root/po/site-specific/ \n";
				
		my %SiteLang = %{ ProductOpener::I18N::read_po_files("$data_root/po/site-specific/") };

		foreach my $key (keys %SiteLang) {
			next if $key =~ /^:/;  # :langname, :langtag
			print STDERR "Site specific string: $key\n";

			$Lang{$key} = {};
			foreach my $l (keys %{$SiteLang{$key}}) {
				$Lang{$key}{$l} = $SiteLang{$key}{$l};
			}
		}
	}

	foreach my $key (keys %Lang) {
		if ((defined $Lang{$key}{fr}) or (defined $Lang{$key}{en})) {
			foreach my $l (@Langs) {

				my $short_l = undef;
				if ($l =~ /_/) {
					$short_l = $`,  # pt_pt
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

				my $tagid = get_fileid($Lang{$key}{$l});
			}
		}
	}

	my @special_fields = ("site_name");

	foreach my $special_field (@special_fields) {

		foreach my $l (@Langs) {
			my $value = $Lang{$special_field}{$l};
			if (not (defined $value)) {
				next;
			}

			foreach my $key (keys %Lang) {
				if (not defined $Lang{$key}{$l}) {
					next;
				}	
				$Lang{$key}{$l} =~ s/\<\<$special_field\>\>/$value/g;
			}
		}
	}
} # build_lang


1;
