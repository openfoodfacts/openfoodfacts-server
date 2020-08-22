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

use utf8;
use Modern::Perl '2017';
use Exporter qw(import);

BEGIN
{
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&check_quality
		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::Config qw(:all);
use ProductOpener::Tags qw(:all);

use ProductOpener::DataQualityCommon qw(:all);
use ProductOpener::DataQualityFood qw(:all);
use ProductOpener::ProducersFood qw(:all);


=head1 FUNCTIONS

=head2 check_quality( PRODUCT_REF )

C<check_quality()> checks the quality of data for a given product.

   check_quality($product_ref)

=cut

sub check_quality($) {

	my $product_ref = shift;

	# Remove old quality_tags
	delete $product_ref->{quality_tags};

	# Initialize the data_quality arrays
	$product_ref->{data_quality_bugs_tags} = [];
	$product_ref->{data_quality_info_tags} = [];
	$product_ref->{data_quality_warnings_tags} = [];
	$product_ref->{data_quality_errors_tags} = [];

	check_quality_common($product_ref);

	if ($options{product_type} eq "food") {
		check_quality_food($product_ref);
	}

	# Also combine all sub facets in a data-quality facet
	$product_ref->{data_quality_tags} = [
		@{$product_ref->{data_quality_bugs_tags}},
		@{$product_ref->{data_quality_info_tags}},
		@{$product_ref->{data_quality_warnings_tags}},
		@{$product_ref->{data_quality_errors_tags}},
	];

	# If we are on the producers platform, also populate facets with the values that exist
	# in the data-quality taxonomy and that have the show_on_producers_platform:en:yes property
	if ((defined $server_options{private_products}) and ($server_options{private_products})) {

		foreach my $level ("warnings", "errors") {

			$product_ref->{"data_quality_" . $level . "_producers_tags"} = [];

			foreach my $value (@{$product_ref->{"data_quality_" . $level . "_tags"}}) {
				if (exists_taxonomy_tag("data_quality", $value)) {
					my $show_on_producers_platform = get_property("data_quality", $value, "show_on_producers_platform:en");
					if ((defined $show_on_producers_platform) and ($show_on_producers_platform eq "yes")) {
						push @{$product_ref->{"data_quality_" . $level . "_producers_tags"}}, $value;
					}
				}
			}
		}

		# Detect possible improvements opportunities for food products
		if ($options{product_type} eq "food") {
			detect_possible_improvements($product_ref);
		}
	}

	return;
}


1;
