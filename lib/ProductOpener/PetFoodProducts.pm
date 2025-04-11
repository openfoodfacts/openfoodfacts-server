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

ProductOpener::PetFood - functions related to pet food products and nutrition

=head1 DESCRIPTION

C<ProductOpener::PetFood> contains functions specific to pet food products.

..

=cut

package ProductOpener::PetFoodProducts;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&specific_processes_for_pet_food_product

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Ingredients
	qw/select_ingredients_lc clean_ingredients_text extract_ingredients_from_text extract_additives_from_text detect_allergens_from_text/;
use ProductOpener::NutritionEstimation qw/estimate_nutrients_from_ingredients/;
use ProductOpener::Food
	qw/compute_nutrition_data_per_100g_and_per_serving assign_categories_properties_to_product compute_estimated_nutrients compute_unknown_nutrients compute_nova_group/;

use Hash::Util;
use Encode;
use URI::Escape::XS;

use CGI qw/:cgi :form escapeHTML/;

use Data::DeepAccess qw(deep_set deep_get);
use Storable qw/dclone/;

use Log::Any qw($log);

=head2 specific_processes_for_pet_food_product ( $ingredients_ref )

Runs specific processes for pet food products:

- Ingredients analysis
- Additives detection
- Allergens detection
- Computation of scores

=cut

sub specific_processes_for_pet_food_product ($product_ref) {

	# Ingredients analysis

	# Select best language to parse ingredients
	$product_ref->{ingredients_lc} = select_ingredients_lc($product_ref);
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);
	extract_additives_from_text($product_ref);
	detect_allergens_from_text($product_ref);

	# Category analysis

	# Nutrition data
	compute_nutrition_data_per_100g_and_per_serving($product_ref);

	# Nutrients
	compute_unknown_nutrients($product_ref);

	# Scores

	# Environmental analysis

	return;
}

1;
