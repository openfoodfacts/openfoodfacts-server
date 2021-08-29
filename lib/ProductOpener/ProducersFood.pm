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

ProductOpener::ProducersFood - special features for food products manufacturers

=head1 DESCRIPTION

C<ProductOpener::ProducersFood> implements special features that are available
on the platform for producers, specific to food producers.

=cut

package ProductOpener::ProducersFood;

use utf8;
use Modern::Perl '2017';
use Exporter qw(import);


BEGIN
{
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&detect_possible_improvements

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::Config qw(:all);
use ProductOpener::Store qw(:all);
use ProductOpener::Tags qw(:all);
use ProductOpener::Food qw(:all);
use ProductOpener::Nutriscore qw(:all);

use Log::Any qw($log);
use Storable qw(dclone);

=head1 FUNCTIONS

=head2 detect_possible_improvements( PRODUCT_REF )

Run all functions to detect food product improvement opportunities.

=cut

sub detect_possible_improvements($) {

	my $product_ref = shift;

	$product_ref->{improvements_tags} = [];
	$product_ref->{improvements_data} = {};

	detect_possible_improvements_compare_nutrition_facts($product_ref);
	detect_possible_improvements_nutriscore($product_ref);

	return;
}

=head2 detect_possible_improvements_nutriscore( PRODUCT_REF )

Detect products that can get a better NutriScore grade with a slight variation
of nutrients like sugar, salt, saturated fat, fiber, proteins etc.

=cut

sub detect_possible_improvements_nutriscore($) {

	my $product_ref = shift;

	$log->debug("detect_possible_improvements_nutriscore - start") if $log->debug();

	return if not defined $product_ref->{nutriscore_data};

	# Reduce negative nutrients

	foreach my $nutrient (qw(sugars saturated_fat sodium)) {

		my $lower_value =  get_value_with_one_less_negative_point($product_ref->{nutriscore_data}, $nutrient);

		if (defined $lower_value) {
			my $new_nutriscore_data_ref = dclone($product_ref->{nutriscore_data});
			$new_nutriscore_data_ref->{$nutrient} = $lower_value;
			my ($new_nutriscore_score, $new_nutriscore_grade) = ProductOpener::Food::compute_nutriscore_score_and_grade($new_nutriscore_data_ref);

			# Store the result of the experiment
			$product_ref->{nutriscore_data}{$nutrient . "_lower"} = $lower_value;
			$product_ref->{nutriscore_data}{$nutrient . "_lower_score"} = $new_nutriscore_score;
			$product_ref->{nutriscore_data}{$nutrient . "_lower_grade"} = $new_nutriscore_grade;

			my $nutrient_short = $nutrient;
			($nutrient eq "saturated_fat") and $nutrient_short = "saturated-fat";

			if ($new_nutriscore_grade lt $product_ref->{nutriscore_grade}) {
				my $difference = $product_ref->{nutriscore_data}{$nutrient} - $lower_value;
				my $difference_percent = $difference / $product_ref->{nutriscore_data}{$nutrient} * 100;

				my $improvements_tag;

				if ($difference_percent <= 5) {
					$improvements_tag = "en:better-nutri-score-with-slightly-less-" . $nutrient_short;
				}
				elsif ($difference_percent <= 10) {
					$improvements_tag = "en:better-nutri-score-with-less-" . $nutrient_short;
				}

				if ($improvements_tag) {
					push @{$product_ref->{improvements_tags}}, $improvements_tag;
					$product_ref->{improvements_data}{$improvements_tag} = {
						current_nutriscore_grade => $product_ref->{nutriscore_grade},
						new_nutriscore_grade => $new_nutriscore_grade,
						nutrient => $nutrient,
						current_value => $product_ref->{nutriscore_data}{$nutrient},
						new_value => $lower_value,
						difference_percent => $difference_percent,
					};
				}
			}
		}
	}

	# Increase positive nutrients

	foreach my $nutrient (qw(fruits_vegetables_nuts_colza_walnut_olive_oils fiber proteins)) {

		# Skip if the current value of the nutrient is 0
		next if ((not defined $product_ref->{nutriscore_data}{$nutrient}) or ($product_ref->{nutriscore_data}{$nutrient} == 0));

		my $higher_value = get_value_with_one_more_positive_point($product_ref->{nutriscore_data}, $nutrient);

		if (defined $higher_value) {
			my $new_nutriscore_data_ref = dclone($product_ref->{nutriscore_data});
			$new_nutriscore_data_ref->{$nutrient} = $higher_value;
			my ($new_nutriscore_score, $new_nutriscore_grade) = ProductOpener::Food::compute_nutriscore_score_and_grade($new_nutriscore_data_ref);

			# Store the result of the experiment
			$product_ref->{nutriscore_data}{$nutrient . "_higher"} = $higher_value;
			$product_ref->{nutriscore_data}{$nutrient . "_higher_score"} = $new_nutriscore_score;
			$product_ref->{nutriscore_data}{$nutrient . "_higher_grade"} = $new_nutriscore_grade;

			my $nutrient_short = $nutrient;
			($nutrient eq "fruits_vegetables_nuts_colza_walnut_olive_oils") and $nutrient_short = "fruits-and-vegetables";

			if ($new_nutriscore_grade lt $product_ref->{nutriscore_grade}) {
				my $difference = $higher_value - $product_ref->{nutriscore_data}{$nutrient};
				my $difference_percent = $difference / $product_ref->{nutriscore_data}{$nutrient} * 100;

				my $improvements_tag;

				if ($difference_percent <= 5) {
					$improvements_tag = "en:better-nutri-score-with-slightly-more-" . $nutrient_short;

				}
				elsif ($difference_percent <= 10) {
					$improvements_tag = "en:better-nutri-score-with-more-" . $nutrient_short;
				}

				if ($improvements_tag) {
					push @{$product_ref->{improvements_tags}}, $improvements_tag;
					$product_ref->{improvements_data}{$improvements_tag} = {
						current_nutriscore_grade => $product_ref->{nutriscore_grade},
						new_nutriscore_grade => $new_nutriscore_grade,
						nutrient => $nutrient,
						current_value => $product_ref->{nutriscore_data}{$nutrient},
						new_value => $higher_value,
						difference_percent => $difference_percent,
					};
				}
			}
		}
	}

	return;
}

=head2 detect_possible_improvements_compare_nutrition_facts( PRODUCT_REF )

Compare the nutrition facts to other products of the same category to try
to identify possible improvement opportunities.

=cut

sub detect_possible_improvements_compare_nutrition_facts($) {

	my $product_ref = shift;

	my $categories_nutriments_ref = $categories_nutriments_per_country{"world"};

	$log->debug("detect_possible_improvements_compare_nutrition_facts - start") if $log->debug();

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

		$log->debug("detect_possible_improvements_compare_nutrition_facts" , { specific_category => $specific_category}) if $log->is_debug();

		# check major nutrients
		my @nutrients = qw(fat saturated-fat sugars salt);

		# Minimum thresholds set at the upper end of the low values for the FSA traffic lights
		my %minimum_thresholds = (
			"fat" => 3,
			"saturated-fat" => 1.5,
			"sugars" => 5,
			"salt" => 0.3,
		);

		foreach my $nid (@nutrients) {

			if ((defined $product_ref->{nutriments}{$nid . "_100g"}) and ($product_ref->{nutriments}{$nid . "_100g"} ne "")
				and (defined $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"})) {

				$log->debug("detect_possible_improvements_compare_nutrition_facts" ,
					{ nid => $nid, product_100g => $product_ref->{nutriments}{$nid . "_100g"},
					category_100g => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"},
					category_std => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}
					} ) if $log->is_debug();

				next if ($product_ref->{nutriments}{$nid . "_100g"} < $minimum_thresholds{$nid});

				my $improvements_tag;

				if ($product_ref->{nutriments}{$nid . "_100g"}
					> ($categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"} + 2 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}) ) {

					push @{$product_ref->{improvements_tags}}, "en:nutrition-very-high-$nid-value-for-category";
					$improvements_tag = "en:nutrition-very-high-$nid-value-for-category";
				}
				elsif ($product_ref->{nutriments}{$nid . "_100g"}
					> ($categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"} + 1 * $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_std"}) ) {

					push @{$product_ref->{improvements_tags}}, "en:nutrition-high-$nid-value-for-category";
					$improvements_tag = "en:nutrition-high-$nid-value-for-category";
				}

				if ($improvements_tag) {
					$product_ref->{improvements_data}{$improvements_tag} = {
						nid => $nid,
						category => $specific_category,
						product_100g => $product_ref->{nutriments}{$nid . "_100g"},
						category_100g => $categories_nutriments_ref->{$specific_category}{nutriments}{$nid . "_100g"},
					};
				}
			}
		}
	}

	return;
}


1;
