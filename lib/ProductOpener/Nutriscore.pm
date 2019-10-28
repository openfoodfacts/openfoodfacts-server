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

=head1 NAME

ProductOpener::Nutriscore - compute the Nutriscore grade of a food product

=head1 SYNOPSIS

C<ProductOpener::Nutriscore> is used to compute the Nutriscore score and grade
of a food product.

    use ProductOpener::Nutriscore qw/:all/;

	my $points_ref = {};	# will be populated with details about the computation

	my ($nutriscore_score, $nutriscore_grade) = compute_nutriscore_score_and_grade(
		{
			# Nutrients
			energy =>  518,	# in kJ
			sugars => 3,
			saturated_fat => 0.7,
			saturated_fat_ratio => 0.7 / 3 * 100,
			sodium => 0.61 / 2.5 * 1000,	# in mg, sodium = salt divided by 2.5
			fruits_vegetables_nuts_colza_walnut_olive_oils => 20,	# in %
			fiber => 2.2,
			proteins => 6.7,

			# The Nutri-Score computation is different for beverages, waters, cheeses and fats
			is_beverage => 1,
			is_water => 0,
			is_cheese => 0,
			is_fat => 0,

		},
		$points_ref
	);

	print "Rounded value for sugars: " . $points_ref->{sugars_value} . "\n";
	print "Points for sugars: " . $points_ref->{sugars}. "\n";

=head1 DESCRIPTION

The modules implements the Nutri-Score computation as defined by Santé publique France.

Input values for nutrients are rounded according to the Nutri-Score definition and returned
in a hash with the corresponding amount of positive or negative points.

=cut

package ProductOpener::Nutriscore;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(

		&compute_nutriscore_score_and_grade

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

=head1 FUNCTIONS

=head2 compute_nutriscore_score_and_grade( PRODUCT_DATA_REF, POINTS_REF )

C<compute_nutriscore_score_and_grade()> computes the Nutri-Score score and grade
of a food product, and also returns the details of the points for each nutrient.

=head3 Arguments

2 hash references need to be passed as arguments:

=head4 PRODUCT_DATA_REF - hash reference to the input product data

The hash must contain values for the following keys:

- energy -> energy in kJ / 100g or 100ml
- sugars -> sugars in g / 100g or 100ml
- saturated_fat -> saturated fats in g / 100g or 100ml
- saturated_fat_ratio -> saturated fat divided by fat * 100 (in %)
- sodium -> sodium in mg / 100g or 100ml (if sodium is computed from salt, it needs to use a sodium = salt / 2.5 conversion factor
- fruits_vegetables_nuts_colza_walnut_olive_oils -> % of fruits, vegetables, nuts, and colza / walnut / olive oiles
- fiber -> fiber in g / 100g or 100ml
- proteins -> proteins in g / 100g or 100ml

The values will be rounded according to the Nutri-Score rules, they do not need to be rounded before being passed as arguments.

If the product is a beverage, water, cheese, or fat, it must contain a positive value for the corresponding keys:
- is_beverage
- is_water
- is_cheese
- is_fat

=head4 POINTS_REF - reference to an empty hash that will be populated with the
details of the points for each nutrient.

Returned values:

- [nutrient]_value -> rounded values for each nutrient according to the Nutri-Score rules
- [nutrient] -> points for each nutrient
- negative_points -> sum of unfavorable nutrients points
- positive_points -> sum of favorable nutrients points

The nutrients that are counted for the negative and positive points depend on the product type
(if it is a beverage, cheese or fat) and on the values for some of the nutrients.

=head3 Return values

The function returns a list of 2 values:

- Nutri-Score score from -15 to 40
- Corresponding nutri-Score letter grade from a to e (in lowercase)

The letter grade depends on the score and on whether the product is a beverage, or is a water.

=cut

sub compute_nutriscore_score_and_grade($$) {

	my $product_data_ref = shift;
	my $points_ref = shift;

	# We will pass a %point structure to get the details of the computation
	# so that it can be returned
	my %points = ();

	my $nutrition_score = compute_nutriscore_score($product_data_ref, $points_ref);

	my $nutrition_grade = compute_nutriscore_grade($nutrition_score, $product_data_ref->{is_beverage}, $product_data_ref->{is_water});

	return ($nutrition_score, $nutrition_grade);
}


my %points_thresholds = (

	# negative points

	energy => [335, 670, 1005, 1340, 1675, 2010, 2345, 2680, 3015, 3350],	# kJ / 100g
	energy_beverages => [0, 30, 60, 90, 120, 150, 180, 210, 240, 270],	# kJ /100g or 100ml
	sugars => [4.5, 9, 13.5, 18, 22.5, 27, 31, 36, 40, 45],	# g / 100g
	sugars_beverages => [0, 1.5, 3, 4.5, 6, 7.5, 9, 10.5, 12, 13.5],	# g / 100g or 100ml
	saturated_fat => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],	# g / 100g
	saturated_fat_ratio => [10, 16, 22, 28, 34, 40, 46, 52, 58, 64],	# %
	sodium => [90, 180, 270, 360, 450, 540, 630, 720, 810, 900],	# mg / 100g

	# positive points

	fruits_vegetables_nuts_colza_walnut_olive_oils => [40, 60, 80, 80, 80],	# %
	fruits_vegetables_nuts_colza_walnut_olive_oils_beverages => [40, 40, 60, 60, 80, 80, 80, 80, 80, 80],
	fiber => [0.9, 1.9, 2.8, 3.7, 4.7],	# g / 100g - AOAC method
	proteins => [1.6, 3.2, 4.8, 6.4, 8.0]	# g / 100g
);


sub compute_nutriscore_score($$) {

	my $product_data_ref = shift;
	my $points_ref = shift;

	# The values must be rounded with one more digit than the thresolds.
	# Undefined values are counted as 0 (it can be the case in particular for waters that have different nutrients listed)

	my $averages_ref = {};

	# Round with 1 digit after the comma for energy, saturated fat, saturated fat ratio, sodium and fruits

	foreach my $nutrient (qw(energy saturated_fat saturated_fat_ratio sodium fruits_vegetables_nuts_colza_walnut_olive_oils)) {
		if (defined $product_data_ref->{$nutrient}) {
			$averages_ref->{$nutrient} = int($product_data_ref->{$nutrient} * 10 + 0.5) / 10;
		}
		else {
			$averages_ref->{$nutrient} = 0;
		}
	}

	# Round with 2 digits for sugars, fiber and proteins

	foreach my $nutrient (qw(sugars fiber proteins)) {
		if (defined $product_data_ref->{$nutrient}) {
			$averages_ref->{$nutrient} = int($product_data_ref->{$nutrient} * 100 + 0.5) / 100;
		}
		else {
			$averages_ref->{$nutrient} = 0;
		}
	}

	# Special case for sugar: we need to round to 2 digits if we are closed to a threshold defined with 1 digit (e.g. 4.5)
	# but if the threshold is defined with 0 digit (e.g. 9) we need to round with 1 digit.
	if ((($averages_ref->{"sugars"} - int($averages_ref->{"sugars"})) > 0.9)
		or (($averages_ref->{"sugars"} - int($averages_ref->{"sugars"})) < 0.1)) {
		$averages_ref->{"sugars"} = int($product_data_ref->{"sugars"} * 10 + 0.5) / 10;
	}

	# Compute the negative and positive points

	foreach my $nutrient (qw(energy sugars saturated_fat saturated_fat_ratio sodium fruits_vegetables_nuts_colza_walnut_olive_oils fiber proteins)) {

		my $nutrient_threshold_id = $nutrient;
		if ((defined $product_data_ref->{is_beverage}) and ($product_data_ref->{is_beverage})
			and (defined $points_thresholds{$nutrient_threshold_id . "_beverages"})) {
			$nutrient_threshold_id .= "_beverages";
		}

		$points_ref->{$nutrient} = 0;
		$points_ref->{$nutrient . "_value"} = $averages_ref->{$nutrient};

		foreach my $threshold (@{$points_thresholds{$nutrient_threshold_id}}) {
			# The saturated fat ratio table uses the greater or equal sign instead of greater
			if ((($nutrient eq "saturated_fat_ratio") and ($averages_ref->{$nutrient} >= $threshold))
				or (($nutrient ne "saturated_fat_ratio") and ($averages_ref->{$nutrient} > $threshold))){
				$points_ref->{$nutrient}++;
			}
		}
	}

	# Negative points

	# If the product is an added fat (oil, butter etc.) the saturated fat points are replaced
	# by the saturated fat / fat ratio points

	my $fat = "saturated_fat";
	if ((defined $product_data_ref->{is_fat}) and ($product_data_ref->{is_fat})) {
		$fat = "saturated_fat_ratio";
	}

	$points_ref->{negative_points} = 0;
	foreach my $nutrient ("energy", "sugars", $fat, "sodium") {
		$points_ref->{negative_points} += $points_ref->{$nutrient};
	}

	# If the sum of negative points is greater or equal to 11
	# and if the fruits points are less than the maximum (5 or 10 for beverages)
	# then proteins do not count

	# If the product is a cheese, always count the proteins points

	$points_ref->{positive_points} = 0;

	my @positive_nutrients = qw(fruits_vegetables_nuts_colza_walnut_olive_oils fiber);

	if (($points_ref->{negative_points} < 11)
		or ((defined $product_data_ref->{is_cheese}) and ($product_data_ref->{is_cheese}))
		or (((defined $product_data_ref->{is_beverage}) and ($product_data_ref->{is_beverage}))
			and ($points_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils} == 10))
		or (((not defined $product_data_ref->{is_beverage}) or (not $product_data_ref->{is_beverage}))
			and ($points_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils} == 5)) ) {
		push @positive_nutrients, "proteins";
	}

	foreach my $nutrient (@positive_nutrients) {
		$points_ref->{positive_points} += $points_ref->{$nutrient};
	}

	my $nutrition_score = $points_ref->{negative_points} - $points_ref->{positive_points};

	return $nutrition_score;
}


sub compute_nutriscore_grade($$$) {

	my $nutrition_score = shift;
	my $is_beverage = shift;
	my $is_water = shift;

	my $grade = "";

	if (not defined $nutrition_score) {
		return '';
	}

	if ($is_beverage) {

		if ($is_water) {
			$grade = 'a';
		}
		elsif ($nutrition_score <= 1) {
			$grade = 'b';
		}
		elsif ($nutrition_score <= 5) {
			$grade = 'c';
		}
		elsif ($nutrition_score <= 9) {
			$grade = 'd';
		}
		else {
			$grade = 'e';
		}
	}
	else {

		if ($nutrition_score <= -1) {
			$grade = 'a';
		}
		elsif ($nutrition_score <= 2) {
			$grade = 'b';
		}
		elsif ($nutrition_score <= 10) {
			$grade = 'c';
		}
		elsif ($nutrition_score <= 18) {
			$grade = 'd';
		}
		else {
			$grade = 'e';
		}
	}
	return $grade;
}


1;

