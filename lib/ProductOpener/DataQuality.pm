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

ProductOpener::DataQuality - check the quality of data for products

=head1 SYNOPSIS

C<ProductOpener::DataQuality> is used to check the quality of the data of products
when they are updated.

    use ProductOpener::DataQuality qw/:all/;
	check_quality($product_ref);

	if (has_tag($product_ref, "data_quality", "en:nutrition-value-total-over-105")) {
		print STDERR "The nutrition facts values are incorrect.";
	}

C<check_quality()> populates the data_quality_[bugs|info|warnings|errors]_tags arrays
and sub-facets:

- /data-quality-bugs : data issues that are due to bugs in the software (and not
bad data entered by users or supplied by producers)

- /data-quality-info : info about product data that does not indicate that there is an error

- /data-quality-warnings : indications that there may be an error in the data (but it is not certain)

- /data-quality-errors : errors in the product data

The values of all sub-facets are also combined in the data_quality_tags array
and /data-quality facet.

C<check_quality()> is run each time products are updated. It can also be run through
the C<scripts/update_all_products.pl> script.

=head1 DESCRIPTION

C<ProductOpener::DataQuality> uses submodules to check quality issues that
can affect different types of products:

C<ProductOpener::DataQualityCommon> for all types of products.

C<ProductOpener::DataQualityFood> for food products.

The type of product is specified through Config.pm

    $options{product_type} = "food";

=cut

package ProductOpener::DataQuality;

use ProductOpener::PerlStandards;
use Exporter qw(import);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&check_quality
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::Config qw(:all);
use ProductOpener::Tags qw(%level exists_taxonomy_tag get_inherited_property has_tag);

use ProductOpener::DataQualityCommon qw(check_quality_common);
use ProductOpener::DataQualityFood qw(check_quality_food);
use ProductOpener::ProducersFood qw(detect_possible_improvements);

=head1 FUNCTIONS

=head2 check_quality( PRODUCT_REF )

C<check_quality()> checks the quality of data for a given product.

   check_quality($product_ref)

=cut

sub check_quality_service ($product_ref, $updated_product_fields_ref, $fields_to_check = ['nutrition', 'ingredients']) {
    # Remove old quality tags
    delete $product_ref->{quality_tags};

    # Initialize the data quality arrays
    $product_ref->{data_quality_bugs_tags} = [];
    $product_ref->{data_quality_info_tags} = [];
    $product_ref->{data_quality_warnings_tags} = [];
    $product_ref->{data_quality_errors_tags} = [];

    # Run general quality checks applicable across different product types
    ProductOpener::DataQualityFood::check_quality_food($product_ref);

    # Check specific fields based on $fields_to_check
    for my $field (@$fields_to_check) {
        if ($field eq 'nutrition' && defined $product_ref->{nutrition}) {
            ProductOpener::DataQualityFood::check_nutrition_data($product_ref);
            ProductOpener::DataQualityFood::check_nutrition_data_energy_computation($product_ref);
        }
        if ($field eq 'ingredients' && defined $product_ref->{ingredients}) {
            ProductOpener::DataQualityFood::check_ingredients($product_ref);
        }
        # Additional checks for specific food products
        if ($field eq 'food' && $options{product_type} eq "food") {
            ProductOpener::DataQualityFood::check_quality_food($product_ref);
        }
    }

    # Combine all data quality tags into a single array
    $product_ref->{data_quality_tags} = [
        @{$product_ref->{data_quality_bugs_tags}},
        @{$product_ref->{data_quality_info_tags}},
        @{$product_ref->{data_quality_warnings_tags}},
        @{$product_ref->{data_quality_errors_tags}}
    ];

    # Update the fields with quality tags
    $updated_product_fields_ref->{data_quality_tags} = $product_ref->{data_quality_tags};

    # Handle producer platform-specific tags and detect improvements if on a private platform
    if ((defined $server_options{private_products}) && ($server_options{private_products})) {
        foreach my $level ("warnings", "errors") {
            $product_ref->{"data_quality_" . $level . "_producers_tags"} = [];
            foreach my $value (@{$product_ref->{"data_quality_" . $level . "_tags"}}) {
                if (exists_taxonomy_tag("data_quality", $value)) {
                    my $show = get_inherited_property("data_quality", $value, "show_on_producers_platform:en");
                    if ((defined $show) && ($show eq "yes")) {
                        push @{$product_ref->{"data_quality_" . $level . "_producers_tags"}}, $value;
                    }
                }
            }
            $updated_product_fields_ref->{"data_quality_" . $level . "_producers_tags"} = $product_ref->{"data_quality_" . $level . "_producers_tags"};
        }
    }
}





1;
