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

ProductOpener::API - implementation of READ and WRITE APIs

=head1 DESCRIPTION

This module contains functions that are common to multiple types of API requests.

Specialized functions to process each type of API request is in separate modules like:

APIProductRead.pm : product READ
APIProductWrite.pm : product WRITE

=cut

package ProductOpener::API;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&init_api_response
		&get_initialized_response
		&add_warning
		&add_error
		&process_api_request
		&read_request_body
		&decode_json_request_body
		&normalize_requested_code
		&customize_response_for_product
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Text qw/:all/;
use ProductOpener::Attributes qw/:all/;
use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::Ecoscore qw/localize_ecoscore/;
use ProductOpener::Packaging qw/:all/;

use ProductOpener::APIProductRead qw/:all/;
use ProductOpener::APIProductWrite qw/:all/;
use ProductOpener::APITagRead qw/:all/;
use ProductOpener::APITaxonomySuggestions qw/:all/;

use CGI qw(header);
use Apache2::RequestIO();
use Apache2::RequestRec();
use JSON::PP;
use Data::DeepAccess qw(deep_get);
use Storable qw(dclone);
use Encode;

sub get_initialized_response() {
	return {
		warnings => [],
		errors => [],
	};
}

sub init_api_response ($request_ref) {

	$request_ref->{api_response} = get_initialized_response();

	$log->debug("init_api_response - done", {request => $request_ref}) if $log->is_debug();
	return $request_ref->{api_response};
}

sub add_warning ($response_ref, $warning_ref) {
	push @{$response_ref->{warnings}}, $warning_ref;
	return;
}

sub add_error ($response_ref, $error_ref) {
	push @{$response_ref->{errors}}, $error_ref;
	return;
}

sub add_invalid_method_error ($response_ref, $request_ref) {

	$log->warn("process_api_request - invalid method", {request => $request_ref}) if $log->is_warn();
	add_error(
		$response_ref,
		{
			message => {id => "invalid_api_method"},
			field => {
				id => "api_method",
				value => $request_ref->{api_method},
				api_action => $request_ref->{api_action},
			},
			impact => {id => "failure"},
		}
	);
	return;
}

=head2 read_request_body ($request_ref)

API V3 POST / PUT / PATCH requests do not use CGI Multipart Form data, and instead pass a JSON structure in the body.
This function reads the request body and saves it in $request_ref->{body}

It must be called before any call to CGI.pm param() which will read the body.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub read_request_body ($request_ref) {

	$log->debug("read_request_body - start", {request => $request_ref}) if $log->is_debug();

	my $r = Apache2::RequestUtil->request();

	my $content = '';

	{
		use bytes;

		my $offset = 0;
		my $cnt = 0;
		do {
			$cnt = $r->read($content, 262144, $offset);
			$offset += $cnt;
		} while ($cnt == 262144);
	}
	$request_ref->{body} = $content;

	$log->debug("read_request_body - end", {request => $request_ref}) if $log->is_debug();
	return;
}

=head2 decode_json_request_body ($request_ref)

Decodes the JSON body of a request and store it in $request_ref->{request_body_json}

Errors are returned in $request_ref->{api_response}

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub decode_json_request_body ($request_ref) {

	if (length($request_ref->{body}) == 0) {
		$log->error("empty request body", {}) if $log->is_error();
		add_error(
			$request_ref->{api_response},
			{
				message => {id => "empty_request_body"},
				field => {id => "body", value => ""},
				impact => {id => "failure"},
			}
		);
	}
	else {
		eval {$request_ref->{body_json} = decode_json($request_ref->{body});};
		if ($@) {
			$log->error("JSON decoding error", {error => $@}) if $log->is_error();
			add_error(
				$request_ref->{api_response},
				{
					message => {id => "invalid_json_in_request_body"},
					field => {id => "body", value => $request_ref->{body}},
					impact => {id => "failure"},
				}
			);
		}
	}
	return;
}

=head2 determine_request_result ($response_ref)

Based on the response's errors and warnings, determine the overall status of the request.

=head3 Parameters

=head4 $response_ref (input)

Reference to the response object.

=cut

sub determine_response_result ($response_ref) {

	my $status_id = "success";

	if (scalar @{$response_ref->{warnings}} > 0) {
		$status_id = "success_with_warnings";
	}

	if (scalar @{$response_ref->{errors}} > 0) {
		$status_id = "success_with_errors";

		# one error of type "failure" means a failure of whole request
		foreach my $error_ref (@{$response_ref->{errors}}) {
			if (deep_get($error_ref, "impact", "id") eq "failure") {
				$status_id = "failure";
				last;
			}
		}
	}

	$response_ref->{status} = $status_id;

	return;
}

=head2 add_localized_messages_to_api_response ($target_lc, $response_ref)

Functions that process API calls may add message ids in $request_ref->{api_response}
to indicate the result and warnings and errors.

This functions adds English and/or localized messages for those messages.

=head3 Parameters

=head4 $target_lc 

API messages (result, warning and errors messages and impacts) are generated:
- in English in the "name" field: those messages are intended for use by developers, monitoring systems etc.
- in the language of the user in the "lc_name" field: those messages may be displayed directly to users
(e.g. to explain that some field values are incorrect and were ignored)

=head4 $response_ref (input and output)

Reference to the response object.

=cut

sub add_localized_messages_to_api_response ($target_lc, $response_ref) {

	my @messages_to_localize = (["result", $response_ref->{result}]);

	foreach my $object_ref (@{$response_ref->{warnings}}, @{$response_ref->{errors}}) {
		push @messages_to_localize, ["message", $object_ref->{message}];
		push @messages_to_localize, ["impact", $object_ref->{impact}];
	}

	$log->debug("response messages to localize",
		{target_lc => $target_lc, messages_to_localize => \@messages_to_localize})
		if $log->is_debug();

	foreach my $message_to_localize_ref (@messages_to_localize) {
		my ($type, $message_ref) = @$message_to_localize_ref;

		next if not defined $message_ref;

		my $id = $message_ref->{id};

		# Construct the id for the message used in the .po files
		my $string_id = "api_" . $type . "_" . $id;

		$message_ref->{name} = lang_in_other_lc("en", $string_id);
		$message_ref->{lc_name} = lang_in_other_lc($target_lc, $string_id);
	}
	return;
}

=head2 send_api_response ($request_ref)

Send the API response with the right headers and status code.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head3 Return value

Reference to the customized product object.

=cut

sub send_api_response ($request_ref) {

	my $status_code = $request_ref->{status_code} || "200";

	my $json = JSON::PP->new->allow_nonref->canonical->utf8->encode($request_ref->{api_response});

	# add headers
	# We need to send the header Access-Control-Allow-Credentials=true so that websites
	# such has hunger.openfoodfacts.org that send a query to world.openfoodfacts.org/cgi/auth.pl
	# can read the resulting response.
	my $allow_credentials = 0;
	if ($request_ref->{query_string} =~ "/auth.pl") {
		$allow_credentials = 1;
	}
	write_cors_headers($allow_credentials);
	print header(-status => $status_code, -type => 'application/json', -charset => 'utf-8');
	# write json response
	print $json;

	my $r = Apache2::RequestUtil->request();

	$r->rflush;

	# Setting the status makes mod_perl append a default error to the body
	# $r->status($status);
	# Send 200 instead. (note: this does not affect the real returned status)
	$r->status(200);
	return;
}

=head2 process_api_request ($request_ref)

Process API v3 requests.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=cut

sub process_api_request ($request_ref) {

	$log->debug("process_api_request - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# Check if we already have errors (e.g. authentification error, invalid JSON body)
	if ((scalar @{$response_ref->{errors}}) > 0) {
		$log->warn("process_api_request - we already have errors, skipping processing", {request => $request_ref})
			if $log->is_warn();
	}
	else {

		# Route the API request to the right processing function, based on API action (from path) and method

		# Product read or write
		if ($request_ref->{api_action} eq "product") {

			if ($request_ref->{api_method} eq "OPTIONS") {
				# Just return CORS headers
			}
			elsif ($request_ref->{api_method} eq "PATCH") {
				write_product_api($request_ref);
			}
			elsif ($request_ref->{api_method} =~ /^(GET|HEAD)$/) {
				read_product_api($request_ref);
			}
			else {
				add_invalid_method_error($response_ref, $request_ref);
			}
		}
		# Taxonomy suggestions
		elsif ($request_ref->{api_action} eq "taxonomy_suggestions") {

			if ($request_ref->{api_method} =~ /^(GET|HEAD|OPTIONS)$/) {
				taxonomy_suggestions_api($request_ref);
			}
			else {
				add_invalid_method_error($response_ref, $request_ref);
			}
		}
		# Tag read
		elsif ($request_ref->{api_action} eq "tag") {

			if ($request_ref->{api_method} =~ /^(GET|HEAD|OPTIONS)$/) {
				read_tag_api($request_ref);
			}
			else {
				add_invalid_method_error($response_ref, $request_ref);
			}
		}
		# Unknown action
		else {
			$log->warn("process_api_request - unknown action", {request => $request_ref}) if $log->is_warn();
			add_error(
				$response_ref,
				{
					message => {id => "invalid_api_action"},
					field => {id => "api_action", value => $request_ref->{api_action}},
					impact => {id => "failure"},
				}
			);
		}
	}

	determine_response_result($response_ref);

	add_localized_messages_to_api_response($request_ref->{lc}, $response_ref);

	send_api_response($request_ref);

	$log->debug("process_api_request - stop", {request => $request_ref}) if $log->is_debug();
	return;
}

=head2 normalize_requested_code($requested_code, $response_ref)

Normalize the product barcode requested by a READ or WRITE API request.
Return a warning if the normalized code is different from the requested code.

=head3 Parameters

=head4 $request_code (input)

Reference to the request object.

=head4 $response_ref (output)

Reference to the response object.

=head3 Return value

Normalized code.

=cut

sub normalize_requested_code ($requested_code, $response_ref) {

	my $code = normalize_code($requested_code);
	$response_ref->{code} = $code;

	# Add a warning if the normalized code is different from the requested code
	if ($code ne $requested_code) {
		add_warning(
			$response_ref,
			{
				message => {id => "different_normalized_product_code"},
				field => {id => "code", value => $code},
				impact => {id => "none"},
			}
		);
	}

	return $code;
}

=head2 get_images_to_update($product_ref, $target_lc)

Return a list of images that are too old, or that are missing.
This is used to ask users to update images.

=head3 Parameters

=head4 $product_ref (input)

Reference to the product object

=head4 $target_lc (input)

Target language code

=head3 Return value

Reference to a hash of images that need to be updated.
The keys are the image ids (e.g. front_fr), and the value is the age in seconds of the image
(or 0 if we don't have an image yet)

=cut

sub get_images_to_update ($product_ref, $target_lc) {

	my $images_to_update_ref = {};

	foreach my $imagetype ("front", "ingredients", "nutrition", "packaging") {

		my $imagetype_lc = $imagetype . "_" . $target_lc;

		# Ask for images in a specific language if we already have an old image for that language
		if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$imagetype_lc})) {

			my $imgid = $product_ref->{images}{$imagetype . "_" . $target_lc}{imgid};
			my $age = time() - $product_ref->{images}{$imgid}{uploaded_t};

			if ($age > 365 * 86400) {    # 1 year
				$images_to_update_ref->{$imagetype_lc} = $age;
			}
		}
		# or if the language is the main language of the product
		# or if we have a text value for ingredients / packagings
		elsif (
			($product_ref->{lc} eq $target_lc)
			or (    (defined $product_ref->{$imagetype . "_text_" . $target_lc})
				and ($product_ref->{$imagetype . "_text_" . $target_lc} ne ""))
			)
		{
			$images_to_update_ref->{$imagetype_lc} = 0;
		}
	}
	return $images_to_update_ref;
}

=head2 customize_packagings ($request_ref, $product_ref)

Packaging components are stored in a compact form: only taxonomy ids for
shape, material and recycling.

This function returns a richer structure with local names for the taxonomy entries.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head4 $product_ref (input)

Reference to the product object (retrieved from disk or from a MongoDB query)

=head3 Return value

Reference to the customized product object.

=cut

sub customize_packagings ($request_ref, $product_ref) {

	my $customized_packagings_ref = $product_ref->{packagings};

	if (defined $product_ref->{packagings}) {

		my $tags_lc = request_param($request_ref, 'tags_lc');

		# We need to make a copy of $product_ref->{packagings}, it cannot be updated directly
		# as the internal format of "packagings" is used in other functions
		# (e.g. to generate knowledge panels)

		$customized_packagings_ref = [];

		foreach my $packaging_ref (@{$product_ref->{packagings}}) {

			my $customized_packaging_ref = dclone($packaging_ref);

			if ($request_ref->{api_version} >= 3) {
				# Shape, material and recycling are localized
				foreach my $property ("shape", "material", "recycling") {
					if (defined $packaging_ref->{$property}) {
						my $property_value_id = $packaging_ref->{$property};
						$customized_packaging_ref->{$property} = {"id" => $property_value_id};
						if (defined $tags_lc) {
							$customized_packaging_ref->{$property}{lc_name}
								= display_taxonomy_tag($tags_lc, $packaging_taxonomies{$property}, $property_value_id);
						}
					}
				}
			}
			push @$customized_packagings_ref, $customized_packaging_ref;
		}
	}

	return $customized_packagings_ref;
}

=head2 customize_response_for_product ( $request_ref, $product_ref, $fields )

Using the fields parameter, API product or search queries can request
a specific set of fields to be returned.

This function filters the field to return only the requested fields,
and computes requested fields that are not stored in the database but
created on demand.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head4 $product_ref (input)

Reference to the product object (retrieved from disk or from a MongoDB query)

=head4 $fields (input)

Comma separated list of fields, default to none.

Special values:
- none: no fields are returned
- all: all fields are returned, and special fields (e.g. attributes, knowledge panels) are not computed
- updated: fields that were updated by a WRITE request

=head3 Return value

Reference to the customized product object.

=cut

sub customize_response_for_product ($request_ref, $product_ref, $fields) {

	my $customized_product_ref = {};

	my $carbon_footprint_computed = 0;

	if ((not defined $fields) or ($fields eq "none")) {
		return {};
	}
	elsif ($fields eq "raw") {
		# Return the raw product data, as stored in the .sto files and database
		return $product_ref;
	}

	if ($fields =~ /\ball\b/) {
		# Return all fields of the product, with processing that depends on the API version used
		# e.g. in API v3, the "packagings" structure is more verbose than the stored version
		$fields = $` . join(",", sort keys %{$product_ref}) . $';
	}

	# Callers of the API V3 WRITE product can send fields = updated to get only updated fields
	if ($fields =~ /\bupdated\b/) {
		if (defined $request_ref->{updated_product_fields}) {
			$fields = $` . join(',', sort keys %{$request_ref->{updated_product_fields}}) . $';
			$log->debug("returning only updated fields", {fields => $fields}) if $log->is_debug();
		}
	}

	# Localize the Eco-Score fields that depend on the country of the request
	localize_ecoscore($cc, $product_ref);

	# lets compute each requested field
	foreach my $field (split(/,/, $fields)) {
		if ($field eq "product_display_name") {
			$customized_product_ref->{$field} = remove_tags_and_quote(product_name_brand_quantity($product_ref));
		}

		# Allow apps to request a HTML nutrition table by passing &fields=nutrition_table_html
		elsif ($field eq "nutrition_table_html") {
			$customized_product_ref->{$field} = display_nutrition_table($product_ref, undef);
		}

		# Eco-Score details in simple HTML
		elsif ($field eq "ecoscore_details_simple_html") {
			if ((1 or $show_ecoscore) and (defined $product_ref->{ecoscore_data})) {
				$customized_product_ref->{$field}
					= display_ecoscore_calculation_details_simple_html($cc, $product_ref->{ecoscore_data});
			}
		}

		# fields in %language_fields can have different values by language
		# by priority, return the first existing value in the language requested,
		# possibly multiple languages if sent ?lc=fr,nl for instance,
		# and otherwise fallback on the main language of the product
		elsif (defined $language_fields{$field}) {
			foreach my $preferred_lc (@lcs, $product_ref->{lc}) {
				if (    (defined $product_ref->{$field . "_" . $preferred_lc})
					and ($product_ref->{$field . "_" . $preferred_lc} ne ''))
				{
					$customized_product_ref->{$field} = $product_ref->{$field . "_" . $preferred_lc};
					last;
				}
			}
		}

		# [language_field]_languages : return a value with all existing values for a specific language field
		elsif ($field =~ /^(.*)_languages$/) {

			my $language_field = $1;
			$customized_product_ref->{$field} = {};
			if (defined $product_ref->{languages_codes}) {
				foreach my $language_code (sort keys %{$product_ref->{languages_codes}}) {
					if (defined $product_ref->{$language_field . "_" . $language_code}) {
						$customized_product_ref->{$field}{$language_code}
							= $product_ref->{$language_field . "_" . $language_code};
					}
				}
			}
		}

		# Taxonomy fields requested in a specific language
		elsif ($field =~ /^(.*)_tags_([a-z]{2})$/) {
			my $tagtype = $1;
			my $target_lc = $2;
			if (defined $product_ref->{$tagtype . "_tags"}) {
				$customized_product_ref->{$field} = [];
				foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
					push @{$customized_product_ref->{$field}}, display_taxonomy_tag($target_lc, $tagtype, $tagid);
				}
			}
		}

		# Apps can request the full nutriments hash
		# or specific nutrients:
		# - saturated-fat_prepared_100g : return field at top level
		# - nutrients|nutriments.sugars_serving : return field in nutrients / nutriments hash
		elsif ($field =~ /^((nutrients|nutriments)\.)?((.*)_(100g|serving))$/) {
			my $return_hash = $2;
			my $nutrient = $3;
			if ((defined $product_ref->{nutriments}) and (defined $product_ref->{nutriments}{$nutrient})) {
				if (defined $return_hash) {
					if (not defined $customized_product_ref->{$return_hash}) {
						$customized_product_ref->{$return_hash} = {};
					}
					$customized_product_ref->{$return_hash}{$nutrient} = $product_ref->{nutriments}{$nutrient};
				}
				else {
					$customized_product_ref->{$nutrient} = $product_ref->{nutriments}{$nutrient};
				}
			}
		}
		# Product attributes requested in a specific language (or data only)
		elsif ($field =~ /^attribute_groups_([a-z]{2}|data)$/) {
			my $target_lc = $1;
			compute_attributes($product_ref, $target_lc, $cc, $attributes_options_ref);
			$customized_product_ref->{$field} = $product_ref->{$field};
		}
		# Product attributes in the $lc language
		elsif ($field eq "attribute_groups") {
			compute_attributes($product_ref, $lc, $cc, $attributes_options_ref);
			$customized_product_ref->{$field} = $product_ref->{"attribute_groups_" . $lc};
		}
		# Knowledge panels in the $lc language
		elsif ($field eq "knowledge_panels") {
			initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
			create_knowledge_panels($product_ref, $lc, $cc, $knowledge_panels_options_ref);
			$customized_product_ref->{$field} = $product_ref->{"knowledge_panels_" . $lc};
		}

		# Images to update in a specific language
		elsif ($field =~ /^images_to_update_([a-z]{2})$/) {
			my $target_lc = $1;
			$customized_product_ref->{$field} = get_images_to_update($product_ref, $target_lc);
		}

		# Packagings data
		elsif ($field eq "packagings") {
			$customized_product_ref->{$field} = customize_packagings($request_ref, $product_ref);
		}

		# straight fields
		elsif ((not defined $customized_product_ref->{$field}) and (defined $product_ref->{$field})) {
			$customized_product_ref->{$field} = $product_ref->{$field};
		}

		# TODO: it would be great to return errors when the caller requests fields that are invalid (e.g. typos)
	}

	return $customized_product_ref;
}

1;
