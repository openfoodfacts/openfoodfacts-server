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

use utf8;
use Modern::Perl '2017';
use Exporter qw(import);


BEGIN
{
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

use Log::Any qw($log);

=head1 HARDCODED BRAND LISTS

The module has 2 hardcoded lists of brands: @baby_food_brands and @cigarette_brands.

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

=head1 FUNCTIONS

=head2 detect_categories( PRODUCT_REF )

Detects some categories like baby milk, baby food and cigarettes from other fields
such as brands, product name, generic name and ingredients.

=cut

sub detect_categories ($) {

	my $product_ref = shift;

	# match on fr product name, generic name, ingredients
	my $match_fr = "";

	(defined $product_ref->{product_name}) and $match_fr .= " " . $product_ref->{product_name};
	(defined $product_ref->{product_name_fr}) and $match_fr .= "  " . $product_ref->{product_name_fr};

	(defined $product_ref->{generic_name}) and $match_fr .= " " . $product_ref->{generic_name};
	(defined $product_ref->{generic_name_fr}) and $match_fr .= "  " . $product_ref->{generic_name_fr};

	(defined $product_ref->{ingredients_text}) and $match_fr .= " " . $product_ref->{ingredients_text};
	(defined $product_ref->{ingredients_text_fr}) and $match_fr .= "  " . $product_ref->{ingredients_text_fr};


	# try to identify baby milks

	if ($match_fr =~ /lait ([^,-]* )?(suite|croissance|infantile|bébé|bebe|nourrisson|nourisson|age|maternise|maternisé)/i) {
		if (not has_tag($product_ref, "categories", "en:baby-milks")) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:detected-category-from-name-and-ingredients-may-be-missing-baby-milks";
		}
	}

	if (defined $product_ref->{brands_tags}) {
		foreach my $brandid (@{$product_ref->{brands_tags}}) {
			if (defined $baby_food_brands{$brandid}) {
				push @{$product_ref->{data_quality_info_tags}}, "en:detected-category-from-brand-baby-foods";
				last;
			}
		}
	}

	if (defined $product_ref->{brands_tags}) {
		foreach my $brandid (@{$product_ref->{brands_tags}}) {
			if (defined $cigarette_brands{$brandid}) {
				push @{$product_ref->{data_quality_info_tags}}, "en:detected-category-from-brand-cigarettes";
				last;
			}
		}
	}

	return;
}

=head2 check_nutrition_grades( PRODUCT_REF )

Compares the nutrition score and nutrition grade (Nutri-Score) we have computed with
the score and grade provided by manufacturers.

=cut

sub check_nutrition_grades($) {
	my $product_ref = shift;

	if ((defined $product_ref->{nutrition_grade_fr_producer}) and (defined $product_ref->{nutrition_grade_fr}) ) {

		if ($product_ref->{nutrition_grade_fr_producer} eq $product_ref->{nutrition_grade_fr}) {
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-grade-fr-producer-same-ok";
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-grade-fr-producer-mismatch-nok";
		}
	}

	if ((defined $product_ref->{nutriments})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr-producer"})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr"}) ) {

		if ($product_ref->{nutriments}{"nutrition-score-fr-producer"} eq $product_ref->{nutriments}{"nutrition-score-fr"}) {
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

sub check_carbon_footprint($) {
	my $product_ref = shift;

	if (defined $product_ref->{nutriments}) {

		if ((defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and not (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})) {
			push @{$product_ref->{data_quality_info_tags}}, "en:carbon-footprint-from-meat-or-fish-but-not-from-known-ingredients";
		}
		if ((not defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})) {
			push @{$product_ref->{data_quality_info_tags}}, "en:carbon-footprint-from-known-ingredients-but-not-from-meat-or-fish";
		}
		if ((defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			and ($product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"} > $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:carbon-footprint-from-known-ingredients-less-than-from-meat-or-fish";
		}
		if ((defined $product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"})
			and (defined $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})
			and ($product_ref->{nutriments}{"carbon-footprint-from-meat-or-fish_100g"} < $product_ref->{nutriments}{"carbon-footprint-from-known-ingredients_100g"})) {
			push @{$product_ref->{data_quality_info_tags}}, "en:carbon-footprint-from-known-ingredients-more-than-from-meat-or-fish";
		}
	}

	return;
}

=head2 check_nutrition_data( PRODUCT_REF )

Checks related to the nutrition facts values.

In particular, checks for obviously invalid values (e.g. more than 105 g of any nutrient for 100 g / 100 ml).
105 g is used instead of 100 g, because for some liquids, 100 ml can weight more than 100 g.

=cut

sub check_nutrition_data($) {
	my $product_ref = shift;

	if ((defined $product_ref->{multiple_nutrition_data}) and ($product_ref->{multiple_nutrition_data} eq 'on')) {

		push @{$product_ref->{data_quality_info_tags}}, "en:multiple-nutrition-data";

		if ((defined $product_ref->{not_comparable_nutrition_data}) and $product_ref->{not_comparable_nutrition_data}) {
			push @{$product_ref->{data_quality_info_tags}}, "en:not-comparable-nutrition-data";
		}
	}
	my $is_dried_product = has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated");

	my $nutrition_data_prepared = defined $product_ref->{nutrition_data_prepared} && $product_ref->{nutrition_data_prepared} eq 'on';
	my $no_nutrition_data = defined $product_ref->{no_nutrition_data} &&  $product_ref->{no_nutrition_data} eq 'on';
	my $nutrition_data = defined $product_ref->{nutrition_data} &&  $product_ref->{nutrition_data} eq 'on';

	$log->debug("nutrition_data_prepared: " . $nutrition_data_prepared) if $log->debug();

	if ( $no_nutrition_data ) {
		push @{$product_ref->{data_quality_info_tags}}, "en:no-nutrition-data";
	} else {
		if ( $nutrition_data_prepared ) {
			push @{$product_ref->{data_quality_info_tags}}, "en:nutrition-data-prepared";

			if (not $is_dried_product ) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-data-prepared-without-category-dried-products-to-be-rehydrated";
			}
		}
		if ($nutrition_data and (defined $product_ref->{nutrition_data_per}) and ($product_ref->{nutrition_data_per} eq 'serving')) {

			if ((not defined $product_ref->{serving_size}) or ($product_ref->{serving_size} eq '')) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-data-per-serving-missing-serving-size";
			}
			elsif ($product_ref->{serving_quantity} == 0) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-data-per-serving-serving-quantity-is-0";
			}
		}
	}

	my $has_prepared_data = 0;

	if (defined $product_ref->{nutriments}) {

		my $nid_n = 0;
		my $nid_zero = 0;

		my $total = 0;

		if ((defined $product_ref->{nutriments}{"energy-kcal_value"}) and (defined $product_ref->{nutriments}{"energy-kj_value"})) {
			
			# energy in kcal greater than in kj
			if ($product_ref->{nutriments}{"energy-kcal_value"} > $product_ref->{nutriments}{"energy-kj_value"}) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-greater-than-in-kj";
			}
			
			# check energy in kcal is ~ 4.2 energy in kj
			# only if kcal > 2 so that we don't flag (1 kcal - 5 kJ) as incorrect
			if (($product_ref->{nutriments}{"energy-kcal_value"} >= 2) and 
				(($product_ref->{nutriments}{"energy-kj_value"} < 3.5 *  $product_ref->{nutriments}{"energy-kcal_value"})
				or ($product_ref->{nutriments}{"energy-kj_value"} > 4.7 *  $product_ref->{nutriments}{"energy-kcal_value"}))) {
				push @{$product_ref->{data_quality_errors_tags}}, "en:energy-value-in-kcal-does-not-match-value-in-kj";
			}
		}

		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			$log->debug("nid: " . $nid . ": " . $product_ref->{nutriments}{$nid} ) if $log->is_debug();

			if ( $nid =~ /_prepared_100g$/ && $product_ref->{nutriments}{$nid} > 0) {
				$has_prepared_data = 1;
			}

			next if $nid =~ /_/;

			if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid . "_100g"} > 105)) {

				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-105-$nid";
			}

			if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid . "_100g"} > 1000)) {

				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-1000-$nid";
			}

			if ((defined $product_ref->{nutriments}{$nid . "_100g"})
				and ($product_ref->{nutriments}{$nid . "_100g"} == 0)) {
				$nid_zero++;
			}
			$nid_n++;

			if (($nid eq 'fat') or ($nid eq 'carbohydrates') or ($nid eq 'proteins') or ($nid eq 'salt')) {
				$total += $product_ref->{nutriments}{$nid . "_100g"};
			}
		}

		if ($total > 105) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-total-over-105";
		}
		if ($total > 1000) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-total-over-1000";
		}

		if ((defined $product_ref->{nutriments}{"energy_100g"})
			and ($product_ref->{nutriments}{"energy_100g"} > 3800)) {
			push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-value-over-3800-energy";
		}

		if (($nid_n >= 1) and ($nid_zero == $nid_n)) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-all-values-zero";
		}

		if ((defined $product_ref->{nutriments}{"carbohydrates_100g"}) and
			((((defined $product_ref->{nutriments}{"sugars_100g"}) ? $product_ref->{nutriments}{"sugars_100g"} : 0)
			+ ((defined $product_ref->{nutriments}{"starch_100g"}) ? $product_ref->{nutriments}{"starch_100g"} : 0))
			> ($product_ref->{nutriments}{"carbohydrates_100g"}) + 0.001)) {

				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-sugars-plus-starch-greater-than-carbohydrates";
		}

		if (((defined $product_ref->{nutriments}{"saturated-fat_100g"}) ? $product_ref->{nutriments}{"saturated-fat_100g"} : 0)
			> (((defined $product_ref->{nutriments}{"fat_100g"}) ? $product_ref->{nutriments}{"fat_100g"} : 0) + 0.001)) {

				push @{$product_ref->{data_quality_errors_tags}}, "en:nutrition-saturated-fat-greater-than-fat";

		}

		# Too small salt value? (e.g. g entered in mg)
		if ((defined $product_ref->{nutriments}{"salt_100g"}) and ($product_ref->{nutriments}{"salt_100g"} > 0)) {

			if ($product_ref->{nutriments}{"salt_100g"} < 0.001) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-under-0-001-g-salt";
			}
			elsif ($product_ref->{nutriments}{"salt_100g"} < 0.01) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-under-0-01-g-salt";
			}
			elsif ($product_ref->{nutriments}{"salt_100g"} < 0.1) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-under-0-1-g-salt";
			}
		}
	}
	$log->debug("has_prepared_data: " . $has_prepared_data) if $log->debug();

	# issue 1466: Add quality facet for dehydrated products that are missing prepared values
	if ( $is_dried_product && ( $no_nutrition_data || !( $nutrition_data_prepared && $has_prepared_data ) )  ) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated";
	}

	return;
}


=head2 compare_nutrition_facts_with_products_from_the_same_category( PRODUCT_REF )

Check that the product nutrition facts are comparable to other products from the same category.

Compare with the most specific category that has enough products to compute stats.

=cut

sub compare_nutrition_facts_with_products_from_same_category($) {
	my $product_ref = shift;

	my $categories_nutriments_ref = $categories_nutriments_per_country{"world"};

	$log->debug("compare_nutrition_facts_with_products_from_same_category - start") if $log->debug();

	return if not defined $product_ref->{nutriments};
	return if not defined $product_ref->{categories_tags};

	my $i = @{$product_ref->{categories_tags}} - 1;

	while (($i >= 0)
		and     not ((defined $categories_nutriments_ref->{$product_ref->{categories_tags}[$i]})
			and (defined $categories_nutriments_ref->{$product_ref->{categories_tags}[$i]}{nutriments}))) {
		$i--;
	}
	# categories_tags has the most specific categories at the end

	if ($i >= 0) {

		my $specific_category = $product_ref->{categories_tags}[$i];
		$product_ref->{compared_to_category} = $specific_category;

		$log->debug("compare_nutrition_facts_with_products_from_same_category" , { specific_category => $specific_category}) if $log->is_debug();

		# check major nutrients
		my @nutrients = qw(energy fat saturated-fat carbohydrates sugars fiber proteins salt);

		foreach my $nid (@nutrients) {

			if ((defined $product_ref->{nutriments}{$nid . "_100g"}) and ($product_ref->{nutriments}{$nid . "_100g"} ne "")
				and (defined $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"})) {

				# check if the value is in the range of the mean +- 3 * standard deviation
				# (for Gaussian distributions, this range contains 99.7% of the values)
				# note: we remove the bottom and top 5% before computing the std (to remove data errors that change the mean and std)
				# the computed std is smaller.
				# Too many values are outside mean +- 3 * std, try 4 * std

				$log->debug("compare_nutrition_facts_with_products_from_same_category" ,
					{ nid => $nid, product_100g => $product_ref->{nutriments}{$nid . "_100g"},
					category_100g => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"},
					category_std => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					} ) if $log->is_debug();

				if ($product_ref->{nutriments}{$nid . "_100g"}
					< ($categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"} - 4 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}) ) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-very-low-for-category-" . $nid;
				}
				elsif ($product_ref->{nutriments}{$nid . "_100g"}
					> ($categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"} + 4 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}) ) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:nutrition-value-very-high-for-category-" . $nid;
				}
			}
		}
	}

	return;
}


sub calculate_digit_percentage($) {
	my $text = shift;
	return 0.0 if not defined $text;
	my $tl = length($text);
	return 0.0 if $tl <= 0;
	my $dc = () = $text =~ /\d/g;
	return $dc / ($tl * 1.0);
}

=head2 check_ingredients( PRODUCT_REF )

Checks related to the ingredients list and ingredients analysis.

=cut

sub check_ingredients($) {
	my $product_ref = shift;

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
		($product_ref->{ingredients_text} =~ /\b(ingredientes|azucar|agua|sal|harina)\b/i) and $nb_languages++;
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

	if ((defined $product_ref->{ingredients_n}) and ( $product_ref->{ingredients_n} > 0)) {

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

				push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-ingredient-tag-length-greater-than-" . $max_length_threshold;

			}
		}
	}

	if ((defined $product_ref->{ingredients_text}) and (calculate_digit_percentage($product_ref->{ingredients_text}) > 0.3)) {
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-over-30-percent-digits';
	}

	if (defined $product_ref->{languages_codes}) {

		foreach my $display_lc (keys %{$product_ref->{languages_codes}}) {

			my $ingredients_text_lc = "ingredients_text_" . ${display_lc};

			if (defined $product_ref->{$ingredients_text_lc}) {

				$log->debug("ingredients text", { quality => $product_ref->{$ingredients_text_lc} }) if $log->is_debug();

				if (calculate_digit_percentage($product_ref->{$ingredients_text_lc}) > 0.3) {
					push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-' . $display_lc . '-over-30-percent-digits';
				}

				if ($product_ref->{$ingredients_text_lc} =~ /,(\s*)$/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-ending-comma";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[aeiouy]{5}/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-5-vowels";
				}

				# Dutch and other languages can have 4 consecutive consonants
				if ($display_lc !~ /de|nl/) {
					if ($product_ref->{$ingredients_text_lc} =~ /[bcdfghjklmnpqrstvwxz]{5}/is) {

						push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-5-consonants";
					}
				}

				if ($product_ref->{$ingredients_text_lc} =~ /(.)\1{4,}/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-4-repeated-chars";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\$\€\£\¥\₩]/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-unexpected-chars-currencies";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\@]/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-unexpected-chars-arobase";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\!]/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-unexpected-chars-exclamation-mark";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\?]/is) {

					push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-unexpected-chars-question-mark";
				}


				# French specific
				#if ($display_lc eq 'fr') {

					if ($product_ref->{$ingredients_text_lc} =~ /kcal|glucides|(dont sucres)|(dont acides gras)|(valeurs nutri)/is) {

						push @{$product_ref->{data_quality_warnings_tags}}, "en:ingredients-" . $display_lc . "-includes-fr-nutrition-facts";
					}

					if ( $product_ref->{$ingredients_text_lc}
						=~ /(à conserver)|(conditions de )|(à consommer )|(plus d'info)|consigne/is
						)
					{

						push @{ $product_ref->{data_quality_warnings_tags} },
							  "en:ingredients-"
							. $display_lc
							. "-includes-fr-instructions";
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
	/xx;

	if ((defined $product_ref->{ingredients_text}) and
		(($product_ref->{ingredients_text} =~ /$agr_bio/is) && !has_tag($product_ref, "labels", "en:organic"))) {
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:organic-ingredients-but-no-organic-label';
	}

	return;
}

=head2 check_quantity( PRODUCT_REF )

Checks related to the quantity and serving quantity.

=cut

sub check_quantity($) {

	my $product_ref = shift;

	# quantity contains "e" - might be an indicator that the user might have wanted to use "℮" \N{U+212E}
	if ((defined $product_ref->{quantity})
		and ($product_ref->{quantity} =~ /(?:.*e$)|(?:[0-9]+\s*[kmc]?[gl]?\s*e)/i)
		and (not ($product_ref->{quantity} =~ /\N{U+212E}/i))) {
		push @{$product_ref->{data_quality_info_tags}}, "en:quantity-contains-e";
	}

	if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} ne "") and (not defined $product_ref->{product_quantity})) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:quantity-not-recognized";
	}

	if ((defined $product_ref->{product_quantity}) and ($product_ref->{product_quantity} ne "")) {
		if ($product_ref->{product_quantity} > 10 * 1000) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:product-quantity-over-10kg";
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
				push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-less-than-product-quantity-divided-by-1000";
			}
		}
		else {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-quantity-defined-but-quantity-undefined";
		}

		if ($product_ref->{serving_size} =~ /\d\s?mg\b/i) {
			push @{$product_ref->{data_quality_warnings_tags}}, "en:serving-size-in-mg";
		}
	}

	return;
}

=head2 check_categories( PRODUCT_REF )

Checks related to specific product categories.

Alcoholic beverages: check that there is an alcohol value in the nutrients.

=cut

sub check_categories($) {
	my $product_ref = shift;

	# Check alcohol content
	if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
		if (!(defined $product_ref->{alcohol_value}) || $product_ref->{alcohol_value} == 0) {
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcoholic-beverages-category-without-alcohol-value';
		}
		if (has_tag($product_ref, "categories", "en:non-alcoholic-beverages")) {
			# Product cannot be alcoholic and non-alcoholic
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcoholic-and-non-alcoholic-categories';
		}
	}

	if (defined $product_ref->{alcohol_value}
		and $product_ref->{alcohol_value} > 0
		and not has_tag($product_ref, "categories", "en:alcoholic-beverages")
		) {

			push @{$product_ref->{data_quality_warnings_tags}}, 'en:alcohol-value-without-alcoholic-beverages-category';
	}

	# Plant milks should probably not be dairies https://github.com/openfoodfacts/openfoodfacts-server/issues/73
	if (has_tag($product_ref, "categories", "en:plant-milks") and has_tag($product_ref, "categories", "en:dairies")) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:incompatible-categories-plant-milk-and-dairy";
	}

	return;
}


sub compare_nutriscore_with_value_from_producer($) {

	my $product_ref = shift;

	if ((defined $product_ref->{nutriscore_score}) and (defined $product_ref->{nutriscore_score_producer}
		and ($product_ref->{nutriscore_score} ne lc($product_ref->{nutriscore_score_producer})))) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:nutri-score-score-from-producer-does-not-match-calculated-score";
	}

	if ((defined $product_ref->{nutriscore_grade}) and (defined $product_ref->{nutriscore_grade_producer}
		and ($product_ref->{nutriscore_grade} ne lc($product_ref->{nutriscore_grade_producer})))) {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:nutri-score-grade-from-producer-does-not-match-calculated-grade";
	}

	if (defined $product_ref->{nutriscore_grade}) {

		foreach my $grade ("a", "b", "c", "d", "e") {

			if (has_tag($product_ref, "labels", "en:nutriscore-grade-$grade") and (lc($product_ref->{nutriscore_grade}) ne $grade)) {
				push @{$product_ref->{data_quality_warnings_tags}}, "en:nutri-score-grade-from-label-does-not-match-calculated-grade";
			}
		}
	}

	return;
}


=head2 check_ingredients_percent_analysis( PRODUCT_REF )

Checks if we were able to analyse the minimum and maximum percent values for ingredients and sub-ingredients.

=cut

sub check_ingredients_percent_analysis($) {
	my $product_ref = shift;

	if (defined $product_ref->{ingredients_percent_analysis}) {

		if ($product_ref->{ingredients_percent_analysis} < 0) {
			push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-percent-analysis-not-ok';
		}
		elsif ($product_ref->{ingredients_percent_analysis} > 0) {
			push @{$product_ref->{data_quality_info_tags}}, 'en:ingredients-percent-analysis-ok';
		}

		delete $product_ref->{ingredients_percent_analysis};
	}

	return;
}

=head2 check_quality_food( PRODUCT_REF )

Run all quality checks defined in the module.

=cut

sub check_quality_food($) {

	my $product_ref = shift;

	check_ingredients($product_ref);
	check_ingredients_percent_analysis($product_ref);
	check_nutrition_data($product_ref);
	compare_nutrition_facts_with_products_from_same_category($product_ref);
	check_nutrition_grades($product_ref);
	check_carbon_footprint($product_ref);
	check_quantity($product_ref);
	detect_categories($product_ref);
	check_categories($product_ref);
	compare_nutriscore_with_value_from_producer($product_ref);

	return;
}

1;
