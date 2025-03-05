#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/get_fileid get_string_id_for_lang/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/$country/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/$User_id/;
use ProductOpener::Images qw/process_image_crop process_image_upload/;
use ProductOpener::Lang qw/$lc lang/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/analyze_and_enrich_product_data init_product retrieve_product store_product/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Units qw/unit_to_g/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::ImportConvert qw/clean_fields extract_nutrition_facts_from_text/;
use ProductOpener::PackagerCodes qw/normalize_packager_codes/;
use ProductOpener::Paths qw/%BASE_DIRS/;

use Log::Any qw($log);
use Log::Any::Adapter 'TAP', filter => "none";

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::MaybeXS;
use Time::Local;
use Data::Dumper;

use Text::CSV;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

# Usage:
# ./convert_systemeu_csv_to_off_csv.pl [input CSV file in Systeme U / AKENEO format] [output CSV file in OFF format]

# Check we have a CSV file passed as argument and that it exists, and that we have an output CSV file name or print usage and exit
if (scalar @ARGV != 2) {
	print STDERR "Usage: $0 [input CSV file in Systeme U / AKENEO format] [output CSV file in OFF format]\n";
	exit 1;
}

my $input_csv_file = $ARGV[0];
my $output_csv_file = $ARGV[1];

my $input_csv = Text::CSV->new({binary => 1, sep_char => ";"})    # should set binary attribute.
	or die "Cannot use CSV: " . Text::CSV->error_diag();

my $output_csv = Text::CSV->new(
	{
		eol => "\n",
		sep => "\t",
		quote_space => 0,
		binary => 1
	}
) or die "Cannot use CSV: " . Text::CSV->error_diag();

$lc = "fr";
$country = "en:france";

# We use a mapping table to convert Systeme U categories to OFF categories when possible
my $categories_csv_file = $BASE_DIRS{SCRIPTS} . "/imports/systemeu/systeme-u-rubriques.csv";

print "converting csv_file: $input_csv_file -- output_csv_file: $output_csv_file\n";

my $i = 0;
my $j = 0;

$lc = 'fr';

my %allergens = (
	'UFS' => 'OEUFS',
	'UF' => 'OEUFS',
	'CACAHU' => 'CACAHUETTE',
	'DISULFITE' => 'SULFITES',
	'DISULFITES' => 'SULFITES',
	'Sulfites et SO2 > 10ppm' => 'SULFITES',
	'Produits laitiers et dérivées' => 'Lait',
	'Céréales contenant du gluten' => 'Gluten',
	'Céréale contenant du gluten' => 'Gluten',
	'CRUSTAC' => 'CRUSTACES',
	'LACTOS' => 'LAIT',
	'LAITI' => 'LAIT',
	'LERI' => 'CELERI',
);
my %allergens_count = ();
my %allergens_codes = ();

my %labels = (
	"MIA-A1" => "Sans colorant",
	"MIA-A2" => "Sans conservateur",
	"MIA-A3" => "Sans arôme artificiel",
	"MIA-A4" => "Aux arômes naturels",
	"MIA-A5" => "Sans aspartame",
	"MIA-A6" => "Sans huile de palme",
	"MIA-A7" => "Sans édulcorant",
	"MIA-A8" => "Sans exhausteur de gout",
	"MIA-A9" => "Sans additif",
	"MIA-A10" => "Colorants naturels",
	"MIA-A11" => "BBC ŒUFS",
	"MIA-A12" => "BBC Porc",
	"MIA-A13" => "BBC Bœuf",
	"MIA-A14" => "BBC VOLAILLE",
	"MIA-A15" => "Nouvelle Agriculture Lapin",
	"MIA-A16" => "BBC Lapin",
	"MIA-A17" => "Nouvelle Agriculture Poulet",
	"MID-D1" => "Sans parabens",
	"MID-D2" => "sans phénoxyéthanol",
	"MID-D3" => "sans sels d'aluminium",
	"MID-D4" => "sans triclosan",
	"MID-D5" => "Sans colorants ",
	"MID-D6" => "Sans huile de palme",
	"MID-D7" => "sans silicone",
	"MID-D8" => "sans colorants azoïques",
	"MID-D9" => "sans nano-particules",
	"MID-D10" => "Sans phosphate",
	"MID-D11" =>
		"Absence de BPA (sur tout produit où la substance n'a pas été interdite à date) - attestation/certificat",
	"MID-D12" => "Absences intentionnelles de substances controverses de PFOA",
	"MID-D13" => "Sans glyphosate",
	"MID-D14" => "95% d'ingrédients d'origine naturelle",
	"ENG-E1" => "Pêche d'une espèce bien gérée",
	"ENG-E2" => "Alimentation sans OGM",
	"ENG-E3" => "Elevage avec une alimentation sans OGM",
	"ENG-E4" => "AGRICONFIANCE",
	"ENG-E5" => "DEMARCHE FLEG METIERS",
	"ENG-E6" => "Viticulture Durable",
	"ENG-E7" => "Blé issu d'une culture maitrisée",
	"ENG-E8" => "Maïs issu d'une culture maitrisée",
	"ENG-E9" => "RSPO MB/BC",
	"ENG-E10" => "RSPO SG",
	"ENG-E11" => "FSC produit",
	"ENG-E12" => "FSC MIXTE produit",
	"ENG-E13" => "DPH concentré",
	"ENG-E14" => "DPH compacte",
	"ENG-E15" => "BBC Porc",
	"ENG-E16" => "BBC Volaille",
	"ENG-E17" => "BBC Viande",
	"ENG-E18" => "BBC Œuf",
	"ENG-E19" => "UTZ",
	"ENG-E20" => "Nouvelle Agriculture",
	"ENG-E21" => "Bioplastique",
	"ENG-E22" => "FSC",
	"ENG-E23" => "Eco conception",
	"ENG-E24" => "Recyclé plastique",
	"ENG-E25" => "Recyclable > 50% ",
	"ENG-E26" => "Recyclable à 100%",
	"ENG-E27" => "Réduction source ",
	"ENG-E28" => "Recyclé hors plastique",
	"ENG-E29" => "Ecorecharge",
	"ENG-E30" => "Compostable",
	"ENG-E31" => "Matière première recyclée",
	"ENG-E32" => "Matière première renouvelable",
	"ENG-E34" => "Dosettes prêt à l'emploi / Emballage adapté au besoin consommateur",
	"ENG-E35" => "Produit rechargeable",
	"ENG-E36" => "Bois issus de forêts  sans risque (Europe du Nord, …) selon analyse de risque définie par TFT.",
	"ENG-E37" => "PEFC produit",
	"ENG-E38" => "Lait BBC",
	"ENG-E39" => "Emballage PEFC",
	"ENG-E40" => "75% de composants issus de ressources renouvelables",
	"ENG-E41" => "BBC Lapin",
	"ENG-E42" => "Sans glyphosate",
	"ENG-E43" => "Produit biodégradable",
	"ENG-E44" => "Sans tourbe",
	"ENG-E45" => "Produit fini non certifié FSC mais FRNS n-2 certifié FSC",
	"ENG-E46" => "Démarche Pommes",
	"MFR-MF1" => "Fabriqué en France",
	"MFR-MF2" => "Conditionné en France",
	"MFR-MF3" => "Cuisiné en France",
	"MFR-MF4" => "Transformé en France",
	# "MFR-MF5" => "Produit fabriqué et/ou transformé par une entreprise Française mais contrat passé avec un fournisseur UE ou non UE.",
	# "MFR-MF5" => "Transformé en France",
	"MFR-MF6" => "Cultivé en France",
	"MFR-MF8" => "Filé en France",
	"MFR-MF9" => "Tissé en France",
	"MFR-MF10" => "Garni en France",
	"MFR-MF11" => "Tricoté en France",
	"MPA-MP1" => "Blé de France",
	"MPA-MP2" => "Lait de France",
	"MPA-MP3" => "Farine de blé français",
	"MPA-MP4" => "Oeufs de France",
	"MPA-MP5" => "Pommes de terre de France",
	"MPA-MP6" => "Légumes de France",
	"MPA-MP7" => "Bœuf origine France",
	"MPA-MP8" => "Volaille Origine France",
	"MPA-MP9" => "Lapin Origine France",
	"MPA-M10" => "Porc origine France",
	"MPA-M11" => "Matière 1erBrut France: légumes",
	"MPA-M12" => "Matière 1erBrut France: fruits",
	"MPA-M13" => "Veau origine France",
	"MPA-M14" => "Mais de France",
	"MPA-M15" => "Fruits de france",
	"MPA-M16" => "Récolté en France",
	"MPA-M17" => "Farine de sarrasin français",
	"MPA-M18" => "Poulet Origine France",
	"MPA-M19" => "Soja de France",
	"MPA-M20" => "Miel de France",
	"MPA-M21" => "Viandes Origine France",
	"MPA-M22" => "Mouton origine France",
	"MPA-M23" => "Pommes de France",
	"LIE-LI1" => "DEMARCHE FLEG METIERS",
	"LIE-LI2" => "Contrat Biolait",
	"LIE-LI3" => "Nouvelle Agriculture",
	"LIE-LI4" => "BITREX",
	"LAB-L1" => "VBF",
	"LAB-L2" => "VPF",
	"LAB-L3" => "VDF",
	"LAB-L4" => "BLEU BLANC CŒUR",
	"LAB-L5" => "FSC PRODUIT",
	"LAB-L6" => "PEFC",
	"LAB-L7" => "FSC EMBALLAGE",
	"LAB-L8" => "RSPO MB",
	"LAB-L9" => "RSPO SG",
	"LAB-L10" => "MAX HAVELAAR",
	"LAB-L11" => "UTZ",
	"LAB-L12" => "ECOLABEL",
	"LAB-L13" => "NF ENVIRONNEMENT",
	"LAB-L14" => "MSC",
	"AOP" => "AOP",
	"AOC" => "AOC",
	"IGP" => "IGP",
	"LRG" => "Label Rouge",
	"FLF" => "Fruits et légumes de France",
);
my %labels_count = ();

my %rubriques_category = ();

open(my $io3, '<:encoding(UTF-8)', $categories_csv_file) or die("Could not open $categories_csv_file: $!");

while (my $line = <$io3>) {

	chomp($line);
	$line =~ /^#/ and next;
	# Convert the tab before the number of products to a space
	$line =~ s/\t(\d+)/ $1/;
	my ($rubriques, $category) = split(/\t/, $line);

	$rubriques =~ s/\s+\d+$//;

	if ((defined $category) and ($category ne "")) {
		$rubriques_category{$rubriques} = $category;
		print STDERR $rubriques . " --> " . $category . "\n";
	}
}

close($io3);

print STDERR "converting products\n";

open(my $io, '<:encoding(UTF-8)', $input_csv_file) or die("Could not open  $input_csv_file: $!");

$input_csv->column_names($input_csv->getline($io));

# sku;UGC_ean;UGC_libEcommerce;UGC_libMarque;UGC_nomGestion;
# UGC_MesureNette;UGC_uniteMesureNette;UGC_Typo;
# UGC_ingredientStatement;ALK_libelleComposition;UGC_allergenStatement;ALK_allergene;ALK_presenceDeContient;
# ALK_presenceDeTraceDe;ALK_presenceDeNeContientPas;UGC_nutritionalValuesPerPackage;UGC_nutritionalValues;
# ALK_valNutritionnelles;SVE_idRubrique;SVE_cdRubriqueN1;SVE_cdRubriqueN2;SVE_cdRubriqueN3

# 100099-3368954000901;3368954000901;"Vinaigre de vin de Xérès U SAVEURS bouteille 25cl";SDSAV;010503250510300505;
# 0.2500;LITRE;MFR-MF4;
# SULFITES;;"A conserver dans un endroit sec, à température ambiante et à l'abri de la lumière.";;;;;;;;0348028402820000;
# "Epicerie salée";Assaisonnement;"Vinaigre et jus de citron"

# We first process all products and store them in memory
# so that we can see which fields are present (in particular which nutrients)
# to output them in the CSV

my @products = ();

# keep track of the number of products in each category, brands etc. to prioritize the creation of mapping tables
my %unknown_categories = ();
my %unverified_categories = ();	# we have a taxonomy match, but it could be incorrect or not specific enough
my %unverified_categories_matches = ();
my %unknown_brands = ();

while (my $imported_product_ref = $input_csv->getline_hr($io)) {

	$i++;

	# SVE_cdRubriqueN1	SVE_cdRubriqueN2	SVE_cdRubriqueN3
	$imported_product_ref->{rubriques}
		= $imported_product_ref->{SVE_cdRubriqueN1} . " - "
		. $imported_product_ref->{SVE_cdRubriqueN2} . " - "
		. $imported_product_ref->{SVE_cdRubriqueN3};

	#print $json;

	my $modified = 0;

	my @modified_fields;
	my @images_ids;

	my $code = $imported_product_ref->{UGC_ean};

	# 253048000000 -> missing leading 0
	if ((length($code) == 12) and ($code =~ /^2/)) {
		$code = "0" . $code;
	}

	if ($code eq '') {
		print STDERR "empty code\n";
		require Data::Dumper;
		print STDERR Data::Dumper::Dumper($imported_product_ref);
		print "EMPTY CODE\n";
		next;
	}

	# We may have images for front / ingredients / nutrition
	# We will need to output their path in the CSV file so that they can be imported by import_csv_file.pl

	print "PRODUCT LINE NUMBER $i - CODE $code\n";

	# $images_ref->{$code}
	# $images_ref->{$code}{front}
	# $images_ref->{$code}{ingredients}
	# $images_ref->{$code}{nutrition}

	print "product $i - code: $code\n";

	my $product_ref = init_product($User_id, "systeme-u", $code, $country);

	# Labels
	my @labels = ();

	foreach my $ugc_typo (split(/,/, $imported_product_ref->{UGC_Typo})) {

		$labels_count{$ugc_typo}++;

		if (defined $labels{$ugc_typo}) {
			push @labels, $labels{$ugc_typo};
		}
	}

	if ($imported_product_ref->{UGC_libEcommerce} =~ /\bBIO\b/i) {
		push @labels, "Bio";
	}

	if (scalar @labels) {
		$product_ref->{labels} = join(", ", @labels);
	}

	print STDERR "labels for product code $code : " . $product_ref->{labels} . "\n";

	if (    (defined $imported_product_ref->{rubriques})
		and ($imported_product_ref->{rubriques} ne "")
		and (defined $rubriques_category{$imported_product_ref->{rubriques}}))
	{
		my $category = $rubriques_category{$imported_product_ref->{rubriques}};
		$category =~ s/^fr://;
		$product_ref->{categories} = $category;
		print "assigning category $category from rubriques $imported_product_ref->{rubriques}\n";
	}
	else {
		# check if the Systeme U categories exist in the OFF categories taxonomy, starting with the most specific
		my @rubriques = split(/ - /, $imported_product_ref->{rubriques});
		foreach my $rubrique (reverse @rubriques) {
			my $exists_in_taxonomy;
			my $category_id = canonicalize_taxonomy_tag("fr", "categories", $rubrique, \$exists_in_taxonomy);
			if ($exists_in_taxonomy) {
				my $category = $rubrique;
				$product_ref->{categories} = $category;
				$unverified_categories{$rubrique}++;
				$unverified_categories_matches{$rubrique} = $category;
				print "assigning category $category_id from rubrique $rubrique ($imported_product_ref->{rubriques})\n";
				last;
			}
		}

		# Keeping track of rubriques that are not mapped to OFF categories
		if (not defined $product_ref->{categories}) {
			$unknown_categories{$imported_product_ref->{rubriques}}++;
		}
	}

	# allergens

	# UGC_allergenStatement
	# A conserver dans un endroit sec, à température ambiante et à l'abri de la lumière.
	# Sulfites et SO2 > 10ppm
	# Céréale contenant du gluten
	# Céréale contenant du gluten
	# Crustacés, Sulfites et SO2 > 10ppm, Mollusques, Lait, Produits laitiers et dérivées, Céréale contenant du gluten
	# AMANDES, CREME, LACTOSE, LAIT, NOISETTES, OEUF, PISTACHES, SULFITES
	# BEURRE, CREME, LAIT, NOISETTE, OEUF, OEUFS
	# CREME, LAIT

	my $allergens_import = "";
	my @allergens = "";

	foreach my $ugc_allergen (split(/,|;/, $imported_product_ref->{UGC_allergenStatement})) {

		$ugc_allergen =~ s/^\s+//;
		$ugc_allergen =~ s/(\.|\s)+$//;

		next if $ugc_allergen eq "FAO";
		next if $ugc_allergen eq "MSC";

		if (defined $allergens{$ugc_allergen}) {
			push @allergens, $allergens{$ugc_allergen};
			print "new known allergen for product code $code : " . $allergens{$ugc_allergen} . "\n";

			$allergens_count{$allergens{$ugc_allergen}}++;
			$allergens_codes{$allergens{$ugc_allergen}} .= "$code ";

		}
		else {
			push @allergens, $ugc_allergen;
			print "new unknown allergen for product code $code : " . $ugc_allergen . "\n";

			$allergens_count{$ugc_allergen}++;
			$allergens_codes{$ugc_allergen} .= "$code ";

		}

	}

	$product_ref->{allergens} = join(", ", @allergens);

	$allergens_import = $product_ref->{allergens};

	print "allergens for product code $code : " . $product_ref->{allergens} . "\n";

	# Vinaigre de vin de Xérès U SAVEURS bouteille 25cl
	# Pur jus de grenade U BIO bocal 75cl
	# Pur jus de tomate salé à 3g/l U BIO bocal 75cl
	# Petits pots vanille/fraise & vanille/chocolat U MAT & LOU, 12 unités,342g
	# Nectar fraise rhubarbe édition limitée U pet 1L
	# Nectar pêche figue édition limitée U pet 1l
	# Bâtonnets vanille U, 10 pièces, 370g
	# Nectar pomme coing édition limitée U pet 1l
	# Nectar prune-cassis édition limitée U pet 1l
	# Rôti de porc cuit au four Viande de Porc Française U 4 tranches 180g

	# DANREMONT	Produit U
	# PRODUIT U	Produit U
	# U SAVEURS	U Saveurs
	# U BIO	U bio
	# U OXYGN	U Oxygn
	# U CUISINES & DECOUVERTES	Produit U
	# U MAT ET LOU	U Mat & Lou
	# NOR U	Produit U
	# U SANS GLUTEN	Produit U
	# U BON ET VEGETARIEN	Produit U
	# U TOUT PETITS	Produit U

	# Gourdes allégée en sucres pomme fraise U MAT&LOU 6x90g

	my $ugc_libecommerce = $imported_product_ref->{UGC_libEcommerce};

	# some products have brand names in UGC_libEcommerce

	# fix typos
	$ugc_libecommerce
		=~ s/(emmental|poire|pasteurisé|sucre|paris|passion|fraise|pomme|banane|bio|grasses|\"|\.|\))U/$1 U/ig;
	$ugc_libecommerce =~ s/(che|noir|\))U/$1 U/g;
	$ugc_libecommerce =~ s/ U(x?\d)/ U $1/ig;
	$ugc_libecommerce =~ s/( )?"( )?U( )?"/ U /ig;
	$ugc_libecommerce =~ s/ u / U /ig;

	$ugc_libecommerce =~ s/\ben(verre|plastique)/en $1/ig;
	$ugc_libecommerce =~ s/(\d)fruit/$1 fruit/i;

	# Bleu à pâte persillée au lait de vache pasteurisé U BIO? 27% de MG? 220g
	# remove ?
	$ugc_libecommerce =~ s/\?//g;

	# 3256225519576
	$ugc_libecommerce =~ s/ RAPAZ,/RAPAZ, U,/;

	#  moutarde de Dijon pot 455gU
	$ugc_libecommerce =~ s/ (pot (\d+))gU/ U $1 g/i;

	# to ease regexp matching
	$ugc_libecommerce =~ s/U(LES| |\.)*SAVEUR(S?)/U_SAVEURS /i;
	$ugc_libecommerce =~ s/U SANS GLUTEN/U_SANS_GLUTEN /i;
	$ugc_libecommerce =~ s/U( |\.)?BIO/ U_BIO /i;
	$ugc_libecommerce =~ s/NOR U/NOR_U /i;
	$ugc_libecommerce =~ s/U?( )?OXYGN/ U_OXYGN /i;
	$ugc_libecommerce =~ s/U?( )?MAT( )?(ET|&)( )?LOU/ U_MAT_ET_LOU /i;
	$ugc_libecommerce =~ s/U?( )?BON( )?(ET|&)( )?VEGETARIEN/ U_BON_ET_VEGETARIEN /i;
	$ugc_libecommerce =~ s/U?( )?CUISINES( )?(ET|&)( )?DECOUVERTES/ U_CUISINES_ET_DECOUVERTES /i;
	$ugc_libecommerce =~ s/U? (TOUT|TT) PETITS|UTP/ U_TOUT_PETITS /i;

	$ugc_libecommerce =~ s/\.U_/ U_/i;

	my %u_brands = (
		U => "U",
		SDSAV => "U Saveurs",
		U_SAVEURS => "U Saveurs",
		U_BIO => "U Bio",
		BIO_U => "U Bio",
		NOR_U => "Nor U",
		U_OXYGN => "U Oxygn",
		U46MAT => "U Mat & Lou",
		U_MAT_ET_LOU => "U Mat & Lou",
		U46VEG => "U Bon & Végétarien",
		U_BON_ET_VEGETARIEN => "U Bon & Végétarien",
		U_TOUT_PETITS => "U Tout Petits",
		U46TPB => "U Tout Petits Bio",
		DANRE => "Danremont",
		DANREMONT => "Danremont",
		U46SGL => "U Sans Gluten",
		U_SANS_GLUTEN => "U Sans Gluten",
		U_CUISINES_ET_DECOUVERTES => "U Cuisines et Découvertes",
		UDNR => "U de nos Régions"
	);

	# Fromage double crème au lait pasteurisé U, 30%MG, 200g
	# Saucisses de Francfort U BIO, 4 pièces, 200g

	my $alcohol;

	# Poulet fermier de la Drôme, U, France, 1 pièce
	# Emincés de veau, U, France

	if ($ugc_libecommerce =~ /,\s?(France|Belgique|Espagne|Italie|Allemagne|Portugal)/i) {
		$product_ref->{origins} = $1;
		print STDERR "found origins: " . $product_ref->{origins} . "\n";
		$ugc_libecommerce =~ s/,\s?(France|Belgique|Espagne|Italie|Allemagne|Portugal)//i;
	}

	# Note: the format has changed, we don't get the brand in the UGC_libEcommerce field anymore
	if ($ugc_libecommerce
		=~ /(.+)( |,)+(U_BIO|U_SAVEURS|NOR_U|U_OXYGN|U_MAT_ET_LOU|U_BON_ET_VEGETARIEN|U_TOUT_PETITS|DANREMONT|U_SANS_GLUTEN|U_CUISINES_ET_DECOUVERTES|U)( |,)+(.*)$/i
		)
	{

		my ($name, $brand, $quantity) = ($1, $3, $5);
		my $brands = $u_brands{$brand};

		my %u_packaging = (
			bte => "boite",
			ble => "bouteille",
		);

		# Confiture de framboises U 50% de fruits 370g
		# Crème fraîche épaisse légère U, 15%MG, 20cl

		# pet 1l
		# 3368953545250 Mini Mont d'Or AOP au lait cru U SAVEURS, 24% de MG

		$quantity =~ s/demg/de MG/;
		$quantity =~ s/(\d)de/$1 de/;

		if ($quantity =~ /(\d+(\s)?(\%)?(\s)?(de( )?)?(MG|matières grasses|matière grasse|fruits)( |,)*)/i) {
			$name .= " " . $1;
			$name =~ s/,\s*$//;

			$quantity =~ s/(\d+(\s)?(\%)?(\s)?(de )?(MG|matières grasses|matière grasse|fruits)( |,)*)//i;
		}

		# Cocktail mojito fraise U , 15°, 70cl
		# Cocktail mojito U, 15°, 70cl
		# Cocktail caipirinha U 18% vol. 70cl

		# Bière blonde d'Abbaye des Flandres U SAVEURS, 6,5°, 50cl

		if ($name =~ /((\d+(\.|,)?\d*)(\s)?(\%)?(\s)?(de )?(°|\% vol\.|\% vol)( |,)*)/i) {
			$alcohol = $2;
		}

		if ($quantity =~ /((\d+(\.|,)?\d*)(\s)?(\%)?(\s)?(de )?(°|\% vol\.|\% vol)( |,)*)/i) {
			$name .= " " . $1;
			$name =~ s/,\s*$//;
			$alcohol = $2;

			$quantity =~ s/((\d+(\.|,)?\d*)(\s)?(\%)?(\s)?(de )?(°|\% vol\.|\% vol)( |,)*)//i;
		}

		# Pouch Up, U, mojito, bouteille de 1,5L

		while ($quantity =~ /\b(mojito)(( |,)*)/i) {
			$name .= " " . $1;
			$name =~ s/,\s*$//;

			$quantity =~ s/\b(mojito)(( |,)*)//i;
		}

		while ($quantity =~ /\b(film neutre)(( |,)*)/i) {

			$product_ref->{packaging} .= ", " . $1;

			$quantity =~ s/\b(film neutre)(( |,)*)//i;
		}

		# Pomme ariane, U BIO, calibre 136/165, catégorie 2, France, barquette 4fruits

		$quantity =~ s/categories/catégories/ig;
		$quantity =~ s/unites/unités/ig;
		$quantity =~ s/pieces/pièces/ig;
		$quantity =~ s/categorie/catégorie/ig;
		$quantity =~ s/unite/unité/ig;
		$quantity =~ s/piece/pièce/ig;

		while ($quantity =~ /\b(calibre|cal\.|catégorie|cat\.)([^,]+),\s?/i) {
			$name .= " " . $1 . $2;
			$quantity =~ s/\b(calibre|cal\.|catégorie|cat\.)([^,]+),\s?//i;
		}

		if ($quantity =~ /\b(nouvelle agriculture)/i) {
			$name .= " " . $1;
			$quantity =~ s/\b(nouvelle agriculture)//i;
		}

		# 2x80g soit 160g

		if (($quantity !~ /unité|unite|piece|pièce|soit|à/i) and ($quantity =~ /^(\D+) /)) {
			my $packaging = $1;
			$quantity = $';
			# 100g -> 100 g
			$quantity =~ s/(\d)([a-z])/$1 $2/;
			# boite de
			$packaging =~ s/ de$//;
			if (defined $u_packaging{$packaging}) {
				$packaging = $u_packaging{$packaging};
			}
			$product_ref->{packaging} =~ s/°//g;
			$product_ref->{packaging} =~ s/\%//g;
			$product_ref->{packaging} .= ", " . $packaging;
		}

		if (    (defined $imported_product_ref->{SVE_cdRubriqueN1})
			and ($imported_product_ref->{SVE_cdRubriqueN1} eq "Surgelés"))
		{
			$product_ref->{packaging} .= ", Surgelés";
		}

		if (    (defined $imported_product_ref->{SVE_cdRubriqueN1})
			and ($imported_product_ref->{SVE_cdRubriqueN1} eq "Produits frais"))
		{
			$product_ref->{packaging} .= ", Frais";
		}

		$quantity =~ s/^(,|\s)*//;

		$product_ref->{product_name_fr} = $name;
		$product_ref->{brands} = $brands;
		$product_ref->{quantity} = $quantity;
		$product_ref->{packaging} =~ s/^, //;

		print "set product_name to $product_ref->{product_name_fr}\n";

	}
	elsif ($ugc_libecommerce
		=~ /(.+)( |,)+(U_BIO|U_SAVEURS|NOR_U|U_OXYGN|U_MAT_ET_LOU|U_BON_ET_VEGETARIEN|U_TOUT_PETITS|DANREMONT|U_SANS_GLUTEN|U_CUISINES_ET_DECOUVERTES|U)( |,)*$/
		)
	{

		# 12 Oeufs de plein air U

		my ($name, $brand) = ($1, $3);
		my $brands = $u_brands{$brand};
		if ($brands ne 'U') {
			$brands .= ", U";
		}

		$product_ref->{product_name_fr} = $name;
		$product_ref->{brands} = $brands;

		print "set product_name to $product_ref->{product_name_fr}\n";
	}
	else {

		print STDERR "unrecognized format for ugc_libecommerce: $ugc_libecommerce\n";
		print "unrecognized format for ugc_libecommerce: $ugc_libecommerce\n";
		$product_ref->{product_name_fr} = $ugc_libecommerce;
	}

	# brand code in UGC_libMarque
	my $ugc_libmarque = $imported_product_ref->{UGC_libMarque};
	if (defined $u_brands{$ugc_libmarque}) {
		$product_ref->{brands} = $u_brands{$ugc_libmarque};
	}
	else {
		$unknown_brands{$ugc_libmarque}++;
	}

	if ($product_ref->{brands} ne 'U') {
		$product_ref->{brands} .= ", U";
	}

	$product_ref->{product_name_fr} =~ s/\s+$//;
	$product_ref->{brands} =~ s/\s+$//;
	$product_ref->{quantity} =~ s/\s+$//;
	$product_ref->{packaging} =~ s/\s+$//;

	$product_ref->{product_name_fr} =~ s/^\s+//;
	$product_ref->{brands} =~ s/^\s+//;
	$product_ref->{quantity} =~ s/^\s+//;
	$product_ref->{packaging} =~ s/^\s+//;

	# if no quantity was found in the libelle, use the mesure fields
	# UGC_MesureNette	UGC_uniteMesureNette

	if (   (not defined $product_ref->{quantity})
		or ($product_ref->{quantity} eq "")
		or ($product_ref->{quantity} !~ /( |\d)(\s)?(mg|g|kg|l|litre|litres|dl|cl|ml)\b/i))
	{
		if ((defined $imported_product_ref->{UGC_MesureNette}) and ($imported_product_ref->{UGC_MesureNette} ne "")) {
			my $quantity
				= $imported_product_ref->{UGC_MesureNette} . " " . $imported_product_ref->{UGC_uniteMesureNette};
			$quantity =~ s/_net//ig;
			# KILOGRAMME_NET_EGOUTTE
			$quantity =~ s/_egoutte//ig;
			$quantity =~ s/litre/l/ig;
			$quantity =~ s/kilogramme/kg/ig;
			# Quantité : 12.0000 UNITE_DE_CONSOMMATION
			$quantity =~ s/\.(0)+ UNITE_DE_CONSOMMATION/ unités/ig;
			$quantity =~ s/UNITE_DE_CONSOMMATION/unités/ig;
			if ($quantity =~ /^0.(\d+) kg$/i) {
				$quantity = (("0." . $1) * 1000) . " g";
			}
			if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} ne "")) {
				$product_ref->{quantity} .= ", " . $quantity;
			}
			else {
				$product_ref->{quantity} = $quantity;
			}
			print STDERR "setting quantity from UGC_MesureNette: $quantity\n";
		}
	}

	my %ingredients_fields = ('UGC_ingredientStatement' => 'ingredients_text_fr',);

	foreach my $field (sort keys %ingredients_fields) {

		if ((defined $imported_product_ref->{$field}) and ($imported_product_ref->{$field} ne '')) {
			# cleaning
			# in 2018 there were extra commas in the ingredients, this might be fixed now
			$imported_product_ref->{$field} =~ s/ ( +)/ /g;
			$imported_product_ref->{$field} =~ s/ce produits/ce produit/g;
			$imported_product_ref->{$field} =~ s/proviennen, t/proviennent/g;
			$imported_product_ref->{$field} =~ s/provienne, nt/proviennent/g;
			$imported_product_ref->{$field} =~ s/provien, nent/proviennent/g;
			$imported_product_ref->{$field} =~ s/provie, nnent/proviennent/g;
			$imported_product_ref->{$field} =~ s/provi, ennent/proviennent/g;
			$imported_product_ref->{$field} =~ s/prov, iennent/proviennent/g;
			$imported_product_ref->{$field} =~ s/pro, viennent/proviennent/g;
			$imported_product_ref->{$field} =~ s/pr, oviennent/proviennent/g;
			$imported_product_ref->{$field} =~ s/p, roviennent/proviennent/g;
			$imported_product_ref->{$field} =~ s/provienennt/proviennent/g;
			$imported_product_ref->{$field} =~ s/Certaines ingrédients/Certains ingrédients/g;
			$imported_product_ref->{$field} =~ s/ne provienne pas/ne proviennent pas/g;
			$imported_product_ref->{$field}
				=~ s/(Certains ingrédients ne viennent pas de France|Certains ingrédients de ce produit peuvent ne pas provenir de France|Certains des ingrédients de ce produit ne proviennent pas de France|L'ingrédient de ce produit ne provient pas de France|Certains ingrédients de ce produit ne provienne pas de France|Certains ingrédients ne proviennent pas de France.|Les ingrédients de ce produit ne proviennent pas de France|Les ingrédients ne viennent pas tous de France|Certains ingrédients de ce produit ne proviennent pas de France)(\.)?//ig;
			$imported_product_ref->{$field} =~ s/ ( +)/ /g;

			$imported_product_ref->{$field} =~ s/(\s|\/|\/|_|-)+$//is;
			$product_ref->{$ingredients_fields{$field}} = $imported_product_ref->{$field};
			print STDERR "setting ingredients, field $field -> $ingredients_fields{$field}, value: "
				. $imported_product_ref->{$field} . "\n";
		}
	}

	# $product_ref->{ingredients_text} = $product_ref->{ingredients_text_fr};

	if (    (defined $imported_product_ref->{UGC_nutritionalValuesPerPackage})
		and ($imported_product_ref->{UGC_nutritionalValuesPerPackage} ne ""))
	{

		if ($imported_product_ref->{UGC_nutritionalValuesPerPackage}
			=~ /^(Pour|à la|a la)?( )?((1|une)?( )?portion( de| d'environ)?)?( )?([^:\n]+)(:|\n)/i)
		{

			my $serving = $8;

			$serving =~ s/^\s+//;
			$serving =~ s/\s+$//;
			$serving =~ s/ environ$//i;
			$serving =~ s/^\((.*)\)$/$1/;
			if ($serving =~ /nergie/i) {
				$serving = "";
			}
			my $debug = $imported_product_ref->{UGC_nutritionalValuesPerPackage};
			$debug =~ s/:.*//isg;
			if ($serving ne "") {
				print "PORTION -- $serving\t-- $debug\n";
				$product_ref->{serving_size} = $serving;
			}
		}

	}

	clean_fields($product_ref);

	# Nutrients

	my $example = <<TXT
UGC_nutritionalValues


"pour 100g :
Energie (kJ) : 750
Energie (kcal) : 180
Graisses (g) : 9.3
dont acides gras saturés (g) : 3.4
Glucides (g) : 9.9
dont sucres (g) : 1.3
Fibres alimentaires (g) : 2.7
Protéines (g) : 12.7
Sel (g) : 1"

"pour 100g :
Energie (kJ) : 1694
Energie (kcal) : 401
Graisses (g) : 5.1
dont acides gras saturés (g) : 0.6
Glucides (g) : 74.8
dont sucres (g) : 7.3
Fibres alimentaires (g) : 3.9
Protéines (g) : 11.9
Sodium (g) : 0,0048
Sel (g) : 0.01"

"pour 100g :
Energie (kJ) : 1628
Energie (kcal) : 385
Graisses (g) : 4.9
dont acides gras saturés (g) : 0.7
Glucides (g) : 72.2
dont sucres (g) : 6.9
Fibres alimentaires (g) : 4.4
Protéines (g) : 10.8
Sodium (g) : 0.6
Sel (g) : 1.4"

Pour 100g:  Energie 379kJ / 91kcal  Matières grasses 4.5g  dont Acides gras saturés 3.1g Glucides 4.8g  dont Sucres 0.8g  Fibres alimentaires <0.5g Protéines 7.7g Sel 0.63g
Energie (kJ)  1738 , Energie (kcal)  420 , Protéines (g)  20.7 , Glucides (g)  1.2 , Glucides (g) Sucres (g) 1 , Graisses (g)  36.9 , Graisses (g) Acides gras saturés (g) 13.1 , Fibres alimentaires (g)  0 , Sodium (g)  1.25 , Sel (g)  3.18

Pour 100g : Energie : 1856 KJ/ 444 Kcal, Matière grasses : 20g dont acides gras saturés 2.3g; Glucides : 51g dont sucres 26g, fibres alimentaire : 7.8g, protéines : 11g, sel : 0.26g

"A la portion (200g) :
Energie (kJ) : 194
Energie (kcal) : 46
Protéines (g) : 3.8
Glucides (g) : 4.4
dont sucres (g) : 2.6
Lipides (g) :
dont acides gras saturés (g) : NaN
Fibres alimentaires (g) : 5
Sodium (g) : 0.02
soit sel (g) : 0.06"


"Pour 1 pot de 50g :
Energie kJ  227
Energie kcal  54
Graisses g  1.6
dont acides gras saturés g 1.1
Glucides g  6.5
dont sucres g  6.3
Fibres alimentaires g  0.09
Protéines g 3.4
Sel g   0.03
Vitamine D µg  0.4 soit 8  % des AQR*
Calcium mg  60 soit 7.5 % des AQR*
*Apports Quotidiens de Référence"

"Pour un tube de 40g :
Energie kJ 184
Energie kcal  44
Graisses g 1.1
dont acides gras saturés g  0.7
Glucides g   5.8
dont sucres g   5.6
Fibres alimentaires g   0
Protéines g  2.6
Sel g   0.03
Vitamine D µg  0.5 soit 10   % des AQR*
Calcium mg  48 soit 6  % des AQR*
*Apports Quotidiens de Référence"

"Pour 38 g :
Valeurs énergétiques: 625 kJ / 150 kcal
Matières grasses : 8,2 g
Dont acides gras saturés : 3,7 g
Glucides : 15 g
Dont sucres : 1,0 g
Fibres alimentaires: 0,4g
Protéines: 2,4 g
Sel : 0,40 g"

"A la portion (47g) :
Energie (kJ) : 848
Energie (kcal) : 203
Graisses (g) : 10.3
dont acides gras saturés (g) : 4.8
Glucides (g) : 23.9
dont sucres (g) : 8.1
Fibres alimentaires (g) : 0.5
Protéines (g) : 2.5
Sel (g) : 0.04
Cette pâte sablée contient 6 parts d'environ 47 g."

Minéraux  0 , Minéraux Calcium (mg) 4.1 , Minéraux Magnésium (mg) 1.7, Minéraux Potassium (mg) .9 , Minéraux Sodium (mg) 2.7 , Minéraux Bicarbonates (mg) 25.8 , Minéraux Sulfates (mg) 1.1 , Minéraux Nitrates(mg) .8 , Minéraux Chlorure (mg) .9

Energie (kJ)  591 , Energie (kcal)  142 , Protéines (g)  12.5 , Glucides (g)  .7 , Glucides (g) Sucres (g) .7 , Graisses (g)  10 , Graisses (g) Acides gras saturés (g) 2.6 , Graisses (g) Acides gras polyinsaturés (g) 1.9 , Graisses (g) Oméga 3 (g) 485 , Graisses (g) Oméga 3 DHA (g) 132 , Fibres alimentaires (g)  0 , Sel (g)  .3

Energie : 2180 kJ / 5226 kcal Matières grasses : 44 g dont acides gras saturés : 15 g Glucides : 2.4 g dont sucres : 2.3 g Fibres alimentaires : <0.5 g Protéines : 30 g Sel : 4.8 g


pour 100g :  Energie (kJ) : Chocolat : 513 /Vanille : 455 Energie (kcal) : Chocolat : 122 / Vanille : 108 Graisses (g) : Chocolat : 3.4/ vanille : 3.7 dont acides gras saturés (g) : Chocolat : 2.2/ Vanille : 2.4 Glucides (g) : Chocolat : 19.5/Vanille : 16.2 dont sucres (g) : Chocolat : 17.1/Vanille : 13.7 Fibres alimentaires (g) : Chocolat : 0.8/Vanille : 0 Protéines (g) : Chocolat : 2.9/ Vanille : 2.5 Sel (g) : Chocolat : 0.13/Vanille : 0.1

TXT
		;

	# fix typos

	$imported_product_ref->{UGC_nutritionalValues} =~ s/matière grasses/matières grasses/i;
	$imported_product_ref->{UGC_nutritionalValues} =~ s/matières grasse /matières grasses /i;
	$imported_product_ref->{UGC_nutritionalValues} =~ s/fibres alimentaire /fibres alimentaires /i;
	$imported_product_ref->{UGC_nutritionalValues} =~ s/fribre/fibre/i;
	# Glucides ....................................... 15,8 g
	$imported_product_ref->{UGC_nutritionalValues} =~ s/ (\.)+ //ig;

	if (
		(defined $imported_product_ref->{UGC_nutritionalValues})
		and (  (not defined $product_ref->{nutrition_facts_100g_fr_imported})
			or ($imported_product_ref->{UGC_nutritionalValues} ne $product_ref->{nutrition_facts_100g_fr_imported}))
		)
	{
		$product_ref->{nutrition_facts_100g_fr_imported} = $imported_product_ref->{UGC_nutritionalValues};
	}
	if (
		(
			defined $imported_product_ref->{UGC_nutritionalValuesPerPackage}
			and (
				(not defined $product_ref->{nutrition_facts_serving_fr_imported})
				or ($imported_product_ref->{UGC_nutritionalValuesPerPackage} ne
					$product_ref->{nutrition_facts_serving_fr_imported})
			)
		)
		)
	{
		$product_ref->{nutrition_facts_serving_fr_imported} = $imported_product_ref->{UGC_nutritionalValuesPerPackage};
	}

	if (    (defined $imported_product_ref->{UGC_nutritionalValues})
		and ($imported_product_ref->{UGC_nutritionalValues} ne "xyz"))
	{

		my $nutrients = $imported_product_ref->{UGC_nutritionalValues};

		# Omega 3 is in mg even if the unit is listed as g...
		# Graisses (g) Oméga 3 (g) 485 , Graisses (g) Oméga 3 DHA (g) 132 , Fibres alimentaires (g)  0 , Sel (g)  .3
		$nutrients =~ s/Oméga 3 \(g\)/Oméga 3 \(mg\)/ig;
		$nutrients =~ s/Oméga 3 DHA \(g\)/Oméga 3 DHA \(mg\)/ig;

		$nutrients = lc($nutrients);

		my $seen_salt = 0;

		my %found_nids = ();

		my %nutrients = ();
		my $nutrition_data_per;
		my $serving_size;

		# un verre de 20 mL
		$nutrients =~ s/verre de 20 mL/verre de 200 mL/gi;
		extract_nutrition_facts_from_text($product_ref->{lc}, $nutrients, \%nutrients, \$nutrition_data_per,
			\$serving_size);

		print STDERR
			"extract_nutrition_facts_from_text - nutrition_data_per : $nutrition_data_per - serving_size : $serving_size\n";

		if ((defined $nutrition_data_per) and ($nutrition_data_per eq "serving")) {

			if ((defined $serving_size) and ($serving_size ne "") and ($product_ref->{serving_size} ne $serving_size)) {
				$product_ref->{serving_size} = $serving_size;
			}
			if (   (not defined $product_ref->{nutrition_data_per})
				or ($product_ref->{nutrition_data_per} ne $nutrition_data_per))
			{
				$product_ref->{nutrition_data_per} = $nutrition_data_per;
			}
		}

		foreach my $nid (sort keys %nutrients) {

			next if $nid =~ /^#/;

			# don't set sodium if we have salt
			next if (($nid eq 'sodium') and ($seen_salt));

			my ($value, $unit, $modifier) = @{$nutrients{$nid}};

			if (($nid eq 'alcohol') and (defined $alcohol)) {
				$value = $alcohol;
			}

			if (defined $value) {

				$found_nids{$nid} = 1;

				# we will skip sodium if we have a value for salt
				if ($nid eq 'salt') {
					$seen_salt = 1;
				}

				# if we have sodium and not salt, delete existing salt value
				if ($nid eq 'sodium') {
					delete $product_ref->{nutriments}{"salt_value"};
					delete $product_ref->{nutriments}{"salt_unit"};
					delete $product_ref->{nutriments}{"salt_modifier"};
				}

				my $enid = encodeURIComponent($nid);

				print STDERR "product $code - nutrient - $nid - modifier: $modifier - value: $value - unit: $unit\n";

				$value =~ s/,/./;
				$value += 0;

				my $new_value;

				if ($nid =~ /^energy-(kj|kcal)/) {
					$new_value = $value;
				}
				else {
					$new_value = unit_to_g($value, $unit);
				}

				if (    (defined $product_ref->{nutriments})
					and (defined $product_ref->{nutriments}{$nid})
					and ($new_value ne $product_ref->{nutriments}{$nid}))
				{
					my $current_value = $product_ref->{nutriments}{$nid};
					print
						"differing nutrient value for product code $code - nid $nid - existing value: $current_value - new value: $new_value - https://world.openfoodfacts.org/product/$code \n";
				}

				if (   (not defined $product_ref->{nutriments})
					or (not defined $product_ref->{nutriments}{$nid})
					or ($new_value ne $product_ref->{nutriments}{$nid}))
				{

					if ((defined $modifier) and ($modifier ne '')) {
						$product_ref->{nutriments}{$nid . "_modifier"} = $modifier;
					}
					else {
						delete $product_ref->{nutriments}{$nid . "_modifier"};
					}

					$product_ref->{nutriments}{$nid . "_unit"} = $unit;

					$product_ref->{nutriments}{$nid . "_value"} = $value;

					$product_ref->{nutriments}{$nid} = $new_value;

					if (not defined $nutrition_data_per) {
						$product_ref->{nutrition_data_per} = "100g";
					}

					print STDERR "Setting $nid to $value $unit\n";

					$modified++;
				}

			}

		}
	}

	push @products, $product_ref;

}

# Output the CSV file

open(my $output_csv_fh, ">:encoding(UTF-8)", $output_csv_file) or die "Could not open $output_csv_file: $!";

my @output_fields = qw(
	code
	lc
	countries
	product_name_fr
	generic_name_fr
	brands
	categories
	labels
	quantity
	ingredients_text_fr
	allergens
	traces
	nutrition_data_per
);

# Add fields for nutrients, with nid suffixed by _value, _unit, and _modifier

my %nutrient_fields = ();

foreach my $product_ref (@products) {
	foreach my $nid (keys %{$product_ref->{nutriments}}) {
		$nutrient_fields{$nid} = 1;
	}
}

my @sorted_nutrients_fields = sort keys %nutrient_fields;

my @all_fields = (@output_fields, @sorted_nutrients_fields);

# Print the header line with fields names
$output_csv->print($output_csv_fh, \@all_fields);

foreach my $product_ref (@products) {

	my @output_values = ();
	foreach my $field (@output_fields) {
		push @output_values, $product_ref->{$field};
	}
	# add nutrients
	foreach my $field (@sorted_nutrients_fields) {
		push @output_values, $product_ref->{nutriments}{$field};
	}
	$output_csv->print($output_csv_fh, \@output_values);
}

print "\n\nlabels:\n";

foreach my $label (sort {$labels_count{$b} <=> $labels_count{$a}} keys %labels_count) {

	defined $labels{$label} or $labels{$label} = "";
	print $label . "\t" . $labels_count{$label} . "\t" . $labels{$label} . "\n";
}

print "\n\nallergens:\n";

foreach my $allergen (sort {$allergens_count{$b} <=> $allergens_count{$a}} keys %allergens_count) {

	defined $allergens{$allergen} or $allergens{$allergen} = "";
	my $canon_tagid = canonicalize_taxonomy_tag("fr", "allergens", $allergen);
	my $taxonomy_tag = "";
	if (exists_taxonomy_tag("allergens", $canon_tagid)) {
		$taxonomy_tag = $canon_tagid;
	}
	else {
		$taxonomy_tag = $allergens_codes{$allergen};
	}
	print $allergen . "\t" . $allergens_count{$allergen} . "\t" . $taxonomy_tag . "\n";
}

print "\n\ncategories with unverified taxonomy matches:\n";

foreach my $category (sort {$unverified_categories{$b} <=> $unverified_categories{$a}} keys %unverified_categories) {

	print $category . "\t" . $unverified_categories{$category} . "\t" . $unverified_categories_matches{$category} . "\n";
}

print "\n\ncategories with no mapping to OFF categories:\n";

foreach my $category (sort {$unknown_categories{$b} <=> $unknown_categories{$a}} keys %unknown_categories) {

	print $category . "\t" . $unknown_categories{$category} . "\n";
}

print "\n\nbrands with no mapping to OFF brands:\n";

foreach my $brand (sort {$unknown_brands{$b} <=> $unknown_brands{$a}} keys %unknown_brands) {

	print $brand . "\t" . $unknown_brands{$brand} . "\n";
}

#print "\n\nlist of nutrient names:\n\n";
#foreach my $name (sort keys %nutrients_names) {
#	print $name . "\n";
#}
