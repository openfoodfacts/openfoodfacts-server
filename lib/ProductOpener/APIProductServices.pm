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
- estimate_ingredients_percent : compute percent_min, percent_max, percent_estimate for each ingredient in the ingredients object

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
		&product_services_api
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

use Encode;

=head2 echo_service ($product_ref)

Echo service that returns the input product unchanged.

=cut

sub echo_service ($product_ref, $updated_product_fields_ref) {

	return;
}

my %service_functions = (
	echo => \&echo_service,
	parse_ingredients_text => \&ProductOpener::Ingredients::parse_ingredients_text_service,
	estimate_ingredients_percent => \&ProductOpener::Ingredients::estimate_ingredients_percent_service,
	analyze_ingredients => \&ProductOpener::Ingredients::analyze_ingredients_service,
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

=head2 product_services_api()

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

		# We will track of fields updated by the services so that we can return only those fields
		# if the fields parameter value is "updated"
		$request_ref->{updated_product_fields} = {};

		foreach my $service (@{$request_body_ref->{services}}) {
			my $service_function = $service_functions{$service};
			if (defined $service_function) {
				&$service_function($product_ref, $request_ref->{updated_product_fields});
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

1;
