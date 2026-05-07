# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

ProductOpener::APIProductServices - Microservices to enrich a product object

=head1 DESCRIPTION

This module implements a microservice API for operations done on an product object.

Applications can send product data (for instance a nested list of ingredients),
ask for one or more services to be executed on the input product data
(for instance computing the min, max and estimated percentages of each ingredient),
and get back resulting product data (possibly filtered to get only specific fields back).

=head2 INTERFACE

=head3 Request

The Routing.pm and API.pm module offer an HTTP interface of this form:
POST /api/v3/product_services

The POST body is a JSON object with those fields:

=head4 services

An array list of services to perform.

Currently implemented services:

- echo : does nothing, mostly for testing
- parse_ingredients_text : parse the ingredients text list and return an ingredients object
- extend_ingredients : extend the ingredients object with additional information
- estimate_ingredients_percent : compute percent_min, percent_max, percent_estimate for each ingredient in the ingredients object
- analyze_ingredients : analyze the ingredients object and return a summary object
- estimate_environmental_cost_ingredients : estimate the environmental cost of a given product (see Ecobalyse)

=head4 product

A product object

=head4 fields

An array list of fields to return. If empty, only fields that can be created or updated by the service are returned.
e.g. a service to parse the ingredients text list will return the "ingredients" object.

=head3 Response

The response is in the JSON API v3 response format, with a resulting product object.

=cut

package ProductOpener::APIProductServices;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&add_product_data_from_external_service
		&product_services_api
		&external_sources_api
	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::HTTP qw/request_param set_http_response_header/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::API qw/add_error customize_response_for_product init_api_response/;
use ProductOpener::EnvironmentalImpact;
use ProductOpener::HTTP qw/create_user_agent/;

use JSON qw(decode_json encode_json);
use Storable qw/dclone/;
use Encode;
use Types::Serialiser;

=head2 add_product_data_from_external_service ($request_ref, $product_ref, $url, $services_ref)

Make a request to execute services on product on an external server using the product services API.

The resulting fields are added to the product object.

e.g. this function is used to run the percent estimation service on the recipe-estimator server.

=cut

sub add_product_data_from_external_service ($request_ref, $product_ref, $url, $services_ref, $fields_ref = undef) {

	$log->debug("add_product_data_from_external_service - start",
		{request => $request_ref, url => $url, services_ref => $services_ref})
		if $log->is_debug();

	defined $request_ref->{api_response} or init_api_response($request_ref);

	my $response_ref = $request_ref->{api_response};

	my $body_ref = {product => $product_ref,};

	if (defined $services_ref) {
		$body_ref->{services} = $services_ref;
	}

	# If the caller requested specific fields, we will return only those fields
	if (defined $fields_ref) {
		$body_ref->{fields} = $fields_ref;
	}

	# hack: recipe-estimator currently expects the product at the root of the body
	if ($url =~ /estimate_recipe/) {
		# We will send the product as the root object
		$body_ref = $product_ref;
	}

	my $ua = create_user_agent(timeout => 10);

	my $response = $ua->post(
		$url,
		Content => encode_json($body_ref),
		"Content-Type" => "application/json; charset=utf-8",
	);

	if (not $response->is_success) {
		$log->error("add_product_data_from_external_service - error response", {response => $response})
			if $log->is_error();
		add_error(
			$response_ref,
			{
				message => {id => "external_service_error"},
				field => {
					id => "services",
					value => join(", ", @{$services_ref || []}),
					url => $url,
					error => $response->status_line
				},
				impact => {id => "failure"},
			}
		);
		return;
	}
	else {

		# Decode the response body
		my $response_content = $response->decoded_content;

		my $decoded_json;
		my $json_decode_error;
		eval {
			$decoded_json = decode_json($response_content);
			1;
		} or do {
			$json_decode_error = $@;
			$log->error(
				"add_product_data_from_external_service - error decoding JSON response",
				{response_content => $response_content, error => $json_decode_error}
			) if $log->is_error();
			add_error(
				$response_ref,
				{
					message => {id => "external_service_invalid_json_response"},
					field => {id => "response", value => $response_content, error => $json_decode_error},
					impact => {id => "failure"},
				}
			);
			return;
		};

		# If the response is not an error, we expect it to be a valid product object

		# hack: recipe-estimator currently returns the product at the root of the body
		if ($url =~ /estimate_recipe/) {
			if (not defined $decoded_json->{product}) {
				$decoded_json = {product => $decoded_json};
			}
		}

		my $response_product_ref = $decoded_json->{product};
		if (not defined $response_product_ref) {
			$log->error("add_product_data_from_external_service - response does not contain a product object",
				{response => $decoded_json})
				if $log->is_error();
			add_error(
				$response_ref,
				{
					message => {id => "external_service_invalid_response"},
					field => {id => "response", value => $response_content, error => "missing product object"},
					impact => {id => "failure"},
				}
			);
			return;
		}

		# Copy the fields present in the response product object to the request product object
		foreach my $field (keys %$response_product_ref) {

			$product_ref->{$field} = $response_product_ref->{$field};
		}

	}

	$log->debug("add_product_data_from_external_service - stop", {response => $response_ref}) if $log->is_debug();

	return;
}

=head2 echo_service ($product_ref, $updated_product_fields_ref, $errors_ref)

Echo service that returns the input product unchanged.

=cut

sub echo_service ($product_ref, $updated_product_fields_ref, $errors_ref) {

	return;
}

=head2 Service function handlers

They will be called with the input product object, a reference to the updated fields hash, and a reference to the errors array.

=cut

my %service_functions = (
	echo => \&echo_service,
	parse_ingredients_text => \&ProductOpener::Ingredients::parse_ingredients_text_service,
	extend_ingredients => \&ProductOpener::Ingredients::extend_ingredients_service,
	estimate_ingredients_percent => \&ProductOpener::Ingredients::estimate_ingredients_percent_service,
	analyze_ingredients => \&ProductOpener::Ingredients::analyze_ingredients_service,
	estimate_environmental_impact => \&ProductOpener::EnvironmentalImpact::estimate_environmental_impact_service,
	determine_food_contact_of_packaging_components =>
		\&ProductOpener::PackagingFoodContact::determine_food_contact_of_packaging_components_service,
);

sub check_product_services_api_input ($request_ref) {

	my $response_ref = $request_ref->{api_response};
	my $request_body_ref = $request_ref->{body_json};

	my $error = 0;

	# Check that we have an input body
	if (not defined $request_body_ref) {
		$log->error("product_services_api - missing or invalid input body", {}) if $log->is_error();
		$error = 1;
	}
	else {
		# Check that we have the input body fields we expect

		if (not defined $request_body_ref->{product}) {
			$log->error("product_services_api - missing input product", {request_body => $request_body_ref})
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

		if (not defined $request_body_ref->{services}) {
			$log->error("product_services_api - missing services", {request_body => $request_body_ref})
				if $log->is_error();
			add_error(
				$response_ref,
				{
					message => {id => "missing_field"},
					field => {id => "services"},
					impact => {id => "failure"},
				}
			);
			$error = 1;
		}
		elsif (ref($request_body_ref->{services}) ne 'ARRAY') {
			add_error(
				$response_ref,
				{
					message => {id => "invalid_type_must_be_array"},
					field => {id => "services"},
					impact => {id => "failure"},
				}
			);
			$error = 1;
		}
		else {
			# Echo back the services that were requested
			$response_ref->{services} = $request_body_ref->{services};
		}
	}
	return $error;
}

=head2 product_services_api($request_ref)

Process API v3 product services requests.

=cut

sub product_services_api ($request_ref) {

	$log->debug("product_services_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};
	my $request_body_ref = $request_ref->{body_json};

	$log->debug("product_services_api - body", {request_body => $request_body_ref}) if $log->is_debug();

	my $error = check_product_services_api_input($request_ref);

	# If we did not get a fatal error, we can execute the services on the input product object
	if (not $error) {

		my $product_ref = $request_body_ref->{product};
		# Normalization of some fields like lc / lang
		normalize_product_data($product_ref);

		# TODO: check that the product object is valid
		# any input product data can be sent, and most of the services expect a specific structure
		# they may crash and return a 500 error if the input data is not as expected (e.g. hash instead of array)

		# We will track of fields updated by the services so that we can return only those fields
		# if the fields parameter value is "updated"
		$request_ref->{updated_product_fields} = {};

		foreach my $service (@{$request_body_ref->{services}}) {
			my $service_function = $service_functions{$service};
			if (defined $service_function) {
				&$service_function($product_ref, $request_ref->{updated_product_fields}, $response_ref->{errors});
			}
			else {
				add_error(
					$response_ref,
					{
						message => {id => "unknown_service"},
						field => {id => "services", value => $service},
						impact => {id => "failure"},
					}
				);
			}
		}

		# Select / compute only the fields requested by the caller, default to updated fields
		my $fields_ref = request_param($request_ref, 'fields');
		if (not defined $fields_ref) {
			$fields_ref = ["updated"];
		}
		$log->debug("product_services_api - before customize", {fields_ref => $fields_ref, product_ref => $product_ref})
			if $log->is_debug();
		$response_ref->{product} = customize_response_for_product($request_ref, $product_ref, undef, $fields_ref);

		# Echo back the services that were executed
		$response_ref->{fields} = $fields_ref;
	}

	$log->debug("product_services_api - stop", {request => $request_ref}) if $log->is_debug();

	return;
}

sub _as_bool($value) {
	if ($value) {
		return $Types::Serialiser::true;
	}
	else {
		return $Types::Serialiser::false;
	}
}

# cache for external_sources method
my %external_sources_cache = ();

=head2 external_sources

Get external sources but translated in target language

=cut

sub external_sources_api ($request_ref) {

	my $target_lc = $request_ref->{lc};
	my $response_ref = $request_ref->{api_response};

	if (not defined $external_sources_cache{$target_lc}) {

		# read external-sources.json and decode
		open(my $in, "<", "$BASE_DIRS{PUBLIC_RESOURCES}/files/external-sources.json")
			or die "cannot read external-sources.json : $! \n";
		my $json_content = join("", (<$in>));
		close $in;
		my $ext_sources = decode_json($json_content);
		my @translated_sources = ();
		# iterate content
		foreach my $ext_source (@$ext_sources) {
			my $source_id = $ext_source->{id};
			my $translated_source = dclone($ext_source);
			# try to translate some fields
			foreach my $field (qw/name description section_title/) {
				my $translation_id = "external_sources_" . $source_id . "_" . $field;
				if ($field eq "section_title") {
					my $section_id = $ext_source->{section};
					$translation_id = "section_" . $section_id . "_title";
					# put a default in this case
					$translated_source->{$field} = $section_id;
				}
				my $translation = lang($translation_id);
				if ((defined $translation) and ($translation ne $translation_id) and ($translation ne "")) {
					$translated_source->{$field} = $translation;
				}
				# add default permission field corresponding to anonymous users
				$translated_source->{"user_in_scope"} = _as_bool($translated_source->{"scope"} eq "public");
			}
			push @translated_sources, $translated_source;
		}
		$external_sources_cache{$target_lc} = \@translated_sources;
	}
	# add information for current user
	if ($request_ref->{user_id}) {
		# duplicate cache
		my @external_sources = @{dclone($external_sources_cache{$target_lc})};
		foreach my $ext_source (@external_sources) {
			if ($ext_source->{scope} eq "users") {
				$ext_source->{user_in_scope} = _as_bool(1);
			}
			elsif ($ext_source->{scope} eq "moderators") {
				$ext_source->{user_in_scope} = _as_bool($request_ref->{moderator} || $request_ref->{admin});
			}
		}
		$response_ref->{external_sources} = \@external_sources;
	}
	else {
		$response_ref->{external_sources} = $external_sources_cache{$target_lc};
	}
	$response_ref->{result} = {id => "ok", name => "External services found"};
	# 1 hour cache
	set_http_response_header($request_ref, "Cache-Control", "public, max-age=3600");
	return;
}

1;
