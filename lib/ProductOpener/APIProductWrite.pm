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
		&process_change_product_code_request_if_we_have_one
		&process_change_product_type_request_if_we_have_one
		&skip_protected_field
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/$subdomain $country/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Products qw/:all/;
use ProductOpener::API
	qw/add_error add_warning check_user_permission customize_response_for_product normalize_requested_code/;
use ProductOpener::Packaging
	qw/add_or_combine_packaging_component_data get_checked_and_taxonomized_packaging_component_data/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::Tags qw/%language_fields %writable_tags_fields add_tags_to_field compute_field_tags/;
use ProductOpener::URL qw(format_subdomain);
use ProductOpener::HTTP qw/request_param single_param redirect_to_url/;

use Encode;

=head2 skip_protected_field($product_ref, $field, $moderator = 0)

Return 1 if we should ignore a field value sent by a user because we already have a value sent by the producer.

=cut

sub skip_protected_field ($product_ref, $field, $moderator = 0) {

	# If we are on the public platform, and the field data has been imported from the producer platform
	# ignore the field changes for non tag fields, unless made by a moderator
	if (    (not $server_options{producers_platform})
		and (not $moderator)
		and (is_owner_field($product_ref, $field)))
	{
		$log->debug(
			"skipping field with a value set by the owner",
			{
				code => $product_ref->{code},
				field_name => $field,
				existing_field_value => $product_ref->{$field},
				new_field_value => remove_tags_and_quote(decode utf8 => single_param($field))
			}
		) if $log->is_debug();
		return 1;
	}
	return 0;
}

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
			},
			200
		);
	}
	else {
		$product_ref->{$field} = $value + 0;    # add 0 to make sure the value is stored as a number
	}
	return;
}

=head2 update_packagings($request_ref, $product_ref, $field, $add_to_existing_components, $value)

Update packagings.

=cut

sub update_packagings ($request_ref, $product_ref, $field, $add_to_existing_components, $value) {

	my $request_body_ref = $request_ref->{body_json};
	my $response_ref = $request_ref->{api_response};

	if (ref($value) ne 'ARRAY') {
		add_error(
			$response_ref,
			{
				message => {id => "invalid_type_must_be_array"},
				field => {id => $field},
				impact => {id => "field_ignored"},
			},
			200
		);
	}
	else {
		if (not $add_to_existing_components) {
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
							},
							200
						);
					}
				}
			}

			# Taxonomize the input packaging component data
			my $packaging_ref = get_checked_and_taxonomized_packaging_component_data($request_body_ref->{tags_lc},
				$input_packaging_ref, $response_ref);

			if (defined $packaging_ref) {
				if (not $add_to_existing_components) {
					push @{$product_ref->{packagings}}, $packaging_ref;
				}
				else {
					# Add or combine with the existing packagings components array
					add_or_combine_packaging_component_data($product_ref, $packaging_ref, $response_ref);
				}
			}
		}
	}
	return;
}

=head2 update_tags_fields ($request_ref, $product_ref, $field, $add_to_existing_tags, $value)

Update packagings.

=cut

sub update_tags_fields ($request_ref, $product_ref, $field, $add_to_existing_tags, $tags_lc, $value) {

	my $request_body_ref = $request_ref->{body_json};
	my $response_ref = $request_ref->{api_response};

	if (ref($value) ne 'ARRAY') {
		add_error(
			$response_ref,
			{
				message => {id => "invalid_type_must_be_array"},
				field => {id => $field},
				impact => {id => "field_ignored"},
			},
			200
		);
	}
	else {
		# Generate a comma separated list of tags, so that we can use existing functions to add tags
		my $tags_list = join(',', @$value);

		if ($add_to_existing_tags) {
			add_tags_to_field($product_ref, $tags_lc, $field, $tags_list);
		}
		else {
			$product_ref->{$field} = $tags_list;
		}

		compute_field_tags($product_ref, $tags_lc, $field);

		$request_ref->{updated_product_fields}{$field} = 1;    # joined inputs, can be in any language
		$request_ref->{updated_product_fields}{$field . '_hierarchy'}
			= 1;  # tags, with entries that are not in the taxonomy in original format (with accents, caps, spaces etc.)
		$request_ref->{updated_product_fields}{$field . '_tags'}
			= 1;    # tags, with entries that are not in the taxonomy in a normalized format
		$request_ref->{updated_product_fields}{$field . '_tags_' . $tags_lc}
			= 1;    # resulting values in the language used to send input values

		$log->debug(
			"update_tags_fields",
			{
				field => $field,
				tags_lc => $tags_lc,
				value => $value,
				tags_list => $tags_list,
				product_field => $product_ref->{$field},
				product_field_tags => $product_ref->{$field . "_tags"}
			}
		) if $log->is_debug();
	}
	return;
}

=head2 update_product_fields ($request_ref, $product_ref, $response_ref)

Update product fields based on input product data.

=cut

# Fields that are not language or tags fields, and that can be written as-is
my %product_simple_fields = (
	quantity => 1,
	serving_size => 1,
);

sub update_product_fields ($request_ref, $product_ref, $response_ref) {

	my $request_body_ref = $request_ref->{body_json};

	if (not exists $request_ref->{updated_product_fields}) {
		$request_ref->{updated_product_fields} = {};
	}

	my $input_product_ref = $request_body_ref->{product};

	foreach my $field (sort keys %{$input_product_ref}) {

		# new_code and product_type have been handled previously,
		# as we do not process the write requests if there is an error with a change of code or product type
		next if $field =~ /^(new_code|product_type)$/;

		my $value = $input_product_ref->{$field};

		# Call preprocess_product_field function for each field
		$value = preprocess_product_field($field, $value);

		# Packaging components
		if ($field =~ /^(packagings)(_add)?$/) {
			$request_ref->{updated_product_fields}{$1} = 1;
			my $add_to_existing_components = (defined $2) ? 1 : 0;

			update_packagings($request_ref, $product_ref, $field, $add_to_existing_components, $value);
		}
		# packagings_complete contains 0 or 1 and is used to indicate that all packaging components are listed in the packagings field
		elsif ($field eq "packagings_complete") {
			$request_ref->{updated_product_fields}{$field} = 1;

			update_field_with_0_or_1_value($request_ref, $product_ref, $field, $value);
		}
		# language fields
		elsif ( ($field =~ /^(.*)_(\w\w)$/)
			and (defined $language_fields{$1}))
		{

			my $language_field = $1;
			my $language_field_lc = $2;

			$request_ref->{updated_product_fields}{$field} = 1;

			$product_ref->{$language_field . '_' . $language_field_lc} = $value;
		}
		# tags fields
		elsif ( ($field =~ /^(.*)_tags(?:_(\w\w))?(_add)?$/)
			and (defined $writable_tags_fields{$1}))
		{
			my $tagtype = $1;
			# If we are passed a language (e.g. categories_tags_fr, use it
			# otherwise use the value of the tags_lc request field)
			my $tags_lc = $2 // $request_body_ref->{tags_lc};

			my $add_to_existing_tags = $3;

			update_tags_fields($request_ref, $product_ref, $tagtype, $add_to_existing_tags, $tags_lc, $value);
		}
		# Simple product fields
		elsif (defined $product_simple_fields{$field}) {
			$product_ref->{$field} = remove_tags_and_quote($value);
			$request_ref->{updated_product_fields}{$field} = 1;
		}
		# Main language
		elsif ($field eq "lang") {
			if ($value !~ /^[a-z]|[a-z]$/i) {
				add_error(
					$response_ref,
					{
						message => {id => "invalid_language_code"},
						field => {id => $field},
						impact => {id => "field_ignored"},
					},
					200
				);

			}
			else {
				$product_ref->{$field} = lc($value);
				$product_ref->{lc} = $value;
				$request_ref->{updated_product_fields}{$field} = 1;
			}
		}
		# Unrecognized field
		else {
			add_warning(
				$response_ref,
				{
					message => {id => "unrecognized_field"},
					field => {id => $field, value => $value},
					impact => {id => "warning"},
				}
			);
		}
	}
	return;
}

=head2 process_change_product_code_request_if_we_have_one($request_ref, $response_ref, $product_ref, $new_code)

Process a change of code request if we have one.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head4 $response_ref (input)

Reference to the response object.

=head4 $product_ref (input)

Reference to the product object.

=head4 $new_code (input)

New code.

=head3 Return value

undef if we don't have a change product code request, or if it was processed correctly.
an error id if there was an error (e.g. no_permisssion or invalid_product_type).

=cut

sub process_change_product_code_request_if_we_have_one($request_ref, $response_ref, $product_ref, $new_code) {

	my $error;
	# Change of code
	if (    (defined $new_code)
		and ($new_code ne $product_ref->{code}))
	{

		if (check_user_permission($request_ref, $response_ref, "product_change_code")) {

			$error = change_product_code($product_ref, $new_code);
			if ($error) {
				add_error(
					$response_ref,
					{
						message => {id => $error},
						field => {id => "new_code"},
						impact => {id => "failure"},
					}
				);
			}
		}
		else {
			$error = "no_permission: product_change_code";
		}
	}
	# If we have an error, we return it, otherwise we just use "return;"
	# so that the function can be used in list context: push @errors, process_change_product_code_request_if_we_have_one(...)
	if ($error) {
		return $error;
	}
	return;
}

sub process_change_product_type_request_if_we_have_one($request_ref, $response_ref, $product_ref, $new_product_type) {

	my $error;

	# Change of product type
	if (
			(defined $new_product_type)
		and ($new_product_type ne "")
		and ($new_product_type ne
			"null")    # 2024/11/21: OFF app sends "null" as a string, ignore it as it is not a valid product type
		and ($new_product_type ne $product_ref->{product_type})
		)
	{

		if (check_user_permission($request_ref, $response_ref, "product_change_product_type")) {

			$error = change_product_type($product_ref, $new_product_type);
			if ($error) {
				add_error(
					$response_ref,
					{
						message => {id => $error},
						field => {id => "product_type"},
						impact => {id => "failure"},
					}
				);
			}
			else {
				$request_ref->{updated_product_fields}{product_type} = 1;
			}
		}
		else {
			$error = "no_permission: product_change_product_type";
		}
	}

	# If we have an error, we return it, otherwise we just use "return;"
	# so that the function can be used in list context: push @errors, process_change_product_code_request_if_we_have_one(...)
	if ($error) {
		return $error;
	}
	return;
}

=head2 write_product_api($request_ref)

Process API v3 WRITE product requests.

TODO: v0 / v1 / v2 WRITE product requests are still handled by cgi/product_jqm_multilingual.pl which contains similar code.
Internally, we should be able to upgrade those requests to v3, and then customize the response to make it return the v2 expected response.

=cut

sub write_product_api ($request_ref) {

	$log->debug("write_product_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};
	my $request_body_ref = $request_ref->{body_json};

	$log->debug("write_product_api - body", {request_body => $request_body_ref}) if $log->is_debug();

	my $error = 0;

	my $code = $request_ref->{code};
	my $product_ref;

	if (not defined $request_body_ref) {
		$log->error("write_product_api - missing or invalid input body", {}) if $log->is_error();
		$error = 1;
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
		$error = 1;
	}
	else {
		# If the code is "test", the API won't save any product, but it will analyze the input product data
		# and return computed fields like Nutri-Score, product attributes etc.

		if ($code ne 'test') {
			# Load the product
			($code, my $ai_data_string) = &normalize_requested_code($request_ref->{code}, $response_ref);

			# Check if the code is valid
			if ($code !~ /^\d{4,24}$/) {

				$log->info("invalid code", {code => $code, original_code => $request_ref->{code}}) if $log->is_info();
				add_error(
					$response_ref,
					{
						message => {id => "invalid_code"},
						field => {id => "code", value => $request_ref->{code}},
						impact => {id => "failure"},
					}
				);
				$error = 1;
			}
			else {
				my $product_id = product_id_for_owner($Owner_id, $code);
				$product_ref = retrieve_product($product_id);
			}
		}
	}

	# If we did not get a fatal error, we can update the product
	if (not $error) {

		# The product does not exist yet, or the requested code is "test"
		if (not defined $product_ref) {
			$product_ref = init_product($User_id, $Org_id, $code, $country);
			$product_ref->{interface_version_created} = "20221102/api/v3";
		}
		else {
			# There is an existing product
			# If the product has a product_type and it is not the product_type of the server, redirect to the correct server
			# unless we are on the pro platform

			if (    (not $server_options{private_products})
				and (defined $product_ref->{product_type})
				and ($product_ref->{product_type} ne $options{product_type}))
			{
				redirect_to_url($request_ref, 307,
					format_subdomain($subdomain, $product_ref->{product_type}) . '/api/v3/product/' . $code);
			}
		}

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
				},
				403
			);
		}
		else {

			if (
				process_change_product_code_request_if_we_have_one(
					$request_ref, $response_ref, $product_ref, $request_body_ref->{product}{code}
				)
				)
			{
				$error = 1;
			}

			if (
				process_change_product_type_request_if_we_have_one(
					$request_ref, $response_ref, $product_ref, $request_body_ref->{product}{product_type}
				)
				)
			{
				$error = 1;
			}

			if (not $error) {
				# Update the product
				update_product_fields($request_ref, $product_ref, $response_ref);

				# Process the product data
				analyze_and_enrich_product_data($product_ref, $response_ref);

				# Save the product
				if ($code ne "test") {
					my $comment = $request_body_ref->{comment} || "API v3";
					store_product($User_id, $product_ref, $comment);
				}

				# Select / compute only the fields requested by the caller, default to updated fields
				$response_ref->{product} = customize_response_for_product($request_ref, $product_ref,
					request_param($request_ref, 'fields') || "updated");
			}
		}
	}

	$log->debug("write_product_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

1;
