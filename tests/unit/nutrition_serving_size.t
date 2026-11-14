#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/%options/;
use ProductOpener::Nutrition qw/:all/;
use ProductOpener::ProductSchemaChanges qw/convert_product_schema/;
use ProductOpener::DataQualityFood;
use ProductOpener::Tags qw/init_taxonomies/;

init_taxonomies(0);
local $options{product_type} = "food";

sub powder_product {
	return {
		product_type => "food",
		serving_size => "2 tbsp (13 g)",
		serving_quantity => 13,
		serving_quantity_unit => "g",
		product_quantity => 500,
		product_quantity_unit => "g",
	};
}

sub serving_set ($preparation, $quantity = undef, $unit = undef) {
	my $set = {
		source => "packaging",
		preparation => $preparation,
		per => "serving",
		nutrients => {
			sugars => {value_string => "20", value => 20, unit => "g"},
		},
	};
	$set->{per_quantity} = $quantity if defined $quantity;
	$set->{per_unit} = $unit if defined $unit;
	return $set;
}

subtest "prepared nutrition uses its own serving size" => sub {
	my $product = powder_product();
	my $as_sold = serving_set("as_sold");
	ProductOpener::Nutrition::set_per_quantity_and_unit($product, $as_sold);
	is($as_sold->{per_quantity}, 13, "as sold still falls back to the powder serving size");
	is($as_sold->{per_unit}, "g", "as sold keeps the powder's unit");

	for my $unit ("g", "ml") {
		my $prepared = serving_set("prepared", 250, $unit);
		ProductOpener::Nutrition::set_per_quantity_and_unit($product, $prepared);
		is($prepared->{per_quantity}, 250, "the complete prepared serving quantity is preserved ($unit)");
		is($prepared->{per_unit}, $unit, "the prepared serving unit is preserved ($unit)");

		my $aggregate = generate_nutrient_aggregated_set_from_sets([$prepared]);
		is($aggregate->{per}, $unit eq "g" ? "100g" : "100ml", "the reference uses the prepared serving unit");
		is($aggregate->{nutrients}{sugars}{value}, 8, "20 g sugar in a 250-unit serving becomes 8 g per 100 units");

		$product->{data_quality_warnings_tags} = [];
		ProductOpener::DataQualityFood::check_nutrition_data_for_input_set($product, $aggregate, "nutrition",
			"data_quality_warnings_tags");
		ok(!scalar(grep {/value-over-105/} @{$product->{data_quality_warnings_tags}}),
			"no false over-105 warning is produced");
	}
};

subtest "unknown prepared quantities are not extrapolated" => sub {
	my $product = powder_product();
	for my $prepared (serving_set("prepared"), serving_set("prepared", 250), serving_set("prepared", undef, "ml")) {
		my %before = %{$prepared};
		ProductOpener::Nutrition::set_per_quantity_and_unit($product, $prepared);
		is($prepared, \%before, "an incomplete prepared serving size is not filled from the shared size");
		$product->{nutrition} = {
			input_sets => [$prepared],
			aggregated_set => {per => "100g", nutrients => {sugars => {value => 154, unit => "g"}}},
		};
		generate_nutrient_aggregated_set($product);
		ok(!exists $product->{nutrition}{aggregated_set},
			"unsupported calculated nutrition is cleared on regeneration");
		is($prepared->{nutrients}{sugars}{value}, 20, "the declared per-serving value is kept");
	}
};

subtest "legacy API edits do not replace a prepared serving size" => sub {
	my $product = powder_product();
	$product->{nutrition}{input_sets} = [serving_set("prepared", 250, "ml")];
	my $request = {
		body_json => {
			nutrition_data_per => "serving",
			nutrition_data_prepared_per => "serving",
			serving_size => "2 tbsp (13 g)",
			nutriment_sugars => "10",
			nutriment_sugars_prepared => "20",
			nutriment_sugars_unit => "g",
		}
	};
	assign_nutrition_values_from_old_request_parameters($request, $product, "off_europe", "packaging");
	my $prepared = get_specific_nutrition_input_set($product, "packaging", "prepared", "serving");
	my $as_sold = get_specific_nutrition_input_set($product, "packaging", "as_sold", "serving");
	is($prepared->{per_quantity}, 250, "legacy API keeps the existing prepared quantity");
	is($prepared->{per_unit}, "ml", "legacy API keeps the existing prepared unit");
	is($as_sold->{per_quantity}, 13, "legacy API still assigns the powder serving size to as sold");

	$request->{body_json}{serving_size} = "2 tbsp (15 g)";
	assign_nutrition_values_from_old_request_parameters($request, $product, "off_europe", "packaging");
	$as_sold = get_specific_nutrition_input_set($product, "packaging", "as_sold", "serving");
	$prepared = get_specific_nutrition_input_set($product, "packaging", "prepared", "serving");
	is($as_sold->{per_quantity}, 15, "editing the shared serving size updates as-sold nutrition");
	is($prepared->{per_quantity}, 250, "editing the shared serving size does not change prepared nutrition");
};

subtest "declared per-100g nutrition and genuine quality warnings are unchanged" => sub {
	my $product = powder_product();
	my $prepared = serving_set("prepared");
	$prepared->{per} = "100g";
	$prepared->{nutrients}{sugars}{value} = 106;
	ProductOpener::Nutrition::set_per_quantity_and_unit($product, $prepared);
	my $aggregate = generate_nutrient_aggregated_set_from_sets([$prepared]);
	is($aggregate->{nutrients}{sugars}{value}, 106, "declared per-100g values are not removed or rescaled");
	$product->{data_quality_warnings_tags} = [];
	ProductOpener::DataQualityFood::check_nutrition_data_for_input_set($product, $aggregate, "nutrition",
		"data_quality_warnings_tags");
	ok(scalar(grep {/value-over-105-sugars/} @{$product->{data_quality_warnings_tags}}),
		"a genuine over-105 warning is retained");
};

subtest "legacy migration does not guess a prepared serving size" => sub {
	my $product = powder_product();
	$product->{schema_version} = 1002;
	$product->{nutrition_data} = "on";
	$product->{nutrition_data_per} = "serving";
	$product->{nutrition_data_prepared} = "on";
	$product->{nutrition_data_prepared_per} = "serving";
	$product->{nutriments} = {
		sugars_serving => 10,
		sugars_unit => "g",
		sugars_prepared_serving => 20,
		sugars_prepared_unit => "g",
	};
	convert_product_schema($product, 1003);
	my $prepared = get_specific_nutrition_input_set($product, "packaging", "prepared", "serving");
	my $as_sold = get_specific_nutrition_input_set($product, "packaging", "as_sold", "serving");
	is($prepared->{per_quantity}, undef, "the old shared quantity is not copied to prepared nutrition");
	is($prepared->{per_unit}, undef, "the old powder/package unit is not assumed for the prepared drink");
	is($prepared->{nutrients}{sugars}{value}, 20, "the prepared nutrition value is retained");
	is($as_sold->{per_quantity}, 13, "the as-sold serving quantity is still migrated");
	is($product->{nutrition}{aggregated_set}{preparation}, "as_sold", "only the known serving can be normalized");
};

done_testing();
