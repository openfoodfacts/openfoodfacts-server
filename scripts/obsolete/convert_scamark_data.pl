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

use ProductOpener::ImportConvert qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Time::Local;
use XML::Rules;

use Log::Any '$log';
use Log::Any::Adapter 'Stderr';
use Log::Any::Adapter 'Stdout';

use Log::Log4perl ();
use Log::Log4perl::Level ();
 
Log::Log4perl->easy_init(Log::Log4perl::Level::to_priority( 'TRACE' ));
Log::Any::Adapter->set('Log4perl'); # Send all logs to Log::Log4perl


%global_params = (
	lc => 'fr',
	countries => "France",
#	brands => "Carrefour",
	stores => "Leclerc",
);

my @files = get_list_of_files(@ARGV);

my $xml_errors = 0;

# to count the different nutrients
my %nutrients = ();

foreach my $file (@files) {

	my $code = undef;

	print STDERR "Reading file $file\n";

	if ($file =~ /\.xml/) {
	
		#use XML::Rules;
		#use Data::Dump;
		#print Data::Dump::dump(XML::Rules::inferRulesFromExample($file));
		#exit;
	
	
		# General info about the product, ingredients

		my @xml_rules = (

_default => sub {$_[0] => $_[1]},
"REFERENTIEL_SCAMARK_OPENFOODFACTS:FLUX_OPENFOODFACTS_PRODUIT" => "pass",
PRODUITS => "pass",
PRDT => "as array",
#GEN => "content",
#RISK => "content",
ADO => "as array",

#        <NUTRIS>
#          <NUTRI TYPE_NUTRI="100 g">
#            <CNUT LIB="Energie (kJoules)" VAL="538" UNT="kJ" />

NUTRIS => "pass",
NUTRI => sub { '%per' => [$_[1]->{TYPE_NUTRI} => $_[1]->{nutrients} ] },
#CNUT => "as array",
CNUT => sub { '%nutrients' => [$_[1]->{LIB} => {value => $_[1]->{VAL}, unit => $_[1]->{UNT}}  ]},

MOD => "content",
#COMP => "content",

#        <ALL>
#          <INGAD ALL="MOLLUSQUE" TYPE_ALL="Recette" />
#          <INGAD ALL="COQUE" TYPE_ALL="Traces" />

ALL => "pass",
INGAD => sub { '%allergens' => [$_[1]->{ALL} => ($_[1]->{TYPE_ALL} eq "Recette" ? "allergen" : "traces")  ]},

#         <LABEL NOM="BIO AB" TYPE_LABEL="Label_Produit" />

LABEL =>  sub { 'label' => $_[1]->{NOM} },

TabNutXMLPF => "pass no content",
TabNutColElements => "pass no content",
#TextFrameLinesPF => "pass no content",
#TextFrameLinePF => sub { '%fields' => [$_[1]->{code_champs} => $_[1]->{languages} ]},
TabNutColElement => sub { '%nutrients' => [$_[1]->{Type_Code} => $_[1]->{Units}  ]},
Units => "pass no content",
Unit => sub { '@Units' => $_[1]},

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

			# multiple products in one xml file, split it

			[ "multiple_products", "PRDT" ], # split products in the PRDT array

			["GEN.GENCOD", "code"],
			["GEN.MARQUE", "brands"],
			["ADO.[max:ADO].LIB2", "product_name_fr"],
			["ADO.[max:ADO].COMP.ING", "ingredients_text_fr"],

			["ADO.[max:ADO].allergens.*", "value_as_target_and_source_as_value"],

			["ADO.[max:ADO].label", "labels"],

			["ADO.[max:ADO].MOD", "preparation_fr"],
			["ADO.[max:ADO].POIDS", "net_weight_value"],
			["ADO.[max:ADO].UNITE_POIDS", "net_weight_unit"],
			["ADO.[max:ADO].PORTION", "serving_size_value"],
			["ADO.[max:ADO].UNITE_POIDS", "serving_size_unit"],
			["ADO.[max:ADO].NOMBREPORTION", "number_of_servings"],
			["ADO.[max:ADO].CAT_NUTRI_SCORE", "CAT_NUTRI_SCORE"],


			["ADO.[max:ADO].per.100 g.Energie (kJoules).value", "nutriments.energy_value"],
			["ADO.[max:ADO].per.100 g.Energie (kJoules).unit", "nutriments.energy_unit"],
			["ADO.[max:ADO].per.100 g.Matières grasses.value", "nutriments.fat_value"],
			["ADO.[max:ADO].per.100 g.Matières grasses.unit", "nutriments.fat_unit"],
			["ADO.[max:ADO].per.100 g.dont Acides gras saturés.value", "nutriments.saturated-fat_value"],
			["ADO.[max:ADO].per.100 g.dont Acides gras saturés.unit", "nutriments.saturated-fat_unit"],
			["ADO.[max:ADO].per.100 g.Glucides.value", "nutriments.carbohydrates_value"],
			["ADO.[max:ADO].per.100 g.Glucides.unit", "nutriments.carbohydrates_unit"],
			["ADO.[max:ADO].per.100 g.dont Sucres.value", "nutriments.sugars_value"],
			["ADO.[max:ADO].per.100 g.dont Sucres.unit", "nutriments.sugars_unit"],
			["ADO.[max:ADO].per.100 g.Fibres alimentaires.value", "nutriments.fiber_value"],
			["ADO.[max:ADO].per.100 g.Fibres alimentaires.unit", "nutriments.fiber_unit"],
			["ADO.[max:ADO].per.100 g.Protéines.value", "nutriments.proteins_value"],
			["ADO.[max:ADO].per.100 g.Protéines.unit", "nutriments.proteins_unit"],
			["ADO.[max:ADO].per.100 g.Sel.value", "nutriments.salt_value"],
			["ADO.[max:ADO].per.100 g.Sel.unit", "nutriments.salt_unit"],

			["ADO.[max:ADO].per.100 ml.Energie (kJoules).value", "nutriments.energy_value"],
			["ADO.[max:ADO].per.100 ml.Energie (kJoules).unit", "nutriments.energy_unit"],
			["ADO.[max:ADO].per.100 ml.Matières grasses.value", "nutriments.fat_value"],
			["ADO.[max:ADO].per.100 ml.Matières grasses.unit", "nutriments.fat_unit"],
			["ADO.[max:ADO].per.100 ml.dont Acides gras saturés.value", "nutriments.saturated-fat_value"],
			["ADO.[max:ADO].per.100 ml.dont Acides gras saturés.unit", "nutriments.saturated-fat_unit"],
			["ADO.[max:ADO].per.100 ml.Glucides.value", "nutriments.carbohydrates_value"],
			["ADO.[max:ADO].per.100 ml.Glucides.unit", "nutriments.carbohydrates_unit"],
			["ADO.[max:ADO].per.100 ml.dont Sucres.value", "nutriments.sugars_value"],
			["ADO.[max:ADO].per.100 ml.dont Sucres.unit", "nutriments.sugars_unit"],
			["ADO.[max:ADO].per.100 ml.Fibres alimentaires.value", "nutriments.fiber_value"],
			["ADO.[max:ADO].per.100 ml.Fibres alimentaires.unit", "nutriments.fiber_unit"],
			["ADO.[max:ADO].per.100 ml.Protéines.value", "nutriments.proteins_value"],
			["ADO.[max:ADO].per.100 ml.Protéines.unit", "nutriments.proteins_unit"],
			["ADO.[max:ADO].per.100 ml.Sel.value", "nutriments.salt_value"],
			["ADO.[max:ADO].per.100 ml.Sel.unit", "nutriments.salt_unit"],

			["ADO.[max:ADO].SCORING.TX_FL", "nutriments.fruits-vegetables-nuts_g"],
			["ADO.[max:ADO].SCORING.ORDRE", "nutrition_grade_fr_producer"],


			#["ProductCode", "producer_product_id"],
			#["fields.AL_DENOCOM.*", "product_name_*"],
			#["fields.AL_BENEF_CONS.*", "_*"],
			#["fields.AL_TXT_LIB_FACE.*", "_*"],
			#["fields.AL_SPE_BIO.*", "_*"],
			#["fields.AL_ALCO_VOL.*", "_*"],
			#["fields.AL_PRESENTATION.*", "_*"],
			#["fields.AL_DENOLEGAL.*", "generic_name_*"],
			#["fields.AL_INGREDIENT.*", "ingredients_text_*"],
			#["fields.AL_RUB_ORIGINE.*", "_*"],
			#["fields.AL_NUTRI_N_AR.*", "_*"],
			#["fields.AL_PREPA.*", "_*"],
			#["fields.AL_CONSERV.*", "conservation_conditions_*"],
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

			#["fields.AL_POIDS_NET.*", "net_weight"],
			#["fields.AL_POIDS_EGOUTTE.*", "drained_weight"],
			#["fields.AL_POIDS_TOTAL.*", "total_weight"],
			#["fields.AL_CONTENANCE.*", "volume"],

			#["fields.AL_RUB_ORIGINE.*", "origin_*"],

			#["fields.AL_ADRESSFRN.*", "producer_*"],

			#["fields.AL_EST_SANITAIRE.*", "emb_codes"],

			#["fields.AL_PAVE_SC.*", "customer_service_*"],

			#["fields.AL_PREPA.*", "preparation_*"],
			#["fields.AL_PRECAUTION.*", "warning_*"],
			#["fields.AL_IDEE_RECET.*", "recipe_idea_*"],

			#["fields.AL_TXT_LIB_REG.*", "other_information_*"],
			#["fields.AL_TXT_LIB_FACE.*", "other_information_*"],
			#["fields.AL_TXT_LIB_DOS.*", "other_information_*"],
			#["fields.AL_BENEF_CONS.*", "other_information_*"],
			#["fields.AL_OTHER_INFORMATION.*", "other_information_*"],

			#["fields.AL_SPE_BIO.*", "spe_bio_*"],

			#["fields.AL_BENEF_CONS.*", "benef_cons_*"],
			#["fields.AL_TXT_LIB_FACE.*", "txt_lib_face_*"],
			#["fields.AL_ALCO_VOL.*", "alco_vol_*"],
			#["fields.AL_PRESENTATION.*", "presentation_*"],

			#["fields.AL_NUTRI_N_AR.*", "nutri_n_ar_*"],

			#["fields.AL_LOGO_ECO.*", "logo_eco_*"],



			#["fields.AL_INFO_EMB.*", "info_emb_*"],


			#["fields.AL_TXT_LIB_DOS.*", "txt_lib_dos_*"],
			#["fields.AL_INFO_CONSERV.*", "info_conserv_*"],



		);

		$xml_errors += load_xml_file($file, \@xml_rules, \@xml_fields_mapping, undef);
	}

}





# Special processing for Leclerc data (before clean_fields_for_all_products)

my @non_food_brands = (
"ELEMBAL",
"MAMISON",
"MOTS D'ENFANTS",
"CLAIR",
"BIEN AIR",
"BIONAÏA",
"CARESSE",
"CARRE HOMME",
"CHORYS",
"DENTAMYL",
"DOULYS",
"EPSIL",
"HYPERDOU",
"INELL",
"INSECTIVOR",
"IROISE",
"MANAVA",
"LYCAT",
"LYDOG",
"MIMOSA",
"NATEIS",
"PETIT DENTAMYL",
"PETIT MANAVA",
"PLUG'IN",
"PRIMOPLAST",
"SANS MARQUE MR",
"SILEX",
"SILISS",
"SYPHON",
"TEXIL",
"TOUS MES AMIS",
"UNI VERT",
"VISIOR",
"VITANOVE",
"XEOR",
);

my %non_food_brands = ();
foreach my $brand (@non_food_brands) {
	$non_food_brands{$brand} = 1;
}

my %brands = (

"5 LAGER" => "5 Lager",
"ABBAYE ALVERINGEM" => "Abbaye Alveringem",
"ADRIEN CHAMPAUD" => "Adrien Champaud",
"ALIX DE FAURE" => "Alix de Faure",
"ANTOINE BARRIER" => "Antoine Barrier",
"AUGUSTE MUGNIOT" => "Auguste Mugniot",
"AUTOUR DU DESSERT" => "Autour du Dessert",
"BELLES SAISONS" => "Belles Saisons",
"BIEN AIR" => "Bien Air",
"BIONAÏA" => "Bionaïa",
"BIO VILLAGE" => "Bio Village",
"BLAZER" => "Blazer",
"BOLIANE" => "Boliane",
"BRIGHTON'S" => "Brighton's",
"BRIN DE JOUR" => "Brin de Jour",
"BRITLEY" => "Britley's",
"CANTANIS" => "Cantanis",
"CHAQ. JR S/ GLUTEN" => "Chaque Jour Sans Gluten",
"CHANTEGRIL" => "Chantegril",
"CHANTET BLANET" => "Chantet Blanet",
"CHAQUE JOUR REDUIT EN LACTOSE" => "Chaque Jour Réduit en Lactose",
"CHIANTI" => "Chianti",
"COMPTOIR DU GRAIN" => "Comptoir du Grain",
"CONFISEO" => "Confiseo",
"COPAINS COPINES" => "Copains Copines",
"COTE CROC" => "Côté Croc",
"COTE SNACK" => "Côté Snack",
"COULEURS VIVES" => "Couleurs Vives",
"DAY BREAK" => "Day Break",
"DELI DEL'O" => "Déli Del'o",
"DESQUILES" => "Desquiles",
"DIANE D'ARRIA" => "Diane d'Arria",
"DUC DE BORZAC" => "Duc de Borzac",
"EAUX MR" => "Eaux Mr",
"EDULCOREL" => "Edulcorel",
"ENTR'AIDE" => "Entr'Aide",
"EPI D'OR" => "Epi d'Or",
"EQUADOR" => "Equador",
"ESKISS" => "Eskiss",
"EXTRA STRONG" => "Extra Strong",
"FALSBOURG" => "Falsbourg",
"FERIAL" => "Férial",
"FÉRIAL" => "Férial",
"FESTALIE" => "Festalie",
"FRESH TEA" => "Fresh Tea",
"FRUCCI" => "Frucci",
"FRUCCI SODA" => "Frucci Soda",
"FRUISTAR" => "Fruistar",
"GIBUS" => "Gibus",
"GREGOIRE XI" => "Grégoire XI",
"HILBORG" => "Hilborg",
"JEAN'S" => "Jean's",
"JOHN DAVON'S" => "John Davon's",
"LAGOA COCKTAIL" => "Lagoa Cocktail",
"LAQUEUILLE" => "Laqueuille",
"LES CARACTERES" => "Les Caractères",
"LES CROISES" => "Les Croisés",
"LOELLA" => "Loella",
"MAITRE COQUILLE" => "Maitre Coquille",
"MAMIE DOUCEUR" => "Mamie Douceur",
"MANZELLA" => "Manzella",
"MARQUES DEL DOMINIO" => "Maques del Dominio",
"MENU FRAICHEUR" => "Menu Fraîcheur",
"NAT&VIE" => "Nat&Vie",
"NEW'R" => "New'R",
"NID D'ABEILLE" => "Nid d'Abeille",
"NOVOTNA" => "Novotna",
"NUSTIKAO" => "Nustikao",
"OEUFS DE NOS REGIONS" => "Oeufs de Nos Régions",
"O'FRESH" => "O'Fresh",
"PAUSE FRAICHEUR" => "Pause Fraîcheur",
"PIC EXPRESS" => "Pic'Express",
"PIC'EXPRESS" => "Pic'Express",
"PIERRE DE CHAUMEYRAC" => "Pierre de Chaumeyrac",
"PRIEUR BARSANNE" => "Prieur Barsanne",
"PULP ORANGE" => "Pulp Orange",
"REBMANN" => "Rebmann",
"RECOLTONS L'AVENIR" => "Récoltons l'avenir",
"REGAL SOUPE" => "Régal Soupe",
"RIVES ET TERRASSES" => "Rives et Terrasses",
"RONDE DES MERS" => "Ronde des Mers",
"SAINT AZAY" => "Saint-Azay",
"SAINT-AZAY" => "Saint-Azay",
"SAINT CHARMIN" => "Saint Charmin",
"SAINT DIERY" => "Saint Diery",
"SIDI YOUSSOUF" => "Sidi Youssouf",
"SMICY" => "Smicy",
"SPRINK'S" => "Sprink's",
"TABLES DU MONDE" => "Tables du Monde",
"TABLETTE D'OR" => "Tablette d'Or",
"TABLIER BLANC" => "Tablier Blanc",
"TERRASSES D'AUTAN" => "Terrasses d'Autan",
"TERRES OCREES" => "Terres Ocrées",
"TEVA" => "Teva",
"TISEA" => "Tisea",
"TOKAPI" => "Tokapi",
"TRADILEGE" => "Tradilège",
"TRADILEGE." => "Tradilège",
"TRADILÈGE" => "Tradilège",
"TRIUM" => "Trium",
"TROFIC" => "Trofic",
"TURINI" => "Turini",
"VIEUX CARION" => "Vieux Carion",
"VOLANDRY" => "Volandry",
"VOLTANO" => "Voltano",
"WHIST CLUB" => "Whist Club",
"X-TENSE" => "X-Tense",
"YENLI" => "Yenli",
"ZAPATA" => "Zapata",
"BAIRD'S" => "Baird's",
"BON CHOCO" => "Bon Choco",
"COTE TABLE" => "Côté Table",
"DELISSE" => "Délisse",
"DORRAO" => "Dorrao",
"DOUCEUR DU VERGER" => "Douceur du Verger",
"GUILLAUME D'ARRIA" => "Guillaume d'Arria",
"JAFADEN" => "Jafaden",
"LAGOA" => "Lagoa",
"LES GOELLERIES" => "Les Goelleries",
"NOTRE JARDIN" => "Notre Jardin",
"PECHE OCEAN" => "Pêche Océan",
"PLANTATION" => "Plantation",
"POL CARSON" => "Pol Carson",
"POM'LISSE" => "Pom'Lisse",
"P'TIT DELI" => "P'tit Déli",
"RUSTICA" => "Rustica",
"VIVALIS" => "Vivalis",

);

foreach my $code (sort keys %products) {
	
	my $product_ref = $products{$code};
	

	
	assign_quantity_from_field($product_ref, "product_name_fr");
	
	# Some products have 0 in the serving size field
	#       <ADO LIB="HACHIS PARMENTIER SURGELE" LIB2="Hachis parmentier - 1 kg" ADO="02" SECT_OQALI="Plats cuisines surgeles" CAT_NUTRI_SCORE="Autres" POIDS="1000.000" UNITE_POIDS="G" PORTION="0" NOMBREPORTION="">

	if ((defined $product_ref->{serving_size_value}) and ($product_ref->{serving_size_value} == 0)) {
	
		delete $product_ref->{serving_size_value};
		delete $product_ref->{serving_size_unit};
	}
	
	if (defined $product_ref->{product_name_fr}) {
	
		$product_ref->{product_name_fr} =~ s/\(?\s*(facultatif|non affiché|non étiqueté)\s*\)?\s*//i;
	}
	
	if ((defined $product_ref->{brands}) and (defined $non_food_brands{$product_ref->{brands}})) {
		delete $products{$code};
	}
	elsif (defined $brands{$product_ref->{brands}}) {
		$product_ref->{brands} = "Marque Repère, " . $brands{$product_ref->{brands}};
	}
	
	$product_ref->{allergens} =~ s/COQUE/FRUITS A COQUE/i;
	
	$product_ref->{traces} =~ s/COQUE/FRUITS A COQUE/i;
	
}


# Clean and normalize fields

clean_fields_for_all_products();


# Special processing for Carrefour data (after clean_fields_for_all_products)

foreach my $code (sort keys %products) {

	my $product_ref = $products{$code};
	
	

	clean_weights($product_ref); # needs the language code


	# also try the product name
	match_taxonomy_tags($product_ref, "product_name_fr", "categories",
	{
		# split => ',|\/|\r|\n|\+|:|;|\b(logo|picto)\b',
		# stopwords =>
	}
	);


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
