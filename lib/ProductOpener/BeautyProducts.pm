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

ProductOpener::BeautyProducts - functions related to beauty products and nutrition

=head1 DESCRIPTION

C<ProductOpener::BeautyProducts> contains functions specific to beauty products.

..

=cut

package ProductOpener::BeautyProducts;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&specific_processes_for_beauty_product

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Ingredients
	qw/select_ingredients_lc clean_ingredients_text extract_ingredients_from_text extract_additives_from_text detect_allergens_from_text/;
use ProductOpener::Food qw/compute_nutrition_data_per_100g_and_per_serving assign_categories_properties_to_product/;

use Log::Any qw($log);

=head2 specific_processes_for_beauty_product ( $ingredients_ref )

Runs specific processes for beauty products:

- Ingredients analysis
- Additives detection
- Allergens detection
- Computation of scores

=cut

sub specific_processes_for_beauty_product ($product_ref) {

	# Ingredients analysis

	# Select best language to parse ingredients
	$product_ref->{ingredients_lc} = select_ingredients_lc($product_ref);
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);

	# Serving size
	compute_nutrition_data_per_100g_and_per_serving($product_ref);

	return;
}

1;
