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

ProductOpener::EnvironmentalImpact - process and analyze products

=head1 SYNOPSIS

C<ProductOpener::EnvironmentalImpact> processes products to compute
their environmental impact (see french ecolabelling Ecobalyse).

    use ProductOpener::EnvironmentalImpact qw/:all/;

	[..]

	estimate_environmental_impact($product_ref);

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::EnvironmentalImpact;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&estimate_environmental_impact_service

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

=head1 FUNCTIONS

=head2 estimate_environmental_impact_service ( $product_ref, $updated_product_fields_ref, $errors_ref )

Compute the environemental cost of a given product (see the french environmental labelling Ecobalyse).

This function is a product service that can be run through ProductOpener::ApiProductServices

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=cut

sub estimate_environmental_impact_service ($product_ref, $updated_product_fields_ref, $errors_ref) {

    # $updated_product_fields_ref, $errors_ref sont des outputs : chaque service 
    # dit quels champs sont modifiés
    # Ici on en ajoute un : "environemental_impact"

    # If undefined ingredients, do nothing
    return if not defined $product_ref->{ingredients};

	# indicate that the service is modifying the "ingredients" structure
	$updated_product_fields_ref->{environmental_impact} = 1;
    $product_ref->{environmental_impact} = 0;

    # Estimating the environmental impact
    while (@ingredients) {
        # Remove and process the first ingredient from the list
        my $ingredient_ref = shift @ingredients;

        # Dummy calculation
        $product_ref->{environmental_impact}++;
    }

    # If necessary, return error as well 
    # (number of unattributed ingredients, 
    # percentage of unattributed mass, etc...)

    # add_error
    # add_warning

	return;
}