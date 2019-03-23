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
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::Import qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Time::Local;
use XML::Rules;

use Log::Any::Adapter ('Stderr');

# Warning some Carrefour XML files are broken with 2 <TabNutXMLPF>.*</TabNutXMLPF>

# command to fix them by removing the second one:

# find . -name "*.xml" -type f -exec sed -i 's/<\/TabNutXMLPF><TabNutXMLPF>.*/<\/TabNutXMLPF>/g' {} \;



$lc = 'fr';

%global_params = (
	lc => 'fr',
#	countries => "France",	# -> will be assigned based on which language fields are present
	brands => "Carrefour",
	stores => "Carrefour",
);

my @files = get_list_of_files(@ARGV);

my $xml_errors = 0;

# to count the different nutrients
my %nutrients = ();

foreach my $file (@files) {

	my $code = undef;

	# CSV file with categories, to be loaded after the XML files

	if ($file =~ /nomenclature(.*).csv/i) {

		my @csv_fields_mapping = (

["[Produit] EAN", "code"],
["[Produit] Nomenclature", "nomenclature_fr"],

);

		load_csv_file({ file => $file, encoding => "UTF-8", separator => "\t", skip_non_existing_products => 1, csv_fields_mapping => \@csv_fields_mapping});
	}

	# Product data XML files

	elsif ($file =~ /(\d+)_(\d+)_(\w+).xml/) {

		$code = $2;
		print STDERR "File $file - Code: $code\n";
	}
	else {
		# print STDERR "Skipping file $file: unrecognized file name format\n";
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

#"b" => "pass",
#"strong" => "pass",
"b" => sub { return '<b>' . $_[1]->{_content} . '</b>' },
"strong" => sub { return '<strong>' . $_[1]->{_content} . '</strong>' },
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

			# don't trust the EAN from the XML file, use the one from the file name instead
			# -> sometimes different
			#["fields.AL_CODE_EAN.*", "code"],

			# we can have multiple files for the same code
			# e.g. butter from Bretagne and from Normandie
			# delete some fields from previously loaded versions

			["[delete_except]", "producer|emb_codes|origin|_value|_unit|brands|stores"],

			["fields.AL_CODE_EAN.*", "code_in_xml"],

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
			["fields.AL_IDEE_RECET.*", "recipe_idea_*"],

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

			# don't trust the EAN from the XML file, use the one from the file name instead
			# -> sometimes different
			#["fields.AL_CODE_EAN.*", "code"],

			["ProductCode", "producer_product_id"],

			["nutrients.ENERKJ.[0].RoundValue", "nutriments.energy_kJ"],
			["nutrients.FAT.[0].RoundValue", "nutriments.fat_g"],
			["nutrients.FASAT.[0].RoundValue", "nutriments.saturated-fat_g"],
			["nutrients.CHOAVL.[0].RoundValue", "nutriments.carbohydrates_g"],
			["nutrients.SUGAR.[0].RoundValue", "nutriments.sugars_g"],
			["nutrients.FIBTG.[0].RoundValue", "nutriments.fiber_g"],
			["nutrients.PRO.[0].RoundValue", "nutriments.proteins_g"],
			["nutrients.SALTEQ.[0].RoundValue", "nutriments.salt_g"],


# unsure about units / values (lots of 0s)
# disabling:

			["nutrients.FAMSCIS.[0].RoundValue", "nutriments.monounsaturated-fat-disabled_g"],
			["nutrients.FAPUCIS.[0].RoundValue", "nutriments.polyunsaturated-fat-disabled_g"],
			["nutrients.POLYL.[0].RoundValue", "nutriments.polyols-disabled_g"],
			["nutrients.STARCH.[0].RoundValue", "nutriments.starch-disabled_g"],
			["nutrients.ACL.[0].RoundValue", "nutriments.alcohol-disabled_g"],
			["nutrients.CHO.[0].RoundValue", "nutriments.cholesterol-disabled_g"],
			["nutrients.AGO.[0].RoundValue", "nutriments.omega-3-fat-disabled_g"],
			["nutrients.LACS.[0].RoundValue", "nutriments.lactose-disabled_g"],

# vitamin C:
#<Unit>
#<Name>ml</Name>
#<Id>ML</Id>
#<Unit_value>100,00</Unit_value>
#<Description>millilitre</Description>
#<RoundValue>12</RoundValue>
#<ARPercent>15</ARPercent>
#</Unit>

			["nutrients.VITA.[0].RoundValue", "nutriments.vitamin-a-disabled_g"],
			["nutrients.VITC.[0].RoundValue", "nutriments.vitamin-c-disabled_g"],
			["nutrients.VITD.[0].RoundValue", "nutriments.vitamin-d-disabled_g"],
			["nutrients.VITE.[0].RoundValue", "nutriments.vitamin-e-disabled_g"],
			["nutrients.K.[0].RoundValue", "nutriments.potassium-disabled_g"],
			["nutrients.ZN.[0].RoundValue", "nutriments.zinc-disabled_g"],
			["nutrients.BIOT.[0].RoundValue", "nutriments.biotin-disabled_g"],
			["nutrients.MO.[0].RoundValue", "nutriments.molybdenum-disabled_g"],
			["nutrients.MN.[0].RoundValue", "nutriments.manganese-disabled_g"],
			["nutrients.FE.[0].RoundValue", "nutriments.iron-disabled_g"],
			["nutrients.MG.[0].RoundValue", "nutriments.magnesium-disabled_g"],
			["nutrients.P.[0].RoundValue", "nutriments.phosphorus-disabled_g"],
			["nutrients.NIA.[0].RoundValue", "nutriments.vitamin-pp-disabled_g"],
			["nutrients.CU.[0].RoundValue", "nutriments.copper-disabled_g"],
			["nutrients.CR.[0].RoundValue", "nutriments.chromium-disabled_g"],
			["nutrients.VITK.[0].RoundValue", "nutriments.vitamin-k-disabled_g"],
			["nutrients.SE.[0].RoundValue", "nutriments.selenium-disabled_g"],
			["nutrients.ID.[0].RoundValue", "nutriments.iodine-disabled_g"],
			["nutrients.FOLDFE.[0].RoundValue", "nutriments.folates-disabled_g"],
			["nutrients.VITB12.[0].RoundValue", "nutriments.vitamin-b12-disabled_g"],
			["nutrients.PANTAC.[0].RoundValue", "nutriments.pantothenic-acid-disabled_g"],
			["nutrients.VITB6.[0].RoundValue", "nutriments.vitamin-b6-disabled_g"],
			["nutrients.RIBF.[0].RoundValue", "nutriments.vitamin-b2-disabled_g"],
			["nutrients.THIA.[0].RoundValue", "nutriments.vitamin-b1-disabled_g"],
			["nutrients.FD.[0].RoundValue", "nutriments.fluoride-disabled_g"],
			["nutrients.CA.[0].RoundValue", "nutriments.calcium-disabled_g"],
			["nutrients.CLD.[0].RoundValue", "nutriments.chloride-disabled_g"],

			# for waters? but present for other products .  by L ?

#<Unit>
#<Name>mg/L</Name>
#<Id>MCL</Id>
#<Unit_value>1,00</Unit_value>
#<Description>milligramme par litre</Description>
#<RoundValue>7,000</RoundValue>
#</Unit>

			["nutrients.CAL.[0].RoundValue", "nutriments.calcium-disabled_mgl"],
			["nutrients.FDL.[0].RoundValue", "nutriments.fluoride-disabled_mgl"],
			["nutrients.FR.[0].RoundValue", "nutriments.fluoride-disabled_mgl"],
			["nutrients.CLDE.[0].RoundValue", "nutriments.chloride-disabled_mgl"],
			["nutrients.BCO.[0].RoundValue", "nutriments.bicarbonates-disabled_mgl"],
			["nutrients.NH.[0].RoundValue", "nutriments.ammonium-disabled_mgl"],
			["nutrients.NAL.[0].RoundValue", "nutriments.sodium-disabled_mgl"],
			["nutrients.SO.[0].RoundValue", "nutriments.sulfates-disabled_mgl"],
			["nutrients.NO.[0].RoundValue", "nutriments.nitrates-disabled_mgl"],
			["nutrients.KL.[0].RoundValue", "nutriments.potassium-disabled_mgl"],
			["nutrients.SIO.[0].RoundValue", "nutriments.silica-disabled_mgl"],
			["nutrients.MGL.[0].RoundValue", "nutriments.magnesium-disabled_mgl"],

			# same thing as bicarbonates ?
			["nutrients.HCO.[0].RoundValue", "nutriments.hydrogenocarbonates-disabled_mgl"],

		);

	# To get the rules:

	#use XML::Rules;
	#use Data::Dump;
	#print Data::Dump::dump(XML::Rules::inferRulesFromExample($file));


		$xml_errors += load_xml_file($file, \@xml_rules, \@xml_fields_mapping, undef);

		open(my $IN, "<:encoding(UTF-8)", $file);
		my $xml = join('', (<$IN>));
		close ($IN);

		while ($xml =~ /Type_Code="(\w+)"/) {
			$nutrients{$1}++;
			$xml = $';
		}
	}
}





# Special processing for Carrefour data (before clean_fields_for_all_products)

foreach my $code (sort keys %products) {

	if (defined $products{$code}{total_weight}) {

		$products{$code}{total_weight} =~ s/(\[emetro\])|(\[zemetro\])/e/ig;

		# + e métrologique
		# (métrologique)
		$products{$code}{total_weight} =~ s/(\+ )?e( ?([\[\(])?(métrologique|metrologique|metro|métro)([\]\)])?)?/e/ig;
		$products{$code}{total_weight} =~ s/(\+ )?( ?([\[\(])?(métrologique|metrologique|metro|métro)([\]\)])?)/e/ig;

		# poids net = poids égoutté = 450 g [zemetro]
		# poids net : 240g (3x80ge)       2
		# poids net égoutté : 150g[zemetro]       2
		# poids net : 320g [zemetro] poids net égoutté : 190g contenance : 370ml  2
		# poids net total : 200g [zemetro] poids net égoutté : 140g contenance 212ml

	}

	if ((defined $products{$code}{emb_codes}) and ($products{$code}{emb_codes} =~ /fabriqu|elabor|conditionn/i)) {

		$products{$code}{producer_fr} = $products{$code}{emb_codes};
		delete $products{$code}{emb_codes};
	}
}


# Clean and normalize fields

clean_fields_for_all_products();


# Special processing for Carrefour data (after clean_fields_for_all_products)

foreach my $code (sort keys %products) {

	my $product_ref = $products{$code};

	print STDERR "emb_codes : " . $product_ref->{emb_codes} . "\n";

	assign_main_language_of_product($product_ref, ['fr','es','it','nl','de','en','ro','pl'], "fr");

	clean_weights($product_ref); # needs the language code

	assign_countries_for_product($product_ref,
	{
		fr => "en:france",
		es => "en:spain",
		it => "en:italy",
		de => "en:germany",
		ro => "en:romania",
		pl => "en:poland",
	}
	, "en:france");


	# categories from the [Produit] Nomenclature field of the Nomenclature .csv file

	# Conserves de mais -> Mais en conserve
	if (defined $product_ref->{nomenclature_fr}) {
		$product_ref->{nomenclature_fr} =~ s/^conserve(s)?( de| d')?(.*)$/$3 en conserve/i;
		$product_ref->{nomenclature_fr} =~ s/^autre(s) //i;
	}

	print STDERR "emb_codes : " . $product_ref->{emb_codes} . "\n";

	# Make sure we only have emb codes and not some other text
	if (defined $product_ref->{emb_codes}) {
		# too many letters -> word instead of code
		if ($product_ref->{emb_codes} =~ /[a-zA-Z]{8}/)	{
			delete $product_ref->{emb_codes};
		}
	}

	print STDERR "emb_codes : " . $product_ref->{emb_codes} . "\n";

	match_taxonomy_tags($product_ref, "nomenclature_fr", "categories",
	{
		# split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		# stopwords =>
	}
	);

	# also try the product name
	match_taxonomy_tags($product_ref, "product_name_fr", "categories",
	{
		# split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		# stopwords =>
	}
	);

	# logo ab
	# logo bio européen : nl-bio-01 agriculture pays bas      1

	# try to parse some fields to find tags
	match_taxonomy_tags($product_ref, "spe_bio_fr", "labels",
	{
		split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		# stopwords =>
	}
	);

	match_taxonomy_tags($product_ref, "other_information_fr", "labels",
	{
		split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		# stopwords =>
	}
	);

	# certifié fsc
	match_taxonomy_tags($product_ref, "info_emb_fr", "labels",
	{
		split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		# stopwords =>
	}
	);


	# Fabriqué en France par EMB 29181 pour Interdis.
	# Fabriqué en France pour EMB 24381 pour Interdis.
	# Elaboré par EMB 14167A pour INTERDIS
	# Fabriqué en France par EMB 29181 (F) ou EMB 86092A (G) pour Interdis.
	# Fabriqué par A = EMB 38080A ou / C = EMB 49058 ou / V = EMB 80120A ou / S = EMB 26124 (voir lettre figurant sur l'étiquette à l'avant du sachet) pour Interdis.

	match_taxonomy_tags($product_ref, "producer_fr", "emb_codes",
	{
		split => ',|( \/ )|\r|\n|\+|:|;|=|\(|\)|\b(et|par|pour|ou)\b',
		# stopwords =>
	}
	);

	print STDERR "emb_codes : " . $product_ref->{emb_codes} . "\n";

#<TextFrameLinePF code_champs="AL_NUTRI_N_AR" F="10">
#<Label>Déclaration nutritionnelle et Apports de référence</Label>
#<Content>
#pH 7,2. Résidu sec à 180°C : 1280 mg/L.
#<br/>
#Eau soumise à une technique d’adsorption autorisée.
#Autorisation ministérielle du 25 août 2003.

}

print_csv_file();

print_stats();

print STDERR "$xml_errors xml errors\n";

foreach my $file (@xml_errors) {
	#print STDERR $file . "\n";
}

foreach my $nutrient (sort { $nutrients{$b} <=> $nutrients{$a} } keys %nutrients) {
	#print STDERR $nutrient . "\t" . $nutrients{$nutrient} . "\n";
}
