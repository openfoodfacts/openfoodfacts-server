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

ProductOpener::DataQualityFood - check the quality of data for food products

=head1 DESCRIPTION

C<ProductOpener::DataQualityFood> is a submodule of C<ProductOpener::DataQuality>.

It implements quality checks that are specific to food products.

When the type of products is set to food, C<ProductOpener::DataQuality::check_quality()>
calls C<ProductOpener::DataQualityFood::check_quality()>, which in turn calls
all the functions of the submodule.

=cut

package ProductOpener::DataQualityFood;

use ProductOpener::PerlStandards;
use Exporter qw(import);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&check_quality_food
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::Config qw(:all);
use ProductOpener::Store qw(:all);
use ProductOpener::Tags qw(:all);
use ProductOpener::Food qw(:all);
use ProductOpener::Ecoscore qw(:all);

use Data::DeepAccess qw(deep_exists);

use Log::Any qw($log);

=head1 HARDCODED BRAND LISTS

The module has 4 hardcoded lists of brands: @baby_food_brands, @cigarette_brands, @petfood_brands and @beauty_brands

We will probably create a brands taxonomy at some point, which will allow us to remove those hardcoded lists.

=cut

my @baby_food_brands = qw(
	Gallia
	Bledina
	Modilac
	Guigoz
	Milumel
	Hipp
	Babybio
	Novalac
	Premibio
	Picot
	Bledilait
	Carrefour-baby
	Pommette
	Laboratoires-guigoz
	Nidal
	Lactel-eveil
	Holle
	Mots-d-enfants
	Laboratoire-guigoz
	Bledidej
	Bebe-nestle
	Laboratoire-gallia
	Gilbert
	Hipp-biologique
	U-tout-petits
	Milupa
	Nestle-bebe
	Blediner
	Guiguoz
	Laboratoires-picot
	Nutricia
	P-tit-souper
	P-tit-dej-croissance
	P-tit-dej
	Sodiaal
	Premichevre
	Auchan-baby
	Aptamil
	Candia-croissance
	Lactel-lait-pour-nourrisson
	Croissance
	Biostime
	Premilait
	Envia
	Babysoif
	Capricare
	France-lait
	Candia-baby
	Physiolac
	Topfer
	Nutrilac
);

my @cigarette_brands = qw(
	A-Mild
	Absolute-Mild
	Access-Mild
	Akhtamar
	Alain-Delon
	Apache
	Ararat
	Ashford
	Avolution
	Bahman
	Basic
	Belomorkanal
	Benson-&-Hedges
	Bentoel
	Berkeley
	Bintang-Buana
	Bond-Street
	Bristol
	Cabin
	Cambridge
	Camel
	Canadian-Classics
	Capri
	Capstan
	Carroll's
	Caster
	Cavanders
	Chancellor
	Charminar
	Charms
	Chesterfield
	Chunghwa
	Clas-Mild
	Classic-Filter-Kings
	Clavo
	Cleopatra
	Club
	Club-Mild
	Cohiba
	Cool
	Country
	Craven-A
	Crossroads
	Crystal
	Dakota
	Davidoff
	Deluxe-Tenor
	Derby
	Djarum-Black
	Djarum-Vanilla
	Dji-Sam-Soe-234
	Dominant
	Doral
	Double-Happiness
	Du-Maurier
	Duke
	Dunhill
	Eclipse
	Elita
	Embassy
	Envio-Mild
	Ernte-23
	Esse
	Eve
	Everest
	Extreme-Mild
	f6
	Fatima
	Fellas-Mild
	Fix-Mild
	Fixation
	Flair
	Flake
	Fortuna
	Four-Square
	FS1
	Galan
	Garni
	Gauloises
	Geo-Mild
	Gitanes
	GL
	Gold-Flake
	Golden-Bat
	GT
	Gudang-Garam
	HB
	Hits-Mild
	Hongtashan
	Hope
	India-Kings
	Insignia
	Intro
	Java
	Jazy-Mild
	Joged
	Player's
	June
	Karo
	Kent
	King's
	Kool
	Krong-Thip
	L&M
	L.A.-Lights
	Lambert-&-Butler
	Lark
	LD
	Legend
	Liggett-Select
	Lips
	Longbeach
	Lucky-Strike
	Main
	Marlboro
	Maraton
	Masis
	Master-Mild
	Matra
	Maverick
	Max
	Maxus
	Mayfair
	MayPole
	Memphis
	Merit
	Mevius
	Mild-Formula
	Minak-Djinggo
	Misty
	Mocne
	Moments
	Mondial
	More
	MS
	Muratti
	Natural-American-Spirit
	Navy-Cut
	Neo-Mild
	Neslite
	Newport
	Next
	Nikki-Super
	Niko-International
	Nil
	Niu-Niu
	NO.10
	Noblesse
	North-Pole
	NOY
	Nuu-Mild
	One-Mild
	Pall-Mall
	Panama
	Parisienne
	Parliament
	Peace
	Pensil-Mas
	Peter-Stuyvesant
	Pianissimo-Peche
	Platinum
	Players
	Polo-Mild
	Popularne
	Prima
	Prince
	Pueblo
	Pundimas
	Pyramid
	Rambler
	Rawit
	Red-&-White
	Red-Mild
	Regal
	Regent
	Relax-Mild
	Richmond
	Romeo-y-Julieta
	Rothmans
	Royal
	Saat
	Salem
	Sampoerna-Hijau
	Sakura
	Scissors
	Score-Mild
	Sejati
	Senior-Service
	Seven-Stars
	Shaan
	Silk-Cut
	Slic-Mild
	Smart
	Sobranie
	Special-Extra-Filter
	ST-Dupont
	Star-Mild
	State-Express-555
	Sterling
	Strand
	Style
	Superkings
	Surya-Pro-Mild
	Sweet-Afton
	Taj-Chhap-Deluxe
	Tali-Jagat
	Tareyton
	Ten-Mild
	Thang-Long
	Time
	Tipper
	True
	U-Mild
	Ultra-Special
	Uno-Mild
	Up-Mild
	Urban-Mild
	Vantage
	Vegas-Mild
	Vogue
	Viceroy
	Virginia-Slims
	Viper
	West
	Wills-Navy-Cut
	Winfield
	Win-Mild
	Winston
	Wismilak
	Woodbine
	X-Mild
	Ziganov
	Zhongnanhai
);

my @petfood_brands = qw(
	Affinity
	Almo-nature
	Animonda
	Brekkies
	Canaillou
	Carnilove
	Cesar
	Compy
	Coshida
	Delikuit
	Dreamies
	Edgard-cooper
	Feringa
	Feringa-mit-viel-liebe-wie-hausgemacht
	Fido
	Friskies
	Frolic
	Greenies
	Hill-s
	Hills
	Iams
	Jacky
	Josera
	Juliet
	Kitekat
	Luckylou
	Lycat
	Lydog
	Monge
	Nutrivet
	Orijen
	Pedigree
	Perfect-fit
	Platinum
	Premiere
	Purina
	Purina-one
	Purizon
	Real-nature
	Riga
	Rinti
	Royal-canin
	Saphir
	Schesir
	Select-gold
	Sheba
	Tetra
	Tom-co
	Trixie
	Ultima
	Versele-laga
	Virbac
	Vitakraft
	Waltham
	Whiskas
	Wild-freedom
	Winston
	Yarrah
	Zooroyal
);

my @beauty_brands = qw(
	A-derma
	Acorelle
	Adidas
	Aleyria-cosmetiques
	Alix-de-faure
	Alterra
	Alverde
	Alverde-naturkosmetik
	Aquafresh
	Aroma-zone
	Arrow
	Aussie
	Aveeno
	Avene
	Avon
	Axe
	Babylove
	Balea
	Balea-med
	Balea-men
	Babaria
	Barnangen
	Batiste
	Beiersdorf
	Bio-naia
	Biocura
	Bioderma
	Biogaran
	Biolane
	Biopha
	Biotherm
	Blend-a-med
	Boiron
	Bourjois
	Briochin
	Brut
	By-u
	Byphasse
	Cadum
	Cattier
	Caudalie
	Cd
	Centifolia
	Cerave
	Cetaphil
	Chanel
	Cien
	Clarins
	Clinique
	Colgate
	Colgate-palmolive
	Cooper
	Corine-de-farme
	Coslys
	Cosmia
	Cosmia-baby
	Cosmia-bio
	Cosmo-naturel
	Cottage
	Cream-ly
	Deliplus
	Dentalux
	Dentamyl
	Dermaclay
	Dermophil
	Dessange
	Dettol
	Diadermine
	Dior
	Dontodent
	Dop
	Douce-nature
	Dove
	Dr-hauschka
	Ducray
	Durex
	Eau-thermale-avene
	q
	Elmex
	Elseve
	Energie-fruit
	Essence
	Essie
	Eucerin
	Eugene-perma
	Evoluderm
	Fa
	Florame
	Fluocaril
	For-women
	Fragonard
	Franck-provost
	Fructis
	Furterer
	Garnier
	Garnier-fructis
	Garnier-skinactive
	Gemey-maybelline
	Gillette
	Gifrer
	Gsk
	Guerlain
	Gum
	Head-shoulders
	Henkel
	Herbal-essences
	Huggies
	I-am
	Inell
	Instituto-espanol
	Integral-8
	John-frieda
	Johnson
	Johnson-johnson
	Jonzac
	Kiko
	Keranove
	Kerastase
	Kiehl-s
	Klorane
	L-arbre-vert
	L-occitane
	L-occitane-en-provence
	L-oreal
	L-oreal-men-expert
	L-oreal-paris
	L-oreal-professionnel
	La-roche-posay
	Labell
	Labello
	Laboratoires-gilbert
	Lacura
	Laino
	Lascad
	Lavera
	Lavera-naturkosmetik
	Le-chat
	Le-comptoir-du-bain
	Le-petit-marseillais
	Le-petit-olivier
	Les-cosmetiques
	Les-cosmetiques-design-paris
	Les-savons-d-orely
	Lifebuoy
	Listerine
	Logodent
	Logona
	Love-beauty-and-planet
	Loreal
	Loreal-paris
	Lovea
	Lush
	Maitre-savon-de-marseille
	Manava
	Marius-fabre
	Maybelline
	Mennen
	Meridol
	Mixa
	Mixa-bebe
	Mixa-solaire
	Mkl
	Monsavon
	Mustela
	Mylan
	N-a-e
	Narta
	Natessance
	Natura-siberica
	Nectar-of-beauty
	Nectar-of-nature
	Neutrogena
	Nivea
	Nivea-men
	Nivea-sun
	Nocibe
	Novexpert
	Nuxe
	Nyx
	Ogx
	Old-spice
	Ombia
	Original-source
	P-g
	Palette
	Palmer-s
	Palmolive
	Pampers
	Pantene
	Pantene-pro-v
	Parodontax
	Persavon
	Persil
	Petrole-hahn
	Pierre-fabre
	Pierre-fabre-oral-care
	Playboy
	Pantene
	Pranarom
	Procter-gamble
	Puressentiel
	Rampal-latour
	Revlon
	Revolution
	Rexona
	Rexona-men
	Rimmel
	Rituals
	Roge-cavailles
	Roger-gallet
	Saforelle
	Saint-algue
	Sanex
	Sanoflore
	Sanogyl
	Sanytol
	Schauma
	Schmidt-s
	Scholl
	Schwarzkopf
	Schwarzkopf-henkel
	Sebamed
	Secrets-de-provence
	Sensodyne
	Sephora
	Shiseido
	Signal
	Skip
	So-bio
	So-bio-etic
	Sonett
	Sooa
	Sun-dance
	Sundance
	Svr
	Syoss
	Taft
	Tahiti
	Teraxyl
	The-body-shop
	The-ordinary
	Timotei
	Today
	Tresemme
	Ultra-doux
	Uriage
	Ushuaia
	Vademecum
	Vaseline
	Veet
	Venus
	Vivelle-dop
	Wella
	White-now
	Williams
	Ysiance
	Yves-rocher
	Yves-saint-laurent
	Zendium
	Zenzitude
);

my %baby_food_brands = ();

foreach my $brand (@baby_food_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$baby_food_brands{$brandid} = 1;

}

my %cigarette_brands = ();

foreach my $brand (@cigarette_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$cigarette_brands{$brandid} = 1;

}

my %petfood_brands = ();

foreach my $brand (@petfood_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$petfood_brands{$brandid} = 1;

}

my %beauty_brands = ();

foreach my $brand (@beauty_brands) {

	my $brandid = get_string_id_for_lang("no_language", $brand);
	$beauty_brands{$brandid} = 1;

}

=head1 FUNCTIONS

=head2 detect_categories( PRODUCT_REF )

Detects some categories like baby milk, baby food and cigarettes from other fields
such as brands, product name, generic name and ingredients.

=cut

sub detect_categories ($product_ref) {

	# match on fr product name, generic name, ingredients
	my $match_fr = "";

	(defined $product_ref->{product_name}) and $match_fr .= " " . $product_ref->{product_name};
	(defined $product_ref->{product_name_fr}) and $match_fr .= "  " . $product_ref->{product_name_fr};

	(defined $product_ref->{generic_name}) and $match_fr .= " " . $product_ref->{generic_name};
	(defined $product_ref->{generic_name_fr}) and $match_fr .= "  " . $product_ref->{generic_name_fr};

	(defined $product_ref->{ingredients_text}) and $match_fr .= " " . $product_ref->{ingredients_text};
	(defined $product_ref->{ingredients_text_fr}) and $match_fr .= "  " . $product_ref->{ingredients_text_fr};

	# try to identify baby milks

	if ($match_fr
		=~ /lait ([^,-]* )?(suite|croissance|infantile|bébé|bebe|nourrisson|nourisson|age|maternise|maternisé)/i)
	{
		if (not has_tag($product_ref, "categories", "en:baby-milks")) {
			push @{$product_ref->{data_quality_warnings_tags}},
				"en:detected-category-from-name-and-ingredients-may-be-missing-baby-milks";
		}
	}

	if (defined $product_ref->{brands_tags}) {
		foreach my $brandid (@{$product_ref->{brands_tags}}) {
			if (defined $baby_food_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-baby-foods");
			}
			if (defined $cigarette_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-cigarettes");
			}
			if (defined $petfood_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-pet-foods");
			}
			if (defined $beauty_brands{$brandid}) {
				add_tag($product_ref, "data_quality_info", "en:detected-category-from-brand-beauty");
			}
		}
	}

	return;
}

=head2 check_nutrition_grades( PRODUCT_REF )

Compares the nutrition score and nutrition grade (Nutri-Score) we have computed with
the score and grade provided by manufacturers.

=cut

sub check_nutrition_grades ($product_ref) {

	if ((defined $product_ref->{nutrition_grade_fr_producer}) and (defined $product_ref->{nutrition_grade_fr})) {

		if ($product_ref->{nutrition_grade_fr_producer} eq $product_ref->{nutrition_grade_fr}) {
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-grade-fr-producer-same-ok";
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-grade-fr-producer-mismatch-nok";
		}
	}

	if (    (defined $product_ref->{nutriments})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr-producer"})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr"}))
	{

		if ($product_ref->{nutriments}{"nutrition-score-fr-producer"} eq
			$product_ref->{nutriments}{"nutrition-score-fr"})
		{
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-score-fr-producer-same-ok";
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-score-fr-producer-mismatch-nok";
		}
	}

	return;
}

=head2 check_carbon_footprint( PRODUCT_REF )

Checks related to the carbon footprint computed from ingredients analysis.

=cut

sub check_carbon_footprint ($product_ref) {

	if (defined $product_ref->{nutriments}) {

		if ((defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and not(defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"}))
		{
			push @{$product_ref->{data_quality_info_tags}},
				"en:carbon-footprint-from-meat-or-fish-but-not-from-known-ingredients";
		}
		if (    (not defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"}))
		{
			push @{$product_ref->{data_quality_info_tags}},
				"en:carbon-footprint-from-known-ingredients-but-not-from-meat-or-fish";
		}
		if (
				(defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			and ($product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"}
				> $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			)
		{
			push @{$product_ref->{data_quality_warnings_tags}},
				"en:carbon-footprint-from-known-ingredients-less-than-from-meat-or-fish";
		}
		if (
				(defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			and ($product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"}
				< $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			)
		{
			push @{$product_ref->{data_quality_info_tags}},
				"en:carbon-footprint-from-known-ingredients-more-than-from-meat-or-fish";
		}
	}

	return;
}

=head2 check_nutrition_data_energy_computation ( PRODUCT_REF )

Checks related to the nutrition facts values.

In particular, checks for obviously invalid values (e.g. more than 105 g of any nutrient for 100 g / 100 ml).
105 g is used instead of 100 g, because for some liquids, 100 ml can weight more than 100 g.

=cut

# Nutrients to energy conversion
# Currently only supporting Europe's method (similar to US and Canada 4-4-9, 4-4-9-7 and 4-4-9-7-2)

my %energy_from_nutrients = (
	europe => {
		carbohydrates_minus_polyols => {kj => 17, kcal => 4},
		polyols_minus_erythritol => {kj => 10, kcal => 2.4},
		proteins => {kj => 17, kcal => 4},
		fat => {kj => 37, kcal => 9},
		salatrim => {kj => 25, kcal => 6},    # no corresponding nutrients in nutrient tables?
		alcohol => {kj => 29, kcal => 7},
		organic_acids => {kj => 13, kcal => 3},    # no corresponding nutrients in nutrient tables?
		fiber => {kj => 8, kcal => 2},
		erythritol => {kj => 0, kcal => 0},
	},
);

sub check_nutrition_data_energy_computation ($product_ref) {

	my $nutriments_ref = $product_ref->{nutriments};

	if (not defined $nutriments_ref) {
		return;
	}

	# Different countries allow different ways to determine energy
	# One way is to compute energy from other nutrients
	# We can thus try to use energy as a key to verify other nutrients

	# See https://esha.com/blog/calorie-calculation-country/
	# and https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32011R1169&from=FR Appendix XIV

	foreach my $unit ("kj", "kcal") {

		my $specified_energy = $nutriments_ref->{"energy-${unit}_value"};
		# We need at a minimum carbohydrates, fat and proteins to be defined to compute
		# energy.
		if (    (defined $specified_energy)
			and (defined $nutriments_ref->{"carbohydrates_value"})
			and (defined $nutriments_ref->{"fat_value"})
			and (defined $nutriments_ref->{"proteins_value"}))
		{

			# Compute the energy from other nutrients
			my $computed_energy = 0;
			foreach my $nid (keys %{$energy_from_nutrients{europe}}) {

				my $energy_per_gram = $energy_from_nutrients{europe}{$nid}{$unit};
				my $grams = 0;
				# handles nutriment1__minus__nutriment2 case
				if ($nid =~ /_minus_/) {
					my $nid_minus = $';
					$nid = $`;

					# If we are computing carbohydrates minus polyols, and we do not have a value for polyols
					# but we have a value for erythritol (which is a polyol), then we need to remove erythritol
					if (($nid_minus eq "polyols") and (not defined $product_ref->{nutriments}{$nid_minus . "_value"})) {
						$nid_minus = "erythritol";
					}
					# Similarly for polyols minus erythritol
					if (($nid eq "polyols") and (not defined $product_ref->{nutriments}{$nid . "_value"})) {
						$nid = "erythritol";
					}

					$grams -= $product_ref->{nutriments}{$nid_minus . "_value"} || 0;
				}
				$grams += $product_ref->{nutriments}{$nid . "_value"} || 0;
				$computed_energy += $grams * $energy_per_gram;
			}

			# following error/warning should be ignored for some categories
			# for example, lemon juices containing organic acid, it is forbidden to display organic acid in nutrition tables but
			# organic acid contributes to the total energy calculation
			my ($ignore_energy_calculated_error, $category_id)
				= get_inherited_property_from_categories_tags($product_ref, "ignore_energy_calculated_error:en");

			if (
				(
					not((defined $ignore_energy_calculated_error) and ($ignore_energy_calculated_error eq 'yes'))
					# consider only when energy is high enough to minimize false positives (issue #7789)
					# consider either computed_energy or energy input by contributor, to avoid when the energy is 5, but it should be 1500
					and (
						(($unit eq "kj") and (($specified_energy > 55) or ($computed_energy > 55)))
						or (    ($unit eq "kcal")
							and (($specified_energy > 13) or ($computed_energy > 13)))
					)
				)
				)
			{
				# Compare to specified energy value with a tolerance of 30% + an additiontal tolerance of 5
				if (   ($computed_energy < ($specified_energy * 0.7 - 5))
					or ($computed_energy > ($specified_energy * 1.3 + 5)))
				{
					# we have a quality problem
					push @{$product_ref->{data_quality_errors_tags}},
						"en:energy-value-in-$unit-does-not-match-value-computed-from-other-nutrients";
				}

				# Compare to specified energy value with a tolerance of 15% + an additiontal tolerance of 5
				if (   ($computed_energy < ($specified_energy * 0.85 - 5))
					or ($computed_energy > ($specified_energy * 1.15 + 5)))
				{
					# we have a quality warning
					push @{$product_ref->{data_quality_warnings_tags}},
						"en:energy-value-in-$unit-may-not-match-value-computed-from-other-nutrients";
				}
			}

			$nutriments_ref->{"energy-${unit}_value_computed"} = $computed_energy;
		}
		else {
			delete $nutriments_ref->{"energy-${unit}_value_computed"};
		}
	}

	return;
}

=head2 check_nutrition_data( PRODUCT_REF )

Checks related to the nutrition facts values.

In particular, checks for obviously invalid values (e.g. more than 105 g of any nutrient for 100 g / 100 ml).
105 g is used instead of 100 g, because for some liquids, 100 ml can weight more than 100 g.

=cut

sub check_nutrition_data ($product_ref) {

	if ((defined $product_ref->{multiple_nutrition_data}) and ($product_ref->{multiple_nutrition_data} eq 'on')) {

		push @{$product_ref->{data_quality_info_tags}}, "en:multiple-nutrition-data";

		if ((defined $product_ref->{not_comparable_nutrition_data}) and $product_ref->{not_comparable_nutrition_data}) {
			push @{$product_ref->{data_quality_info_tags}}, "en:not-comparable-nutrition-data";
		}
	}
	my $is_dried_product = has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated");

	my $nutrition_data_prepared
		= defined $product_ref->{nutrition_data_prepared} && $product_ref->{nutrition_data_prepared} eq 'on';
	my $no_nutrition_data = defined $product_ref->{no_nutrition_data} && $product_ref->{no_nutrition_data} eq 'on';
	my $nutrition_data = defined $product_ref->{nutrition_data} && $product_ref->{nutrition_data} eq 'on';

	$log->debug("nutrition_data_prepared: " . $nutrition_data_prepared) if $log->debug();

	if ($no_nutrition_data) {
		push @{$product_ref->{data_quality_info_tags}}, "en:no-nutrition-data";
	}
	else {
		if ($nutrition_data_prepared) {
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-data-prepared";

			if (not $is_dried_product) {
				push @{$product_ref->{data_quality_warnings_tags}},
					"en:nutrition-data-prepared-without-category-dried-products-to-be-rehydrated";
			}
		}

		# catch serving_size = "serving", regardless of setting (per 100g or per serving)
		if (    (defined $product_ref->{serving_size})
			and ($product_ref->{serving_size} ne "")
			and ($product_ref->{serving_size} !~ /\d/))
		{
			push @{$product_ref->{data_quality_errors_tags}}, "en:serving-size-is-missing-digits";
		}
		if (    $nutrition_data
			and (defined $product_ref->{nutrition_data_per})
			and ($product_ref->{nutrition_data_per} eq 'serving'))
		{
			if ((not defined $product_ref->{serving_size}) or ($product_ref->{serving_size} eq '')) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-data-per-serving-missing-serving-size";
			}
			elsif ($product_ref->{serving_quantity} eq "0") {
				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-data-per-serving-serving-quantity-is-0";
			}
		}
	}

	my $has_prepared_data = 0;

	if (defined $product_ref->{nutriments}) {

		my $nid_n = 0;
		my $nid_zero = 0;
		my $nid_non_zero = 0;

		my $total = 0;
		# variables to check if there are 3 or more duplicates in nutriments
		my @major_nutriments_values = ();
		my %nutriments_values_occurences = ();

		if (    (defined $product_ref->{nutriments}{"energy-kcal_value"})
			and (defined $product_ref->{nutriments}{"energy-kj_value"}))
		{

			# energy in kcal greater than in kj
			if ($product_ref->{nutriments}{"energy-kcal_value"} > $product_ref->{nutriments}{"energy-kj_value"}) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-greater-than-in-kj";

				# additionally check if kcal value and kj value are reversed. Exact opposite condition as next error below
				if (
					(
						$product_ref->{nutriments}{"energy-kcal_value"}
						> 3.7 * $product_ref->{nutriments}{"energy-kj_value"} - 2
					)
					and ($product_ref->{nutriments}{"energy-kcal_value"}
						< 4.7 * $product_ref->{nutriments}{"energy-kj_value"} + 2)
					)
				{
					push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-and-kj-are-reversed";
				}
			}

			# check energy in kcal is ~ 4.2 (+/- 0.5) energy in kj
			#   +/- 2 to avoid false positives due to rounded values below 2 Kcal.
			#   Eg. 1.49 Kcal -> 6.26 KJ in reality, can be rounded by the producer to 1 Kcal -> 6 KJ.
			if (
				(
					$product_ref->{nutriments}{"energy-kj_value"}
					< 3.7 * $product_ref->{nutriments}{"energy-kcal_value"} - 2
				)
				or ($product_ref->{nutriments}{"energy-kj_value"}
					> 4.7 * $product_ref->{nutriments}{"energy-kcal_value"} + 2)
				)
			{
				push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-does-not-match-value-in-kj";
			}
		}

		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			$log->debug("nid: " . $nid . ": " . $product_ref->{nutriments}{$nid}) if $log->is_debug();

			if ($nid =~ /_prepared_100g$/ && $product_ref->{nutriments}{$nid} > 0) {
				$has_prepared_data = 1;
			}

			if ($nid =~ /_100g/) {

				my $nid2 = $`;
				$nid2 =~ s/_/-/g;

				if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid} > 105)) {

					push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-105-$nid2";
				}

				if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid} > 1000)) {

					push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-1000-$nid2";
				}
				# fruits vegetables estimate is a computed value, it should not count for empty / non-empty values
				if ($nid !~ /fruits-vegetables-nuts-estimate-from-ingredients/) {
					if ($product_ref->{nutriments}{$nid} == 0) {
						$nid_zero++;
					}
					else {
						$nid_non_zero++;
					}
				}
				# negative value in nutrition table, exclude key containing "nutrition-score" as they can be negative
				if (($product_ref->{nutriments}{$nid} < 0) and (index($nid, "nutrition-score") == -1)) {
					push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-negative-$nid2";
				}
			}

			$nid_n++;

			if (    (defined $product_ref->{nutriments}{$nid . "_100g"})
				and (($nid eq 'fat') or ($nid eq 'carbohydrates') or ($nid eq 'proteins') or ($nid eq 'salt')))
			{
				$total += $product_ref->{nutriments}{$nid . "_100g"};
			}

			# variables to check if there are 3 or more duplicates in nutriments
			if (
				(
					   ($nid eq 'fat_100g')
					or ($nid eq 'saturated-fat_100g')
					or ($nid eq 'carbohydrates_100g')
					or ($nid eq 'sugars_100g')
					or ($nid eq 'fiber_100g')
					or ($nid eq 'proteins_100g')
					or ($nid eq 'salt_100g')
					or ($nid eq 'sodium_100g')
				)
				and ($product_ref->{nutriments}{$nid} > 1)
				)
			{
				push(@major_nutriments_values, $product_ref->{nutriments}{$nid});
			}

		}

		# create a hash key: nutriment value, value: number of occurence
		foreach my $nutriment_value (@major_nutriments_values) {
			if (exists($nutriments_values_occurences{$nutriment_value})) {
				$nutriments_values_occurences{$nutriment_value}++;
			}
			else {
				$nutriments_values_occurences{$nutriment_value} = 1;
			}
		}
		# raise warning if there are 3 or more duplicates in nutriments
		foreach my $keys (keys %nutriments_values_occurences) {
			if ($nutriments_values_occurences{$keys} > 2) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-3-or-more-values-are-identical";
				last;
			}
		}

		if ($total > 105) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-total-over-105";
		}
		if ($total > 1000) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-total-over-1000";
		}

		if (    (defined $product_ref->{nutriments}{"energy_100g"})
			and ($product_ref->{nutriments}{"energy_100g"} > 3800))
		{
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-3800-energy";
		}

		if (($nid_non_zero == 0) and ($nid_zero > 0) and ($nid_zero == $nid_n)) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:all-nutrition-values-are-set-to-0";
		}

		if (
			(defined $product_ref->{nutriments}{"carbohydrates_100g"})
			and (
				(
					(
						(defined $product_ref->{nutriments}{"sugars_100g"}) ? $product_ref->{nutriments}{"sugars_100g"}
						: 0
					) + (
						(defined $product_ref->{nutriments}{"starch_100g"}) ? $product_ref->{nutriments}{"starch_100g"}
						: 0
					)
				) > ($product_ref->{nutriments}{"carbohydrates_100g"}) + 0.001
			)
			)
		{

			push @{$product_ref->{data_quality_errors_tags}},
				"en:nutrition-sugars-plus-starch-greater-than-carbohydrates";
		}

		# sum of nutriments that compose sugar can not be greater than sugar value
		if (
			(defined $product_ref->{nutriments}{sugars_100g})
			and (
				(
					(
						(defined $product_ref->{nutriments}{fructose_100g}) ? $product_ref->{nutriments}{fructose_100g}
						: 0
					) + (
						(defined $product_ref->{nutriments}{glucose_100g}) ? $product_ref->{nutriments}{glucose_100g}
						: 0
					) + (
						(defined $product_ref->{nutriments}{maltose_100g}) ? $product_ref->{nutriments}{maltose_100g}
						: 0
					) + (
						(defined $product_ref->{nutriments}{lactose_100g}) ? $product_ref->{nutriments}{lactose_100g}
						: 0
					) + (
						(defined $product_ref->{nutriments}{sucrose_100g}) ? $product_ref->{nutriments}{sucrose_100g}
						: 0
					)
				) > ($product_ref->{nutriments}{sugars_100g}) + 0.001
			)
			)
		{

			push @{$product_ref->{data_quality_errors_tags}},
				"en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars";
		}

		if (
			(
				(defined $product_ref->{nutriments}{"saturated-fat_100g"})
				? $product_ref->{nutriments}{"saturated-fat_100g"}
				: 0
			)
			> (((defined $product_ref->{nutriments}{"fat_100g"}) ? $product_ref->{nutriments}{"fat_100g"} : 0) + 0.001)
			)
		{

			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-saturated-fat-greater-than-fat";

		}

		# Too small salt value? (e.g. g entered in mg)
		# warning for salt < 0.1 was removed because it was leading to too much false positives (see #9346)
		if ((defined $product_ref->{nutriments}{"salt_100g"}) and ($product_ref->{nutriments}{"salt_100g"} > 0)) {

			if ($product_ref->{nutriments}{"salt_100g"} < 0.001) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-under-0-001-g-salt";
			}
			elsif ($product_ref->{nutriments}{"salt_100g"} < 0.01) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-under-0-01-g-salt";
			}
		}

		# some categories have expected nutriscore grade - push data quality error if calculated nutriscore grade differs from expected nutriscore grade or if it is not calculated
		my ($expected_nutriscore_grade, $category_id)
			= get_inherited_property_from_categories_tags($product_ref, "expected_nutriscore_grade:en");

		if (
			# exclude error if nutriscore cannot be calculated due to missing nutrients information (see issue #9297)
			($product_ref->{nutriscore}{2023}{nutrients_available} == 1)
			# we expect single letter a, b, c, d, e for nutriscore grade in the taxonomy. Case insensitive (/i).
			and (defined $expected_nutriscore_grade)
			and (($expected_nutriscore_grade =~ /^([a-e]){1}$/i))
			# nutriscore calculated but unexpected nutriscore grade
			and (defined $product_ref->{nutrition_grade_fr})
			and ($product_ref->{nutrition_grade_fr} ne $expected_nutriscore_grade)
			)
		{
			push @{$product_ref->{data_quality_errors_tags}},
				"en:nutri-score-grade-from-category-does-not-match-calculated-grade";
		}

		# some categories have an expected ingredient - push data quality error if ingredient differs from expected ingredient
		# note: we currently support only 1 expected ingredient
		my ($expected_ingredients, $category_id2)
			= get_inherited_property_from_categories_tags($product_ref, "expected_ingredients:en");

		if ((defined $expected_ingredients)) {
			$expected_ingredients = canonicalize_taxonomy_tag("en", "ingredients", $expected_ingredients);
			my $number_of_ingredients = (defined $product_ref->{ingredients}) ? @{$product_ref->{ingredients}} : 0;

			if ($number_of_ingredients == 0) {
				push @{$product_ref->{data_quality_warnings_tags}},
					"en:ingredients-single-ingredient-from-category-missing";
			}
			elsif (
				# more than 1 ingredient
				($number_of_ingredients > 1)
				# ingredient different than expected ingredient
				or not(is_a("ingredients", $product_ref->{ingredients}[0]{id}, $expected_ingredients))
				)
			{
				push @{$product_ref->{data_quality_errors_tags}},
					"en:ingredients-single-ingredient-from-category-does-not-match-actual-ingredients";
			}
		}
	}
	$log->debug("has_prepared_data: " . $has_prepared_data) if $log->debug();

	# issue 1466: Add quality facet for dehydrated products that are missing prepared values
	if ($is_dried_product && ($no_nutrition_data || !($nutrition_data_prepared && $has_prepared_data))) {
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated";
	}

	return;
}

=head2 compare_nutrition_facts_with_products_from_the_same_category( PRODUCT_REF )

Check that the product nutrition facts are comparable to other products from the same category.

Compare with the most specific category that has enough products to compute stats.

=cut

sub compare_nutrition_facts_with_products_from_same_category ($product_ref) {

	my $categories_nutriments_ref = $categories_nutriments_per_country{"world"};

	$log->debug("compare_nutrition_facts_with_products_from_same_category - start") if $log->debug();

	return if not defined $product_ref->{nutriments};
	return if not defined $product_ref->{categories_tags};

	my $i = @{$product_ref->{categories_tags}} - 1;

	while (
		($i >= 0)
		and not((defined $categories_nutriments_ref->{$product_ref->{categories_tags}[$i]})
			and (defined $categories_nutriments_ref->{$product_ref->{categories_tags}[$i]}{nutriments}))
		)
	{
		$i--;
	}
	# categories_tags has the most specific categories at the end

	if ($i >= 0) {

		my $specific_category = $product_ref->{categories_tags}[$i];
		$product_ref->{compared_to_category} = $specific_category;

		$log->debug("compare_nutrition_facts_with_products_from_same_category",
			{specific_category => $specific_category})
			if $log->is_debug();

		# check major nutrients
		my @nutrients = qw(energy fat saturated-fat carbohydrates sugars fiber proteins salt);

		foreach my $nid (@nutrients) {

			if (    (defined $product_ref->{nutriments}{$nid . "_100g"})
				and ($product_ref->{nutriments}{$nid . "_100g"} ne "")
				and (defined $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}))
			{

				# check if the value is in the range of the mean +- 3 * standard deviation
				# (for Gaussian distributions, this range contains 99.7% of the values)
				# note: we remove the bottom and top 5% before computing the std (to remove data errors that change the mean and std)
				# the computed std is smaller.
				# Too many values are outside mean +- 3 * std, try 4 * std

				$log->debug(
					"compare_nutrition_facts_with_products_from_same_category",
					{
						nid => $nid,
						product_100g => $product_ref->{nutriments}{$nid . "_100g"},
						category_100g => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"},
						category_std => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					}
				) if $log->is_debug();

				if (
					$product_ref->{nutriments}{$nid . "_100g"} < (
						$categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"}
							- 4 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					)
					)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:nutrition-value-very-low-for-category-" . $nid;
				}
				elsif (
					$product_ref->{nutriments}{$nid . "_100g"} > (
						$categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"}
							+ 4 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					)
					)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:nutrition-value-very-high-for-category-" . $nid;
				}
			}
		}
	}

	return;
}

sub calculate_digit_percentage ($text) {

	return 0.0 if not defined $text;

	my $tl = length($text);
	return 0.0 if $tl <= 0;

	my $dc = () = $text =~ /\d/g;
	return $dc / ($tl * 1.0);
}

=head2 check_ingredients( PRODUCT_REF )

Checks related to the ingredients list and ingredients analysis.

=cut

sub check_ingredients ($product_ref) {

	# spell corrected additives

	if ((defined $product_ref->{additives}) and ($product_ref->{additives} =~ /spell correction/)) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-spell-corrected-additives";
	}

	# Multiple languages in ingredient lists

	my $nb_languages = 0;

	if (defined $product_ref->{ingredients_text}) {
		($product_ref->{ingredients_text} =~ /\b(ingrédients|sucre|eau|sel|farine)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(sugar|salt|flour|milk)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(ingrediënten|suiker|zout|bloem)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(azucar|agua|harina)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(zutaten|Zucker|Salz|Wasser|Mehl)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(açúcar|farinha|água)\b/i) and $nb_languages++;
		($product_ref->{ingredients_text} =~ /\b(ingredienti|zucchero|farina|acqua)\b/i) and $nb_languages++;
	}

	if ($nb_languages > 1) {
		foreach my $max (5, 4, 3, 2, 1) {
			if ($nb_languages > $max) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-number-of-languages-above-$max";
			}
		}
		push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-number-of-languages-$nb_languages";
	}

	if ((defined $product_ref->{ingredients_n}) and ($product_ref->{ingredients_n} > 0)) {

		my $score = $product_ref->{unknown_ingredients_n} * 2 - $product_ref->{ingredients_n};

		foreach my $max (50, 40, 30, 20, 10, 5, 0) {
			if ($score > $max) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-unknown-score-above-$max";
				last;
			}
		}

		foreach my $max (100, 90, 80, 70, 60, 50) {
			if (($product_ref->{unknown_ingredients_n} / $product_ref->{ingredients_n}) >= ($max / 100)) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-$max-percent-unknown";
				last;
			}
		}
	}

	if (defined $product_ref->{ingredients_tags}) {

		my $max_length = 0;

		foreach my $ingredient_tag (@{$product_ref->{ingredients_tags}}) {
			my $length = length($ingredient_tag);
			$length > $max_length and $max_length = $length;
		}

		foreach my $max_length_threshold (50, 100, 200, 500, 1000) {

			if ($max_length > $max_length_threshold) {

				push @{$product_ref->{data_quality_warnings_tags}},
					"en:ingredients-ingredient-tag-length-greater-than-" . $max_length_threshold;

			}
		}
	}

	if (    (defined $product_ref->{ingredients_text})
		and (calculate_digit_percentage($product_ref->{ingredients_text}) > 0.3))
	{
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-over-30-percent-digits';
	}

	if (defined $product_ref->{languages_codes}) {

		foreach my $display_lc (keys %{$product_ref->{languages_codes}}) {

			my $ingredients_text_lc = "ingredients_text_" . ${display_lc};

			if (defined $product_ref->{$ingredients_text_lc}) {

				$log->debug("ingredients text", {quality => $product_ref->{$ingredients_text_lc}}) if $log->is_debug();

				if (calculate_digit_percentage($product_ref->{$ingredients_text_lc}) > 0.3) {
					push @{$product_ref->{data_quality_warnings_tags}},
						'en:ingredients-' . $display_lc . '-over-30-percent-digits';
				}

				if ($product_ref->{$ingredients_text_lc} =~ /,(\s*)$/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-ending-comma";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[aeiouy]{5}/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-5-vowels";
				}

				# Dutch and other languages can have 4 consecutive consonants
				if ($display_lc !~ /de|hr|nl|pl/) {
					if ($product_ref->{$ingredients_text_lc} =~ /[bcdfghjklmnpqrstvwxz]{5}/is) {

						push @{$product_ref->{data_quality_warnings_tags}},
							"en:ingredients-" . $display_lc . "-5-consonants";
					}
				}

				if ($product_ref->{$ingredients_text_lc} =~ /(.)\1{4,}/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-4-repeated-chars";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\$\€\£\¥\₩]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-currencies";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\@]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-arobase";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\!]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-exclamation-mark";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\?]/is) {

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-unexpected-chars-question-mark";
				}

				# French specific
				#if ($display_lc eq 'fr') {

				if ($product_ref->{$ingredients_text_lc}
					=~ /kcal|glucides|(dont sucres)|(dont acides gras)|(valeurs nutri)/is)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-includes-fr-nutrition-facts";
				}

				if ($product_ref->{$ingredients_text_lc}
					=~ /(à conserver)|(conditions de )|(à consommer )|(plus d'info)|consigne/is)
				{

					push @{$product_ref->{data_quality_warnings_tags}},
						"en:ingredients-" . $display_lc . "-includes-fr-instructions";
				}
				#}
			}

		}

	}

	my $agr_bio = qr/
		(ingrédients issus de l'Agriculture Biologique)
		|(aus biologischer Landwirtschaft)
		|(aus kontrolliert ökologischer Landwirtschaft)
		|(Zutaten aus ökol. Landwirtschaft)
	/x;

	if (    (defined $product_ref->{ingredients_text})
		and (($product_ref->{ingredients_text} =~ /$agr_bio/is) && !has_tag($product_ref, "labels", "en:organic")))
	{
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:organic-ingredients-but-no-organic-label';
	}

	return;
}

=head2 check_quantity( PRODUCT_REF )

Checks related to the quantity and serving quantity.

=cut

# Check quantity values. See https://en.wiki.openfoodfacts.org/Products_quantities
sub check_quantity ($product_ref) {

	# quantity contains "e" - might be an indicator that the user might have wanted to use "℮" \N{U+212E}
	# example: 650 g e
	if (
		(defined $product_ref->{quantity})
		# contains "kg e", or "g e", or "cl e", etc.
		and ($product_ref->{quantity} =~ /(?:[0-9]+\s*[kmc]?[gl]\s*e)/i)
		# contains the "℮" symbol
		and (not($product_ref->{quantity} =~ /\N{U+212E}/i))
		)
	{
		push @{$product_ref->{data_quality_info_tags}}, "en:quantity-contains-e";
	}

	if (    (defined $product_ref->{quantity})
		and ($product_ref->{quantity} ne "")
		and (not defined $product_ref->{product_quantity}))
	{
		push @{$product_ref->{data_quality_warnings_tags}}, "en:quantity-not-recognized";
	}

	if ((defined $product_ref->{product_quantity}) and ($product_ref->{product_quantity} ne "")) {
		if ($product_ref->{product_quantity} > 10 * 1000) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:product-quantity-over-10kg";

			if ($product_ref->{product_quantity} > 30 * 1000) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:product-quantity-over-30kg";
			}
		}
		if ($product_ref->{product_quantity} < 1) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:product-quantity-under-1g";
		}

		if ($product_ref->{quantity} =~ /\d\s?mg\b/i) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:product-quantity-in-mg";
		}
	}

	if ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} ne "")) {
		if ($product_ref->{serving_quantity} > 500) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-over-500g";
		}
		if ($product_ref->{serving_quantity} < 1) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-under-1g";
		}

		if ((defined $product_ref->{product_quantity}) and ($product_ref->{product_quantity} ne "")) {
			if ($product_ref->{serving_quantity} > $product_ref->{product_quantity}) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-over-product-quantity";
			}
			if ($product_ref->{serving_quantity} < $product_ref->{product_quantity} / 1000) {
				push @{$product_ref->{data_quality_warnings_tags}},
					"en:serving-quantity-less-than-product-quantity-divided-by-1000";
			}
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-defined-but-quantity-undefined";
		}

		if ($product_ref->{serving_size} =~ /\d\s?mg\b/i) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-size-in-mg";
		}
	}

	# serving size not recognized (undefined serving quantity)
	# serving_size = 10g -> serving_quantity = 10
	# serving_size = 10  -> serving_quantity will be undefined
	if (    (defined $product_ref->{serving_size})
		and ($product_ref->{serving_size} ne "")
		and (!defined $product_ref->{serving_quantity}))
	{
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:nutrition-data-per-serving-serving-quantity-is-not-recognized";
	}

	return;
}

=head2 check_categories( PRODUCT_REF )

Checks related to specific product categories.

Alcoholic beverages: check that there is an alcohol value in the nutrients.

=cut

sub check_categories ($product_ref) {

	# Check alcohol content
	if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
		if (!(defined $product_ref->{nutriments}{alcohol_value}) || $product_ref->{nutriments}{alcohol_value} == 0) {
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcoholic-beverages-category-without-alcohol-value';
		}
		if (has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
			# Product cannot be alcoholic and non-alcoholic
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcoholic-and-non-alcoholic-categories';
		}
	}

	if (    defined $product_ref->{nutriments}{alcohol_value}
		and $product_ref->{nutriments}{alcohol_value} > 0
		and not has_tag($product_ref, "categories", "en:alcoholic-beverages"))
	{

		push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcohol-value-without-alcoholic-beverages-category';
	}

	# Plant milks should probably not be dairies https://github.com/openfoodfacts/openfoodfacts-server/issues/73
	if (has_tag($product_ref, "categories", "en:plant-milks") and has_tag($product_ref, "categories", "en:dairies")) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:incompatible-categories-plant-milk-and-dairy";
	}

	return;
}

=head2 check_labels( PRODUCT_REF )

Checks related to specific product labels.

Vegan label: check that there is no non-vegan ingredient.

Vegetarian label: check that there is no non-vegetarian ingredient.

=cut

sub check_labels ($product_ref) {
	# this also include en:vegan that is a child of en:vegetarian
	if (defined $product_ref->{labels_tags} && has_tag($product_ref, "labels", "en:vegetarian")) {
		if (defined $product_ref->{ingredients}) {
			my @ingredients = @{$product_ref->{ingredients}};

			while (@ingredients) {

				# Remove and process the first ingredient
				my $ingredient_ref = shift @ingredients;
				my $ingredientid = $ingredient_ref->{id};

				# Add sub-ingredients at the beginning of the ingredients array
				if (defined $ingredient_ref->{ingredients}) {

					unshift @ingredients, @{$ingredient_ref->{ingredients}};
				}

				# some additives_classes (like thickener, for example) do not have the key-value vegan and vegetarian
				# it can be additives_classes that contain only vegan/vegetarian additives.
				# to avoid false-positive - instead of raising a warning (else below) we ignore additives_classes
				if (!exists_taxonomy_tag("additives_classes", $ingredientid)) {
					if (has_tag($product_ref, "labels", "en:vegan")) {
						# vegan
						if (defined $ingredient_ref->{"vegan"}) {
							if ($ingredient_ref->{"vegan"} eq 'no') {
								add_tag($product_ref, "data_quality_errors", "en:vegan-label-but-non-vegan-ingredient");
							}
							# else 'yes', 'maybe'
						}
						# no tag
						else {
							add_tag($product_ref, "data_quality_warnings",
								"en:vegan-label-but-could-not-confirm-for-all-ingredients");
						}
					}

					# vegetarian label condition is above
					if (defined $ingredient_ref->{"vegetarian"}) {
						if ($ingredient_ref->{"vegetarian"} eq 'no') {
							add_tag($product_ref, "data_quality_errors",
								"en:vegetarian-label-but-non-vegetarian-ingredient");
						}
						# else 'yes', 'maybe'
					}
					# no tag
					else {
						add_tag($product_ref, "data_quality_warnings",
							"en:vegetarian-label-but-could-not-confirm-for-all-ingredients");
					}
				}
			}
		}
	}

	return;
}

sub compare_nutriscore_with_value_from_producer ($product_ref) {

	if (
		(defined $product_ref->{nutriscore_score})
		and (defined $product_ref->{nutriscore_score_producer}
			and ($product_ref->{nutriscore_score} ne lc($product_ref->{nutriscore_score_producer})))
		)
	{
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:nutri-score-score-from-producer-does-not-match-calculated-score";
	}

	if (
		(defined $product_ref->{nutriscore_grade})
		and (defined $product_ref->{nutriscore_grade_producer}
			and ($product_ref->{nutriscore_grade} ne lc($product_ref->{nutriscore_grade_producer})))
		)
	{
		push @{$product_ref->{data_quality_warnings_tags}},
			"en:nutri-score-grade-from-producer-does-not-match-calculated-grade";
	}

	if (defined $product_ref->{nutriscore_grade}) {

		foreach my $grade ("a", "b", "c", "d", "e") {

			if (has_tag($product_ref, "labels", "en:nutriscore-grade-$grade")
				and (lc($product_ref->{nutriscore_grade}) ne $grade))
			{
				push @{$product_ref->{data_quality_warnings_tags}},
					"en:nutri-score-grade-from-label-does-not-match-calculated-grade";
			}
		}
	}

	return;
}

=head2 check_ingredients_percent_analysis( PRODUCT_REF )

Checks if we were able to analyze the minimum and maximum percent values for ingredients and sub-ingredients.

=cut

sub check_ingredients_percent_analysis ($product_ref) {

	if (defined $product_ref->{ingredients_percent_analysis}) {

		if ($product_ref->{ingredients_percent_analysis} < 0) {
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-percent-analysis-not-ok';
		}
		elsif ($product_ref->{ingredients_percent_analysis} > 0) {
			push @{$product_ref->{data_quality_info_tags}}, 'en:ingredients-percent-analysis-ok';
		}

	}

	return;
}

=head2 check_ingredients_with_specified_percent( PRODUCT_REF )

Check if all or almost all the ingredients have a specified percentage in the ingredients list.

=cut

sub check_ingredients_with_specified_percent ($product_ref) {

	if (defined $product_ref->{ingredients_with_specified_percent_n}) {

		if (    ($product_ref->{ingredients_with_specified_percent_n} > 0)
			and ($product_ref->{ingredients_with_unspecified_percent_n} == 0))
		{
			push @{$product_ref->{data_quality_info_tags}}, 'en:all-ingredients-with-specified-percent';
		}
		elsif ($product_ref->{ingredients_with_unspecified_percent_n} == 1) {
			push @{$product_ref->{data_quality_info_tags}}, 'en:all-but-one-ingredient-with-specified-percent';
		}

		if (    ($product_ref->{ingredients_with_specified_percent_n} > 0)
			and ($product_ref->{ingredients_with_specified_percent_sum} >= 90)
			and ($product_ref->{ingredients_with_unspecified_percent_sum} < 10))
		{
			push @{$product_ref->{data_quality_info_tags}},
				'en:sum-of-ingredients-with-unspecified-percent-lesser-than-10';
		}

		# Flag products where the sum of % is higher than 100
		if (    ($product_ref->{ingredients_with_specified_percent_n} > 0)
			and ($product_ref->{ingredients_with_specified_percent_sum} > 100))
		{
			push @{$product_ref->{data_quality_info_tags}},
				'en:sum-of-ingredients-with-specified-percent-greater-than-100';
		}

		if (    ($product_ref->{ingredients_with_specified_percent_n} > 0)
			and ($product_ref->{ingredients_with_specified_percent_sum} > 200))
		{
			push @{$product_ref->{data_quality_warnings_tags}},
				'en:sum-of-ingredients-with-specified-percent-greater-than-200';
		}

		# Percentage for ingredient is higher than 100% in extracted ingredients from the picture
		if ($product_ref->{ingredients_with_specified_percent_n} > 0) {
			foreach my $ingredient_id (@{$product_ref->{ingredients}}) {
				if (    (defined $ingredient_id->{percent})
					and ($ingredient_id->{percent} > 100))
				{
					push @{$product_ref->{data_quality_warnings_tags}},
						'en:ingredients-extracted-ingredient-from-picture-with-more-than-100-percent';
					last;
				}

			}
		}
	}

	return;
}

=head2 check_ecoscore_data( PRODUCT_REF )

Checks for data needed to compute the Eco-score.

=cut

sub check_ecoscore_data ($product_ref) {

	if (defined $product_ref->{ecoscore_data}) {

		foreach my $adjustment (sort keys %{$product_ref->{ecoscore_data}{adjustments}}) {

			if (defined $product_ref->{ecoscore_data}{adjustments}{$adjustment}{warning}) {
				my $warning = $adjustment . '-' . $product_ref->{ecoscore_data}{adjustments}{$adjustment}{warning};
				$warning =~ s/_/-/g;
				push @{$product_ref->{data_quality_warnings_tags}}, 'en:ecoscore-' . $warning;
			}
		}
	}

	# Extended Eco-Score data from impact estimator
	if (defined $product_ref->{ecoscore_extended_data}) {

		push @{$product_ref->{data_quality_info_tags}}, 'en:ecoscore-extended-data-computed';

		if (is_ecoscore_extended_data_more_precise_than_agribalyse($product_ref)) {
			push @{$product_ref->{data_quality_info_tags}}, 'en:ecoscore-extended-data-more-precise-than-agribalyse';
		}
		else {
			push @{$product_ref->{data_quality_info_tags}}, 'en:ecoscore-extended-data-less-precise-than-agribalyse';
		}
	}
	else {
		push @{$product_ref->{data_quality_info_tags}}, 'en:ecoscore-extended-data-not-computed';
	}

	return;
}

=head2 check_food_groups( PRODUCT_REF )

Add info tags about food groups.

=cut

sub check_food_groups ($product_ref) {

	for (my $level = 1; $level <= 3; $level++) {

		if (deep_exists($product_ref, "food_groups_tags", $level - 1)) {
			push @{$product_ref->{data_quality_info_tags}}, 'en:food-groups-' . $level . '-known';
		}
		else {
			push @{$product_ref->{data_quality_info_tags}}, 'en:food-groups-' . $level . '-unknown';
		}
	}

	return;
}

=head2 check_quality_food( PRODUCT_REF )

Run all quality checks defined in the module.

=cut

sub check_quality_food ($product_ref) {

	check_ingredients($product_ref);
	check_ingredients_percent_analysis($product_ref);
	check_ingredients_with_specified_percent($product_ref);
	check_nutrition_data($product_ref);
	check_nutrition_data_energy_computation($product_ref);
	compare_nutrition_facts_with_products_from_same_category($product_ref);
	check_nutrition_grades($product_ref);
	check_carbon_footprint($product_ref);
	check_quantity($product_ref);
	detect_categories($product_ref);
	check_categories($product_ref);
	check_labels($product_ref);
	compare_nutriscore_with_value_from_producer($product_ref);
	check_ecoscore_data($product_ref);
	check_food_groups($product_ref);

	return;
}

1;
