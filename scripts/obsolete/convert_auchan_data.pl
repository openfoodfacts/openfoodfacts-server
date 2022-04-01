#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use Log::Any '$log';
use Log::Any::Adapter 'Stderr';

#use Log::Log4perl;
#Log::Log4perl->init("log.conf");
#use Log::Any::Adapter;
#Log::Any::Adapter->set('Log4perl');

use ProductOpener::ImportConvert qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Time::Local;
use XML::Rules;



# Warning some Auchan XML files are broken with 2 <TabNutXMLPF>.*</TabNutXMLPF>

# command to fix them by removing the second one:

# find . -name "*.xml" -type f -exec sed -i 's/<\/TabNutXMLPF><TabNutXMLPF>.*/<\/TabNutXMLPF>/g' {} \;



%global_params = (
	lc => 'fr',
#	countries => "France",	# -> will be assigned based on which language fields are present
	brands => "Auchan",
	stores => "Auchan",
);

my @files = get_list_of_files(@ARGV);

my $xml_errors = 0;

# to count the different nutrients
my %nutrients = ();



foreach my $file (@files) {

	my $code = undef;

	# CSV file with categories, to be loaded after the XML files

	# Product data XML files
	# spec_405692_Barre céréalière boules choco lait ATR_8228-Auchan_11105.xml
	
	if ($file =~ /spec(.*).xml/) {

		$code = $2;
		print STDERR "File $file - Code: $code\n";
	}
	else {
		# print STDERR "Skipping file $file: unrecognized file name format\n";
		next;
	}

	print STDERR "Reading file $file\n";

	if ($file =~ /spec/) {
		# General info about the product, ingredients
		
		#use Data::Dump;
		#Data::Dump::dump( XML::Rules::inferRulesFromExample($file) ); 
		#exit();

		my @xml_rules = (

#_default => sub {$_[0] => $_[1]->{_content}},
_default => "as is",
OspDataFlow => "pass no content",
OspDataFlowHeader => undef,
Document => "pass no content",
Content => "pass no content",
#Generalites => "pass no content",
# TextFrameLinePF => sub { '%fields' => [$_[1]->{code_champs} => \%{$_[1]} ]},
#TextFrameLinePF => sub { '%fields' => [$_[1]->{code_champs} => $_[1]->{languages} ]},
#Languages => "pass no content",
#LanguagePF => sub { '%languages' => [$_[1]->{language_name} => $_[1]->{Content}]},

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

# TabNutColElement => sub { '%nutrients' => [$_[1]->{Type_Code} => $_[1]->{Units}  ]},

"Generalites" => "pass no content",
"IdentificationGeneralites" => "pass no content",
"TradeItems" => "pass no content",
"TradeItem" => sub { '%codes' => [$_[1]->{Gtin} => $_[1]]},


#"PortionValeur" => sub { '%valeurs' => [$_[1]->{ValeurNutritionnelReferantId}{_content} => $_[1]]},
"Portion" => sub { '%portions' => [$_[1]->{PortionLabelId} => $_[1]]},
"PortionValeur" => sub { '%valeurs' => [$_[1]->{ValeurNutritionnelReferantId}{_content} => ($_[1]->{SpecificationValeurRounded}{_content} ? $_[1]->{SpecificationValeurRounded}{_content} : $_[1]->{SpecificationValeur}{_content} )]},

"PortionLabelId" => "content",

"PortionVitamineMineraux" => sub { '%portions' => [$_[1]->{PortionLabelId} => $_[1]]},
"PortionVitamineMinerauxValeur" => sub { '%valeurs' => [$_[1]->{ReferantId}{_content} => ($_[1]->{SpecificationValeurRounded}{_content} ? $_[1]->{SpecificationValeurRounded}{_content} : $_[1]->{SpecificationValeur}{_content} ) ]},

"Etiquette" => sub { '%etiquettes' => [$_[1]->{name} => $_[1]]},



"ProduitFini_Caracteristiques" => undef,
"Echantillon" => undef,
"NutrionnelAnimaux" => undef,
"Allegations" => undef,
"EtiquetteComment" => undef,
"ValidationState" => undef,
"CommentsForEcologicalSorting" => undef,
"ConditionnementConcerne" => undef,
"LogoNePasJeterVoiePublique" => undef,
"NumeroDeLotExpression" => undef,
"PlansDeControle" => undef,

AdresseInformationsConsommateurs => "content",
AvantOuverture => "content",
ApresOuverture => "content",
PoidsNetUnite => "content",
PoidsNetValeur => "content",
PoidsNetEgouteUnite => "content",
PoidsNetEgouteValeur => "content",

"GeneraliteMotifRevision" => undef,
"Acheteur" => undef,
"GeneralitesFournisseur" => undef,
"SitesDeFab" => undef,
"DP_ListeAnnOblig" => undef,


"Properties" => undef,
"Signatures" => undef,
"VersionHistory" => undef,
"MatierePremiere" => undef,
"Composition" => undef,
"Conservation" => undef,

"ConditionnemenEmballages" => undef,

ProductClassifications => "pass no content",


Etiquetages => "pass no content",

GeneralitesEtiquetages => "pass no content",

DenominationCommerciale => "content",
DenominationLegale => "content",
Ingredients => "content",

localId => undef,
NumeroDeLotLocalisation => undef,
DlcDluoExpression => undef,
MentionsLogosCertificationTiercePartie => undef,

"ProcessDeFabrication" => undef,
"PlansDeControles" => undef,
"Tracabilite" => undef,
"Logistique" => undef,
"GeneralitesFtReferencesCommerciale" => undef,
"Sections" => undef,
"Annexes" => undef,

CodeEmballeurLocalisation => "content",
PointVertLogoEcoEmballageFrance => "content",
PointVertLogoEcoEmballageFrance => "content",
VolumeNetUnite => "content",
PoidsVariable => "content",
DenominationCommerciale => "content",
DenominationLegale => "content",
AutreInformationsConsommateurs => "content",
AutresMentionsObligatoires => "content",
FormulationExactEMetrologiqueEmballage => "content",
TemperatureConservationEmplacement => "content",
SectionEtiquetage => "content",
VolumeNetValeur => "content",
VolumeNetUnite => "content",
ContenanceValeur => "content",
ContenanceUnite => "content",
PoidsNetValeur => "content",
PoidsNetUnite => "content",
PoidsMinValeur => "content",
PoidsMinUnite => "content",
PoidsMaxValeur => "content",
PoidsMaxUnite => "content",
PoidsNetEgouteValeur => "content",
PoidsNetEgouteUnite => "content",
PoidsMinEgouteValeur => "content",
PoidsMinEgouteUnite => "content",
PoidsMaxEgouteValeur => "content",
PoidsMaxEgouteUnite => "content",
TitreAlcoolmetriqueVolumiqueValeur => "content",
TitreAlcoolmetriqueVolumiqueUnite => "content",
ConseilsPreparation => "pass no content",
Conseils => "content",

DatePeremption => undef,
EMetrologique => undef,
DlcDluoFormuleLegale => undef,
DlcDluoLocalisation => undef,

PointVertLogoEcoEmballageFrance => "content",

SignalEcoAmbalaje => "content",
SignalTriman => "content",
conditionneSousAtmosphereProtectrice => "content",
Label => "content",
Nutriscore => "content",
Sector => "content",
Family => "content",
EstampilleSanitaireLocalisation => "content",
 
ValidationState => undef,
ApplicationA => undef, 

UpdateDate => undef,


);



		my @xml_fields_mapping = (

			# special field mapping for XML file with multiple products

#<ProductFolder Name="Auchan Cremes Dessert Autres Parfums"/>
#-<TradeItems>
#<TradeItem Ean7="" Gtin="3596710402274" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT spÃ©culoos 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710402281" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT baba au rhum 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710406074" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT PISTACHE 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710402250" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT chocolat caramel 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710402267" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREME DESSERT chocolat blanc 4X125G"/>
#<TradeItem Ean7="" Gtin="3596710016495" Brand="AUCHAN" Packing="" Format="" DenominationCommerciale="CREM DESS CAFE 4X125G"/>
#</TradeItems>
# ...
#+<Etiquette localId="347348" name="Crème Dessert Café Auchan x4">
#-<Etiquette localId="347381" name="Crème Dessert Chocolat Caramel Auchan x4">
#<SectionEtiquetage>Crème Dessert Chocolat Caramel Auchan x4</SectionEtiquetage>
#<ConditionnementConcerne>Chocolat Caramel x 4</ConditionnementConcerne>
#<DenominationCommerciale>Crème dessert Caram'choc</DenominationCommerciale>
#<DenominationLegale>Crème dessert aromatisée caramel chocolat</DenominationLegale>

			[ "multiple_codes", {
				codes => "codes",   # all sub fields will be moved to the root of the split children
				fuzzy_match => "etiquettes",    # if exists, specify a field that depends on the child
				fuzzy_from => "DenominationCommerciale", # value from "codes" that will be fuzzy matched to find the id for "fuzzy_match" hash
			}],

			["code", "code"],
			["DenominationCommerciale", "TradeItem_DenominationCommerciale"],
			["name", "name"],
			["ProductClassification.FullName", "ProductClassification"],
			["GeneralitesEtiquetage.DenominationCommerciale", "product_name_fr"],
			["GeneralitesEtiquetage.DenominationLegale", "generic_name_fr"],

			["GeneralitesEtiquetage.AvantOuverture", "AvantOuverture"],
			["GeneralitesEtiquetage.ApresOuverture", "ApresOuverture"],
			["GeneralitesEtiquetage.TemperatureConservationEmplacement", "TemperatureConservationEmplacement"],

			["GeneralitesEtiquetage.FormulationExactEMetrologiqueEmballage", "FormulationExactEMetrologiqueEmballage"],
			["GeneralitesEtiquetage.AutreInformationsConsommateurs", "AutreInformationsConsommateurs"],
			["GeneralitesEtiquetage.AutresMentionsObligatoires", "AutresMentionsObligatoires"],
			["GeneralitesEtiquetage.AdresseInformationsConsommateur", "customer_service_fr"],

			["GeneralitesEtiquetage.CodeEmballeurLocalisation", "CodeEmballeurLocalisation"],
			["GeneralitesEtiquetage.EstampilleSanitaireLocalisation", "EstampilleSanitaireLocalisation"],
			["GeneralitesEtiquetage.Conseils", "preparation_fr"],

			["GeneralitesEtiquetage.PoidsNetUnite", "net_weight_unit"],
			["GeneralitesEtiquetage.PoidsNetValeur", "net_weight_value"],
			["GeneralitesEtiquetage.PoidsNetEgouteUnite", "drained_weight_unit"],
			["GeneralitesEtiquetage.PoidsNetEgouteValeur", "drained_weight_value"],
			["GeneralitesEtiquetage.PoidsNetUnite", "net_weight_unit"],
			["GeneralitesEtiquetage.PoidsNetValeur", "net_weight_value"],

			["GeneralitesEtiquetage.Ingredients", "ingredients_text_fr"],


			["LetterNutriscore", "nutriments.nutrition-score-fr-producer"],

			["Nutritionnel.portions.100g.valeurs.EquivalenceSodiumEnSelGrammes", "nutriments.salt_g"],
			["Nutritionnel.portions.100g.valeurs.AcidesGrasOmega3Grammes", "nutriments.omega-3-fat_g"],
			["Nutritionnel.portions.100g.valeurs.AcidesGrasOmega6Grammes", "nutriments.omega-6-fat_g"],
			["Nutritionnel.portions.100g.valeurs.LipidesGrammes", "nutriments.fat_g"],
			["Nutritionnel.portions.100g.valeurs.AcidesGrasSaturesGrammes", "nutriments.saturated-fat_g"],
			["Nutritionnel.portions.100g.valeurs.AcidesGrasPolyInsaturesGrammes", "nutriments.polyunsaturated-fat_g"],
			["Nutritionnel.portions.100g.valeurs.CholesterolMilliGrammes", "nutriments.cholesterol_mg"],
			["Nutritionnel.portions.100g.valeurs.ProteinesGrammes", "nutriments.proteins_g"],
			["Nutritionnel.portions.100g.valeurs.AcidesGrasInsaturesGrammes", "nutriments.unsaturated-fat_g"],
			["Nutritionnel.portions.100g.valeurs.GlucidesGrammes", "nutriments.carbohydrates_g"],
			["Nutritionnel.portions.100g.valeurs.AcidesGrasMonoInsaturesGrammes", "nutriments.nutriments.monounsaturated-fat_g"],
			["Nutritionnel.portions.100g.valeurs.ValeurEnergetiquekJ", "nutriments.energy_kJ"],
			["Nutritionnel.portions.100g.valeurs.AmidonGrammes", "nutriments.starch_g"],
			["Nutritionnel.portions.100g.valeurs.PolyolsGrammes", "nutriments.polyols_g"],
			["Nutritionnel.portions.100g.valeurs.SucresGrammes", "nutriments.sugars_g"],
			["Nutritionnel.portions.100g.valeurs.FibresAlimTotalGrammes", "nutriments.fiber_g"],
			["Nutritionnel.portions.100g.valeurs.AlcoolGrammes", "nutriments.alcohol_g"],

			#["Nutritionnel.portions.100g.valeurs.AcideGrasO3ALA", "nutriments."],
			#["Nutritionnel.portions.100g.valeurs.Erythritol", "nutriments."],
			#["Nutritionnel.portions.100g.valeurs.Salatrim", "nutriments."],
			["Nutritionnel.portions.100g.valeurs.AcidesGrasTransGrammes", "nutriments.trans-fat_g"],
			#["Nutritionnel.portions.100g.valeurs.AcideGrasO3EPADHA", "nutriments."],


			["VitaminesMineraux.portions.100g.valeurs.Vit_B8_(H)_-_Biotine_(µg)_-_AJR_:_50_µg", "nutriments."],
			["VitaminesMineraux.portions.100g.valeurs.Magnésium_(mg)_-_AJR_:_375_mg", "nutriments.magnesium_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Extrait_sec_(g)", "nutriments.drained_extract_g"],
			["VitaminesMineraux.portions.100g.valeurs.Chlorures_(mg)_-_AJR_:_800_mg", "nutriments.chloride_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_B5_-_Acide_pantothénique_(mg)_-_AJR_:_6_mg", "nutriments.pantothenic-acid_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_D_-_Calciférol_(µg)_-_AJR_:_5_µg", "nutriments.vitamin-d_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_C_-_Acide ascorbique_(mg)_-_AJR_:_80_mg", "nutriments.vitaminc-c_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Molybdène_(µg)_-_AJR_:_50_µg", "nutriments.molybdenum_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Manganèse_(mg)_2", "nutriments.manganese_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_E_-_Tocophérol_(mg)_-_AJR_:_12_mg", "nutriments.vitamin-e_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Zinc_(mg)_10", "nutriments.zinc_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Phosphore_(mg)_-_AJR_:_700_mg", "nutriments.phosphorus_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Cuivre_(mg)_1", "nutriments.copper_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Fer_(mg)_-_AJR_:_14_mg", "nutriments.iron_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_B6_-_Pyridoxine_(mg)_-_AJR_:_1,4_mg", "nutriments.vitamin-b6_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Chrome_(µg)_-_AJR_:_40_µg", "nutriments.chromium_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_B12_-_Cobalamine_(µg)_-_AJR_:_2,5_µg", "nutriments.vitamin-b12_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Potassium_(mg)_-_AJR_:_2000 mg", "nutriments.potassium_mg"],
			# ["VitaminesMineraux.portions.100g.valeurs.Sodium_(g)", "nutriments."],
			["VitaminesMineraux.portions.100g.valeurs.Iode_(µg)_-_AJR_:_150_µg", "nutriments.iodine_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_B9_-_Acide_folique_(µg)_-_AJR_:_200_µg", "nutriments.vitamin-b9_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_K_-_Phylloquinone_(µg)_-_AJR_:_75_µg", "nutriments.vitamin-k_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Calcium_(mg)_-_AJR_:_800_mg", "nutriments.calcium_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_B1_-_Thiamine_(mg)_-_AJR_:_1,1_mg", "nutriments.b1_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_A_-_Rétinol_(µg)_-_AJR_:_800_µg", "nutriments.vitamin-a_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_B3_(PP)_-_Niacine_(mg)_-_AJR_:_16_mg", "nutriments.vitamin-pp_mg"],
			["VitaminesMineraux.portions.100g.valeurs.Sélénium_(µg)_-_AJR_:_55_µg", "nutriments.selenium_µg"],
			["VitaminesMineraux.portions.100g.valeurs.Vit_B2_-_Riboflavine_(mg)_-_AJR_:_1,4_mg", "nutriments.vitamin-b2_mg"],

			#["VitaminesMineraux.portions.100g.valeurs.Sodium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Bicarbonates_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Fluor_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Silice_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Potassium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Sulfates_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Chlorures_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Calcium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Magnésium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Nitrates_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100g.valeurs.Résidu_sec_à_180°C_(mg/l)", "nutriments."],


			# 100 ml

			["Nutritionnel.portions.100ml.valeurs.EquivalenceSodiumEnSelGrammes", "nutriments.salt_g"],
			["Nutritionnel.portions.100ml.valeurs.AcidesGrasOmega3Grammes", "nutriments.omega-3-fat_g"],
			["Nutritionnel.portions.100ml.valeurs.AcidesGrasOmega6Grammes", "nutriments.omega-6-fat_g"],
			["Nutritionnel.portions.100ml.valeurs.LipidesGrammes", "nutriments.fat_g"],
			["Nutritionnel.portions.100ml.valeurs.AcidesGrasSaturesGrammes", "nutriments.saturated-fat_g"],
			["Nutritionnel.portions.100ml.valeurs.AcidesGrasPolyInsaturesGrammes", "nutriments.polyunsaturated-fat_g"],
			["Nutritionnel.portions.100ml.valeurs.CholesterolMilliGrammes", "nutriments.cholesterol_mg"],
			["Nutritionnel.portions.100ml.valeurs.ProteinesGrammes", "nutriments.proteins_g"],
			["Nutritionnel.portions.100ml.valeurs.AcidesGrasInsaturesGrammes", "nutriments.unsaturated-fat_g"],
			["Nutritionnel.portions.100ml.valeurs.GlucidesGrammes", "nutriments.carbohydrates_g"],
			["Nutritionnel.portions.100ml.valeurs.AcidesGrasMonoInsaturesGrammes", "nutriments.nutriments.monounsaturated-fat_g"],
			["Nutritionnel.portions.100ml.valeurs.ValeurEnergetiquekJ", "nutriments.energy_kJ"],
			["Nutritionnel.portions.100ml.valeurs.AmidonGrammes", "nutriments.starch_g"],
			["Nutritionnel.portions.100ml.valeurs.PolyolsGrammes", "nutriments.polyols_g"],
			["Nutritionnel.portions.100ml.valeurs.SucresGrammes", "nutriments.sugars_g"],
			["Nutritionnel.portions.100ml.valeurs.FibresAlimTotalGrammes", "nutriments.fiber_g"],
			["Nutritionnel.portions.100ml.valeurs.AlcoolGrammes", "nutriments.alcohol_g"],

			#["Nutritionnel.portions.100ml.valeurs.AcideGrasO3ALA", "nutriments."],
			#["Nutritionnel.portions.100ml.valeurs.Erythritol", "nutriments."],
			#["Nutritionnel.portions.100ml.valeurs.Salatrim", "nutriments."],
			["Nutritionnel.portions.100ml.valeurs.AcidesGrasTransGrammes", "nutriments.trans-fat_g"],
			#["Nutritionnel.portions.100ml.valeurs.AcideGrasO3EPADHA", "nutriments."],


			["VitaminesMineraux.portions.100ml.valeurs.Vit_B8_(H)_-_Biotine_(µg)_-_AJR_:_50_µg", "nutriments."],
			["VitaminesMineraux.portions.100ml.valeurs.Magnésium_(mg)_-_AJR_:_375_mg", "nutriments.magnesium_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Extrait_sec_(g)", "nutriments.drained_extract_g"],
			["VitaminesMineraux.portions.100ml.valeurs.Chlorures_(mg)_-_AJR_:_800_mg", "nutriments.chloride_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_B5_-_Acide_pantothénique_(mg)_-_AJR_:_6_mg", "nutriments.pantothenic-acid_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_D_-_Calciférol_(µg)_-_AJR_:_5_µg", "nutriments.vitamin-d_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_C_-_Acide ascorbique_(mg)_-_AJR_:_80_mg", "nutriments.vitaminc-c_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Molybdène_(µg)_-_AJR_:_50_µg", "nutriments.molybdenum_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Manganèse_(mg)_2", "nutriments.manganese_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_E_-_Tocophérol_(mg)_-_AJR_:_12_mg", "nutriments.vitamin-e_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Zinc_(mg)_10", "nutriments.zinc_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Phosphore_(mg)_-_AJR_:_700_mg", "nutriments.phosphorus_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Cuivre_(mg)_1", "nutriments.copper_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Fer_(mg)_-_AJR_:_14_mg", "nutriments.iron_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_B6_-_Pyridoxine_(mg)_-_AJR_:_1,4_mg", "nutriments.vitamin-b6_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Chrome_(µg)_-_AJR_:_40_µg", "nutriments.chromium_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_B12_-_Cobalamine_(µg)_-_AJR_:_2,5_µg", "nutriments.vitamin-b12_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Potassium_(mg)_-_AJR_:_2000 mg", "nutriments.potassium_mg"],
			# ["VitaminesMineraux.portions.100ml.valeurs.Sodium_(g)", "nutriments."],
			["VitaminesMineraux.portions.100ml.valeurs.Iode_(µg)_-_AJR_:_150_µg", "nutriments.iodine_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_B9_-_Acide_folique_(µg)_-_AJR_:_200_µg", "nutriments.vitamin-b9_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_K_-_Phylloquinone_(µg)_-_AJR_:_75_µg", "nutriments.vitamin-k_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Calcium_(mg)_-_AJR_:_800_mg", "nutriments.calcium_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_B1_-_Thiamine_(mg)_-_AJR_:_1,1_mg", "nutriments.b1_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_A_-_Rétinol_(µg)_-_AJR_:_800_µg", "nutriments.vitamin-a_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_B3_(PP)_-_Niacine_(mg)_-_AJR_:_16_mg", "nutriments.vitamin-pp_mg"],
			["VitaminesMineraux.portions.100ml.valeurs.Sélénium_(µg)_-_AJR_:_55_µg", "nutriments.selenium_µg"],
			["VitaminesMineraux.portions.100ml.valeurs.Vit_B2_-_Riboflavine_(mg)_-_AJR_:_1,4_mg", "nutriments.vitamin-b2_mg"],

			#["VitaminesMineraux.portions.100ml.valeurs.Sodium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Bicarbonates_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Fluor_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Silice_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Potassium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Sulfates_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Chlorures_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Calcium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Magnésium_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Nitrates_(mg/l)", "nutriments."],
			#["VitaminesMineraux.portions.100ml.valeurs.Résidu_sec_à_180°C_(mg/l)", "nutriments."],


			# get the code first

			# don't trust the EAN from the XML file, use the one from the file name instead
			# -> sometimes different
			#["fields.AL_CODE_EAN.*", "code"],


			# we can have multiple files for the same code
			# e.g. butter from Bretagne and from Normandie
			# delete some fields from previously loaded versions

			# ["[delete_except]", "producer|emb_codes|origin|_value|_unit|brands|stores"],
#			["ProductCode", "producer_product_id"],
#			["fields.AL_DENOCOM.*", "product_name_*"],
			#["fields.AL_BENEF_CONS.*", "_*"],
			#["fields.AL_TXT_LIB_FACE.*", "_*"],
			#["fields.AL_SPE_BIO.*", "_*"],
			#["fields.AL_ALCO_VOL.*", "_*"],
			#["fields.AL_PRESENTATION.*", "_*"],
#			["fields.AL_DENOLEGAL.*", "generic_name_*"],
#			["fields.AL_INGREDIENT.*", "ingredients_text_*"],
			#["fields.AL_RUB_ORIGINE.*", "_*"],
			#["fields.AL_NUTRI_N_AR.*", "_*"],
			#["fields.AL_PREPA.*", "_*"],
#			["fields.AL_CONSERV.*", "conservation_conditions_*"],
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





# Special processing for Auchan data (before clean_fields_for_all_products)

$fields{conservation_fr} = 1;
$fields{preparation_fr} = 1;
$fields{other_information_fr} = 1;
push @fields, "conservation_fr";
push @fields, "preparation_fr";
push @fields, "other_information_fr";
	

foreach my $code (sort keys %products) {

	my $product_ref = $products{$code};

	#		["GeneralitesEtiquetage.AvantOuverture", "AvantOuverture"],
	#		["GeneralitesEtiquetage.ApresOuverture", "ApresOuverture"],
	#		["GeneralitesEtiquetage.TemperatureConservationEmplacement", "TemperatureConservationEmplacement"],
	#		["GeneralitesEtiquetage.AutreInformationsConsommateurs", "AutreInformationsConsommateurs"],
	#		["GeneralitesEtiquetage.AutresMentionsObligatoires", "AutresMentionsObligatoires"],
	
	if ((defined $product_ref->{TemperatureConservationEmplacement}) and ($product_ref->{TemperatureConservationEmplacement} ne "")) {
		defined ($product_ref->{conservation_fr}) or $product_ref->{conservation_fr} = "";
		$product_ref->{conservation_fr} .= $product_ref->{TemperatureConservationEmplacement} . "\n";
	}
	if ((defined $product_ref->{AvantOuverture}) and ($product_ref->{AvantOuverture} ne "")) {
		defined ($product_ref->{conservation_fr}) or $product_ref->{conservation_fr} = "";
		if ($product_ref->{AvantOuverture} !~ /avant ouverture/i) {
			$product_ref->{conservation_fr} .= "Avant ouverture : ";
		}
		$product_ref->{conservation_fr} .= $product_ref->{AvantOuverture} . "\n";
	}
	if ((defined $product_ref->{ApresOuverture}) and ($product_ref->{ApresOuverture} ne "")) {
		defined ($product_ref->{conservation_fr}) or $product_ref->{conservation_fr} = "";
		if ($product_ref->{ApresOuverture} !~ /après ouverture/i) {
			$product_ref->{conservation_fr} .= "Après ouverture : ";
		}
		$product_ref->{conservation_fr} .= $product_ref->{ApresOuverture} . "\n";
	}

	if (0) {    # some data not intended for consumers
	if ((defined $product_ref->{AutreInformationsConsommateurs}) and ($product_ref->{AutreInformationsConsommateurs} ne "")) {
		defined ($product_ref->{other_information_fr}) or $product_ref->{other_information_fr} = "";
		$product_ref->{other_information_fr} .= $product_ref->{AutreInformationsConsommateurs} . "\n";
	}
	if ((defined $product_ref->{AutresMentionsObligatoires}) and ($product_ref->{AutresMentionsObligatoires} ne "")) {
		defined ($product_ref->{other_information_fr}) or $product_ref->{other_information_fr} = "";
		$product_ref->{other_information_fr} .= $product_ref->{AutresMentionsObligatoires} . "\n";
	}
	}
	
	if ((defined $product_ref->{AutresMentionsObligatoires}) and ($product_ref->{AutresMentionsObligatoires} ne "")) {
		$product_ref->{AutresMentionsObligatoires} =~ s/Nutriscore(\s?): \w/Nutriscore /;
	}

	if ($product_ref->{product_name_fr} =~ /\bauchan\b/i) {
		$product_ref->{product_name_fr} =~ s/\bauchan\b//ig;
	}
	
	if ($product_ref->{product_name_fr} =~ /\brik et rok\b/i) {
		$product_ref->{product_name_fr} =~ s/\brik et rok\b//ig;
		$product_ref->{brands} .= ", Rik et Rok";
	}
	
	$product_ref->{product_name_fr} =~ s/\r|\n/ /g;
	
	# quantity
	$product_ref->{quantity} = $product_ref->{FormulationExactEMetrologiqueEmballage};
	# en face avant  => 3 mini sachets / 210 g (3 x 70 g)
	# en face arrière => Poids net : 210 g (3x70 g)
	$product_ref->{quantity} =~ s/.*=>//s;    # take the last one
	$product_ref->{quantity} =~ s/^(poids|volume|net|:|\s)+//i;

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


# Special processing for Auchan data (after clean_fields_for_all_products)

foreach my $code (sort keys %products) {

	my $product_ref = $products{$code};

	print STDERR "emb_codes : " . $product_ref->{emb_codes} . "\n";

	# assign_main_language_of_product($product_ref, ['fr','es','it','nl','de','en','ro','pl'], "fr");

	clean_weights($product_ref); # needs the language code

#	assign_countries_for_product($product_ref,
#	{
#		fr => "en:france",
#		es => "en:spain",
#		it => "en:italy",
#		de => "en:germany",
#		ro => "en:romania",
#		pl => "en:poland",
#	}
#	, "en:france");


	# categories from the [Produit] Nomenclature field of the Nomenclature .csv file

	# Conserves de mais -> Mais en conserve
#	if (defined $product_ref->{nomenclature_fr}) {
#		$product_ref->{nomenclature_fr} =~ s/^conserve(s)?( de| d')?(.*)$/$3 en conserve/i;
#		$product_ref->{nomenclature_fr} =~ s/^autre(s) //i;
#	}

	print STDERR "emb_codes : " . $product_ref->{emb_codes} . "\n";

	# Make sure we only have emb codes and not some other text
	if (defined $product_ref->{emb_codes}) {
		# too many letters -> word instead of code
		if ( $product_ref->{emb_codes} =~ /[a-zA-Z]{8}/ ) {
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

#ProductClassification: {
#FullName: "305 - FRAIS LS>125 - CREMERIE>846 - DESSERTS>466 - CREMES DESSERT"

	if (defined $product_ref->{ProductClassification}) {
		$product_ref->{ProductClassification} =~ s/.*\d - //;
	}
	
	match_taxonomy_tags($product_ref, "ProductClassification", "categories",
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
	match_taxonomy_tags($product_ref, "AutreInformationsConsommateurs", "labels",
	{
		split => ',|\/|\r|\n|\+|:|;|\b(logo|picto|pictogramme|encart|à apposer|)\b',
		# stopwords =>
	}
	);

	match_taxonomy_tags($product_ref, "AutresMentionsObligatoires", "labels",
	{
		split => ',|\/|\r|\n|\+|:|;|\b(logo|picto|pictogramme|encart|à apposer|)\b',
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

	match_taxonomy_tags($product_ref, "CodeEmballeurLocalisation", "emb_codes",
	{
		split => ',|( \/ )|\r|\n|\+|:|;|=|\(|\)|\b(et|par|pour|ou|sur|au)\b',
		# stopwords =>
	}
	);
	
	match_taxonomy_tags($product_ref, "EstampilleSanitaireLocalisation", "emb_codes",
	{
		split => ',|( \/ )|\r|\n|\+|:|;|=|\(|\)|\b(et|par|pour|ou|sur|au)\b',
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
