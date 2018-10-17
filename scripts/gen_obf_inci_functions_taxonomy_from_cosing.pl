#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;


use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Text::CSV;

use strict;

binmode(STDOUT, ":encoding(UTF-8)");


# INCI Functions from http://ec.europa.eu/growth/tools-databases/cosing/index.cfm?fuseaction=ref_data.functions

my %functions = (
"ABRASIVE" => "Removes materials from various body surfaces or aids mechanical tooth cleaning or improves gloss",
"ABSORBENT" => "Takes up water- and/or oil-soluble dissolved or finely dispersed substances",
"ANTICAKING" => "Allows free flow of solid particles and thus avoids agglomeration of powdered cosmetics into lumps or hard masses",
"ANTICORROSIVE" => "Prevents corrosion of the packaging",
"ANTIDANDRUFF" => "Helps control dandruff",
"ANTIFOAMING" => "Suppresses foam during manufacturing or reduces the tendency of finished products to generate foam",
"ANTIMICROBIAL" => "Helps control the growth of micro-organisms on the skin",
"ANTIOXIDANT" => "Inhibits reactions promoted by oxygen, thus avoiding oxidation and rancidity",
"ANTIPERSPIRANT" => "Reduces perspiration",
"ANTIPLAQUE" => "Helps protect against plaque",
"ANTISEBORRHOEIC" => "Helps control sebum production",
"ANTISTATIC" => "Reduces static electricity by neutralising electrical charge on a surface",
"ASTRINGENT" => "Contracts the skin",
"BINDING" => "Provides cohesion in cosmetics",
"BLEACHING" => "Lightens the shade of hair or skin",
"BUFFERING" => "Stabilises the pH of cosmetics",
"BULKING" => "Reduces bulk density of cosmetics",
"CHELATING" => "Reacts and forms complexes with metal ions which could affect the stability and/or appearance of cosmetics",
"CLEANSING" => "Helps to keep the body surface clean",
"COSMETIC COLORANT" => "Colours cosmetics and/or imparts colour to the skin and/or its appendages. All colours listed are substances on the positive list of colorants (Annex IV of the Cosmetics Directive)",
"DENATURANT" => "Renders cosmetics unpalatable. Mostly added to cosmetics containing ethyl alcohol",
"DEODORANT" => "Reduces or masks unpleasant body odours",
"DEPILATORY" => "Removes unwanted body hair",
"DETANGLING" => "Reduces or eliminates hair intertwining due to hair surface alteration or damage and, thus, helps combing",
"EMOLLIENT" => "Softens and smooths the skin",
"EMULSIFYING" => "Promotes the formation of intimate mixtures of non-miscible liquids by altering the interfacial tension",
"EMULSION STABILISING" => "Helps the process of emulsification and improves emulsion stability and shelf-life",
"FILM FORMING" => "Produces, upon application, a continuous film on skin, hair or nails",
"FLAVOURING" => "Gives flavour to the cosmetic product",
"FOAM BOOSTING" => "Improves the quality of the foam produced by a system by increasing one or more of the following properties: volume, texture and/or stability",
"FOAMING" => "Traps numerous small bubbles of air or other gas within a small volume of liquid by modifying the surface tension of the liquid",
"GEL FORMING" => "Gives the consistency of a gel (a semi-solid preparation with some elasticity) to a liquid preparation",
"HAIR CONDITIONING" => "Leaves the hair easy to comb, supple, soft and shiny and/or imparts volume, lightness, gloss, etc.",
"HAIR DYEING" => "Colours hair",
"HAIR FIXING" => "Permits physical control of hair style",
"HAIR WAVING OR STRAIGHTENING" => "Modifies the chemical structure of the hair, allowing it to be set in the style required",
"HUMECTANT" => "Holds and retains moisture",
"HYDROTROPE" => "Enhances the solubility of substance which is only slightly soluble in water",
"KERATOLYTIC" => "Helps eliminate the dead cells of the stratum corneum",
"MASKING" => "Reduces or inhibits the basic odour or taste of the product",
"MOISTURISING" => "Increases the water content of the skin and helps keep it soft and smooth",
"NAIL CONDITIONING" => "Improves the cosmetic characteristics of the nail",
"NOT REPORTED" => "NOT REPORTED",
"OPACIFYING" => "Reduces transparency or translucency of cosmetics",
"ORAL CARE" => "Provides cosmetic effects to the oral cavity, e.g. cleansing, deodorising, protecting",
"OXIDISING" => "Changes the chemical nature of another substance by adding oxygen or removing hydrogen",
"PEARLESCENT" => "Imparts a nacreous appearance to cosmetics",
"PERFUMING" => "Used for perfume and aromatic raw materials (Section II)",
"PLASTICISER" => "Softens and makes supple another substance that otherwise could not be easily deformed, spread or worked out",
"PRESERVATIVE" => "Inhibits primarily the development of micro-organisms in cosmetics. All preservatives listed are substances on the positive list of preservatives (Annex VI of the Cosmetics Directive)",
"PROPELLANT" => "Generates pressure in an aerosol pack, expelling contents when the valve is opened. Some liquefied propellants can act as solvents",
"REDUCING" => "Changes the chemical nature of another substance by adding hydrogen or removing oxygen",
"REFATTING" => "Replenishes the lipids of the hair or of the top layers of the skin",
"REFRESHING" => "Imparts a pleasant freshness to the skin",
"SKIN CONDITIONING" => "Maintains the skin in good condition",
"SKIN PROTECTING" => "Helps to avoid harmful effects to the skin from external factors",
"SMOOTHING" => "Seeks to achieve an even skin surface by decreasing roughness or irregularities",
"SOLVENT" => "Dissolves other substances",
"SOOTHING" => "Helps lightening discomfort of the skin or of the scalp",
"STABILISING" => "Improves ingredients or formulation stability and shelf-life",
"SURFACTANT" => "Lowers the surface tension of cosmetics as well as aids the even distribution of the product when used",
"TANNING" => "Darkens the skin with or without exposure to UV",
"TONIC" => "Produces a feeling of well-being on skin and hair",
"UV ABSORBER" => "Protects the cosmetic product from the effects of UV-light",
"UV FILTER" => "Filters certain UV rays in order to protect the skin or the hair from harmful effects of these rays.",
"VISCOSITY CONTROLLING" => "Increases or decreases the viscosity of cosmetics",
)
;

# removed:
#  All UV filters listed are substances on the positive list of UV filters (Annex VII of the Cosmetics Directive)

# read the EU translation memory

my %translations = ();
my %english = ();

if (open (my $IN, "<:encoding(UTF-16)", "$data_root/taxonomies-obf/32006D0257.tmx.txt")) {

	my $english;

	while (<$IN>) {
		
		my $line = $_;
		if ($line =~ /<tuv lang="EN-GB">/) {
		
			$english = <$IN>;
			$english =~ s/<(\/)?seg>//g;
			
			chomp($english);
			$english =~ s/(\s|\r|\n)*$//;
			$english =~ s/^(\s|\r|\n)*//;		
			$english =~ s/(-|_|\s|\r|\n)+/ /g;
			my $english_orig = $english;
			# lowercase and remove ending dot to increase chance of matching
			$english = lc($english);
			$english =~ s/\.$//;
			$translations{$english} = {};
			$english{$english} = $english_orig;
			
		}
		elsif ($line =~ /<tuv lang="(..).*">/) {
		
			my $lang = lc($1);
			my $translation = <$IN>;
			$translation =~ s/<(\/)?seg>//g;
			chomp($translation);
			$translation =~ s/(\s|\r|\n)*$//;
			$translation =~ s/^(\s|\r|\n)*//;
			$translation =~ s/(\s|\r|\n)+/ /g;
			# print "English: $english -- Translation: $lang - $translation\n";			
			$translations{$english}{$lang} = $translation;
		}

	}
	close $IN;
}
else {
	print STDERR "Could not open $data_root/taxonomies-obf/32006D0257.tmx.txt\n";
	exit;
}



foreach my $function (sort keys %functions) {

	my $name = ucfirst(lc($function));
	$name =~ s/\buv\b/UV/ig;
	
	print "en: $name\n";

	my $english = lc($name);
	$english =~ s/(\s|\r|\n)*$//;
	$english =~ s/^(\s|\r|\n)*//;
	$english =~ s/(-|_|\s|\r|\n)+/ /g;
	$english =~ s/\.$//;
	if (defined $translations{$english}) {
		foreach my $lang (sort keys %{$translations{$english}}) {
			$name = ucfirst(lc($translations{$english}{$lang}));
			$name =~ s/\buv\b/UV/ig;
			print $lang . ": " . $name . "\n";
		}
	}

		my $description = "";
	
		$english = lc($functions{$function});
		$english =~ s/(\s|\r|\n)*$//;
		$english =~ s/^(\s|\r|\n)*//;
		$english =~ s/(-|_|\s|\r|\n)+/ /g;
		$english =~ s/\.$//;
		
		print "description:en: " . $english{$english} . "\n";
			
		if (defined $translations{$english}) {
			foreach my $lang (sort keys %{$translations{$english}}) {
				$description = $translations{$english}{$lang};
				
				# the EU translation memory is buggy and sometime the name of another function appears at the start or the end, always in all caps.
				
				$description =~ s/[[:upper:]][[:upper:]][[:upper:]]([[:upper:]]|-| )*//;
				
				$description =~ s/\buv\b/UV/ig;
				
				$description =~ s/(\s|\r|\n)+/ /g;
				
				
				
				print "description:" . $lang . ": " . $description . "\n";
			}
		}			

		print "\n";
}



exit(0);

