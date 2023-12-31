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

binmode(STDOUT, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Units qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::ImportConvert qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;

use Log::Any qw($log);
use Log::Any::Adapter 'TAP', filter => "none";

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;

use Text::CSV;

my $csv = Text::CSV->new({binary => 1, sep_char => "\t"})    # should set binary attribute.
	or die "Cannot use CSV: " . Text::CSV->error_diag();

$lc = "fr";
$country = "en:france";

$User_id = 'systeme-u';

my $editor_user_id = 'systeme-u';

$User_id = $editor_user_id;
my $photo_user_id = $editor_user_id;
$editor_user_id = $editor_user_id;

not defined $photo_user_id and die;

my $csv_file = "/srv2/off/imports/systemeu/data/SUYQD_AKENEO_PU_09_2020.csv";
my $categories_csv_file = "/srv2/off/imports/systemeu/systeme-u-rubriques.csv";
my $imagedir;
#$imagedir = "/srv2/off/imports/systemeu/images";
#$imagedir = "/srv2/off/imports/systemeu/images1/images";
#$imagedir = "/srv2/off/imports/systemeu/images2";
my $products_without_ingredients_lists = "/srv2/off/imports/systemeu/systeme-u-products-without-ingredients-lists.txt";

#my $csv_file = "/home/systemeu/SUYQD_AKENEO_PU_08.csv";
#my $categories_csv_file = "/home/systemeu/systeme-u-rubriques.csv";
#my $imagedir = "/home/systemeu/all_product_images";
#my $products_without_ingredients_lists = "/home/systemeu/systeme-u-products-without-ingredients-lists.txt";

print "uploading csv_file: $csv_file, image_dir: $imagedir\n";

my %products_without_ingredients_lists = ();

open(my $fh, '<:encoding(UTF-8)', $products_without_ingredients_lists)
	or die("Could not open $products_without_ingredients_lists: $!");
while (<$fh>) {
	my $code = $_;
	chomp($code);
	$code =~ s/\D//;
	$code += 0;
	$products_without_ingredients_lists{$code} = 1;
}

# Images

# d : ingredients
# e : nutrition

# 3256225094547_0_d.jpg
# 3256225094547_0_e.jpg
# 3256225094547.jpg

#-rwx------ 1 root root   229339 avril 20 15:44 3256225425105_D.jpg
#-rwx------ 1 root root   320218 avril 20 15:44 3256225425105_E.jpg
#-rwx------ 1 root root   410014 avril 20 15:44 3256225425617_a_E.jpg
#-rwx------ 1 root root   374778 avril 20 15:44 3256225425617_b_E.jpg
#-rwx------ 1 root root   213484 avril 20 15:45 3256225426560_a_D.jpg

# 03368957378571_C0N1_S02_ETUI_USAV_SAUMO_ANETH_CITRO.jpg

my $images_ref = {};

my %rubriques = ();

print "Opening image dir $imagedir\n";

if (opendir(DH, "$imagedir")) {
	foreach my $file (sort {$a cmp $b} readdir(DH)) {

		# systeme-u archives includes files starting with ._
		# that contain metadata, skip them

		next if ($file =~ /^._/);

		if ($file =~ /(\d+)(.*)\.(jpg|jpeg|png)/i) {

			my $code = $1;
			my $suffix = $2;
			my $imagefield = "other";
			((not defined $suffix) or ($suffix eq "")) and $imagefield = "front";
			($suffix =~ /^(_mp)?(_(\d+))?_d(.*)$/i) and $imagefield = "ingredients";
			($suffix =~ /^(_mp)?(_(\d+))?_e(.*)$/i) and $imagefield = "nutrition";

			print "FOUND IMAGE FOR PRODUCT CODE ($code) - file ($file) - imagefield: ($imagefield)\n";

			# 03368953216518_C0N1_S01_ETUI_USAV_CREVE_LABEL_ROUGE_400G.jpg
			if ($code =~ /^0(\d{13})/) {
				$code = $1;
			}

			(defined $images_ref->{$code}) or $images_ref->{$code} = {};

			$images_ref->{$code}{$imagefield} = $file;

		}

	}
}

closedir(DH);

my $i = 0;
my $j = 0;
my %codes = ();
my $current_code = undef;
my $previous_code = undef;
my $last_imgid = undef;

my $current_product_ref = undef;

my @param_sorted_langs = qw(fr);

my %global_params = (
	lc => 'fr',
	lang => 'fr',
	countries => "France",
	brands => "U",
	stores => "Magasins U",
);

$lc = 'fr';

my $comment = "Systeme U direct data import";

my $time = time();

my $existing = 0;
my $new = 0;
my $differing = 0;
my %differing_fields = ();
my @edited = ();
my %edited = ();

my $testing = 0;
my $testing_allergens = 0;
# my $testing = 1;

print STDERR "importing labels\n";

print STDERR "importing products\n";

my %missing_nids = ();

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

open(my $io3, '<:encoding(UTF-8)', $categories_csv_file) or die("Could not open $csv_file: $!");

while (my $line = <$io3>) {

	chomp($line);
	my ($rubriques, $category) = split(/\t/, $line);

	$rubriques =~ s/\s+\d+$//;

	if ((defined $category) and ($category ne "")) {
		$rubriques_category{$rubriques} = $category;
		print STDERR $rubriques . " --> " . $category . "\n";
	}
}

close($io3);

print STDERR "importing products\n";

open(my $io, '<:encoding(UTF-8)', $csv_file) or die("Could not open $csv_file: $!");

$csv->column_names($csv->getline($io));

# sku;UGC_ean;UGC_libEcommerce;UGC_libMarque;UGC_nomGestion;
# UGC_MesureNette;UGC_uniteMesureNette;UGC_Typo;
# UGC_ingredientStatement;ALK_libelleComposition;UGC_allergenStatement;ALK_allergene;ALK_presenceDeContient;
# ALK_presenceDeTraceDe;ALK_presenceDeNeContientPas;UGC_nutritionalValuesPerPackage;UGC_nutritionalValues;
# ALK_valNutritionnelles;SVE_idRubrique;SVE_cdRubriqueN1;SVE_cdRubriqueN2;SVE_cdRubriqueN3

# 100099-3368954000901;3368954000901;"Vinaigre de vin de Xérès U SAVEURS bouteille 25cl";SDSAV;010503250510300505;
# 0.2500;LITRE;MFR-MF4;
# SULFITES;;"A conserver dans un endroit sec, à température ambiante et à l'abri de la lumière.";;;;;;;;0348028402820000;
# "Epicerie salée";Assaisonnement;"Vinaigre et jus de citron"

while (my $imported_product_ref = $csv->getline_hr($io)) {

	$i++;

	# SVE_cdRubriqueN1	SVE_cdRubriqueN2	SVE_cdRubriqueN3
	$imported_product_ref->{rubriques}
		= $imported_product_ref->{SVE_cdRubriqueN1} . " - "
		. $imported_product_ref->{SVE_cdRubriqueN2} . " - "
		. $imported_product_ref->{SVE_cdRubriqueN3};
	$rubriques{$imported_product_ref->{rubriques}}++;

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

	#next if ($code ne "3256220067515");

	# next if ($i < 2665);

	print "PRODUCT LINE NUMBER $i - CODE $code\n";

	if (not defined $images_ref->{$code}) {
		print "MISSING IMAGES ALL - PRODUCT CODE $code\n";
	}
	if (not defined $images_ref->{$code}{front}) {
		print "MISSING IMAGES FRONT - PRODUCT CODE $code\n";
	}
	if (not defined $images_ref->{$code}{ingredients}) {
		print "MISSING IMAGES INGREDIENTS - PRODUCT CODE $code\n";
	}
	if (not defined $images_ref->{$code}{nutrition}) {
		print "MISSING IMAGES NUTRITION - PRODUCT CODE $code\n";
	}

	if (
		   (not defined $images_ref->{$code})
		or (not defined $images_ref->{$code}{front})
		or ((not defined $images_ref->{$code}{ingredients}) and (not exists $products_without_ingredients_lists{$code}))
		)
	{
		print "MISSING IMAGES SOME - PRODUCT CODE $code\n";
		#next;
	}

	print "product $i - code: $code\n";

	my $product_ref = product_exists("org-systeme-u/" . $code);    # returns 0 if not

	if (not $product_ref) {
		print "- does not exist in OFF yet\n";
		$new++;
		if (1 and (not $product_ref)) {
			print "product code $code does not exist yet, creating product\n";
			$User_id = $photo_user_id;
			$product_ref = init_product($User_id, "systeme-u", $code, $country);
			$product_ref->{interface_version_created} = "import_systemeu.pl - version 2019/12/13";
			$product_ref->{lc} = $global_params{lc};
			delete $product_ref->{countries};
			delete $product_ref->{countries_tags};
			delete $product_ref->{countries_hierarchy};
			store_product($User_id, $product_ref, "Creating product (import_systemeu.pl bulk upload) - " . $comment);
		}

	}
	else {
		print "- already exists in OFF\n";
		$existing++;
	}

	# First load the global params, then apply the product params on top
	my %params = %global_params;

	if (not $testing) {
		print STDERR "uploading images for product code $code\n";

		if (defined $images_ref->{$code}) {

			print STDERR "we have some images for product code $code\n";

			foreach my $imagefield ('front', 'ingredients', 'nutrition', 'other') {

				if (not defined $images_ref->{$code}{$imagefield}) {
					print STDERR "no images for code $code - imagefield $imagefield\n";
					next;
				}
				else {
					print STDERR
						"found image for code $code - imagefield $imagefield: $images_ref->{$code}{$imagefield}\n";
				}

				my $current_max_imgid = -1;

				if (defined $product_ref->{images}) {
					foreach my $imgid (keys %{$product_ref->{images}}) {
						if (($imgid =~ /^\d/) and ($imgid > $current_max_imgid)) {
							$current_max_imgid = $imgid;
						}
					}
				}

				my $imported_image_file = $images_ref->{$code}{$imagefield};

				# upload the image
				my $file = $imported_image_file;
				if (-e "$imagedir/$file") {
					print "found image file $imagedir/$file\n";

					# upload a photo
					my $imgid;
					my $debug;
					my $return_code = process_image_upload("org-systeme-u/" . $code,
						"$imagedir/$file", $User_id, undef, $comment, \$imgid, \$debug);
					print "process_image_upload - file: $file - return code: $return_code - imgid: $imgid\n";

					if (($imgid > 0) and ($imgid > $current_max_imgid) and ($imagefield ne 'other')) {

						print STDERR "assigning image $imgid to ${imagefield}_fr\n";
						eval {
							process_image_crop(
								$User_id,
								"org-systeme-u/" . $code,
								$imagefield . "_fr",
								$imgid, 0, undef, undef, -1, -1, -1, -1, "full"
							);
						};
						# $modified++;

					}
					else {
						print STDERR
							"returned imgid $imgid not greater than the previous max imgid: $current_max_imgid\n";

						# overwrite already selected images
						if (    ($imgid > 0)
							and (exists $product_ref->{images})
							and (exists $product_ref->{images}{$imagefield . "_fr"})
							and ($product_ref->{images}{$imagefield . "_fr"}{imgid} != $imgid))
						{
							print STDERR "re-assigning image $imgid to ${imagefield}_fr\n";
							eval {
								process_image_crop(
									$User_id,
									"org-systeme-u/" . $code,
									$imagefield . "_fr",
									$imgid, 0, undef, undef, -1, -1, -1, -1, "full"
								);
							};
							# $modified++;
						}

					}

				}
				else {
					print "did not find image file $imagedir/$file\n";
				}

			}

		}

		# reload the product (changed by image upload)
		$product_ref = retrieve_product("org-systeme-u/" . $code);
	}

	foreach my $ugc_typo (split(/,/, $imported_product_ref->{UGC_Typo})) {

		$labels_count{$ugc_typo}++;

		if (defined $labels{$ugc_typo}) {
			$params{labels} .= ", " . $labels{$ugc_typo};
		}

	}

	if ($imported_product_ref->{UGC_libEcommerce} =~ /\bBIO\b/i) {
		$params{labels} .= ", " . "Bio";
	}

	$params{labels} =~ s/^, //;

	print STDERR "labels for product code $code : " . $params{labels} . "\n";

	if (    (defined $imported_product_ref->{rubriques})
		and ($imported_product_ref->{rubriques} ne "")
		and (defined $rubriques_category{$imported_product_ref->{rubriques}}))
	{
		my $category = $rubriques_category{$imported_product_ref->{rubriques}};
		$category =~ s/^fr://;
		$params{categories} = $category;
		print "assigning category $category from rubriques $imported_product_ref->{rubriques}\n";
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

	foreach my $ugc_allergen (split(/,|;/, $imported_product_ref->{UGC_allergenStatement})) {

		$ugc_allergen =~ s/^\s+//;
		$ugc_allergen =~ s/(\.|\s)+$//;

		next if $ugc_allergen eq "FAO";
		next if $ugc_allergen eq "MSC";

		if (defined $allergens{$ugc_allergen}) {
			$params{allergens} .= ", " . $allergens{$ugc_allergen};
			print "new known allergen for product code $code : " . $allergens{$ugc_allergen} . "\n";

			$allergens_count{$allergens{$ugc_allergen}}++;
			$allergens_codes{$allergens{$ugc_allergen}} .= "$code ";

		}
		else {
			$params{allergens} .= ", " . $ugc_allergen;
			print "new unknown allergen for product code $code : " . $ugc_allergen . "\n";

			$allergens_count{$ugc_allergen}++;
			$allergens_codes{$ugc_allergen} .= "$code ";

		}

	}

	$params{allergens} =~ s/^, //;

	$allergens_import = $params{allergens};

	print "allergens for product code $code : " . $params{allergens} . "\n";

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
		U_SAVEURS => "U Saveurs",
		U_BIO => "U Bio",
		NOR_U => "Nor U",
		U_OXYGN => "U Oxygn",
		U_MAT_ET_LOU => "U Mat & Lou",
		U_BON_ET_VEGETARIEN => "U Bon & Végétarien",
		U_TOUT_PETITS => "U Tout Petits",
		DANREMONT => "Danremont",
		U_SANS_GLUTEN => "U Sans Gluten",
		U_CUISINES_ET_DECOUVERTES => "U Cuisines et Découvertes",
	);

	# Fromage double crème au lait pasteurisé U, 30%MG, 200g
	# Saucisses de Francfort U BIO, 4 pièces, 200g

	my $alcohol;

	# Poulet fermier de la Drôme, U, France, 1 pièce
	# Emincés de veau, U, France

	if ($ugc_libecommerce =~ /,\s?(France|Belgique|Espagne|Italie|Allemagne|Portugal)/i) {
		$params{origins} = $1;
		print STDERR "found origins: " . $params{origins} . "\n";
		$ugc_libecommerce =~ s/,\s?(France|Belgique|Espagne|Italie|Allemagne|Portugal)//i;
	}

	if ($ugc_libecommerce
		=~ /(.+)( |,)+(U_BIO|U_SAVEURS|NOR_U|U_OXYGN|U_MAT_ET_LOU|U_BON_ET_VEGETARIEN|U_TOUT_PETITS|DANREMONT|U_SANS_GLUTEN|U_CUISINES_ET_DECOUVERTES|U)( |,)+(.*)$/i
		)
	{

		my ($name, $brand, $quantity) = ($1, $3, $5);
		my $brands = $u_brands{$brand};
		if ($brands ne 'U') {
			$brands .= ", U";
		}

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

			$params{packaging} .= ", " . $1;

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
			$params{packaging} =~ s/°//g;
			$params{packaging} =~ s/\%//g;
			$params{packaging} .= ", " . $packaging;
		}

		if (    (defined $imported_product_ref->{SVE_cdRubriqueN1})
			and ($imported_product_ref->{SVE_cdRubriqueN1} eq "Surgelés"))
		{
			$params{packaging} .= ", Surgelés";
		}

		if (    (defined $imported_product_ref->{SVE_cdRubriqueN1})
			and ($imported_product_ref->{SVE_cdRubriqueN1} eq "Produits frais"))
		{
			$params{packaging} .= ", Frais";
		}

		$quantity =~ s/^(,|\s)*//;

		$params{product_name} = $name;
		$params{brands} = $brands;
		$params{quantity} = $quantity;
		$params{packaging} =~ s/^, //;

		print "set product_name to $params{product_name}\n";

		# copy value to main language
		$params{"product_name_" . $global_params{lc}} = $params{product_name};
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

		$params{product_name} = $name;
		$params{brands} = $brands;

		print "set product_name to $params{product_name}\n";

		# copy value to main language
		$params{"product_name_" . $global_params{lc}} = $params{product_name};
	}
	elsif (($code eq "3256220178334")
		or ($code eq "3256220879040"))
	{

		my $name = $ugc_libecommerce;
		my $brands = "U";

		$params{product_name} = $name;
		$params{brands} = $brands;

		print "no brand - set product_name to $params{product_name}\n";

		# copy value to main language
		$params{"product_name_" . $global_params{lc}} = $params{product_name};

	}
	else {

		print STDERR "unrecognized format for ugc_libecommerce: $ugc_libecommerce\n";
		print "unrecognized format for ugc_libecommerce: $ugc_libecommerce\n";
		next;

	}

	$params{product_name} =~ s/\s+$//;
	$params{brands} =~ s/\s+$//;
	$params{quantity} =~ s/\s+$//;
	$params{packaging} =~ s/\s+$//;

	$params{product_name} =~ s/^\s+//;
	$params{brands} =~ s/^\s+//;
	$params{quantity} =~ s/^\s+//;
	$params{packaging} =~ s/^\s+//;

	# if no quantity was found in the libelle, use the mesure fields
	# UGC_MesureNette	UGC_uniteMesureNette

	if (   (not defined $params{quantity})
		or ($params{quantity} eq "")
		or ($params{quantity} !~ /( |\d)(\s)?(mg|g|kg|l|litre|litres|dl|cl|ml)\b/i))
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
			if ((defined $params{quantity}) and ($params{quantity} ne "")) {
				$params{quantity} .= ", " . $quantity;
			}
			else {
				$params{quantity} = $quantity;
			}
			print STDERR "setting quantity from UGC_MesureNette: $quantity\n";
		}
	}

	my %ingredients_fields = ('UGC_ingredientStatement' => 'ingredients_text_fr',);

	foreach my $field (sort keys %ingredients_fields) {

		if ((defined $imported_product_ref->{$field}) and ($imported_product_ref->{$field} ne '')) {
			# cleaning
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
			$params{$ingredients_fields{$field}} = $imported_product_ref->{$field};
			print STDERR "setting ingredients, field $field -> $ingredients_fields{$field}, value: "
				. $imported_product_ref->{$field} . "\n";
		}
	}

	# $params{ingredients_text} = $params{ingredients_text_fr};

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
				$params{serving_size} = $serving;
			}
		}

	}

	my $args_ref = {"import_lc" => "fr"};
	my %stats = ();

	# Create or update fields

	my @param_fields = ();

	foreach my $field ('lc', 'lang', 'product_name', 'generic_name', @ProductOpener::Config::product_fields,
		'serving_size', 'ingredients_text', 'allergens', 'traces')
	{

		if (defined $language_fields{$field}) {
			foreach my $display_lc (@param_sorted_langs) {
				push @param_fields, $field . "_" . $display_lc;
			}
		}
		else {
			push @param_fields, $field;
		}
	}

	# Clean the fields to be imported

	$params{lc} = "fr";
	@fields = @param_fields;
	clean_fields(\%params);

	foreach my $field (@param_fields) {

		if ((defined $params{$field}) and ($params{$field} ne "")) {

			print STDERR "defined value for field $field : " . $params{$field} . "\n";
			$imported_product_ref->{$field} = $params{$field};

			# for tag fields, only add entries to it, do not remove other entries

			if (defined $tags_fields{$field}) {

				my $current_field = $product_ref->{$field};

				# we may want to replace brands completely at some point
				# disabling for now

				#if ($field eq 'brands') {
				#	$product_ref->{$field} = "";
				#	delete $product_ref->{$field . "_tags"};
				#}

				# If we are on the producers platform, remove existing values for brands
				if (($server_options{producers_platform}) and ($field eq "brands")) {
					$product_ref->{$field} = "";
					delete $product_ref->{$field . "_tags"};
				}

				my %existing = ();
				if (defined $product_ref->{$field . "_tags"}) {
					foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
						$existing{$tagid} = 1;
					}
				}

				foreach my $tag (split(/,/, $imported_product_ref->{$field})) {

					my $tagid;

					next if $tag =~ /^(\s|,|-|\%|;|_|°)*$/;
					next
						if $tag
						=~ /^\s*((n(\/|\.)?a(\.)?)|(not applicable)|none|aucun|aucune|unknown|inconnu|inconnue|non|non renseigné|non applicable|nr|n\/r|no)\s*$/i;

					$tag =~ s/^\s+//;
					$tag =~ s/\s+$//;

					if ($field eq 'emb_codes') {
						$tag = normalize_packager_codes($tag);
					}

					if (defined $taxonomy_fields{$field}) {
						$tagid = get_taxonomyid($imported_product_ref->{lc},
							canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag));
					}
					else {
						$tagid = get_string_id_for_lang("no_language", $tag);
					}

					if (not exists $existing{$tagid}) {
						$log->debug("adding tagid to field", {field => $field, tagid => $tagid}) if $log->is_debug();
						$product_ref->{$field} .= ", $tag";
						$existing{$tagid} = 1;
					}
					else {
						#print "- $tagid already in $field\n";
						# update the case (e.g. for brands)
						if ($field eq "brands") {
							my $regexp = $tag;
							$regexp =~ s/( |-)/\( \|-\)/g;
							$product_ref->{$field} =~ s/\b$tagid\b/$tag/i;
							$product_ref->{$field} =~ s/\b$regexp\b/$tag/i;
						}
					}
				}

				if ((defined $product_ref->{$field}) and ($product_ref->{$field} =~ /^, /)) {
					$product_ref->{$field} = $';
				}

				my $tag_lc = $product_ref->{lc};

				# If an import_lc was passed as a parameter, assume the imported values are in the import_lc language
				if (defined $args_ref->{import_lc}) {
					$tag_lc = $args_ref->{import_lc};
				}

				if ($field eq 'emb_codes') {
					# French emb codes
					$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
					$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});
				}
				if (not defined $current_field) {
					$log->debug("added value to field", {field => $field, value => $product_ref->{$field}})
						if $log->is_debug();
					compute_field_tags($product_ref, $tag_lc, $field);
					push @modified_fields, $field;
					$modified++;
					$stats{products_info_added}{$code} = 1;
				}
				elsif ($current_field ne $product_ref->{$field}) {
					$log->debug("changed value for field",
						{field => $field, value => $product_ref->{$field}, old_value => $current_field})
						if $log->is_debug();
					compute_field_tags($product_ref, $tag_lc, $field);
					push @modified_fields, $field;
					$modified++;
					$stats{products_info_changed}{$code} = 1;
				}
				elsif ($field eq "brands") {    # we removed it earlier
					compute_field_tags($product_ref, $tag_lc, $field);
				}
			}
			else {
				# non-tag field
				my $new_field_value = $params{$field};

				$new_field_value =~ s/\s+$//;
				$new_field_value =~ s/^\s+//;

				if (($field eq 'quantity') or ($field eq 'serving_size')) {

					# openfood.ch now seems to round values to the 1st decimal, e.g. 28.0 g
					$new_field_value =~ s/\.0 / /;

					# 6x90g
					$new_field_value =~ s/(\d)(\s*)x(\s*)(\d)/$1 x $4/i;

					$new_field_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
					$new_field_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
					#$new_field_value =~ s/(\d)( )?cl/${1}0 ml/i;
					#$new_field_value =~ s/(\d)( )?dl/${1}00 ml/i;
					$new_field_value =~ s/litre|litres|liter|liters/l/i;
					#$new_field_value =~ s/(0)(,|\.)(\d)( )?(l)(\.)?/${3}00 ml/i;
					#$new_field_value =~ s/(\d)(,|\.)(\d)( )?(l)(\.)?/${1}${3}00 ml/i;
					#$new_field_value =~ s/(\d)( )?(l)(\.)?/${1}000 ml/i;
					$new_field_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
					#$new_field_value =~ s/(0)(,|\.)(\d)( )?(kg)(\.)?/${3}00 g/i;
					#$new_field_value =~ s/(\d)(,|\.)(\d)( )?(kg)(\.)?/${1}${3}00 g/i;
					#$new_field_value =~ s/(\d)( )?(kg)(\.)?/${1}000 g/i;
				}

				$new_field_value =~ s/\s+$//g;
				$new_field_value =~ s/^\s+//g;

				next if $new_field_value eq "";

				my $normalized_new_field_value = $new_field_value;

				# existing value?
				if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {
					my $current_value = $product_ref->{$field};
					$current_value =~ s/\s+$//g;
					$current_value =~ s/^\s+//g;

					# normalize current value
					if (($field eq 'quantity') or ($field eq 'serving_size')) {

						$current_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
						$current_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
						#$current_value =~ s/(\d)( )?cl/${1}0 ml/i;
						#$current_value =~ s/(\d)( )?dl/${1}00 ml/i;
						$current_value =~ s/litre|litres|liter|liters/l/i;
						#$current_value =~ s/(0)(,|\.)(\d)( )?(l)(\.)?/${3}00 ml/i;
						#$current_value =~ s/(\d)(,|\.)(\d)( )?(l)(\.)?/${1}${3}00 ml/i;
						#$current_value =~ s/(\d)( )?(l)(\.)?/${1}000 ml/i;
						$current_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
						#$current_value =~ s/(0)(,|\.)(\d)( )?(kg)(\.)?/${3}00 g/i;
						#$current_value =~ s/(\d)(,|\.)(\d)( )?(kg)(\.)?/${1}${3}00 g/i;
						#$current_value =~ s/(\d)( )?(kg)(\.)?/${1}000 g/i;
					}

					if ($field =~ /ingredients/) {

						#$current_value = get_fileid(lc($current_value));
						#$current_value =~ s/\W+//g;
						#$normalized_new_field_value = get_fileid(lc($normalized_new_field_value));
						#$normalized_new_field_value =~ s/\W+//g;

					}

					if (lc($current_value) ne lc($normalized_new_field_value)) {
						print
							"differing value for product code $code - field $field - existing value: $product_ref->{$field} (normalized: $current_value) - new value: $new_field_value - https://world.openfoodfacts.org/product/$code \n";
						$differing++;
						$differing_fields{$field}++;

						print
							"changing previously existing value for product code $code - field $field - value: $new_field_value\n";
						$product_ref->{$field} = $new_field_value;
						push @modified_fields, $field;
						$modified++;
					}
					elsif (($field eq 'quantity') and ($product_ref->{$field} ne $new_field_value)) {
						# normalize quantity
						$log->debug(
							"normalizing quantity",
							{field => $field, existing_value => $product_ref->{$field}, new_value => $new_field_value}
						) if $log->is_debug();
						$product_ref->{$field} = $new_field_value;
						push @modified_fields, $field;
						$modified++;
					}

				}
				else {
					print
						"setting previously unexisting value for product code $code - field $field - value: $new_field_value\n";
					$product_ref->{$field} = $new_field_value;
					push @modified_fields, $field;
					$modified++;
				}
			}
		}
	}

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
		$modified++;
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
		$modified++;
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
				$modified++;
			}
			if (   (not defined $product_ref->{nutrition_data_per})
				or ($product_ref->{nutrition_data_per} ne $nutrition_data_per))
			{
				$product_ref->{nutrition_data_per} = $nutrition_data_per;
				$modified++;
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

	}    # if nutrient are not empty in the csv

	# Skip further processing if we have not modified any of the fields

	print STDERR "product code $code - number of modifications - $modified\n";
	if ($modified == 0) {
		print STDERR "skipping product code $code - no modifications\n";
		next;
	}
	#exit;

	# Process the fields

	$User_id = $editor_user_id;

	my $response_ref = {};
	analyze_and_enrich_product_data($product_ref, $response_ref);

	if (not defined $product_ref->{sources}) {
		$product_ref->{sources} = [];
	}

	push @{$product_ref->{sources}},
		{
		id => "systemeu",
		name => "Systeme U",
		url => "https://www.magasins-u.com/",
		manufacturer => 1,
		import_t => time(),
		fields => \@modified_fields,
		images => \@images_ids,
		};

	if ((not $testing) and (not $testing_allergens)) {

		$product_ref->{owner} = "org-systeme-u";
		$product_ref->{owners_tags} = ["org-systeme-u"];

		store_product($User_id, $product_ref, "Editing product (import_systemeu.pl bulk import) - " . $comment);

		push @edited, $code;
		$edited{$code}++;

		$j++;
		#$j > 10 and last;
		#last;
	}

	#last;
}    # if $file =~ json

print "$i products\n";
print "$new new products\n";
print "$existing existing products\n";
print "$differing differing values\n\n";

print((scalar @edited) . " edited products\n");
print((scalar keys %edited) . " editions\n");

foreach my $field (sort keys %differing_fields) {
	print "field $field - $differing_fields{$field} differing values\n";
}

print "\n\nlabels:\n";

#foreach my $label (sort { $labels_count{$b} <=> $labels_count{$a}} keys %labels_count ) {

#defined $labels{$label} or $labels{$label} = "";
#print $label . "\t" . $labels_count{$label} . "\t" .  $labels{$label} . "\n";
#}

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

#foreach my $rubrique (sort { $rubriques{$b} <=> $rubriques{$a}} keys %rubriques ) {
#
#	print $rubrique . "\t" . $rubriques{$rubrique} . "\n";
#}

#print "\n\nlist of nutrient names:\n\n";
#foreach my $name (sort keys %nutrients_names) {
#	print $name . "\n";
#}
