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
use File::Basename qw/dirname/;
use Scalar::Util qw/looks_like_number/;
use Data::DeepAccess qw(deep_exists deep_get);

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

=head4 $skip_ecobalyse_call

Boolean flag indicating whether to skip the Ecobalyse API call, in which case we only prepare the request payload and store it in the product.

=cut

sub estimate_environmental_impact_service ($product_ref, $updated_product_fields_ref, $errors_ref,
	$skip_ecobalyse_call = 0)
{

	# $updated_product_fields_ref, $errors_ref sont des outputs : chaque service
	# dit quels champs sont modifiés
	# Ici on en ajoute un : "environmental_impact"

	# If undefined ingredients, do nothing
	return if not defined $product_ref->{ingredients};

	# indicate that the service is modifying the "ingredients" structure
	$updated_product_fields_ref->{environmental_impact} = 1;

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

	# Add ingredients
	# We only add leaf ingredients (without their parents)

	my @ingredients_queue = @{$product_ref->{ingredients} // []};
	my $total_ingredients_quantity = 0;
	my $total_ingredients_quantity_with_ecobalyse_code = 0;

	while (@ingredients_queue) {
		my $ingredient_ref = shift @ingredients_queue;
		if (defined $ingredient_ref->{ingredients}) {
			push @ingredients_queue, @{$ingredient_ref->{ingredients}};
		}
		else {
			# We use the quantity_estimate if available (not set by the current product opener % estimation),
			# or the percent_estimate
			my $quantity = $ingredient_ref->{quantity_estimate} // $ingredient_ref->{percent_estimate};
			next unless defined $quantity;

			$total_ingredients_quantity += $quantity;

			my $id = $ingredient_ref->{ecobalyse_code} || $ingredient_ref->{ecobalyse_proxy_code};
			if (defined $id) {
				$total_ingredients_quantity_with_ecobalyse_code += $quantity;
				push @{$payload_ref->{ingredients}},
					{
					id => $id,
					mass => $quantity,
					};
				# Also store the ingredient in the ecobalyse_input structure for debugging and analysis
				push @{$product_ref->{environmental_impact}{ecobalyse_input}{ingredients}},
					{
					id => $id,
					mass => $quantity,
					name => $ingredient_ref->{text} // '',
					};
			}
		}
	}

	# Add transformations / processing
	my @transformation_entries = get_ecobalyse_transformation_entries($product_ref);
	if (@transformation_entries) {
		$payload_ref->{transformations} = [];
		$product_ref->{environmental_impact}{ecobalyse_input}{transformations} = [];
		foreach my $entry (@transformation_entries) {
			push @{$payload_ref->{transformations}},
				{
				id => $entry->{id},
				mass => $total_ingredients_quantity,
				};
			push @{$product_ref->{environmental_impact}{ecobalyse_input}{transformations}},
				{
				id => $entry->{id},
				name => $entry->{name},
				name_fr => $entry->{name_fr},
				mass => $total_ingredients_quantity,
				};
		}
	}

	# Add packaging
	my $packaging_entry_ref = get_ecobalyse_packaging_entry($product_ref);
	if (defined $packaging_entry_ref) {
		$payload_ref->{packaging} = [];
		$product_ref->{environmental_impact}{ecobalyse_input}{packaging} = [];
		push @{$payload_ref->{packaging}},
			{
			id => $packaging_entry_ref->{id},
			amount => 1
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
	my $distribution = $product_ref->{storage_conditions} || "en:ambient";
	$distribution =~ s/^[a-z]{2}://;
	$payload_ref->{distribution} = $distribution;
	$product_ref->{environmental_impact}{ecobalyse_input}{distribution} = $distribution;

	# API URL
	my $url_recipe = "https://ecobalyse.beta.gouv.fr/api/food";

	$product_ref->{environmental_impact}{ecobalyse_request} = {url => $url_recipe, data => $payload_ref};

	if ($skip_ecobalyse_call) {
		$log->debug(
			"Skipping Ecobalyse API call, only preparing request payload",
			{endpoint => $url_recipe, payload => $payload_ref}
		) if $log->is_debug();
	}
	else {

		# Debug information for the request
		$log->debug("Send Ecobalyse API request", {endpoint => $url_recipe, payload => $payload_ref})
			if $log->is_debug();

		# Send the request and get the response
		# For tests, we pass a testid to call_ecobalyse() so that the mock response is used instead of a real API call.
		my ($response_content, $is_success) = (call_ecobalyse($url_recipe, $payload_ref, $product_ref->{testid}));

		# Parse the JSON response
		my $response_data = $response_content;
		# if the response is JSON, decode it
		eval {$response_data = decode_json($response_content);};

		$product_ref->{environmental_impact}{ecobalyse_response} = $response_data;

		# Handle the response based on success or failure
		if ($is_success) {

			# Access the specific "ecs" value
			my $ecs_value = deep_get($response_data, 'results', 'total', 'ecs');
			if (defined $ecs_value) {
				# If 'ecs' is defined, store it in the product reference
				$product_ref->{environmental_impact}{ecs} = $ecs_value;
			}
		}
		else {
			# If the request failed, log the error
			$log->error("send_event request failed",
				{endpoint => $url_recipe, payload => $payload_ref, response => $response_content})
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
	}

	return;
}

sub call_ecobalyse($url_recipe, $payload_ref, $testid) {
	# Create a UserAgent object to make the API request
	my $ua = create_user_agent();
	$ua->timeout(5);

	# Prepare the POST request with the payload
	my $request = POST $url_recipe, $payload_ref;
	$request->header('content-type' => 'application/json');

	# Send the ECOBALYSE API_TOKEN token in the token header if it's defined
	# the token is now required, the API request will fail without a token
	if (defined $ecobalyse_api_token) {
		$request->header('token' => $ecobalyse_api_token);
	}
	else {
		$log->error("ECOBALYSE_API_TOKEN is not defined, the API request will fail without a token")
			if $log->is_error();
	}
	$request->content(decode_utf8(encode_json($payload_ref)));

	# Send the request and get the response
	my $response = $ua->request($request);
	return ($response->decoded_content, $response->is_success);
}

# Packaging data from Ecobalyse is stored in a JSON file (processes_packaging_matched.json) that is loaded and indexed on first call.

# Load and index the Ecobalyse packaging data. Cached on first call in a state variable.
# The packaging material/shape fields in the data have already been canonicalized to
# OFF taxonomy tagids by scripts/match_ecobalyse_packaging_categories.pl.
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

=cut

sub get_ecobalyse_transformation_entries ($product_ref) {

	my %transforms = (
		'a2836bb8-7f45-5cfa-bb00-8b38046291cf' => {
			id => 'a2836bb8-7f45-5cfa-bb00-8b38046291cf',
			name => 'Cooking, industrial, 1kg of cooked product {FR} U',
			name_fr => 'Cuisson',
			ecs => 17.42,
			unit => 'kg',
		},
		'a83c94af-6e31-5599-8022-7ae795862a99' => {
			id => 'a83c94af-6e31-5599-8022-7ae795862a99',
			name => 'Canning fruits or vegetables, industrial, 1kg of canned product {FR} U',
			name_fr => 'Mise en conserve',
			ecs => 19.54,
			unit => 'kg',
		},
	);

	my %seen = ();
	my @entries = ();

	for my $category_id (@{$product_ref->{categories_tags} // []}) {
		my $processing = get_property("categories", $category_id, "ingredients_processing:en");
		next unless defined $processing;
		for my $proc_id (split(/,/, $processing)) {
			$proc_id =~ s/^\s+|\s+$//g;
			next if $proc_id eq '';
			my $transformation_id = get_property("ingredients_processing", $proc_id, "ecobalyse_transformation:en");
			next unless defined $transformation_id;
			next if $seen{$transformation_id}++;
			push @entries, $transforms{$transformation_id} if exists $transforms{$transformation_id};
		}
	}

	return @entries;
}

1;
