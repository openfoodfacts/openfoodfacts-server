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

ProductOpener::ProductsFeatures - Specify which features (e.g. ingredient list, Nutri-Score) are available for a specific product

=head1 DESCRIPTION

C<ProductOpener::ProductsFeatures> is used to turn on or off specific features for a product.

Currently, product features are determined using the product type (e.g. food, pet food, beauty products).

In the future, we may have features that depend on other attributes of the product (for instance its category)

=cut

package ProductOpener::ProductsFeatures;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&feature_enabled

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw(:all);

use Data::DeepAccess qw(deep_get);

use Log::Any qw($log);

my %product_type_features = (
	food => {
		health_card => 1,
		ingredients => 1,
		additives => 1,
		food_recommendations => 1,
		nova => 1,
		nutrition => 1,
		nutriscore => 1,
		environmental_score => 1,
		forest_footprint => 1,
		user_preferences => 1,
		popularity => 1,    # indicates if we have computed popularity from scan data
	},
	foodsupplement => {
		health_card => 1,
		ingredients => 1,
		additives => 1,
		nova => 1,
		nutrition => 1,
		user_preferences => 1,
	},
	petfood => {
		health_card => 1,
		ingredients => 1,
		additives => 1,
		nova => 1,
		nutrition => 1,
		user_preferences => 1,
	},
	beauty => {
		health_card => 1,
		ingredients => 1,
		user_preferences => 1,
	},
	product => {
		user_preferences => 1,
	},
);

=head2 features($feature, $product_ref)

Returns whether a specific feature is available for a product.

=head3 Parameters

=head4 $feature (input)

The feature to check.

=head4 $product_ref (input, optional)

Reference to the product hash.

Currently not used, may be used later to determine features based on product fields (e.g. category).

=head3 Return value

1 if the feature is available, undef or 0 otherwise.

=cut

sub feature_enabled($feature, $product_ref = undef) {
	# If we have a product reference, and the product type is set, use it
	# otherwise use the product type of the site instance (e.g. "Open Food Facts" -> "food")
	my $product_type
		= ((defined $product_ref) and (defined $product_ref->{product_type}))
		? $product_ref->{product_type}
		: $options{product_type};
	my $enabled = deep_get(\%product_type_features, $product_type, $feature);
	$log->debug("feature_enabled", {feature => $feature, product_type => $options{product_type}, enabled => $enabled})
		if $log->is_debug();
	return $enabled;
}

1;
