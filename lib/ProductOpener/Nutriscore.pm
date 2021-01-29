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

ProductOpener::Nutriscore - compute the Nutriscore grade of a food product

=head1 SYNOPSIS

C<ProductOpener::Nutriscore> is used to compute the Nutriscore score and grade
of a food product.

    use ProductOpener::Nutriscore qw/:all/;

	my $nutriscore_data_ref = {
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
	}

	my ($nutriscore_score, $nutriscore_grade) = compute_nutriscore_score_and_grade(
		$nutriscore_data_ref
	);

	print "Rounded value for sugars: " . $nutriscore_data_ref->{sugars_value} . "\n";
	print "Points for sugars: " . $nutriscore_data_ref->{sugars_points}. "\n";

=head1 DESCRIPTION

The modules implements the Nutri-Score computation as defined by Santé publique France.

Input values for nutrients are rounded according to the Nutri-Score definition and added
to the hash passed in parameter with the corresponding amount of positive or negative points.

=cut

package ProductOpener::Nutriscore;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		%points_thresholds

		&compute_nutriscore_score_and_grade
		&compute_nutriscore_grade

		&get_value_with_one_less_negative_point
		&get_value_with_one_more_positive_point

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

=head1 FUNCTIONS

=head2 compute_nutriscore_score_and_grade( NUTRISCORE_DATA_REF )

C<compute_nutriscore_score_and_grade()> computes the Nutri-Score score and grade
of a food product, and also returns the details of the points for each nutrient.

=head3 Arguments

1 hash references need to be passed as arguments. It is used for both input and output:

=head4 Input keys: data to compute Nutri-Score

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

=head4 Output keys: details of the Nutri-Score computation

Returned values:

- [nutrient]_value -> rounded values for each nutrient according to the Nutri-Score rules
- [nutrient]_points -> points for each nutrient
- negative_points -> sum of unfavorable nutrients points
- positive_points -> sum of favorable nutrients points
- score -> nutrition score
- grade -> Nutri-Score grade (A ti E

The nutrients that are counted for the negative and positive points depend on the product type
(if it is a beverage, cheese or fat) and on the values for some of the nutrients.

=head3 Return values

The function returns a list of 2 values:

- Nutri-Score score from -15 to 40
- Corresponding nutri-Score letter grade from a to e (in lowercase)

The letter grade depends on the score and on whether the product is a beverage, or is a water.

=cut

sub compute_nutriscore_score_and_grade($) {

	my $nutriscore_data_ref = shift;

	# We will pass a %point structure to get the details of the computation
	# so that it can be returned
	my %points = ();

	my $nutrition_score = compute_nutriscore_score($nutriscore_data_ref);

	my $nutrition_grade = compute_nutriscore_grade($nutrition_score, $nutriscore_data_ref->{is_beverage}, $nutriscore_data_ref->{is_water});

	$nutriscore_data_ref->{score} = $nutrition_score;
	$nutriscore_data_ref->{grade} = $nutrition_grade;

	return ($nutrition_score, $nutrition_grade);
}

%points_thresholds = (

	# negative points

	energy => [ 335, 670, 1005, 1340, 1675, 2010, 2345, 2680, 3015, 3350 ], # kJ / 100g
	energy_beverages => [ 0, 30, 60, 90, 120, 150, 180, 210, 240, 270 ],    # kJ /100g or 100ml
	sugars => [ 4.5, 9, 13.5, 18, 22.5, 27, 31, 36, 40, 45 ],               # g / 100g
	sugars_beverages => [ 0, 1.5, 3, 4.5, 6, 7.5, 9, 10.5, 12, 13.5 ],      # g / 100g or 100ml
	saturated_fat    => [ 1, 2,   3, 4,   5, 6,   7, 8,    9,  10 ],        # g / 100g
	saturated_fat_ratio => [ 10, 16, 22, 28, 34, 40, 46, 52, 58, 64 ],      # %
	sodium => [ 90, 180, 270, 360, 450, 540, 630, 720, 810, 900 ],          # mg / 100g

	# positive points

	fruits_vegetables_nuts_colza_walnut_olive_oils => [40, 60, 80, 80, 80], # %
	fruits_vegetables_nuts_colza_walnut_olive_oils_beverages => [40, 40, 60, 60, 80, 80, 80, 80, 80, 80],
	fiber => [0.9, 1.9, 2.8, 3.7, 4.7],                                     # g / 100g - AOAC method
	proteins => [1.6, 3.2, 4.8, 6.4, 8.0]                                   # g / 100g
);

=head2 get_value_with_one_less_negative_point( NUTRISCORE_DATA_REF, NUTRIENT )

For a given Nutri-Score nutrient value, return the highest smaller value that would result in less negative points.
e.g. for a sugars value of 15 (which gives 3 points), return 13.5 (which gives 2 points).

The value corresponds to the highest smaller threshold.

Return undef is the input nutrient value already gives the minimum amount of points (0).

=cut

sub get_value_with_one_less_negative_point($$) {

	my $nutriscore_data_ref = shift;
	my $nutrient = shift;

	my $nutrient_threshold_id = $nutrient;
	if ((defined $nutriscore_data_ref->{is_beverage}) and ($nutriscore_data_ref->{is_beverage})
		and (defined $points_thresholds{$nutrient_threshold_id . "_beverages"})) {
		$nutrient_threshold_id .= "_beverages";
	}

	my $lower_threshold;

	foreach my $threshold (@{$points_thresholds{$nutrient_threshold_id}}) {
		# The saturated fat ratio table uses the greater or equal sign instead of greater
		if ((($nutrient eq "saturated_fat_ratio") and ($nutriscore_data_ref->{$nutrient . "_value"} >= $threshold))
			or (($nutrient ne "saturated_fat_ratio") and ($nutriscore_data_ref->{$nutrient . "_value"} > $threshold))) {
			$lower_threshold = $threshold;
		}
	}

	return $lower_threshold;
}


=head2 get_value_with_one_more_positive_point( NUTRISCORE_DATA_REF, NUTRIENT )

For a given Nutri-Score nutrient value, return the smallest higher value that would result in more positive points.
e.g. for a proteins value of 2.0 (which gives 1 point), return 3.3 (which gives 2 points)

The value correspond to the smallest higher threshold + 1 increment so that it strictly greater than the threshold.

Return undef is the input nutrient value already gives the maximum amount of points.

=cut


sub get_value_with_one_more_positive_point($$) {

	my $nutriscore_data_ref = shift;
	my $nutrient = shift;

	my $nutrient_threshold_id = $nutrient;
	if ((defined $nutriscore_data_ref->{is_beverage}) and ($nutriscore_data_ref->{is_beverage})
		and (defined $points_thresholds{$nutrient_threshold_id . "_beverages"})) {
		$nutrient_threshold_id .= "_beverages";
	}

	my $higher_threshold;

	foreach my $threshold (@{$points_thresholds{$nutrient_threshold_id}}) {
		if ($nutriscore_data_ref->{$nutrient . "_value"} < $threshold) {
			$higher_threshold = $threshold;
			last;
		}
	}

	# The return value needs to be stricly greater than the threshold

	my $return_value = $higher_threshold;

	if ($return_value) {
		if ($nutrient eq "fruits_vegetables_nuts_colza_walnut_olive_oils") {
			$return_value += 1;
		}
		else {
			$return_value += 0.1;
		}
	}

	return $return_value;
}


sub compute_nutriscore_score($) {

	my $nutriscore_data_ref = shift;

	# The values must be rounded with one more digit than the thresolds.
	# Undefined values are counted as 0 (it can be the case in particular for waters that have different nutrients listed)

	# Round with 1 digit after the comma for energy, saturated fat, saturated fat ratio, sodium and fruits

	foreach my $nutrient (qw(energy saturated_fat saturated_fat_ratio sodium fruits_vegetables_nuts_colza_walnut_olive_oils)) {
		if (defined $nutriscore_data_ref->{$nutrient}) {
			$nutriscore_data_ref->{$nutrient . "_value"} = int($nutriscore_data_ref->{$nutrient} * 10 + 0.5) / 10;
		}
		else {
			$nutriscore_data_ref->{$nutrient . "_value"} = 0;
		}
	}

	# Round with 2 digits for sugars, fiber and proteins

	foreach my $nutrient (qw(sugars fiber proteins)) {
		if (defined $nutriscore_data_ref->{$nutrient}) {
			$nutriscore_data_ref->{$nutrient . "_value"} = int($nutriscore_data_ref->{$nutrient} * 100 + 0.5) / 100;
		}
		else {
			$nutriscore_data_ref->{$nutrient . "_value"} = 0;
		}
	}

	# Special case for sugar: we need to round to 2 digits if we are closed to a threshold defined with 1 digit (e.g. 4.5)
	# but if the threshold is defined with 0 digit (e.g. 9) we need to round with 1 digit.
	if ((($nutriscore_data_ref->{"sugars_value"} - int($nutriscore_data_ref->{"sugars_value"})) > 0.9)
		or (($nutriscore_data_ref->{"sugars_value"} - int($nutriscore_data_ref->{"sugars_value"})) < 0.1)) {
		$nutriscore_data_ref->{"sugars_value"} = int($nutriscore_data_ref->{"sugars"} * 10 + 0.5) / 10;
	}

	# Compute the negative and positive points

	foreach my $nutrient (qw(energy sugars saturated_fat saturated_fat_ratio sodium fruits_vegetables_nuts_colza_walnut_olive_oils fiber proteins)) {

		my $nutrient_threshold_id = $nutrient;
		if ((defined $nutriscore_data_ref->{is_beverage}) and ($nutriscore_data_ref->{is_beverage})
			and (defined $points_thresholds{$nutrient_threshold_id . "_beverages"})) {
			$nutrient_threshold_id .= "_beverages";
		}

		$nutriscore_data_ref->{$nutrient . "_points"} = 0;

		foreach my $threshold (@{$points_thresholds{$nutrient_threshold_id}}) {
			# The saturated fat ratio table uses the greater or equal sign instead of greater
			if ((($nutrient eq "saturated_fat_ratio") and ($nutriscore_data_ref->{$nutrient . "_value"} >= $threshold))
				or (($nutrient ne "saturated_fat_ratio") and ($nutriscore_data_ref->{$nutrient . "_value"} > $threshold))){
				$nutriscore_data_ref->{$nutrient . "_points"}++;
			}
		}
	}

	# Negative points

	# If the product is an added fat (oil, butter etc.) the saturated fat points are replaced
	# by the saturated fat / fat ratio points

	my $fat = "saturated_fat";
	if ((defined $nutriscore_data_ref->{is_fat}) and ($nutriscore_data_ref->{is_fat})) {
		$fat = "saturated_fat_ratio";
	}

	$nutriscore_data_ref->{negative_points} = 0;
	foreach my $nutrient ("energy", "sugars", $fat, "sodium") {
		$nutriscore_data_ref->{negative_points} += $nutriscore_data_ref->{$nutrient . "_points"};
	}

	# If the sum of negative points is greater or equal to 11
	# and if the fruits points are less than the maximum (5 or 10 for beverages)
	# then proteins do not count

	# If the product is a cheese, always count the proteins points

	$nutriscore_data_ref->{positive_points} = 0;

	my @positive_nutrients = qw(fruits_vegetables_nuts_colza_walnut_olive_oils fiber);

	if (($nutriscore_data_ref->{negative_points} < 11)
		or ((defined $nutriscore_data_ref->{is_cheese}) and ($nutriscore_data_ref->{is_cheese}))
		or (((defined $nutriscore_data_ref->{is_beverage}) and ($nutriscore_data_ref->{is_beverage}))
			and ($nutriscore_data_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils_points} == 10))
		or (((not defined $nutriscore_data_ref->{is_beverage}) or (not $nutriscore_data_ref->{is_beverage}))
			and ($nutriscore_data_ref->{fruits_vegetables_nuts_colza_walnut_olive_oils_points} == 5)) ) {
		push @positive_nutrients, "proteins";
	}

	foreach my $nutrient (@positive_nutrients) {
		$nutriscore_data_ref->{positive_points} += $nutriscore_data_ref->{$nutrient . "_points"};
	}

	my $score = $nutriscore_data_ref->{negative_points} - $nutriscore_data_ref->{positive_points};

	return $score;
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

