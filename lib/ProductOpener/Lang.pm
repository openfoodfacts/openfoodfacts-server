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


					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::I18N;
use ProductOpener::SiteLang qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;


print STDERR "data_root: $data_root\n";

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




# initialize languages values:
# - compute tag_type_singular and tag_type_plural
# - compute missing values by assigning English values

sub init_languages($) {

	my $recompute = shift;
	
	# At this point, @Langs contains all the language codes (initialized from countries taxonomy by Tags.pm)
	# init_languages may already have been called once with $recompute == 0 from Tags.pm,
	# and it can called a 2nd time with $recompute == 1 by recompute_lang.pm
	
	# Load the strings from the .po files
	# UI strings, non-Roman characters can be used
	print STDERR "Load %Lang from $data_root/po/common/\n";
	%Lang = %{ ProductOpener::I18N::read_po_files("$data_root/po/common/") };	

	my @debug_taxonomies = ("categories", "labels", "additives");

	foreach my $taxonomy (@debug_taxonomies) {

		foreach my $suffix ("prev", "next", "debug") {
		
			foreach my $field ("", "_s", "_p") {
				$Lang{$taxonomy . "_$suffix" . $field } = { en => get_fileid($taxonomy) . "-$suffix" };
				print STDERR " Lang{ " . $taxonomy . "_$suffix" . $field  . "} = { en => " . get_fileid($taxonomy) . "-$suffix } \n";
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
				# print "tag_type_from_plural{$l}{$tag_type_plural{$type}{$l}} = $type;\n";
		}

	}

	if ((-e "$data_root/Lang.${server_domain}.sto") and (not $recompute)) {

		print STDERR "Loading \%Lang from $data_root/Lang.${server_domain}.sto\n";
		my $lang_ref = retrieve("$data_root/Lang.${server_domain}.sto");
		%Lang = %{$lang_ref};
		print STDERR "Loaded \%Lang from $data_root/Lang.${server_domain}.sto\n";
		
	}
	else {

		print STDERR "Recomputing \%Lang\n";


		# Load overrides from %SiteLang

		print "SiteLang - overrides \n";


		foreach my $key (keys %SiteLang) {
			print "SiteLang{$key} \n";

			$Lang{$key} = {};
			foreach my $l (keys %{$SiteLang{$key}}) {
				$Lang{$key}{$l} = $SiteLang{$key}{$l};
				print "SiteLang{$key}{$l} \n";
			}
		}
		
		
		# Save to file, for debugging and comparing purposes
	
		use Data::Dumper::AutoEncode;
		use Data::Dumper;
		$Data::Dumper::Sortkeys = 1;
		open my $fh, ">", "$data_root/po/translations.debug.${server_domain}" or die "can not create $data_root/po/translations.debug.${server_domain} : $!";
		print $fh "Lang.pm - %Lang\n\n" . eDumper(\%Lang) . "\n";
		close $fh;		


		foreach my $l (@Langs) {
			$CanonicalLang{$l} = {};	 # To map 'a-completer' to 'A compléter',
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

					$CanonicalLang{$l}{$tagid} = $Lang{$key}{$l};
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
					if (not defined ($Lang{$key}{$l})) {
						next;
					}
					
					$Lang{$key}{$l} =~ s/\<\<$special_field\>\>/$value/g;
				}
			}

		}
		
		# use $server_domain in part of the name so that we have different files
		# when 2 instances of Product Opener share the same $data_root
		# as is the case with world.openfoodfacts.org and world.preprod.openfoodfacts.org
		store("$data_root/Lang.${server_domain}.sto",\%Lang);
		
}

} # init_languages


1;
