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

ProductOpener::EnvironmentalImpact - process and analyze products

=head1 SYNOPSIS

C<ProductOpener::EnvironmentalImpact> processes products to compute
their environmental impact (see french environmental labeling Ecobalyse).

    use ProductOpener::EnvironmentalImpact qw/:all/;

	[..]

	estimate_environmental_impact($product_ref);

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::EnvironmentalImpact;

use ProductOpener::PerlStandards;
use Exporter qw< import >;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use Encode qw(decode_utf8 encode_utf8);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&estimate_environmental_impact_service

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any '$log', default_adapter => 'Stderr';

=head1 FUNCTIONS

=head2 estimate_environmental_impact_service ( $product_ref, $updated_product_fields_ref, $errors_ref )

Compute the environmental impact of a given product (see the french environmental environmental labeling Ecobalyse).

This function is a product service that can be run through ProductOpener::ApiProductServices

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=cut

sub estimate_environmental_impact_service ($product_ref, $updated_product_fields_ref, $errors_ref) {

	# $updated_product_fields_ref, $errors_ref sont des outputs : chaque service
	# dit quels champs sont modifiés
	# Ici on en ajoute un : "environmental_impact"

	# If undefined ingredients, do nothing
	return if not defined $product_ref->{ingredients};

	# indicate that the service is modifying the "ingredients" structure
	$updated_product_fields_ref->{environmental_impact} = 1;
	$product_ref->{environmental_impact} = 0;

	# Initialisation of the payload structure
	my $payload = {
		ingredients => [],
		transform => {
			"id" => "7541cf94-1d4d-4d1c-99e3-a9d5be0e7569",
			"mass" => 545
		},
		packaging => [],
		distribution => "ambient",
		preparation => ["refrigeration"]
	};

	# Estimating the environmental impact
	foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {
		# TODO: when we don't have an ecobalyse_code or ecobalyse_proxy_code,
		# we can ignore the ingredient, but we need to record the quantity of unrecognized ingredients
		next unless defined $ingredient_ref->{id} && defined $ingredient_ref->{percent_estimate};
		push @{$payload->{ingredients}},
			{
			id => $ingredient_ref->{ecobalyse_code} || $ingredient_ref->{ecobalyse_proxy_code},
			mass => $ingredient_ref->{percent_estimate}
			};
	}

	# Adding a transformation
	if (defined $product_ref->{transform}) {
		$payload->{transform} = {
			id => $product_ref->{transform}->{id},
			mass => $product_ref->{transform}->{mass}
			}
			if defined $product_ref->{transform}->{id} && defined $product_ref->{transform}->{mass};
	}

	# Adding a packaging
	if (defined $product_ref->{packaging}) {
		foreach my $packaging_ref (@{$product_ref->{packaging}}) {
			next unless defined $packaging_ref->{id} && defined $packaging_ref->{mass};
			push @{$payload->{packaging}},
				{
				id => $packaging_ref->{id},
				mass => $packaging_ref->{mass}
				};
		}
	}

	# API URL
	my $url_recipe = "https://staging-ecobalyse.incubateur.net/api/food";

	# Create a UserAgent object to make the API request
	my $ua = LWP::UserAgent->new();
	$ua->timeout(5);

	# Prepare the POST request with the payload
	my $request = POST $url_recipe, $payload;
	$request->header('content-type' => 'application/json');
	$request->content(decode_utf8(encode_json($payload)));

	# Debug information for the request
	$log->debug("send_event request", {endpoint => $url_recipe, payload => $payload}) if $log->is_debug();

	$product_ref->{environmental_impact} = {ecobalyse_request => {url => $url_recipe, data => $payload}};

	# Send the request and get the response
	my $response = $ua->request($request);

	# Parse the JSON response
	my $response_content = $response->decoded_content;
	my $response_data = $response_content;
	# if the response is JSON, decode it
	eval {$response_data = decode_json($response_content);};

	$product_ref->{environmental_impact}{ecobalyse_response} = $response_data;

	# Handle the response based on success or failure
	if ($response->is_success) {

		# Access the specific "ecs" value
		if (exists $response_data->{results}{total}{ecs}) {
			my $ecs_value = $response_data->{results}{total}{ecs};
			# If 'ecs' is defined, store it in the product reference
			if (defined $ecs_value) {
				$product_ref->{environmental_impact}{ecs} = $ecs_value;
			}
		}
	}
	else {
		# If the request failed, log the error
		$log->error("send_event request failed",
			{endpoint => $url_recipe, payload => $payload, response => $response_content})
			if $log->is_error();
		# Add an error message to the errors array
		$product_ref->{environmental_impact}{ecobalyse_response} = $response_data;

		push @{$errors_ref},
			{
			message => {id => "error_response_from_ecobalyse"},
			field => {
				id => "ecobalyse_response",
				value => $response_content,
			},
			impact => {id => "failure"},
			service => {id => "estimate_environmental_impact_service"},
			};
	}

	# If necessary, return error as well
	# (number of unattributed ingredients,
	# percentage of unattributed mass, etc...)

	# add_error
	# add_warning

	# $product_ref->{environmental_impact} = 5;

	return;
}

1;

