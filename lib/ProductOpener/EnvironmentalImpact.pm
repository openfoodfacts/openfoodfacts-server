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

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&estimate_environmental_impact_service
		&get_ecobalyse_packaging_entry
		&get_ecobalyse_transformation_entries
		&filter_ecobalyse_response_for_open_data
		&get_ecobalyse_ingredients_quantities
		&set_ecobalyse_coverage_misc_tags
		&get_ecobalyse_reference_quantity
		&format_ecs_value
		&ecobalyse_api_call_enabled
		&call_ecobalyse
		&get_ecobalyse_call_stats
		&format_ecobalyse_call_stats

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Log::Any '$log', default_adapter => 'Stderr';

use HTTP::Request::Common;
use JSON;
use Encode qw(decode_utf8 encode_utf8);

use ProductOpener::Config qw/:all/;
use ProductOpener::HTTP qw/create_user_agent/;
use ProductOpener::Tags qw/is_a get_taxonomy_tag_level get_property/;
use ProductOpener::ProductsTags qw/get_inherited_property_from_categories_tags add_tag remove_tag/;
use File::Basename qw/dirname/;
use Scalar::Util qw/looks_like_number/;
use Time::HiRes qw/clock_gettime CLOCK_MONOTONIC/;
use List::Util qw/sum/;
use Data::DeepAccess qw(deep_exists deep_get);

my $ecobalyse_version
	= "food";    # "food" or "food2" (the Ecobalyse food2 API is newer and more complete, but not yet fully documented)

# Mapping of OFF storage conditions (inherited from categories) to Ecobalyse food API distribution values
# (Ecobalyse accepts only "ambient", "fresh" and "frozen")
my %ecobalyse_distribution_for_storage_conditions = (
	"en:ambient" => "ambient",
	"en:refrigerated" => "fresh",
	"en:frozen" => "frozen",
);

# Products that are refrigerated or frozen at the distributor are also kept in the fridge or freezer by the consumer:
# Ecobalyse food API preparation (consumption step) values for each distribution value
my %ecobalyse_preparation_for_distribution = (
	"fresh" => "refrigeration",
	"frozen" => "freezing",
);

=head1 FUNCTIONS

=head2 estimate_environmental_impact_service ( $product_ref, $updated_product_fields_ref, $errors_ref, $skip_ecobalyse_call = 0 )

Compute the environmental impact of a given product (see the french environmental environmental labeling Ecobalyse).

This function is a product service that can be run through ProductOpener::ApiProductServices

=head3 Arguments

=head4 $product_ref

product object reference

=head4 $updated_product_fields_ref

reference to a hash of product fields that have been created or updated

=head4 $errors_ref

reference to an array of error messages

=head4 $skip_ecobalyse_call

Boolean flag indicating whether to skip the Ecobalyse API call, in which case we only prepare the request payload and store it in the product.

=cut

=head2 set_ecobalyse_coverage_misc_tags ($product_ref)

Set misc_tags for Ecobalyse ingredients coverage ranges.

=cut

sub set_ecobalyse_coverage_misc_tags ($product_ref) {
	return unless defined $product_ref->{environmental_impact}{ecobalyse_input}{ingredients_coverage_percent};

	my $pct = $product_ref->{environmental_impact}{ecobalyse_input}{ingredients_coverage_percent};

	# Remove any existing ecobalyse coverage tags
	if (defined $product_ref->{misc_tags}) {
		$product_ref->{misc_tags}
			= [grep {$_ !~ /^en:ecobalyse-ingredients-matched-between-\d+-and-\d+/} @{$product_ref->{misc_tags}}];
	}

	# Determine range: 0-9, 10-19, ..., 90-100
	my $range_start = int($pct / 10) * 10;
	my $range_end = $range_start + 9;
	# Special case: 90-100% should map to 90-100 range
	if ($range_start >= 90) {
		$range_start = 90;
		$range_end = 100;
	}

	my $tag = "en:ecobalyse-ingredients-matched-between-$range_start-and-$range_end";
	add_tag($product_ref, "misc", $tag);

	return;
}

=head2 get_ecobalyse_reference_quantity ($product_ref)

Determine the quantity of product for which we send the ingredients and packaging to Ecobalyse.

Ecobalyse packaging entries are for a whole package (e.g. a 500 g tray), so we send the ingredients
for the whole product, so that the returned impacts are consistent for the whole product.
The impacts per 100 g or 100 ml are then computed from the impacts for the whole product.

The reference quantity is:
- the product quantity (in g or ml) if it is known,
- otherwise 100 g or 100 ml (depending on the nutrition data of the product)
and in that case we do not send the packaging, and we compute only the impacts per 100 g or 100 ml.

=head3 Return values

($quantity, $unit, $source) with $unit = "g" or "ml",
and $source = "product_quantity" or "default"

=cut

# Product quantities outside of this range are likely to be errors
my $min_reference_quantity = 1;
my $max_reference_quantity = 50000;

sub get_ecobalyse_reference_quantity ($product_ref) {

	my $product_quantity = $product_ref->{product_quantity};
	my $product_quantity_unit = $product_ref->{product_quantity_unit} // '';
	if (    (looks_like_number($product_quantity))
		and ($product_quantity_unit =~ /^(g|ml)$/)
		and ($product_quantity >= $min_reference_quantity)
		and ($product_quantity <= $max_reference_quantity))
	{
		return ($product_quantity + 0, $product_quantity_unit, "product_quantity");
	}

	# Unknown product quantity: ingredients quantities are estimated for 100 g or 100 ml of product,
	# depending on the nutrition data
	my $nutrition_per = deep_get($product_ref, qw(nutrition aggregated_set per)) // '';
	return (100, ($nutrition_per eq "100ml" ? "ml" : "g"), "default");
}

=head2 format_ecs_value ($value)

Round an Ecobalyse environmental cost (ECS) value for display:
1 decimal for values below 100, no decimals for values of 100 and more.

Returns an empty string if the value is not a number (e.g. unexpected value from the Ecobalyse API).

=cut

sub format_ecs_value ($value) {
	return "" unless looks_like_number($value);
	return sprintf("%.0f", $value) if abs($value) >= 99.95;
	return sprintf("%.1f", $value);
}

=head2 ecobalyse_api_call_enabled ()

Return 1 if the Ecobalyse API should be called each time a product is updated or reprocessed:
the ecobalyse_call_api_on_product_update option must be set, and we need an Ecobalyse API token.

=cut

sub ecobalyse_api_call_enabled () {
	return ($options{ecobalyse_call_api_on_product_update} and $ecobalyse_api_token) ? 1 : 0;
}

# Previous environmental impact data has Ecobalyse results if it has an ECS value
sub _has_ecobalyse_results ($environmental_impact_ref) {
	return ((defined $environmental_impact_ref)
			and looks_like_number($environmental_impact_ref->{ecs_per_100g_or_100ml}));
}

# Copy of a data structure with all numeric values as numbers,
# as numbers may become strings (or the reverse) when the product is stored and loaded
sub _normalize_numbers ($value) {
	return {map {$_ => _normalize_numbers($value->{$_})} keys %$value} if ref($value) eq 'HASH';
	return [map {_normalize_numbers($_)} @$value] if ref($value) eq 'ARRAY';
	return looks_like_number($value) ? $value + 0 : $value;
}

sub _same_ecobalyse_request ($request1_ref, $request2_ref) {
	return 0 if not(defined $request1_ref and defined $request2_ref);
	state $json = JSON->new->canonical;
	return $json->encode(_normalize_numbers($request1_ref)) eq $json->encode(_normalize_numbers($request2_ref));
}

# Fields of the environmental_impact structure that contain the results of a successful Ecobalyse API call
my @ecobalyse_results_fields = qw(ecobalyse_response ecs_per_product ecs_per_100g_or_100ml ecs_per ecobalyse_results_t);

=head2 keep_previous_ecobalyse_results_as_stale ($product_ref, $previous_environmental_impact_ref)

When we could not get new results from Ecobalyse (API not called, timeout, server error etc.),
we keep the previous environmental impact data (input, request and results, so that they stay consistent),
and we mark the results as stale.

The new request that we could not send or that failed is kept in ecobalyse_pending_request.

=cut

sub keep_previous_ecobalyse_results_as_stale ($product_ref, $previous_environmental_impact_ref, $error_response = undef)
{
	my $new_request_ref = $product_ref->{environmental_impact}{ecobalyse_request};

	$product_ref->{environmental_impact} = $previous_environmental_impact_ref;
	$previous_environmental_impact_ref->{ecobalyse_stale} = 1;
	# Keep the time at which the results first became stale
	$previous_environmental_impact_ref->{ecobalyse_stale_t} //= time();
	$previous_environmental_impact_ref->{ecobalyse_pending_request} = $new_request_ref;
	if (defined $error_response) {
		$previous_environmental_impact_ref->{ecobalyse_error_response} = $error_response;
	}
	else {
		delete $previous_environmental_impact_ref->{ecobalyse_error_response};
	}
	add_tag($product_ref, "misc", "en:ecobalyse-results-stale");
	return;
}

=head2 estimate_environmental_impact_service ($product_ref, $updated_product_fields_ref, $errors_ref, $skip_ecobalyse_call = 0, $force_ecobalyse_call = 0)

Prepare the Ecobalyse API request for the product, and call the Ecobalyse API to get its environmental cost.

If the request is the same as the one for the existing results, the existing results are reused
without calling the API (unless $force_ecobalyse_call is set).

If we do not call the API ($skip_ecobalyse_call) or if the call fails because of a temporary error
(timeout, server error), the existing results are kept and marked as stale (en:ecobalyse-results-stale misc tag).

=cut

sub estimate_environmental_impact_service (
	$product_ref, $updated_product_fields_ref, $errors_ref,
	$skip_ecobalyse_call = 0,
	$force_ecobalyse_call = 0
	)
{
	# clear previous environmental impact data, but keep it so that we can reuse previous results
	my $previous_environmental_impact_ref = delete $product_ref->{environmental_impact};
	$previous_environmental_impact_ref = undef
		if not _has_ecobalyse_results($previous_environmental_impact_ref);

	# Remove Ecobalyse misc tags from previous runs
	if (defined $product_ref->{misc_tags}) {
		$product_ref->{misc_tags}
			= [grep {$_ !~ /^en:ecobalyse-/} @{$product_ref->{misc_tags}}];
	}

	# indicate that the service is modifying the "environmental_impact" and "misc_tags" structures
	$updated_product_fields_ref->{environmental_impact} = 1;
	$updated_product_fields_ref->{misc_tags} = 1;

	# If undefined ingredients, do nothing
	return if not defined $product_ref->{ingredients};

	# Example Ecobalyse food API request:

	# {
	# 	"ingredients": [
	# 		{
	# 		"id": "5fc8032f-ca1c-4497-844b-f9213075eab3",
	# 		"mass": 100
	# 		}
	# 	],
	# 	"transform": {
	# 		"id": "a2836bb8-7f45-5cfa-bb00-8b38046291cf",
	# 		"mass": 100
	# 	},
	# 	"packaging": [
	# 		{
	# 		"id": "6bc3e083-e989-4bb0-bf49-99a8e68694a4",
	# 		"amount": 1
	# 		}
	# 	],
	# 	"distribution": "frozen"
	# }

	# Example Ecobalyse food2 API request:
	#
	# {
	#   "components": [
	#     {
	#       "quantity": 100,
	#       "custom": {
	#         "name": "Sucre de betterave par défaut (2025)",
	#         "elements": [
	#           {
	#             "amount": 1,
	#             "material": {
	#               "id": "5fc8032f-ca1c-4497-844b-f9213075eab3"
	#             },
	#             "transforms": []
	#           }
	#         ]
	#       }
	#     }
	#   ],
	#   "recyclable": true
	# }

	# Initialisation of the payload structure
	my $payload_ref = {ingredients => [],};

	# Keep a separate structure with more information for debugging and analysis
	$product_ref->{environmental_impact}{ecobalyse_input}{ingredients} = [];

	# Reference quantity of product for which we send the ingredients and packaging to Ecobalyse
	my ($reference_quantity, $reference_quantity_unit, $reference_quantity_source)
		= get_ecobalyse_reference_quantity($product_ref);
	$product_ref->{environmental_impact}{ecobalyse_input}{reference_quantity} = $reference_quantity;
	$product_ref->{environmental_impact}{ecobalyse_input}{reference_quantity_unit} = $reference_quantity_unit;
	$product_ref->{environmental_impact}{ecobalyse_input}{reference_quantity_source} = $reference_quantity_source;
	my $reference_quantity_source_tag = $reference_quantity_source =~ s/_/-/gr;
	add_tag($product_ref, "misc", "en:ecobalyse-reference-quantity-from-$reference_quantity_source_tag");

	# Ingredients quantities (in g) are estimated for 100 g or 100 ml of product
	# (depending on the nutrition data, which is used to estimate the ingredients percentages):
	# we scale them to the reference quantity
	my $quantity_factor = $reference_quantity / 100;

	# Add ingredients
	# We only add leaf ingredients (without their parents)

	my $ingredients_quantities_ref = get_ecobalyse_ingredients_quantities($product_ref);
	my $total_ingredients_quantity = $ingredients_quantities_ref->{total_quantity};
	my $total_ingredients_quantity_with_ecobalyse_id = $ingredients_quantities_ref->{total_quantity_with_ecobalyse_id};

	foreach my $leaf_ref (@{$ingredients_quantities_ref->{ingredients}}) {
		my $quantity = $leaf_ref->{quantity};
		my $id = $leaf_ref->{ecobalyse_id};
		# Ecobalyse rejects the whole request if an ingredient has a mass of 0
		# (e.g. ingredients with an estimated percent of 0)
		next unless defined $quantity and defined $id and $quantity > 0;

		my $ingredient_ref = $leaf_ref->{ingredient};
		push @{$payload_ref->{ingredients}},
			{
			id => $id,
			mass => $quantity * $quantity_factor,
			};
		# Also store the ingredient in the ecobalyse_input structure for debugging and analysis
		push @{$product_ref->{environmental_impact}{ecobalyse_input}{ingredients}},
			{
			id => $id,
			mass => $quantity * $quantity_factor,
			name => $ingredient_ref->{text} // '',
			ecobalyse_name => $ingredient_ref->{ecobalyse_name} || $ingredient_ref->{ecobalyse_proxy_name} // '',
			};
	}

	# Compute ingredients coverage percentage and set misc_tags
	my $ingredients_coverage_percent = 0;
	if ($total_ingredients_quantity > 0) {
		$ingredients_coverage_percent
			= int(($total_ingredients_quantity_with_ecobalyse_id / $total_ingredients_quantity) * 100);
	}
	$product_ref->{environmental_impact}{ecobalyse_input}{ingredients_coverage_percent} = $ingredients_coverage_percent;

	set_ecobalyse_coverage_misc_tags($product_ref);

	# Add transformations / processing
	my @transformation_entries = get_ecobalyse_transformation_entries($product_ref);
	if (@transformation_entries) {
		# Note: the food2 API allows multiple transformations, but the food API only allows one transformation in the "transform" field.
		# We use the food API for now, so we only take the first transformation entry.
		if ($ecobalyse_version eq "food") {
			@transformation_entries = ($transformation_entries[0]);
			$payload_ref->{transform} = {
				id => $transformation_entries[0]->{id},
				mass => $total_ingredients_quantity * $quantity_factor,
			};
			$product_ref->{environmental_impact}{ecobalyse_input}{transform} = {
				id => $transformation_entries[0]->{id},
				name => $transformation_entries[0]->{name},
				name_fr => $transformation_entries[0]->{name_fr},
				mass => $total_ingredients_quantity * $quantity_factor,
			};
		}
		else {
			# For the food2 API, we can keep all transformation entries
			$payload_ref->{transformations} = [];
			$product_ref->{environmental_impact}{ecobalyse_input}{transformations} = [];

			foreach my $entry (@transformation_entries) {
				push @{$payload_ref->{transformations}},
					{
					id => $entry->{id},
					mass => $total_ingredients_quantity * $quantity_factor,
					};
				push @{$product_ref->{environmental_impact}{ecobalyse_input}{transformations}},
					{
					id => $entry->{id},
					name => $entry->{name},
					name_fr => $entry->{name_fr},
					mass => $total_ingredients_quantity * $quantity_factor,
					};
			}
		}

	}

	# Add packaging
	# The Ecobalyse packaging entries are for a whole package,
	# so we send the packaging only if we know the product quantity
	my $packaging_entry_ref = get_ecobalyse_packaging_entry($product_ref);
	if ((defined $packaging_entry_ref) and ($reference_quantity_source ne "product_quantity")) {
		$product_ref->{environmental_impact}{ecobalyse_input}{packaging_skip_reason} = "unknown_product_quantity";
	}
	elsif (defined $packaging_entry_ref) {
		$payload_ref->{packaging} = [];
		$product_ref->{environmental_impact}{ecobalyse_input}{packaging} = [];
		push @{$payload_ref->{packaging}}, {
			id => $packaging_entry_ref->{id},
			amount =>
				1 # The packaging entries in Ecobalyse are already normalized to the product quantity, so we always use amount=1 here (only raw materials need a mass)
		};
		push @{$product_ref->{environmental_impact}{ecobalyse_input}{packaging}},
			{
			id => $packaging_entry_ref->{id},
			name => $packaging_entry_ref->{activityName},
			name_fr => $packaging_entry_ref->{displayName},
			category => $packaging_entry_ref->{categories_tagid},
			};
	}

	# Add distribution
	# storage_conditions is set by set_storage_conditions() when the product is processed,
	# but it may be missing when this function is called through the product services API
	my $storage_conditions
		= $product_ref->{storage_conditions}
		|| (get_inherited_property_from_categories_tags($product_ref, "storage_conditions:en"))[0]
		|| "en:ambient";
	$storage_conditions = "en:" . $storage_conditions if $storage_conditions !~ /^[a-z]{2}:/;
	my $distribution = $ecobalyse_distribution_for_storage_conditions{$storage_conditions} // "ambient";
	$payload_ref->{distribution} = $distribution;
	$product_ref->{environmental_impact}{ecobalyse_input}{distribution} = $distribution;

	# Add consumer preparation (consumption step)
	my $preparation = $ecobalyse_preparation_for_distribution{$distribution};
	if (defined $preparation) {
		$payload_ref->{preparation} = [$preparation];
		$product_ref->{environmental_impact}{ecobalyse_input}{preparation} = [$preparation];
	}

	# API URL
	my $url_recipe = "https://ecobalyse.beta.gouv.fr/api/food";

	my $request_ref = {url => $url_recipe, data => $payload_ref};
	$product_ref->{environmental_impact}{ecobalyse_request} = $request_ref;

	# Check ingredients coverage threshold ($ingredients_coverage_percent was computed above)
	my $threshold = $options{ecobalyse_min_ingredients_coverage_percent} // 80;

	if ($ingredients_coverage_percent < $threshold) {
		$log->info(
			"Skipping Ecobalyse API call: ingredients coverage ${ingredients_coverage_percent}% < ${threshold}%");
		$product_ref->{environmental_impact}{ecobalyse_skipped} = 1;
		$product_ref->{environmental_impact}{ecobalyse_skip_reason} = "insufficient_ingredients_coverage";
		add_tag($product_ref, "misc", "en:ecobalyse-api-not-called");
		return;
	}

	# If the request is the same as the one for the previous results, reuse them
	if (    (not $force_ecobalyse_call)
		and (defined $previous_environmental_impact_ref)
		and _same_ecobalyse_request($previous_environmental_impact_ref->{ecobalyse_request}, $request_ref))
	{
		$log->debug("Same Ecobalyse API request as for the previous results, reusing them") if $log->is_debug();
		foreach my $field (@ecobalyse_results_fields) {
			$product_ref->{environmental_impact}{$field} = $previous_environmental_impact_ref->{$field}
				if defined $previous_environmental_impact_ref->{$field};
		}
		add_tag($product_ref, "misc", "en:ecobalyse-api-not-called-same-request");
		return;
	}

	if ($skip_ecobalyse_call) {
		$log->debug(
			"Skipping Ecobalyse API call, only preparing request payload",
			{endpoint => $url_recipe, payload => $payload_ref}
		) if $log->is_debug();
		add_tag($product_ref, "misc", "en:ecobalyse-api-skipped");
		# The previous results do not correspond to the current product data anymore
		keep_previous_ecobalyse_results_as_stale($product_ref, $previous_environmental_impact_ref)
			if defined $previous_environmental_impact_ref;
	}
	else {

		# Debug information for the request
		$log->debug("Send Ecobalyse API request", {endpoint => $url_recipe, payload => $payload_ref})
			if $log->is_debug();

		# Send the request and get the response
		# For tests, we pass a testid to call_ecobalyse() so that the mock response is used instead of a real API call.
		add_tag($product_ref, "misc", "en:ecobalyse-api-called");
		my ($response_content, $is_success, $response_code)
			= (call_ecobalyse($url_recipe, $payload_ref, $product_ref->{testid}));

		# Parse the JSON response
		my $response_data_ref;
		# if the response is JSON, decode it

		my $json_decoded = 1;
		eval {$response_data_ref = decode_json($response_content);};
		# Check if the JSON decoding was successful
		if ($@) {
			$json_decoded = 0;
			$log->error("Failed to decode JSON response from Ecobalyse API",
				{endpoint => $url_recipe, payload => $payload_ref, response => $response_content, error => $@})
				if $log->is_error();
			$response_data_ref = {error => "Failed to decode JSON response: $@"};
		}
		else {
			$response_data_ref = filter_ecobalyse_response_for_open_data($response_data_ref);
		}

		# Access the specific "ecs" value
		my $ecs_value = $json_decoded ? deep_get($response_data_ref, 'results', 'total', 'ecs') : undef;

		# Handle the response based on success or failure
		# We consider the call successful only if we got a valid JSON response with an ecs value
		if ($is_success and (defined $ecs_value)) {

			add_tag($product_ref, "misc", "en:ecobalyse-api-success");

			# The impacts returned by Ecobalyse are for the reference quantity of product
			if ($reference_quantity_source ne "default") {
				$product_ref->{environmental_impact}{ecs_per_product} = $ecs_value;
			}
			$product_ref->{environmental_impact}{ecs_per_100g_or_100ml} = $ecs_value * 100 / $reference_quantity;
			$product_ref->{environmental_impact}{ecs_per} = "100" . $reference_quantity_unit;
			$product_ref->{environmental_impact}{ecobalyse_results_t} = time();
			$product_ref->{environmental_impact}{ecobalyse_response} = $response_data_ref;
		}
		else {
			# If the request failed, log the error
			$log->error("Ecobalyse API request failed or returned no ecs value",
				{endpoint => $url_recipe, payload => $payload_ref, response => $response_content})
				if $log->is_error();
			# Add error misc tag
			add_tag($product_ref, "misc", "en:ecobalyse-api-error");

			# Temporary errors: timeout, no response, server errors, rate limiting, or a response that is not JSON
			# In that case, we keep the previous results (if any) and mark them as stale.
			# Other errors (e.g. 4xx with a JSON error message) mean that Ecobalyse rejected our request:
			# the previous results do not apply anymore.
			my $temporary_error = (
					   (not $json_decoded)
					or ((defined $response_code) and (($response_code >= 500) or ($response_code == 429)))
			);

			if ($temporary_error and (defined $previous_environmental_impact_ref)) {
				add_tag($product_ref, "misc", "en:ecobalyse-api-temporary-error");
				keep_previous_ecobalyse_results_as_stale($product_ref, $previous_environmental_impact_ref,
					$response_content);
			}
			else {
				# Store the error response for debugging
				$product_ref->{environmental_impact}{ecobalyse_error_response} = $response_content;
				$product_ref->{environmental_impact}{ecobalyse_response} = $response_data_ref;
			}
			# Add an error message to the errors array
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
	}

	return;
}

=head2 get_ecobalyse_ingredients_quantities ($product_ref)

Return the leaf ingredients of a product (ingredients without sub-ingredients) with the
quantity and Ecobalyse id that are used to compute the environmental impact.

The quantity is the quantity_estimate if available (not set by the current product opener % estimation),
or the percent_estimate. Leaf ingredients without a quantity are not counted in the totals
(they are not sent to Ecobalyse).

=head3 Arguments

=head4 $product_ref

=head3 Return value

A hash reference with:

=over

=item ingredients

Reference to an array of hashes, one for each leaf ingredient: ingredient (reference to the ingredient),
quantity (undef if no quantity), ecobalyse_id (ecobalyse_id or ecobalyse_proxy_id, undef if none).

=item total_quantity

Sum of the quantities of the leaf ingredients.

=item total_quantity_with_ecobalyse_id

Sum of the quantities of the leaf ingredients that have an Ecobalyse id or proxy id.

=back

=cut

sub get_ecobalyse_ingredients_quantities ($product_ref) {

	my @leaf_ingredients = ();
	my $total_quantity = 0;
	my $total_quantity_with_ecobalyse_id = 0;

	my @ingredients_queue = @{$product_ref->{ingredients} // []};

	while (@ingredients_queue) {
		my $ingredient_ref = shift @ingredients_queue;
		if (defined $ingredient_ref->{ingredients}) {
			push @ingredients_queue, @{$ingredient_ref->{ingredients}};
		}
		else {
			my $quantity = $ingredient_ref->{quantity_estimate} // $ingredient_ref->{percent_estimate};
			my $id = $ingredient_ref->{ecobalyse_id} || $ingredient_ref->{ecobalyse_proxy_id};

			push @leaf_ingredients,
				{
				ingredient => $ingredient_ref,
				quantity => $quantity,
				ecobalyse_id => $id,
				};

			next unless defined $quantity;

			$total_quantity += $quantity;
			$total_quantity_with_ecobalyse_id += $quantity if defined $id;
		}
	}

	return {
		ingredients => \@leaf_ingredients,
		total_quantity => $total_quantity,
		total_quantity_with_ecobalyse_id => $total_quantity_with_ecobalyse_id,
	};
}

# Durations and status codes of the Ecobalyse API calls made by this process,
# so that scripts like update_all_products.pl can report how long the calls take
# (we only keep the durations and the number of calls per status code, to keep memory low for millions of calls)
my @ecobalyse_call_durations = ();
my %ecobalyse_call_codes = ();

=head2 get_ecobalyse_call_stats ()

Return the durations (in seconds) of the Ecobalyse API calls made by this process,
and the number of calls for each HTTP status code:
{durations => [0.234, ...], codes => {200 => 10, 500 => 1}}

=cut

sub get_ecobalyse_call_stats () {
	return {durations => \@ecobalyse_call_durations, codes => \%ecobalyse_call_codes};
}

=head2 format_ecobalyse_call_stats ()

Return a text summary of the Ecobalyse API calls made by this process:
number of calls, number per status code, and durations (mean, percentiles, max).

=cut

sub format_ecobalyse_call_stats () {
	my $n = scalar @ecobalyse_call_durations;
	return "Ecobalyse API calls: 0\n" if not $n;

	my %codes = %ecobalyse_call_codes;
	my @durations = sort {$a <=> $b} @ecobalyse_call_durations;
	my $percentile = sub ($p) {
		return $durations[int(($n - 1) * $p / 100 + 0.5)];
	};

	return sprintf(
		"Ecobalyse API calls: %d (%s)\n"
			. "Ecobalyse API calls durations (s): total %.1f - mean %.3f - min %.3f - median %.3f - p90 %.3f - p99 %.3f - max %.3f\n",
		$n, join(", ", map {"$_: $codes{$_}"} sort keys %codes),
		sum(@durations), sum(@durations) / $n,
		$durations[0], $percentile->(50), $percentile->(90), $percentile->(99), $durations[-1]
	);
}

sub call_ecobalyse($url, $payload_ref, $testid) {
	# Create a UserAgent object to make the API request
	my $ua = create_user_agent();
	$ua->timeout(5);

	# Send the ECOBALYSE API_TOKEN token in the token header if it's defined
	# the token is now required, the API request will fail without a token
	if (not defined $ecobalyse_api_token) {
		$log->error("ECOBALYSE_API_TOKEN is not defined, the API request will fail without a token")
			if $log->is_error();
	}

	my $start = clock_gettime(CLOCK_MONOTONIC);

	my $response = $ua->post(
		$url,
		Content_Type => 'application/json',
		Content => encode_json($payload_ref),
		Authorization => "Bearer " . $ecobalyse_api_token || "",
	);

	my $duration = clock_gettime(CLOCK_MONOTONIC) - $start;
	push @ecobalyse_call_durations, $duration;
	$ecobalyse_call_codes{$response->code // "none"}++;
	$log->info("Ecobalyse API call", {duration => sprintf("%.3f", $duration), code => $response->code})
		if $log->is_info();

	return ($response->decoded_content, $response->is_success, $response->code);
}

# Packaging data from Ecobalyse is stored in a JSON file (processes_packaging_matched.json) that is loaded and indexed on first call.

# Load and index the Ecobalyse packaging data. Cached on first call in a state variable.
# The packaging material/shape fields in the data have already been canonicalized to
# OFF taxonomy tagids by external-data/ecobalyse/match_ecobalyse_packaging_categories.pl.
sub _load_ecobalyse_packaging_data () {

	state $cache;
	return $cache if defined $cache;

	my $file = $data_root . "/external-data/ecobalyse/processes_packaging_matched.json";
	open(my $fh, '<:encoding(UTF-8)', $file)
		or die "Could not open Ecobalyse packaging data file $file: $!\n";
	my $json = JSON->new->canonical;
	my $entries = $json->decode(do {local $/; <$fh>});
	close($fh);

	# Index 1: by category tagid (exact lookup, no is_a traversal needed because
	# a product's categories_tags already contains all ancestor categories)
	my %by_category = ();
	for my $entry (@$entries) {
		my $category_id = $entry->{categories_tagid};
		if (defined $category_id and $category_id ne '') {
			push @{$by_category{$category_id}}, $entry;
		}
	}

	# Index 2: category-less proxies — 1 entry per unique
	# (shape, material, quantity rounded to nearest 100g). When several entries map
	# to the same bucket, keep the one whose quantity is closest to the rounded value;
	# ties are broken by activityName so the result is deterministic.
	my %proxies_categoryless = ();
	for my $entry_ref (@$entries) {
		my $shape = $entry_ref->{packaging_shape} // '';
		my $material = $entry_ref->{packaging_material} // '';
		next if $shape eq '' or $material eq '';
		my $quantity = $entry_ref->{quantity} // 0;
		my $quantity_rounded = $quantity ? int(($quantity + 50) / 100) * 100 : 0;
		my $key = "$shape|$material|$quantity_rounded";
		# Category-less proxy: keep the entry's id/name/ecs/quantity but zero out its
		# category so it scores with category specificity 0 (matches material+shape only).
		my $proxy = {%$entry_ref};
		$proxy->{categories_tagid} = '';
		if (not exists $proxies_categoryless{$key}) {
			$proxies_categoryless{$key} = $proxy;
		}
		else {
			my $existing = $proxies_categoryless{$key};
			my $existing_diff = abs(($existing->{quantity} // 0) - $quantity_rounded);
			my $new_diff = abs($quantity - $quantity_rounded);
			if (
				$new_diff < $existing_diff
				or ($new_diff == $existing_diff
					and (($entry_ref->{activityName} // '') lt($existing->{activityName} // '')))
				)
			{
				$proxies_categoryless{$key} = $proxy;
			}
		}
	}

	$cache = {
		by_category => \%by_category,
		proxies_categoryless => \%proxies_categoryless,
		proxies_manual => _load_manual_proxies($entries),
	};
	return $cache;
}

# Load the manual proxy configuration file (packaging_proxies.tsv). Rows map a
# specific Ecobalyse entry (by id) to additional OFF categories it should apply to.
# Returns a hashref: category_tagid => [ entries ].
sub _load_manual_proxies ($entries) {
	my %proxies_manual = ();

	my $file = $data_root . "/external-data/ecobalyse/packaging_proxies.tsv";
	return \%proxies_manual unless -e $file;

	# Index entries by id for quick lookup
	my %by_id = ();
	for my $entry_ref (@$entries) {
		$by_id{$entry_ref->{id}} = $entry_ref if defined $entry_ref->{id};
	}

	open(my $fh, '<:encoding(UTF-8)', $file)
		or return \%proxies_manual;
	while (my $line = <$fh>) {
		chomp $line;
		next if $line =~ /^\s*#/;    # skip comments
		next if $line =~ /^\s*$/;    # skip blank lines
		my ($ecobalyse_id, $name_en, $name_fr, $categories) = split(/\t/, $line);
		next unless defined $ecobalyse_id and $ecobalyse_id ne '';
		my $entry_ref = $by_id{$ecobalyse_id};
		next unless defined $entry_ref;
		next unless defined $categories and $categories ne '';

		for my $category_id (split(/,/, $categories)) {
			$category_id =~ s/^\s+|\s+$//g;
			next if $category_id eq '';
			push @{$proxies_manual{$category_id}}, $entry_ref;
		}
	}
	close($fh);
	return \%proxies_manual;
}

# Score the material match between an OFF packaging_materials tag and an Ecobalyse
# packaging_material tagid (already canonicalized by match_ecobalyse_packaging_categories.pl).
# Returns 100 (exact), 80 (is_a parent/child either direction) or 0.
sub _material_match_score ($off_tag, $ecobalyse_tag) {
	return 0 if $ecobalyse_tag eq '';
	return 100 if $off_tag eq $ecobalyse_tag;
	return 80 if is_a('packaging_materials', $off_tag, $ecobalyse_tag);
	return 80 if is_a('packaging_materials', $ecobalyse_tag, $off_tag);
	return 0;
}

# Score the shape match between an OFF packaging_shapes tag and an Ecobalyse
# packaging_shape tagid (already canonicalized by match_ecobalyse_packaging_categories.pl).
# Returns 70 (exact), 56 (is_a parent/child either direction) or 0.
sub _shape_match_score ($off_tag, $ecobalyse_tag) {
	return 0 if $ecobalyse_tag eq '';
	return 70 if $off_tag eq $ecobalyse_tag;
	return 56 if is_a('packaging_shapes', $off_tag, $ecobalyse_tag);
	return 56 if is_a('packaging_shapes', $ecobalyse_tag, $off_tag);
	return 0;
}

=head2 get_ecobalyse_packaging_entry ($product_ref)

Select the best-matching Ecobalyse packaging entry for a product, based on its
categories, packaging materials, shapes and quantity.

The match is scored with the following weighted factors:
- Material match: 100 (exact), 80 (is_a parent/child in either direction), 0
- Shape match: 70 (exact), 56 (is_a parent/child in either direction), 0
- Category specificity: raw taxonomy level (0-10) of the matched category,
  via get_taxonomy_tag_level() (0 for category-less entries)
- Quantity distance: 0-5, only counted if material and shape both match
- ECS tiebreaker: higher ecs wins when total scores are equal

The selected entry (or undef when no candidate matched) is returned as a hashref.

=cut

sub get_ecobalyse_packaging_entry ($product_ref) {

	my $cache = _load_ecobalyse_packaging_data();
	my %by_category = %{$cache->{by_category}};
	my %proxies_categoryless = %{$cache->{proxies_categoryless}};
	my %proxies_manual = %{$cache->{proxies_manual}};

	my @packagings = @{$product_ref->{packagings} // []};

	my @categories_tags = @{$product_ref->{categories_tags} // []};
	my $product_quantity = $product_ref->{product_quantity} // 0;

	# Collect candidate entries
	my @candidates = ();

	# 1. Exact category matches (product categories_tags already include ancestors)
	for my $category_id (@categories_tags) {
		if (defined $by_category{$category_id}) {
			push @candidates, @{$by_category{$category_id}};
		}
	}
	# 2. Manual proxies (from packaging_proxies.tsv)
	for my $category_id (@categories_tags) {
		if (defined $proxies_manual{$category_id}) {
			push @candidates, @{$proxies_manual{$category_id}};
		}
	}

	# 3. Category-less proxies (always available as a fallback)
	push @candidates, values %proxies_categoryless;

	# Score each candidate
	my $best_score = -1;
	my $best_entry_ref;
	my $highest_ecs = -1;

	for my $entry_ref (@candidates) {
		my $best_material = 0;
		my $best_shape = 0;

		# Match against each packaging component (shape + material in same component)
		for my $packaging_component_ref (@packagings) {
			if (defined $packaging_component_ref->{material}) {
				my $m = _material_match_score($packaging_component_ref->{material},
					$entry_ref->{packaging_material} // '');
				$best_material = $m if $m > $best_material;
			}
			if (defined $packaging_component_ref->{shape}) {
				my $s = _shape_match_score($packaging_component_ref->{shape}, $entry_ref->{packaging_shape} // '');
				$best_shape = $s if $s > $best_shape;
			}
		}

		# Category specificity: raw taxonomy level (0 for category-less entries)
		my $cat_level = 0;
		if ($entry_ref->{categories_tagid} and $entry_ref->{categories_tagid} ne '') {
			$cat_level = get_taxonomy_tag_level('categories', $entry_ref->{categories_tagid});
		}

		# Skip category less entries if there was no match on material and shape
		if (($cat_level) == 0 and ($best_material == 0 and ($best_shape == 0))) {
			next;
		}

		# Quantity distance: only counted if material and shape both match at all
		my $quantity_score = 0;
		if ($best_material > 0 and $best_shape > 0 and $product_quantity) {
			my $entry_quantity = $entry_ref->{quantity} // 0;
			if ($entry_quantity > 0) {
				my $diff = abs($entry_quantity - $product_quantity);
				$quantity_score = 5 * (1 - $diff / $entry_quantity);
				$quantity_score = 0 if $quantity_score < 0;
			}
		}

		my $total = $best_material + $best_shape + $cat_level + $quantity_score;

		# ECS tiebreaker: on equal total scores, prefer the higher-impact entry
		if ($total > $best_score
			or ($total == $best_score and ($entry_ref->{ecs} // 0) > $highest_ecs))
		{
			$best_score = $total;
			$highest_ecs = $entry_ref->{ecs} // 0;
			$best_entry_ref = $entry_ref;
		}
	}

	return $best_entry_ref;
}

=head2 get_ecobalyse_transformation_entries ($product_ref)

Return the list of Ecobalyse transformation entries applicable to the product,
based on the ingredients_processing properties of its categories.

Each returned entry is a hashref with keys: id, name, name_fr, ecs, unit.
Returns an empty list when no transformation applies.

The ingredients_processing:en property of a category overrides the property of its parent categories
(e.g. xx:sashimi has the value en:none to cancel the en:cooked value of en:meals).
Properties of categories that are not parents of each other are combined
(e.g. en:canned-soups is both a canned food and a meal).

A transformation that includes another one (e.g. canning includes cooking) supersedes it.

=cut

sub get_ecobalyse_transformation_entries ($product_ref) {

	my $cooking_id = 'a2836bb8-7f45-5cfa-bb00-8b38046291cf';
	my $canning_id = 'a83c94af-6e31-5599-8022-7ae795862a99';

	my %transforms = (
		$cooking_id => {
			id => $cooking_id,
			name => 'Cooking, industrial, 1kg of cooked product {FR} U',
			name_fr => 'Cuisson',
			ecs => 17.42,
			unit => 'kg',
		},
		$canning_id => {
			id => $canning_id,
			name => 'Canning fruits or vegetables, industrial, 1kg of canned product {FR} U',
			name_fr => 'Mise en conserve',
			ecs => 19.54,
			unit => 'kg',
		},
	);

	# Transformations that are included in other transformations
	my %superseded_by = ($cooking_id => [$canning_id],);

	# Categories of the product that have the ingredients_processing:en property
	my @categories_with_processing = ();
	my %processing_for_category = ();
	for my $category_id (@{$product_ref->{categories_tags} // []}) {
		my $processing = get_property("categories", $category_id, "ingredients_processing:en");
		next unless defined $processing;
		push @categories_with_processing, $category_id;
		$processing_for_category{$category_id} = $processing;
	}

	my %seen = ();
	my @entries = ();

	for my $category_id (@categories_with_processing) {
		# Skip the category if a more specific category of the product overrides its property
		next
			if grep {($_ ne $category_id) and is_a("categories", $_, $category_id)} @categories_with_processing;

		my $processing = $processing_for_category{$category_id};

		# Values without an Ecobalyse transformation (e.g. en:none) do not add any transformation
		for my $proc_id (split(/,/, $processing)) {
			$proc_id =~ s/^\s+|\s+$//g;
			next if $proc_id eq '';
			my $transformation_id = get_property("ingredients_processing", $proc_id, "ecobalyse_transformation:en");
			next unless defined $transformation_id;
			next if $seen{$transformation_id}++;
			push @entries, $transforms{$transformation_id} if exists $transforms{$transformation_id};
		}
	}

	# Remove transformations that are included in other transformations of the product
	@entries = grep {
		my $entry_ref = $_;
		not grep {$seen{$_}} @{$superseded_by{$entry_ref->{id}} // []}
	} @entries;

	return @entries;
}

=head2 filter_ecobalyse_response_for_open_data ( $response_ref )

Filter an Ecobalyse API response so that only the data suitable for the
OFF open-data database is retained.

The following transformations are applied:

- The C<query> key is removed (it is already stored separately in
C<ecobalyse_input>).

- Only the contents of the C<results> key are kept; all other
top-level keys (C<description>, C<webUrl>, …) are dropped.

- For every hash that contains an C<ecs> key, all other keys are
removed so that only C<ecs> remains.  This pruning is applied recursively
throughout the C<results> sub-structure.

The original hash is not modified; a new hash reference is returned.

=cut

sub filter_ecobalyse_response_for_open_data ($response_ref) {
	return unless ref($response_ref) eq 'HASH';

	# Keep only what's inside "error" and "results"; remove query, description, webUrl, etc.

	my $filtered_response_ref = {};
	if (exists $response_ref->{error}) {
		$filtered_response_ref->{error} = $response_ref->{error};
	}
	if (exists $response_ref->{results}) {
		$filtered_response_ref->{results} = _filter_ecobalyse_results_for_open_data($response_ref->{results});
	}

	return $filtered_response_ref;
}

sub _filter_ecobalyse_results_for_open_data ($value_ref) {
	# Hash reference: if it has an "ecs" key, keep only that key
	if (ref($value_ref) eq 'HASH') {
		if (exists $value_ref->{ecs}) {
			return {ecs => $value_ref->{ecs}};
		}
		my %filtered = ();
		for my $key (keys %$value_ref) {
			$filtered{$key} = _filter_ecobalyse_results_for_open_data($value_ref->{$key});
		}
		return \%filtered;
	}

	# Array reference: recurse into each element
	if (ref($value_ref) eq 'ARRAY') {
		return [map {_filter_ecobalyse_results_for_open_data($_)} @$value_ref];
	}

	# Scalar or undef: return as-is
	return $value_ref;
}

1;
