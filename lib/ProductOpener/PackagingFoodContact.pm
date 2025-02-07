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

ProductOpener::PackagingFoodContact 

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

package ProductOpener::PackagingFoodContact;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&determine_food_contact_of_packaging_components_service
		&determine_food_contact_of_packaging_components
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::API qw/add_warning/;
use ProductOpener::Packaging qw/%packaging_taxonomies/;
use ProductOpener::Tags qw/:all/;

use Data::DeepAccess qw(deep_get deep_val);
use List::Util qw(first);

=head1 FUNCTIONS

=head2 determine_food_contact_of_packaging_components_service ( $product_ref, $updated_product_fields_ref, $errors_ref )

Determine if packaging components are in contact with the food.

This function is a product service that can be run through ProductOpener::ApiProductServices

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=cut

sub determine_food_contact_of_packaging_components_service (
	$product_ref,
	$updated_product_fields_ref = {},
	$errors_ref = []
	)
{

	# Check if we have packaging data in the packagings structure
	my $packagings_ref = $product_ref->{packagings};

	if (not defined $packagings_ref) {
		push @{$errors_ref},
			{
			message => {id => "missing_field"},
			field => {
				id => "packagings",
				impact => {id => "skipped_service"},
				service => {id => "determine_food_contact_of_packaging_components"}
			}
			};
		return;
	}

	# indicate that the service is updating the "packagings" structure
	$updated_product_fields_ref->{packagings} = 1;

	determine_food_contact_of_packaging_components($packagings_ref, $product_ref);

	return;
}

=head2 get_matching_and_non_matching_packaging_components ($packagings_ref, $conditions_ref)

Find packaging components that match specific conditions (e.g material, shape, recycling).
Conditions are matched using the taxonomy, a parent in the condition matches more specific children.
(e.g. "en:plastic" matches "en:pet" and "en:hdpe")

=head3 Parameters

=head4 $packaging_ref packaging data

=head4 $conditions_ref conditions

Hash reference with conditions like material, shape, recycling as keys, and a value or an array of values as values.

=head3 Return values

Array with:
- a reference to an array of packaging components that match the conditions,
- a reference to an array of packaging components that do not match the conditions.

=cut 

sub get_matching_and_non_matching_packaging_components ($packagings_ref, $conditions_ref) {

	my @matching_packagings = ();
	my @non_matching_packagings = ();

	foreach my $packaging_ref (@$packagings_ref) {

		my $matched = 1;

		foreach my $property (keys %$conditions_ref) {

			if (defined $packaging_ref->{$property}) {

				# Check if the component value is a child of one of the condition values
				my @values
					= ref $conditions_ref->{$property} eq 'ARRAY'
					? @{$conditions_ref->{$property}}
					: ($conditions_ref->{$property});
				my $matched_value = 0;

				foreach my $value (@values) {
					if (is_a($packaging_taxonomies{$property}, $packaging_ref->{$property}, $value)) {
						$matched_value = 1;
						last;
					}
				}
				if (not $matched_value) {
					$matched = 0;
					last;
				}
			}
			else {
				$matched = 0;
				last;
			}
		}

		if ($matched) {
			push @matching_packagings, $packaging_ref;
		}
		else {
			push @non_matching_packagings, $packaging_ref;
		}
	}

	return \@matching_packagings, \@non_matching_packagings;
}

sub set_food_contact_property_of_packaging_components ($packagings_ref, $food_contact) {

	foreach my $packaging_ref (@$packagings_ref) {

		$packaging_ref->{food_contact} = $food_contact;
	}

	return;
}

=head2 determine_food_contact_of_packaging_components ($packagings_ref, $product_ref = {})

Determine if packaging components are in contact with the food.

=head3 Parameters

=head4 $packagings_ref packaging data

=head4 $product_ref product data (optional)

Used to apply specific rules (e.g. for products in specific categories)

=cut

sub determine_food_contact_of_packaging_components ($packagings_ref, $product_ref = {}) {

	# Cans: only the can itself is in contact with the food
	my ($cans_ref, $non_cans_ref)
		= get_matching_and_non_matching_packaging_components($packagings_ref, {shape => "en:can"});
	if (@$cans_ref) {
		set_food_contact_property_of_packaging_components($cans_ref, 1);
		set_food_contact_property_of_packaging_components($non_cans_ref, 0);
		return;
	}

	# Bottles, pots, jars: in contact with the food
	my ($bottles_ref, $non_bottles_ref)
		= get_matching_and_non_matching_packaging_components($packagings_ref,
		{shape => ["en:bottle", "en:pot", "en:jar"]});
	if (@$bottles_ref) {
		set_food_contact_property_of_packaging_components($bottles_ref, 1);
		set_food_contact_property_of_packaging_components($non_bottles_ref, 0);

		# If there is a seal, it is in contact with the food
		my ($seals_ref, $non_seals_ref)
			= get_matching_and_non_matching_packaging_components($non_bottles_ref, {shape => "en:seal"});
		if (@$seals_ref) {
			set_food_contact_property_of_packaging_components($seals_ref, 1);
		}
		# Otherwise, if there is a lid or a cap, it is in contact wit the food
		else {
			my ($lids_ref, $non_lids_ref)
				= get_matching_and_non_matching_packaging_components($non_bottles_ref, {shape => ["en:lid-or-cap"]});
			if (@$lids_ref) {
				set_food_contact_property_of_packaging_components($lids_ref, 1);
			}
		}
		return;
	}

	# Trays: in contact with food, and the film is in contact with the food
	my ($trays_ref, $non_trays_ref)
		= get_matching_and_non_matching_packaging_components($packagings_ref, {shape => "en:tray"});
	if (@$trays_ref) {
		set_food_contact_property_of_packaging_components($trays_ref, 1);
		set_food_contact_property_of_packaging_components($non_trays_ref, 0);

		my ($films_ref, $non_films_ref)
			= get_matching_and_non_matching_packaging_components($non_trays_ref, {shape => "en:film"});
		if (@$films_ref) {
			set_food_contact_property_of_packaging_components($films_ref, 1);
		}
		return;
	}

	# Individual packaging components (dose, bag): in contact with the food
	my ($individuals_ref, $non_individuals_ref)
		= get_matching_and_non_matching_packaging_components($packagings_ref,
		{shape => ["en:individual-dose", "en:individual-bag"]});
	if (@$individuals_ref) {
		set_food_contact_property_of_packaging_components($individuals_ref, 1);
		set_food_contact_property_of_packaging_components($non_individuals_ref, 0);
		return;
	}

	# Specific rules for chocolate bars
	if (has_tag($product_ref, "categories", "en:chocolates")) {

		# We could have a plastic wrap in contact with the chocolate, or as an outside packaging if there are several paper bars..

		# If there is a metallic film, sheet, wrap etc., it is in contact with the food
		my ($metals_ref, $non_metals_ref)
			= get_matching_and_non_matching_packaging_components($packagings_ref,
			{material => "en:metal", shape => ["en:film", "en:sheet"]});
		if (@$metals_ref) {
			set_food_contact_property_of_packaging_components($metals_ref, 1);
			return;
		}

		# Otherwise, if there is a plastic film, sheet, wrap etc. , it is in contact with the food
		my ($plastics_ref, $non_plastics_ref)
			= get_matching_and_non_matching_packaging_components($packagings_ref,
			{material => "en:plastic", shape => ["en:film", "en:sheet"]});
		if (@$plastics_ref) {
			set_food_contact_property_of_packaging_components($plastics_ref, 1);
			return;
		}
	}

	# If there is only one packaging component, it is in contact with the food
	if (@$packagings_ref == 1) {
		set_food_contact_property_of_packaging_components($packagings_ref, 1);
		return;
	}

	return;
}

1;

