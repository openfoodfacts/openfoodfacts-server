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
		&check_user_permission
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::HTTP qw/write_cors_headers request_param/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/$lc lang_in_other_lc/;
use ProductOpener::Products qw/normalize_code_with_gs1_ai product_name_brand_quantity/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Tags qw/%language_fields display_taxonomy_tag/;
use ProductOpener::Text qw/remove_tags_and_quote/;
use ProductOpener::Attributes qw/compute_attributes/;
use ProductOpener::KnowledgePanels qw/create_knowledge_panels initialize_knowledge_panels_options/;
use ProductOpener::EnvironmentalScore qw/localize_environmental_score/;
use ProductOpener::Packaging qw/%packaging_taxonomies/;
use ProductOpener::Permissions qw/has_permission/;
use ProductOpener::GeoIP qw/get_country_for_ip_api/;
use ProductOpener::ProductSchemaChanges qw/$current_schema_version convert_product_schema/;
use ProductOpener::ProductsFeatures qw(feature_enabled);

use ProductOpener::APIProductRead qw/read_product_api/;
use ProductOpener::APIProductWrite qw/write_product_api/;
use ProductOpener::APIProductRevert qw/revert_product_api/;
use ProductOpener::APIProductServices qw/product_services_api/;
use ProductOpener::APITagRead qw/read_tag_api/;
use ProductOpener::APITaxonomySuggestions qw/taxonomy_suggestions_api/;

use CGI qw(header);
use Apache2::RequestIO();
use Apache2::RequestRec();
use JSON::MaybeXS;
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
	defined $response_ref->{warnings} or $response_ref->{warnings} = [];
	push @{$response_ref->{warnings}}, $warning_ref;
	return;
}

=head2 add_error ($response_ref, $error_ref, $status_code = 400)

Add an error to the response object.

=head3 Parameters

=head4 $response_ref (input)

Reference to the response object.

=head4 $error_ref (input)

Reference to the error object.

=head4 $status_code (input)

HTTP status code to return in the response, defaults to 400 bad request.

=cut

sub add_error ($response_ref, $error_ref, $status_code = 400) {
	defined $response_ref->{errors} or $response_ref->{errors} = [];
	push @{$response_ref->{errors}}, $error_ref;
	$response_ref->{status_code} = $status_code;
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
		},
		405
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
					field => {id => "body", value => $request_ref->{body}, error => $@},
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

	my $status_code = $request_ref->{api_response}{status_code} || $request_ref->{status_code} || "200";
	delete $request_ref->{api_response}{status_code};

	my $json = JSON::MaybeXS->new->allow_nonref->canonical->utf8->encode($request_ref->{api_response});

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

# Dipatch table for API actions
my $dispatch_table = {
	# Product read or write
	product => {
		GET => \&read_product_api,
		HEAD => \&read_product_api,
		OPTIONS => sub {return;},    # Just return CORS headers
		PATCH => \&write_product_api,
	},
	# Product revert
	product_revert => {
		# Check that the method is POST (GET may be dangerous: it would allow to revert a product by just clicking or loading a link)
		POST => \&revert_product_api,
	},
	# Product services
	product_services => {
		POST => \&product_services_api,
		OPTIONS => sub {return;},    # Just return CORS headers
	},
	# Taxonomy suggestions
	taxonomy_suggestions => {
		GET => \&taxonomy_suggestions_api,
		HEAD => \&taxonomy_suggestions_api,
		OPTIONS => sub {return;},    # Just return CORS headers
	},
	# Tag read
	tag => {
		GET => \&read_tag_api,
		HEAD => \&read_tag_api,
		OPTIONS => sub {return;},    # Just return CORS headers
	},
	geoip => {
		GET => \&get_country_for_ip_api,
	}

};

sub process_api_request ($request_ref) {

	$log->debug("process_api_request - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# Check if we already have errors (e.g. authentification error, invalid JSON body)
	if ((defined $response_ref->{errors}) and ((scalar @{$response_ref->{errors}}) > 0)) {
		$log->warn("process_api_request - we already have errors, skipping processing", {request => $request_ref})
			if $log->is_warn();
	}
	else {
		# Route the API request to the right processing function, based on API action (from path) and method
		if (exists $dispatch_table->{$request_ref->{api_action}}) {
			my $action_dispatch_ref = $dispatch_table->{$request_ref->{api_action}};
			if (exists $action_dispatch_ref->{$request_ref->{api_method}}) {
				$action_dispatch_ref->{$request_ref->{api_method}}->($request_ref);
			}
			else {
				add_invalid_method_error($response_ref, $request_ref);
			}
		}
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

Normalized code and, if available, GS1 AI data string.

=cut

sub normalize_requested_code ($requested_code, $response_ref) {

	my ($code, $ai_data_str) = &normalize_code_with_gs1_ai($requested_code);
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

	return ($code, $ai_data_str);
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

			if ((defined $request_ref->{api_version}) and ($request_ref->{api_version} >= 3)) {
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

=head2 api_compatibility_for_field ($field, $api_version)

To support older API versions that can request fields that have been renamed or changed,
we rename older requested fields to the new field names to construct the response.

Resulting fields will then be renamed back to older names by the api_compatibility_for_product_response function.

=cut

sub api_compatibility_for_field ($field, $api_version) {

	# Provide a default value for $api_version if it is not defined
	$api_version //= 0;

	# API 3.1 - 2024/12/18 - ecoscore* fields have been renamed to environmental_score*
	if ($api_version < 3.1) {
		if ($field =~ /^ecoscore/) {
			$field = "environmental_score" . $';
		}
	}

	return $field;
}

=head2 api_compatibility_for_product_input ($product_ref)

The product objects saved in the database or in the .sto files may have different schema over time.
This function updates the product object to the latest schema version, for some fields, when possible,
so that we can read older revisions of products, or when all products are not migrated yet.

=cut

sub api_compatibility_for_product_input ($product_ref) {

	$log->debug("api_compatibility_for_product_input - start") if $log->is_debug();

	convert_product_schema($product_ref, $current_schema_version);

	return $product_ref;
}

=head2 api_compatibility_for_product_response ($product_ref, $api_version)

The response schema can change between API versions. This function transforms the product object to match the requested API version.

=cut

my %api_version_to_schema_version = (
	"0" => 996,
	"1" => 997,
	"2" => 998,
	"3" => 999,
	"3.0" => 999,
	"3.1" => 1000,
	"3.2" => 1001,
);

sub api_compatibility_for_product_response ($product_ref, $api_version) {

	$log->debug("api_compatibility_for_product_response - start", {api_version => $api_version}) if $log->is_debug();

	# no requested version, return the latest schema version, no conversion needed
	if (not defined $api_version) {
		return $product_ref;
	}

	my $target_schema_version = $api_version_to_schema_version{$api_version} || $current_schema_version;
	convert_product_schema($product_ref, $target_schema_version);

	return $product_ref;
}

=head2 customize_response_for_product ( $request_ref, $product_ref, $fields_comma_separated_list, $fields_ref )

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

=head4 $fields_comma_separated_list (input)

Comma separated list of fields (usually from GET query parameters), default to none.

Special values:
- none: no fields are returned
- all: all fields are returned, and special fields (e.g. attributes, knowledge panels) are not computed
- updated: fields that were updated by a WRITE request

=head4 $fields_ref (input)

Reference to a list of fields (alternative way to provide fields, e.g. from a JSON body).

=head3 Return value

Reference to the customized product object.

=cut

sub customize_response_for_product ($request_ref, $product_ref, $fields_comma_separated_list, $fields_ref = undef) {

	# Fields can be in a comma separated list (if provided as a query parameter)
	# or in a array reference (if provided in a JSON body)

	my @fields = ();
	if (defined $fields_comma_separated_list) {
		push @fields, split(/,/, $fields_comma_separated_list);
	}
	if (defined $fields_ref) {
		push @fields, @$fields_ref;
	}

	my $customized_product_ref = {};

	my $carbon_footprint_computed = 0;

	# Special case if fields is empty, or contains only "none" or "raw": we do not need to localize the Environmental-Score

	if ((scalar @fields) == 0) {
		return {};
	}
	if ((scalar @fields) == 1) {
		if ($fields[0] eq "none") {
			return {};
		}
		if ($fields[0] eq "raw") {
			# Return the raw product data, as stored in the .sto files and database
			return $product_ref;
		}
	}

	# Update the product object to the latest schema, for some fields, when possible
	api_compatibility_for_product_input($product_ref);

	# Localize the Environmental-Score fields that depend on the country of the request
	if (feature_enabled("environmental_score", $product_ref)) {
		localize_environmental_score($request_ref->{cc}, $product_ref);
	}

	# lets compute each requested field
	foreach my $field (@fields) {

		# Compatibility with older API versions
		$field = api_compatibility_for_field($field, $request_ref->{api_version});

		if ($field eq 'all') {
			# Return all fields of the product, with processing that depends on the API version used
			# e.g. in API v3, the "packagings" structure is more verbose than the stored version
			push @fields, sort keys %{$product_ref};
			next;
		}

		# Callers of the API V3 WRITE product can send fields = updated to get only updated fields
		if ($field eq "updated") {
			if (defined $request_ref->{updated_product_fields}) {
				push @fields, sort keys %{$request_ref->{updated_product_fields}};
				$log->debug("returning only updated fields", {fields => \@fields}) if $log->is_debug();
			}
			next;
		}

		if ($field eq "product_display_name") {
			# For web search queries, we may already have a product_display_name field computed and stored in the query cache
			# and the product name / brands / quantity fields have been removed in that case, so we use it as-is.
			$customized_product_ref->{$field} = $product_ref->{product_display_name}
				|| remove_tags_and_quote(product_name_brand_quantity($product_ref));
			next;
		}

		# Allow apps to request a HTML nutrition table by passing &fields=nutrition_table_html
		if ($field eq "nutrition_table_html") {
			$customized_product_ref->{$field} = display_nutrition_table($product_ref, undef, $request_ref);
			next;
		}

		# Environmental-Score details in simple HTML
		if ($field eq "environmental_score_details_simple_html") {
			if ((1 or $show_environmental_score) and (defined $product_ref->{environmental_score_data})) {
				$customized_product_ref->{$field}
					= display_environmental_score_calculation_details_simple_html($request_ref->{cc},
					$product_ref->{environmental_score_data});
			}
			next;
		}

		# fields in %language_fields can have different values by language
		# by priority, return the first existing value in the language requested,
		# possibly multiple languages if sent ?lc=fr,nl for instance,
		# and otherwise fallback on the main language of the product
		if (defined $language_fields{$field}) {
			foreach my $preferred_lc (@lcs, $product_ref->{lc}) {
				if (    (defined $product_ref->{$field . "_" . $preferred_lc})
					and ($product_ref->{$field . "_" . $preferred_lc} ne ''))
				{
					$customized_product_ref->{$field} = $product_ref->{$field . "_" . $preferred_lc};
					last;
				}
			}
			# Also copy the field for the main language if it exists
			if (defined $product_ref->{$field}) {
				$customized_product_ref->{$field} = $product_ref->{$field};
			}
			next;
		}

		# [language_field]_languages : return a value with all existing values for a specific language field
		if ($field =~ /^(.*)_languages$/) {

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
			next;
		}

		# Taxonomy fields requested in a specific language
		if ($field =~ /^(.*)_tags_([a-z]{2})$/) {
			my $tagtype = $1;
			my $target_lc = $2;
			if (defined $product_ref->{$tagtype . "_tags"}) {
				$customized_product_ref->{$field} = [];
				foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
					push @{$customized_product_ref->{$field}}, display_taxonomy_tag($target_lc, $tagtype, $tagid);
				}
			}
			next;
		}

		# Apps can request the full nutriments hash
		# or specific nutrients:
		# - saturated-fat_prepared_100g : return field at top level
		# - nutrients|nutriments.sugars_serving : return field in nutrients / nutriments hash
		if ($field =~ /^((nutrients|nutriments)\.)?((.*)_(100g|serving))$/) {
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
			next;
		}

		# Product attributes requested in a specific language (or data only)
		if ($field =~ /^attribute_groups_([a-z]{2}|data)$/) {
			my $target_lc = $1;
			compute_attributes($product_ref, $target_lc, $request_ref->{cc}, $attributes_options_ref);
			$customized_product_ref->{$field} = $product_ref->{$field};
			next;
		}

		# Product attributes in the $lc language
		if ($field eq "attribute_groups") {
			compute_attributes($product_ref, $lc, $request_ref->{cc}, $attributes_options_ref);
			$customized_product_ref->{$field} = $product_ref->{"attribute_groups_" . $lc};
			next;
		}

		# Knowledge panels in the $lc language
		if ($field eq "knowledge_panels") {
			initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
			create_knowledge_panels($product_ref, $lc, $request_ref->{cc}, $knowledge_panels_options_ref, $request_ref);
			$customized_product_ref->{$field} = $product_ref->{"knowledge_panels_" . $lc};
			next;
		}

		# Images to update in a specific language
		if ($field =~ /^images_to_update_([a-z]{2})$/) {
			my $target_lc = $1;
			$customized_product_ref->{$field} = get_images_to_update($product_ref, $target_lc);
			next;
		}

		# Packagings data
		if ($field eq "packagings") {
			$customized_product_ref->{$field} = customize_packagings($request_ref, $product_ref);
			next;
		}

		# straight fields
		if ((not defined $customized_product_ref->{$field}) and (defined $product_ref->{$field})) {
			$customized_product_ref->{$field} = $product_ref->{$field};
			next;
		}

		# TODO: it would be great to return errors when the caller requests fields that are invalid (e.g. typos)
	}

	# Before returning the product, we need to make sure that the fields are compatible with the requested API version
	api_compatibility_for_product_response($customized_product_ref, $request_ref->{api_version});

	return $customized_product_ref;
}

=head2 check_user_permission ($request_ref, $response_ref, $permission)

Check the user has a specific permission, before processing an API request.
If the user does not have the permission, an error is added to the response.

=head3 Parameters

=head4 $request_ref (input)

Reference to the request object.

=head4 $response_ref (output)

Reference to the response object.

=head4 $permission (input)

Permission to check.

=head3 Return value $has_permission

1 if the user has the permission, 0 otherwise.

=cut

sub check_user_permission ($request_ref, $response_ref, $permission) {

	my $has_permission = 1;

	# Check if the user has permission
	if (not has_permission($request_ref, $permission)) {
		$has_permission = 0;
		$log->error("check_user_permission - user does not have permission", {permission => $permission})
			if $log->is_error();
		add_error(
			$response_ref,
			{
				message => {id => "no_permission"},
				field => {id => "permission", value => $permission},
				impact => {id => "failure"},
			},
			403
		);
	}

	return $has_permission;
}

1;
