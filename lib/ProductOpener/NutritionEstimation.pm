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

ProductOpener::NutritionEstimation - estimate nutrition facts from the list of ingredients of a product

=head1 DESCRIPTION

This module uses nutritional databases such as CIQUAL to estimate the nutrients of a product, using its list of ingredients.

=cut

package ProductOpener::NutritionEstimation;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&estimate_nutrients_from_ingredients

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::NutritionCiqual qw/:all/;

use Data::DeepAccess qw(deep_get deep_set deep_exists);

=head1 FUNCTIONS

=head2 estimate_nutrients_from_ingredients($ingredients_ref)

Estimate nutrition facts from a structured list of ingredients (of a product or a recipe)
with percentages.

In its current form, this function only looks at top level ingredients,
and does not take into account nested sub ingredients.

=cut

sub estimate_nutrients_from_ingredients ($ingredients_ref) {

	my $total = 0;
	my $total_with_nutrients = 0;
	my %nutrients = ();
	my %unknown_ingredients = ();

	# Go through each first level ingredient
	foreach my $ingredient_ref (@$ingredients_ref) {
		if (defined $ingredient_ref->{percent_estimate}) {
			# Check if we have a ciqual_food_code or ciqual_proxy_food_code property
			my $ciqual_id = get_inherited_property("ingredients", $ingredient_ref->{id}, "ciqual_food_code:en")
				// get_inherited_property("ingredients", $ingredient_ref->{id}, "ciqual_proxy_food_code:en");
			$total += $ingredient_ref->{percent_estimate};
			if ((defined $ciqual_id) and (defined $ciqual_data{$ciqual_id})) {
				$total_with_nutrients += $ingredient_ref->{percent_estimate};

				# Add nutrient value of the ingredient for all nutrients
				while (my ($nid, $value) = each(%{$ciqual_data{$ciqual_id}{nutrients}})) {
					$nutrients{$nid} += $value * $ingredient_ref->{percent_estimate} / 100;
				}
			}
			else {
				# Keep track of ingredients for which we don't have nutrient values
				$unknown_ingredients{$ingredient_ref->{id}} += $ingredient_ref->{percent_estimate} / 100;
			}
		}
	}

	# Copy energy-kj value to energy
	if (exists $nutrients{"energy-kj"}) {
		$nutrients{"energy"} = $nutrients{"energy-kj"};
	}

	my $results_ref = {
		total => $total,
		total_with_nutrients => $total_with_nutrients,
		nutrients => \%nutrients,
		unknown_ingredients => \%unknown_ingredients,
	};

	return $results_ref;
}

1;

