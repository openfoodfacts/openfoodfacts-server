#!/usr/bin/perl -w

# Tests for the request sent to the Ecobalyse food2 API

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::Tags qw/:all/;
use ProductOpener::EnvironmentalImpact qw/estimate_environmental_impact_service/;

ProductOpener::Tags::init_taxonomies(0);

my $mock_calls = 0;
my $ecobalyse_mock = mock 'ProductOpener::EnvironmentalImpact' => (
	override => [
		'call_ecobalyse' => sub {
			++$mock_calls;
			return (encode_json({score => {ecs => 330, complements => -30}}), 1, 200);
		}
	]
);

my $rice_id = "cce078cf-3d3e-4153-a0a1-35555b2da639";    # kg
my $water_id = "36b3ffec-51e7-4e26-b1b5-7d52554e0aa6";    # kg
my $wine_id = "6621c18e-85de-4683-82be-7b236e68bc48";    # L
my $cooking_id = "e297d2a0-1945-4f48-838f-fbbb4a6cde72";

# Refrigerated cooked meal of 300 g, with ingredients quantities estimated by the recipe estimator:
# 110 g of ingredients for 100 g of product, as some water evaporates during cooking
my $product_ref = {
	categories_tags => ["en:meals"],
	storage_conditions => "en:refrigerated",
	product_quantity => 300,
	product_quantity_unit => "g",
	ingredients => [
		{id => "en:rice", text => "riz", quantity_estimate => 50, percent_estimate => 45, ecobalyse_id => $rice_id},
		{
			id => "en:red-beans",
			text => "haricots rouges",
			ingredients => [
				{
					id => "en:water",
					text => "eau",
					quantity_estimate => 20,
					percent_estimate => 20,
					ecobalyse_id => $water_id
				}
			]
		},
		{id => "en:water", text => "eau", quantity_estimate => 30, percent_estimate => 27, ecobalyse_id => $water_id},
		{
			id => "en:red-wine",
			text => "vin rouge",
			quantity_estimate => 10,
			percent_estimate => 8,
			ecobalyse_id => $wine_id
		},
	],
};

estimate_environmental_impact_service($product_ref, {}, []);
is($mock_calls, 1, "API called");

my $data_ref = $product_ref->{environmental_impact}{ecobalyse_request}{data};
my $input_ref = $product_ref->{environmental_impact}{ecobalyse_input};

is(
	$data_ref->{components},
	[
		{
			quantity => 1,
			name => "riz",
			elements => [{amount => 0.15, material => {id => $rice_id}, transforms => [$cooking_id]}]
		},
		# water from the main recipe and from the beans sub-recipe is merged
		{
			quantity => 1,
			name => "eau",
			elements => [{amount => 0.15, material => {id => $water_id}, transforms => [$cooking_id]}]
		},
		# red wine is in L in Ecobalyse: no transformation (they are in kg)
		{
			quantity => 1,
			name => "vin rouge",
			elements => [{amount => 0.03, material => {id => $wine_id}, transforms => []}]
		},
	],
	"one component per ingredient, with quantities before cooking"
);
is($input_ref->{ingredients_total_mass}, 330, "total mass of ingredients before cooking");

# Refrigerated product: fresh product distribution, refrigeration by the consumer, cooled transport
is($data_ref->{distribution}, "be66b80b-1500-4e3b-bfd2-87a89ff54031", "fresh product distribution");
is($data_ref->{consumptions}, ["b4642cec-b72e-4116-81c5-5dbfccb46055"], "refrigeration");
ok($data_ref->{transportOptions}{cooling}, "cooled transport");
is($input_ref->{distribution}, "fresh", "distribution in the input");
is($input_ref->{preparation}, ["refrigeration"], "preparation in the input");

is($product_ref->{environmental_impact}{ecs_per_product}, 330, "environmental cost for the product");
is($product_ref->{environmental_impact}{ecs_per_100g_or_100ml}, 110, "environmental cost for 100 g");

# Ambient product: dry product distribution, no consumption, no cooled transport
$product_ref->{storage_conditions} = "en:ambient";
estimate_environmental_impact_service($product_ref, {}, []);
$data_ref = $product_ref->{environmental_impact}{ecobalyse_request}{data};
is($data_ref->{distribution}, "29118025-efa0-47bb-94e2-f5ccba31a903", "dry product distribution");
is($data_ref->{consumptions}, [], "no consumption");
ok(!$data_ref->{transportOptions}{cooling}, "no cooled transport");

done_testing();
