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

=encoding UTF-8

=head1 NAME

ProductOpener::Food - functions related to food products

=head1 DESCRIPTION

C<ProductOpener::FoodProducts> contains functions specific to food products.

..

=cut

package ProductOpener::FoodProducts;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&specific_processes_for_food_product

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Ingredients
	qw/select_ingredients_lc clean_ingredients_text extract_ingredients_from_text extract_additives_from_text detect_allergens_from_text/;
use ProductOpener::NutritionEstimation qw/estimate_nutrients_from_ingredients/;
use ProductOpener::Food
	qw/fix_salt_equivalent compute_nutrition_data_per_100g_and_per_serving assign_categories_properties_to_product compute_estimated_nutrients compute_unknown_nutrients compute_nova_group compute_nutriscore compute_nutrient_levels/;
use ProductOpener::FoodGroups qw/compute_food_groups/;
use ProductOpener::Nutriscore qw/:all/;
use ProductOpener::EnvironmentalScore qw/compute_environmental_score/;
use ProductOpener::ForestFootprint qw/compute_forest_footprint/;

use Log::Any qw($log);

=head2 specific_processes_for_food_product ( $ingredients_ref )

Runs specific processes for food products:

- Ingredients analysis
- Additives detection
- Allergens detection
- Determination of food groups, and whether a product is to be considered a beverage for the Nutri-Score.
- Computation of scores

=cut

sub specific_processes_for_food_product ($product_ref) {

	# Ingredients analysis

	# Select best language to parse ingredients
	select_ingredients_lc($product_ref);
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);
	extract_additives_from_text($product_ref);
	detect_allergens_from_text($product_ref);

	# Category analysis
	# Food category rules for sweetened/sugared beverages
	# French PNNS groups from categories

	assign_categories_properties_to_product($product_ref);
	compute_food_groups($product_ref);

	# Nutrition data per 100g and per serving size

	fix_salt_equivalent($product_ref);
	compute_nutrition_data_per_100g_and_per_serving($product_ref);

	# Nutrients

	compute_estimated_nutrients($product_ref);
	compute_unknown_nutrients($product_ref);

	# Scores

	compute_nutriscore($product_ref);
	compute_nova_group($product_ref);
	compute_nutrient_levels($product_ref);

	# Environmental analysis

	compute_environmental_score($product_ref);
	compute_forest_footprint($product_ref);

	return;
}

1;
