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

ProductOpener::APIProductWrite - implementation of WRITE API for creating and updating products

=head1 DESCRIPTION

=cut

package ProductOpener::APIProductWrite;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&write_product_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::Packaging qw/:all/;

=head2 update_field_with_0_or_1_value($request_ref, $product_ref, $field, $value)

Update a field that takes only 0 or 1 as a value (e.g. packagings_complete).

=cut

sub update_field_with_0_or_1_value ($request_ref, $product_ref, $field, $value) {

	my $response_ref = $request_ref->{api_response};

	# Check that the value is 0 or 1

	if (($value != 0) and ($value != 1)) {

		add_error(
			$response_ref,
			{
				message => {id => "invalid_value_must_be_0_or_1"},
				field => {id => $field},
				impact => {id => "field_ignored"},
			}
		);
	}
	else {
		$product_ref->{$field} = $value + 0;    # add 0 to make sure the value is stored as a number
	}
	return;
}

=head2 update_packagings($request_ref, $product_ref, $field, $is_addition, $value)

Update packagings.

=cut

sub update_packagings ($request_ref, $product_ref, $field, $is_addition, $value) {

	my $request_body_ref = $request_ref->{body_json};
	my $response_ref = $request_ref->{api_response};

	if (ref($value) ne 'ARRAY') {
		add_error(
			$response_ref,
			{
				message => {id => "invalid_type_must_be_array"},
				field => {id => $field},
				impact => {id => "field_ignored"},
			}
		);
	}
	else {
		if (not $is_addition) {
			# We will replace the packagings structure if it already exists
			$product_ref->{packagings} = [];
		}

		foreach my $input_packaging_ref (@{$value}) {

			# Shape, material and recycling
			foreach my $property ("shape", "material", "recycling") {
				if (defined $input_packaging_ref->{$property}) {

					# the API specifies that the property is a hash with either an id or a lc_name field
					# (same structure as when the packagings structure is read)
					# both will be treated the same way and be canonicalized
					# by get_checked_and_taxonomized_packaging_component_data()

					if (ref($input_packaging_ref->{$property}) eq 'HASH') {
						$input_packaging_ref->{$property} = $input_packaging_ref->{$property}{id}
							|| $input_packaging_ref->{$property}{lc_name};
					}
					else {
						add_error(
							$response_ref,
							{
								message => {id => "invalid_type_must_be_object"},
								field => {id => $property},
								impact => {id => "field_ignored"},
							}
						);
					}
				}
			}

			# Taxonomize the input packaging component data
			my $packaging_ref = get_checked_and_taxonomized_packaging_component_data($request_body_ref->{tags_lc},
				$input_packaging_ref, $response_ref);

			if (defined $packaging_ref) {
				# Add or combine with the existing packagings components array
				add_or_combine_packaging_component_data($product_ref, $packaging_ref, $response_ref);
			}
		}
	}
	return;
}

=head2 update_product_fields ($request_ref, $product_ref)

Update product fields based on input product data.

=cut

sub update_product_fields ($request_ref, $product_ref) {

	my $request_body_ref = $request_ref->{body_json};

	$request_ref->{updated_product_fields} = {};

	my $input_product_ref = $request_body_ref->{product};

	foreach my $field (sort keys %{$input_product_ref}) {

		my $value = $input_product_ref->{$field};

		# Packaging components
		if ($field =~ /^(packagings)(_add)?$/) {
			$request_ref->{updated_product_fields}{$1} = 1;
			my $is_addition = (defined $2) ? 1 : 0;

			update_packagings($request_ref, $product_ref, $field, $is_addition, $value);
		}
		# packagings_complete contains 0 or 1 and is used to indicate that all packaging components are listed in the packagings field
		elsif ($field eq "packagings_complete") {
			$request_ref->{updated_product_fields}{$field} = 1;

			update_field_with_0_or_1_value($request_ref, $product_ref, $field, $value);
		}
	}
	return;
}

=head2 write_product_api()

Process API v3 WRITE product requests.

TODO: v0 / v1 / v2 WRITE product requests are still handled by cgi/product_jqm_multilingual.pl which contains similar code.
Internally, we should be able to upgrade those requests to v3, and then customize the response to make it return the v2 expected response.

=cut

sub write_product_api ($request_ref) {

	$log->debug("write_product_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};
	my $request_body_ref = $request_ref->{body_json};

	$log->debug("write_product_api - body", {request_body => $request_body_ref}) if $log->is_debug();

	if (not defined $request_body_ref) {
		$log->error("write_product_api - missing or invalid input body", {}) if $log->is_error();
	}
	elsif (not defined $request_body_ref->{product}) {
		$log->error("write_product_api - missing input product", {request_body => $request_body_ref})
			if $log->is_error();
		add_error(
			$response_ref,
			{
				message => {id => "missing_field"},
				field => {id => "product"},
				impact => {id => "failure"},
			}
		);
	}
	else {

		# Use default request language if we did not get tags_lc
		if (not defined $request_body_ref->{tags_lc}) {
			$request_body_ref->{tags_lc} = $lc;
			add_warning(
				$response_ref,
				{
					message => {id => "missing_field"},
					field => {id => "tags_lc", default_value => $request_body_ref->{tags_lc}},
					impact => {id => "warning"},
				}
			);
		}

		# Load the product
		my $code = normalize_requested_code($request_ref->{code}, $response_ref);
		my $product_id = product_id_for_owner($Owner_id, $code);
		my $product_ref = retrieve_product($product_id);

		if (not defined $product_ref) {
			$product_ref = init_product($User_id, $Org_id, $code, $country);
			$product_ref->{interface_version_created} = "20221102/api/v3";
		}

		# Process edit rules

		$log->debug("phase 0 - checking edit rules", {code => $code}) if $log->is_debug();

		my $proceed_with_edit = process_product_edit_rules($product_ref);

		$log->debug("phase 0", {code => $code, proceed_with_edit => $proceed_with_edit}) if $log->is_debug();

		if (not $proceed_with_edit) {

			add_error(
				$response_ref,
				{
					message => {id => "edit_against_edit_rules"},
					field => {id => "product"},
					impact => {id => "failure"},
				}
			);
		}
		else {
			# Response structure to keep track of warnings and errors for the whole product
			# (not for the update fields)
			# Note: currently some warnings and errors are added,
			# but we do not yet do anything with them
			my $product_response_ref = get_initialized_response();

			# Update the product
			update_product_fields($request_ref, $product_ref);

			# Process the product data
			analyze_and_enrich_product_data($product_ref, $product_response_ref);

			# Save the product
			my $comment = $request_body_ref->{comment} || "API v3";
			store_product($User_id, $product_ref, $comment);

			# Select / compute only the fields requested by the caller, default to updated fields
			$response_ref->{product} = customize_response_for_product($request_ref, $product_ref,
				request_param($request_ref, 'fields') || "updated");
		}
	}

	$log->debug("write_product_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

1;
