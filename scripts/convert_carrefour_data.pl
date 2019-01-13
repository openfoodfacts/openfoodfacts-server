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

use strict;
use utf8;

binmode(STDOUT, ":encoding(UTF-8)");

use ProductOpener::Import qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Time::Local;
use XML::Rules;



my @files = get_list_of_files(@ARGV);

my $xml_errors = 0;

foreach my $file (@files) {

	my $code = undef;
	
	if ($file =~ /(\d+)_(\d+)_(\w+).xml/) {
	
		$code = $2;
		print STDERR "File $file - Code: $code\n";
	}
	else {
		print STDERR "Skipping file $file: unrecognized file name format\n";
		next;
	}

	print STDERR "Reading file $file\n";
	
	if ($file =~ /_text/) {
		# General info about the product, ingredients
		
		my @xml_rules = (
		
_default => sub {$_[0] => $_[1]->{_content}},
TextFramesXMLPF => "pass no content",
TextFrameXMLPF => "pass no content",		
TextFrameLinesPF => "pass no content",				
# TextFrameLinePF => sub { '%fields' => [$_[1]->{code_champs} => \%{$_[1]} ]},
TextFrameLinePF => sub { '%fields' => [$_[1]->{code_champs} => $_[1]->{languages} ]},
Languages => "pass no content",				
LanguagePF => sub { '%languages' => [$_[1]->{language_name} => $_[1]->{Content}]},

#"b" => sub { $_[0] => "<b>" . $_[1]->{_content} . "</b>"},
#"u" => sub { $_[0] => "<u>" . $_[1]->{_content} . "</u>"},
#"em" => sub { $_[0] => "<em>" . $_[1]->{_content} . "</em>"},

"b" => "==bcontent",
"u" => sub { return '<u>' . $_[1]->{_content} . '</u>' },
"em" => "pass",

"br" => "==<br />",


lOrder => undef,
SetOrder => undef,
SetCode => undef,
SetName => undef,
Comments => undef,
ModifiedBy => undef,
TextFrameLineId => undef,
F=>undef,

);


		
		my @xml_fields_mapping = (

			# get the code first
			
			["fields.AL_CODE_EAN.*", "code"],
			["ProductCode", "producer_product_id"],	
			["fields.AL_DENOCOM.*", "product_name_*"],			
			#["fields.AL_BENEF_CONS.*", "_*"],
			#["fields.AL_TXT_LIB_FACE.*", "_*"],
			#["fields.AL_SPE_BIO.*", "_*"],
			#["fields.AL_ALCO_VOL.*", "_*"],
			#["fields.AL_PRESENTATION.*", "_*"],
			["fields.AL_DENOLEGAL.*", "generic_name_*"],			
			["fields.AL_INGREDIENT.*", "ingredients_text_*"],
			#["fields.AL_RUB_ORIGINE.*", "_*"],
			#["fields.AL_NUTRI_N_AR.*", "_*"],
			#["fields.AL_PREPA.*", "_*"],
			["fields.AL_CONSERV.*", "conservation_conditions_*"],
			#["fields.AL_PRECAUTION.*", "_*"],
			#["fields.AL_IDEE_RECET.*", "_*"],
			#["fields.AL_LOGO_ECO.*", "_*"],
			#["fields.AL_POIDS_NET.*", "_*"],
			#["fields.AL_POIDS_EGOUTTE.*", "_*"],
			#["fields.AL_CONTENANCE.*", "_*"],
			#["fields.AL_POIDS_TOTAL.*", "_*"],
			#["fields.AL_INFO_EMB.*", "_*"],
			#["fields.AL_PAVE_SC.*", "_*"],
			#["fields.AL_ADRESSFRN.*", "_*"],
			#["fields.AL_EST_SANITAIRE.*", "_*"],
			#["fields.AL_TXT_LIB_DOS.*", "_*"],
			#["fields.AL_TXT_LIB_REG.*", "other_information_*"],
			#["fields.AL_INFO_CONSERV.*", "_*"],
			
			["fields.AL_POIDS_NET.*", "net_weight"],
			["fields.AL_POIDS_EGOUTTE.*", "drained_weight"],
			["fields.AL_POIDS_TOTAL.*", "total_weight"],
			["fields.AL_CONTENANCE.*", "volume"],			
			
			["fields.AL_RUB_ORIGINE.*", "origin_*"],			
			
			["fields.AL_ADRESSFRN.*", "producer_*"],
			
			["fields.AL_EST_SANITAIRE.*", "emb_codes"],			
			
			["fields.AL_PAVE_SC.*", "customer_service_*"],			
			
			["fields.AL_PREPA.*", "preparation_*"],			
			["fields.AL_PRECAUTION.*", "warning_*"],
			["fields.AL_IDEE_RECET.*", "recipe_*"],			
			
			["fields.AL_TXT_LIB_REG.*", "other_information_*"],
			["fields.AL_TXT_LIB_FACE.*", "other_information_*"],
			["fields.AL_TXT_LIB_DOS.*", "other_information_*"],
			["fields.AL_BENEF_CONS.*", "other_information_*"],
			["fields.AL_OTHER_INFORMATION.*", "other_information_*"],
			
			["fields.AL_SPE_BIO.*", "spe_bio_*"],		
			
			["fields.AL_BENEF_CONS.*", "benef_cons_*"],
			["fields.AL_TXT_LIB_FACE.*", "txt_lib_face_*"],
			["fields.AL_ALCO_VOL.*", "alco_vol_*"],
			["fields.AL_PRESENTATION.*", "presentation_*"],			

			["fields.AL_NUTRI_N_AR.*", "nutri_n_ar_*"],

			["fields.AL_LOGO_ECO.*", "logo_eco_*"],

			

			["fields.AL_INFO_EMB.*", "info_emb_*"],


			["fields.AL_TXT_LIB_DOS.*", "txt_lib_dos_*"],
			["fields.AL_INFO_CONSERV.*", "info_conserv_*"],			
		);		
	
		$xml_errors += load_xml_file($file, \@xml_rules, \@xml_fields_mapping, undef);
	}
	
	
	elsif ($file =~ /_valNut/) {
		# Nutrition facts
		
		my @xml_rules = (
		
_default => sub {$_[0] => $_[1]->{_content}},
TabNutXMLPF => "pass no content",
TabNutColElements => "pass no content",		
#TextFrameLinesPF => "pass no content",				
#TextFrameLinePF => sub { '%fields' => [$_[1]->{code_champs} => $_[1]->{languages} ]},
TabNutColElement => sub { '%nutrients' => [$_[1]->{Type_Code} => $_[1]->{Units}  ]},
Units => "pass no content",				
Unit => sub { '@Units' => $_[1]},

"ARPercent,Description,Id,Label,Language,ModifiedBy,Name,ProductCode,RoundValue,TabNutCadrans,TabNutId,TabNutName,TabNutTemplateCode,TypeCode,Unit_value,lOrder,name" => "content",
#"LanguageTB,TabNutColElements,TabNutPhrases,TabNutXMLPF,Units,languages" => "no content",
  #"TabNutColElement,TabNutPhrase,Unit" => "as array no content",


lOrder => undef,
SetOrder => undef,
SetCode => undef,
SetName => undef,
Comments => undef,
ModifiedBy => undef,
TextFrameLineId => undef,
F=>undef,

);


		
		my @xml_fields_mapping = (

			# get the code first
			
			["fields.AL_CODE_EAN.*", "code"],
			["ProductCode", "producer_product_id"],	

			["fields.AL_INFO_CONSERV.*", "info_conserv_*"],			
		);		
	
	# To get the rules:	
	
	#use XML::Rules;
	#use Data::Dump;
	#print Data::Dump::dump(XML::Rules::inferRulesFromExample($file));
	
	
		$xml_errors += load_xml_file($file, \@xml_rules, \@xml_fields_mapping, undef);
	}	
}


# Special processing for Carrefour data

foreach my $code (sort keys %products) {

	if (defined $products{$code}{spe_bio_fr}) {
	
		$products{$code}{spe_bio_fr} =~ s/ / /;
	
	}
}


clean_fields_for_all_products();

print_csv_file();

print_stats();

print STDERR "$xml_errors xml errors\n";
