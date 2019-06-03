# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

package ProductOpener::SiteQuality;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;




BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();	# symbols to export by default
	@EXPORT_OK = qw(


					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

use Log::Any qw($log);

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
Hollywood
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
Win Mild
Winston
Wismilak
Woodbine
X-Mild
Ziganov
Zhongnanhai
);

my %baby_food_brands = ();

foreach my $brand (@baby_food_brands) {

	my $brandid = get_fileid($brand);
	$baby_food_brands{$brandid} = 1;

}


my %cigarette_brands = ();

foreach my $brand (@cigarette_brands) {

	my $brandid = get_fileid($brand);
	$cigarette_brands{$brandid} = 1;

}

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
			push @{$product_ref->{quality_tags}}, "detected-category-from-name-ingredients-en-baby-milks";
		}
	}

	if (defined $product_ref->{brands_tags}) {
		foreach my $brandid (@{$product_ref->{brands_tags}}) {
			if (defined $baby_food_brands{$brandid}) {
				push @{$product_ref->{quality_tags}}, "detected-category-from-brand-en-baby-foods";
				last;
			}
		}
	}

	if (defined $product_ref->{brands_tags}) {
		foreach my $brandid (@{$product_ref->{brands_tags}}) {
			if (defined $cigarette_brands{$brandid}) {
				push @{$product_ref->{quality_tags}}, "detected-category-from-brand-en-cigarettes";
				last;
			}
		}
	}

	# Plant milks should probably not be dairies https://github.com/openfoodfacts/openfoodfacts-server/issues/73
	if (has_tag($product_ref, "categories", "en:plant-milks") and has_tag($product_ref, "categories", "en:dairies")) {
		push @{$product_ref->{quality_tags}}, "plant-milk-also-is-dairy";
	}

}


sub check_nutrition_grades($) {


	my $product_ref = shift;

	if ((defined $product_ref->{nutrition_grade_fr_producer}) and (defined $product_ref->{nutrition_grade_fr}) ) {

		if ($product_ref->{nutrition_grade_fr_producer} eq $product_ref->{nutrition_grade_fr}) {
			push @{$product_ref->{quality_tags}}, "nutrition-grade-fr-producer-same-ok";
		}
		else {
			push @{$product_ref->{quality_tags}}, "nutrition-grade-fr-producer-mismatch-nok";
		}
	}

	if ((defined $product_ref->{nutriments})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr-producer"})
		and (defined $product_ref->{nutriments}{"nutrition-score-fr"}) ) {

		if ($product_ref->{nutriments}{"nutrition-score-fr-producer"} eq $product_ref->{nutriments}{"nutrition-score-fr"}) {
			push @{$product_ref->{quality_tags}}, "nutrition-score-fr-producer-same-ok";
		}
		else {
			push @{$product_ref->{quality_tags}}, "nutrition-score-fr-producer-mismatch-nok";
		}
	}

}


sub check_nutrition_data($) {


	my $product_ref = shift;


	if ((defined $product_ref->{multiple_nutrition_data}) and ($product_ref->{multiple_nutrition_data} eq 'on')) {

		push @{$product_ref->{quality_tags}}, "multiple-nutrition-data";

		if ((defined $product_ref->{not_comparable_nutrition_data}) and $product_ref->{not_comparable_nutrition_data}) {
			push @{$product_ref->{quality_tags}}, "not-comparable-nutrition-data";
		}
	}

	if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {

		push @{$product_ref->{quality_tags}}, "no-nutrition-data";
	}


	if (defined $product_ref->{nutriments}) {

		if ((defined $product_ref->{nutrition_data_prepared}) and ($product_ref->{nutrition_data_prepared} eq 'on')) {
			push @{$product_ref->{quality_tags}}, "nutrition-data-prepared";

			if (not has_tag($product_ref, "categories", "en:dried-products-to-be-rehydrated")) {
				push @{$product_ref->{quality_tags}}, "nutrition-data-prepared-without-category-dried-products-to-be-rehydrated";
			}
		}


		if ((defined $product_ref->{nutrition_data_per}) and ($product_ref->{nutrition_data_per} eq 'serving')) {

			if ((not defined $product_ref->{serving_size}) or ($product_ref->{serving_size} eq '')) {
				push @{$product_ref->{quality_tags}}, "nutrition-data-per-serving-missing-serving-size";
			}
			elsif ($product_ref->{serving_quantity} == 0) {
				push @{$product_ref->{quality_tags}}, "nutrition-data-per-serving-missing-serving-quantity-is-zero";
			}
		}



		my $nid_n = 0;
		my $nid_zero = 0;

		my $total = 0;

		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			next if $nid =~ /_/;

			if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid . "_100g"} > 105)) {

				push @{$product_ref->{quality_tags}}, "nutrition-value-over-105-for-$nid";
			}

			if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid . "_100g"} > 1000)) {

				push @{$product_ref->{quality_tags}}, "nutrition-value-over-1000-for-$nid";
			}

			if ($product_ref->{nutriments}{$nid . "_100g"} == 0) {
				$nid_zero++;
			}
			$nid_n++;

			if (($nid eq 'fat') or ($nid eq 'carbohydrates') or ($nid eq 'proteins') or ($nid eq 'salt')) {
				$total += $product_ref->{nutriments}{$nid . "_100g"};
			}
		}

		if ($total > 105) {
			push @{$product_ref->{quality_tags}}, "nutrition-value-total-over-105";
		}
		if ($total > 1000) {
			push @{$product_ref->{quality_tags}}, "nutrition-value-total-over-1000";
		}

		if ($product_ref->{nutriments}{"energy_100g"} > 4000) {
			push @{$product_ref->{quality_tags}}, "nutrition-value-over-4000-for-energy";
		}

		if (($nid_n >= 1) and ($nid_zero == $nid_n)) {
			push @{$product_ref->{quality_tags}}, "nutrition-all-values-zero";
		}

		if ((defined $product_ref->{nutriments}{"carbohydrates_100g"}) and
			((((defined $product_ref->{nutriments}{"sugars_100g"}) ? $product_ref->{nutriments}{"sugars_100g"} : 0)
			+ ((defined $product_ref->{nutriments}{"starch_100g"}) ? $product_ref->{nutriments}{"starch_100g"} : 0))
			> ($product_ref->{nutriments}{"carbohydrates_100g"}) + 0.001)) {

				push @{$product_ref->{quality_tags}}, "nutrition-sugars-plus-starch-greater-than-carbohydrates";

		}

		if (((defined $product_ref->{nutriments}{"saturated-fat_100g"}) ? $product_ref->{nutriments}{"saturated-fat_100g"} : 0)
			> (((defined $product_ref->{nutriments}{"fat_100g"}) ? $product_ref->{nutriments}{"fat_100g"} : 0) + 0.001)) {

				push @{$product_ref->{quality_tags}}, "nutrition-saturated-fat-greater-than-fat";

		}

		# Fat has the highest nutrient energy density of 37 kJ/g. With some leeway/inaccuracies,
		# it is safe to assume that no product can have a higher energy of 3800 kJ.
		if ((defined $product_ref->{nutriments}{energy}) and ($product_ref->{nutriments}{energy} > 3800)) {
			push @{$product_ref->{quality_tags}}, 'illogically-high-energy-value';
		}
	}
}


sub check_ingredients($) {

	my $product_ref = shift;

	# spell corrected additives

	if ($product_ref->{additives} =~ /spell correction/) {
		push @{$product_ref->{quality_tags}}, "ingredients-spell-corrected-additives";
	}


	# Multiple languages in ingredient lists

	my $nb_languages = 0;

	($product_ref->{ingredients_text} =~ /\b(ingrédients|sucre|eau|sel|farine)\b/i) and $nb_languages++;
	($product_ref->{ingredients_text} =~ /\b(sugar|salt|flour|milk)\b/i) and $nb_languages++;
	($product_ref->{ingredients_text} =~ /\b(ingrediënten|suiker|zout|bloem)\b/i) and $nb_languages++;
	($product_ref->{ingredients_text} =~ /\b(ingredientes|azucar|agua|sal|harina)\b/i) and $nb_languages++;
	($product_ref->{ingredients_text} =~ /\b(zutaten|Zucker|Salz|Wasser|Mehl)\b/i) and $nb_languages++;
	($product_ref->{ingredients_text} =~ /\b(açúcar|farinha|água)\b/i) and $nb_languages++;
	($product_ref->{ingredients_text} =~ /\b(ingredienti|zucchero|farina|acqua)\b/i) and $nb_languages++;


	if ($nb_languages > 1) {
			foreach my $max (5, 4, 3, 2, 1) {
				if ($nb_languages > $max) {
					push @{$product_ref->{quality_tags}}, "ingredients-number-of-languages-above-$max";
				}
			}
		push @{$product_ref->{quality_tags}}, "ingredients-number-of-languages-$nb_languages";
	}

	if ((defined $product_ref->{ingredients_n}) and ( $product_ref->{ingredients_n} > 0)) {

			my $score = $product_ref->{unknown_ingredients_n} * 2 - $product_ref->{ingredients_n};

			foreach my $max (50, 40, 30, 20, 10, 5, 0) {
				if ($score > $max) {
					push @{$product_ref->{quality_tags}}, "ingredients-unknown-score-above-$max";
					last;
				}
			}

			foreach my $max (100, 90, 80, 70, 60, 50) {
				if (($product_ref->{unknown_ingredients_n} / $product_ref->{ingredients_n}) >= ($max / 100)) {
					push @{$product_ref->{quality_tags}}, "ingredients-$max-percent-unknown";
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

				push @{$product_ref->{quality_tags}}, "ingredients-ingredient-tag-length-greater-than-" . $max_length_threshold;

			}
		}
	}


	if (defined $product_ref->{languages_codes}) {

		foreach my $display_lc (keys %{$product_ref->{languages_codes}}) {

			my $ingredients_text_lc = "ingredients_text_" . ${display_lc};

			if (defined $product_ref->{$ingredients_text_lc}) {

				$log->debug("ingredients text", { quality => $product_ref->{$ingredients_text_lc} }) if $log->is_debug();

				if ($product_ref->{$ingredients_text_lc} =~ /,(\s*)$/is) {

					push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-ending-comma";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[aeiouy]{5}/is) {

					push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-5-vowels";
				}

				# Dutch and other languages can have 4 consecutive consonants
				if ($display_lc !~ /de|nl/) {
					if ($product_ref->{$ingredients_text_lc} =~ /[bcdfghjklmnpqrstvwxz]{4}/is) {

						push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-4-consonants";
					}
				}

				if ($product_ref->{$ingredients_text_lc} =~ /(.)\1{4,}/is) {

					push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-4-repeated-chars";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\$\€\£\¥\₩]/is) {

					push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-unexpected-chars-currencies";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\@]/is) {

					push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-unexpected-chars-arobase";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\!]/is) {

					push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-unexpected-chars-exclamation-mark";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\?]/is) {

					push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-unexpected-chars-question-mark";
				}


				# French specific
				#if ($display_lc eq 'fr') {

					if ($product_ref->{$ingredients_text_lc} =~ /kcal|glucides|(dont sucres)|(dont acides gras)|(valeurs nutri)/is) {

						push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-includes-fr-nutrition-facts";
					}

					if ($product_ref->{$ingredients_text_lc} =~ /(à conserver)|(conditions de )|(à consommer )|(plus d'info)|consigne/is) {

						push @{$product_ref->{quality_tags}}, "ingredients-" . $display_lc . "-includes-fr-instructions";
					}
				#}
			}

		}

	}

}


sub check_quantity($) {

	my $product_ref = shift;

	# quantity contains "e" - might be an indicator that the user might have wanted to use "℮" \N{U+212E}
	if ((defined $product_ref->{quantity})
		and ($product_ref->{quantity} =~ /(?:.*e$)|(?:[0-9]+\s*[kmc]?[gl]?\s*e)/i)
		and (not ($product_ref->{quantity} =~ /\N{U+212E}/i))) {
		push @{$product_ref->{quality_tags}}, "quantity-contains-e";
	}

	if ((defined $product_ref->{quantity}) and ($product_ref->{quantity} ne "") and (not defined $product_ref->{product_quantity})) {
		push @{$product_ref->{quality_tags}}, "quantity-not-recognized";
	}

	if ((defined $product_ref->{product_quantity}) and ($product_ref->{product_quantity} ne "")) {
		if ($product_ref->{product_quantity} > 10 * 1000) {
			push @{$product_ref->{quality_tags}}, "product-quantity-over-10kg";
		}
		if ($product_ref->{product_quantity} < 1) {
			push @{$product_ref->{quality_tags}}, "product-quantity-under-1g";
		}

		if ($product_ref->{quantity} =~ /\d\s?mg\b/i) {
			push @{$product_ref->{quality_tags}}, "product-quantity-in-mg";
		}
	}

	if ((defined $product_ref->{serving_quantity}) and ($product_ref->{serving_quantity} ne "")) {
		if ($product_ref->{serving_quantity} > 500) {
			push @{$product_ref->{quality_tags}}, "serving-quantity-over-500g";
		}
		if ($product_ref->{serving_quantity} < 1) {
			push @{$product_ref->{quality_tags}}, "serving-quantity-under-1g";
		}

		if ((defined $product_ref->{product_quantity}) and ($product_ref->{product_quantity} ne "")) {
			if ($product_ref->{serving_quantity} > $product_ref->{product_quantity}) {
				push @{$product_ref->{quality_tags}}, "serving-quantity-over-product-quantity";
			}
			if ($product_ref->{serving_quantity} < $product_ref->{product_quantity} / 1000) {
				push @{$product_ref->{quality_tags}}, "serving-quantity-less-than-product-quantity-divided-by-1000";
			}
		}
		else {
			push @{$product_ref->{quality_tags}}, "serving-quantity-defined-but-quantity-undefined";
		}

		if ($product_ref->{serving_size} =~ /\d\s?mg\b/i) {
			push @{$product_ref->{quality_tags}}, "serving-size-in-mg";
		}
	}
}


sub check_bugs($) {

	my $product_ref = shift;

	check_bug_code_missing($product_ref);
	check_bug_created_t_missing($product_ref);

}

sub check_bug_code_missing($) {

	my $product_ref = shift;

	# https://github.com/openfoodfacts/openfoodfacts-server/issues/185#issuecomment-364653043
	if ((not (defined $product_ref->{code}))) {
		push @{$product_ref->{quality_tags}}, "code-missing";
	}
	elsif ($product_ref->{code} eq '') {
		push @{$product_ref->{quality_tags}}, "code-empty";
	}
	elsif ($product_ref->{code} == 0) {
		push @{$product_ref->{quality_tags}}, "code-zero";
	}

}

sub check_bug_created_t_missing($) {

	my $product_ref = shift;

	# https://github.com/openfoodfacts/openfoodfacts-server/issues/185
	if ((not (defined $product_ref->{created_t}))) {
		push @{$product_ref->{quality_tags}}, "created-missing";
	}
	elsif ($product_ref->{created_t} == 0) {
		push @{$product_ref->{quality_tags}}, "created-zero";
	}

}

sub check_codes($) {

	my $product_ref = shift;

	check_code_gs1_prefixes($product_ref);

}

sub check_code_gs1_prefixes($) {

	my $product_ref = shift;

	if ((not (defined $product_ref->{code}))) {
		return;
	}

	my $code = $product_ref->{code};
	# https://github.com/openfoodfacts/openfoodfacts-server/issues/1129
	if ($code =~ /^99[0-9]{10,11}$/) {
		push @{$product_ref->{quality_tags}}, 'gs1-coupon-prefix';
	}
	elsif ($code =~ /^98[5-9][0-9]{9,10}$/) {
		push @{$product_ref->{quality_tags}}, 'gs1-future-coupon-prefix';
	}
	elsif ($code =~ /^98[1-4][0-9]{9,10}$/) {
		push @{$product_ref->{quality_tags}}, 'gs1-coupon-common-currency-area-prefix';
	}
	elsif ($code =~ /^980[0-9]{9,10}$/) {
		push @{$product_ref->{quality_tags}}, 'gs1-refund-prefix';
	}
	elsif ($code =~ /^97[8-9][0-9]{9,10}$/) {
		push @{$product_ref->{quality_tags}}, 'gs1-isbn-prefix';
	}
	elsif ($code =~ /^977[0-9]{9,10}$/) {
		push @{$product_ref->{quality_tags}}, 'gs1-issn-prefix';
	}
	elsif ($code =~ /^3600550xxxxxx[0-9]{9,10}$/) {
		push @{$product_ref->{quality_tags}}, 'cosmetic-product';
	}
}

# Run site specific quality checks

sub check_quality($) {

	my $product_ref = shift;

	$product_ref->{quality_tags} = [];

	check_ingredients($product_ref);
	check_nutrition_data($product_ref);
	check_nutrition_grades($product_ref);
	check_quantity($product_ref);
	check_bugs($product_ref);
	check_codes($product_ref);

	detect_categories($product_ref);
}





1;
