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

use HTTP::Request::Common;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&estimate_environmental_impact_service

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

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
	# Ici on en ajoute un : "environemental_impact"

	# If undefined ingredients, do nothing
	return if not defined $product_ref->{ingredients};

	# indicate that the service is modifying the "ingredients" structure
	$updated_product_fields_ref->{environmental_impact} = 1;
	$product_ref->{environmental_impact} = 0;

	# Initialisation of the payload structure
	my $payload = {
		ingredients => [],
		transform => {},
		packaging => [],
		distribution => "ambient",
		preparation => ["refrigeration"]
	};

	# Estimating the environmental impact
	while (@{$product_ref->{ingredients}}) {
		# Retrieving the first ingredient and deleting it
		my $ingredient_ref = shift @{$product_ref->{ingredients}};

		# Adding each ingredient to the payload structure
		push @{$payload->{ingredients}},
			{
			id => $ingredient_ref->{id},
			mass => $ingredient_ref->{mass}
			};
	}

	# Adding a transformation
	if (defined $product_ref->{transform}) {
		$payload->{transform} = {
			id => $product_ref->{transform}->{id},
			mass => $product_ref->{transform}->{mass}
		};
	}

	# Adding a packaging
	if (defined $product_ref->{packaging}) {
		foreach my $packaging_ref (@{$product_ref->{packaging}}) {
			push @{$payload->{packaging}},
				{
				id => $packaging_ref->{id},
				mass => $packaging_ref->{mass}
				};
		}
	}

	# API URL
	$url_recipe = "https://staging-ecobalyse.incubateur.net/api/food";

	# Create a UserAgent object to make the API request
	my $ua = LWP::UserAgent->new();
	$ua->timeout(2);    # Set the request timeout

	# Prepare the POST request with the payload
	my $request = POST $url_recipe, $payload;
	$request->header('content-type' => 'application/json');
	$request->content(decode_utf8(encode_json($payload)));

	# Debug information for the request
	$log->debug("send_event request", {endpoint => $url_recipe, payload => $payload}) if $log->is_debug();

	# Send the request and get the response
	my $response = $ua->request($request);

	# Handle the response based on success or failure
	if ($response->is_success) {
	    $log->debug(
	        "send_event response ok",
	        {
	            endpoint => $url_recipe,
	            payload => $payload,
	            is_success => $response->is_success,
	            code => $response->code,
	            status_line => $response->status_line
	        }
	    ) if $log->is_debug(); {

		    # Parse the JSON response
		    my $response_data;
		    eval {$response_data = decode_json($response->decoded_content);};
		    if ($@) {
		        $log->warn("Invalid JSON response: $@") if $log->is_warn();
		        return;
		    }

		    # Access the specific "ecs" value
		    my $ecs_value;  # Declare the variable outside the condition
		    if (exists $response_data->{results}{total}{ecs}) {
		        $ecs_value = $response_data->{results}{total}{ecs};
		    }
		    # Check if ecs exists and store it in the product field
		    if (defined $ecs_value) {
		        $product_ref->{environmental_impact} = $ecs_value;
		        $log->debug("ecs value stored", {ecs => $product_ref->{ecs}}) if $log->is_debug();
		    }
		    else {
		        $log->warn("'ecs' key not found") if $log->is_warn();
		    }
		}
	}
	else {
		$log->warn(
			"send_event response not ok",
			{
				endpoint => $url_recipe,
				payload => $payload,
				is_success => $response->is_success,
				code => $response->code,
				status_line => $response->status_line,
				response => $response
			}
		) if $log->is_warn();
	}

	# If necessary, return error as well
	# (number of unattributed ingredients,
	# percentage of unattributed mass, etc...)

	# add_error
	# add_warning

	return;
}
