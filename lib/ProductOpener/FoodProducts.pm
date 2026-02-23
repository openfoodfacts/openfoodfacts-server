# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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
	qw/select_ingredients_lc clean_ingredients_text extract_ingredients_from_text extract_additives_from_text detect_allergens_from_text detect_rare_crops/;
use ProductOpener::NutritionEstimation qw/estimate_nutrients_from_ingredients/;
use ProductOpener::Food
	qw/assign_categories_properties_to_product compute_nova_group compute_nutriscore compute_nutrient_levels/;
use ProductOpener::FoodGroups qw/compute_food_groups/;
use ProductOpener::Nutrition
	qw/generate_nutrient_aggregated_set compute_estimated_nutrients add_misc_tags_for_input_nutrition_data_pers/;
use ProductOpener::Nutriscore qw/:all/;
use ProductOpener::EnvironmentalScore qw/compute_environmental_score/;
use ProductOpener::ForestFootprint qw/compute_forest_footprint/;
use ProductOpener::PackagingFoodContact qw/determine_food_contact_of_packaging_components_service/;

use Log::Any qw($log);

use Data::DeepAccess qw(deep_exists);

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

	# Rare crops / Neglected and Underutilized Crops (NUCs) (DIVINFOOD project)
	detect_rare_crops($product_ref);

	# Category analysis
	# Food category rules for sweetened/sugared beverages
	# French PNNS groups from categories

	assign_categories_properties_to_product($product_ref);
	compute_food_groups($product_ref);

	# Nutrition

	compute_estimated_nutrients($product_ref);

	generate_nutrient_aggregated_set($product_ref);

	# Scores

	compute_nutriscore($product_ref);
	compute_nova_group($product_ref);
	compute_nutrient_levels($product_ref);

	# Environmental analysis

	compute_environmental_score($product_ref);
	compute_forest_footprint($product_ref);

	# Determine packaging components in contact with food
	determine_food_contact_of_packaging_components_service($product_ref);

	# Add some labels from nutrition data (e.g. glycemic index, carbon footprint)
	add_labels_from_nutrition_data($product_ref);

	# Add misc tags for nutrition data per X (done last as compute_nutriscore() removes misc_tags starting with en:nutrition)
	add_misc_tags_for_input_nutrition_data_pers($product_ref);

	return;
}

sub add_labels_from_nutrition_data ($product_ref) {

	if (deep_exists($product_ref, 'nutrition', 'aggregated_set', 'nutrients', 'carbon-footprint'))

	{
		push @{$product_ref->{"labels_hierarchy"}}, "en:carbon-footprint";
		push @{$product_ref->{"labels_tags"}}, "en:carbon-footprint";
	}

	if (deep_exists($product_ref, 'nutrition', 'aggregated_set', 'nutrients', 'glycemic-index'))

	{
		push @{$product_ref->{"labels_hierarchy"}}, "en:glycemic-index";
		push @{$product_ref->{"labels_tags"}}, "en:glycemic-index";
	}

	return;
}

1;
