#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use Clone qw/clone/;
use ProductOpener::Nutrition qw/:all/;
use ProductOpener::Display qw/data_to_display_nutrition_table process_template/;
use ProductOpener::KnowledgePanels qw/create_panel_from_json_template/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::FoodProducts;

$lc = 'en';

sub carbon_set ($per, $value, $unit, $source = 'packaging') {
	my $set_ref = {
		source => $source,
		preparation => 'as_sold',
		per => $per,
		per_quantity => $per eq '1kg' ? 1000 : 100,
		per_unit => 'g',
		nutrients => {'carbon-footprint' => {value => $value, value_string => "$value", unit => $unit}},
	};
	return $set_ref;
}

# Nutrition facts of an oat drink: per 100ml
sub drink_set ($nutrients = {fat => {value => 2.8, value_string => '2.8', unit => 'g'}}, $source = 'packaging') {
	return {
		source => $source,
		preparation => 'as_sold',
		per => '100ml',
		per_quantity => 100,
		per_unit => 'ml',
		nutrients => $nutrients,
	};
}

sub product_with_sets ($inputs) {
	return {
		product_type => 'food',
		nutrition => {input_sets => $inputs, aggregated_set => generate_nutrient_aggregated_set_from_sets($inputs)}
	};
}

for my $case (['1kg', 0.48, 'kg', 48], ['100g', 0.31, 'kg', 310], ['1kg', 480, 'g', 48]) {
	my ($per, $value, $unit, $expected) = @$case;
	my $set_ref = carbon_set($per, $value, $unit);
	my $original = clone($set_ref);
	my $aggregate = generate_nutrient_aggregated_set_from_sets([$set_ref]);
	is($aggregate->{per}, '100g', "$value $unit per $per: normalize to a mass reference");
	is($aggregate->{nutrients}{'carbon-footprint'}{value}, $expected, "$value $unit per $per: correct emissions");
	is($set_ref, $original, 'keep the original declaration and unit');
}

for my $unit ('mg') {
	my $sets = {};
	assign_nutrient_modifier_value_string_and_unit($sets, 'packaging', 'as_sold', '100g',
		'carbon-footprint', undef, '12', $unit);
	is($sets->{packaging}{as_sold}{'100g'}{nutrients}{'carbon-footprint'}{value},
		12, "continue accepting carbon footprint in $unit");
}

# Only the carbon footprint of a food can be declared per kg
is([get_pers_for_nutrient('food', 'carbon-footprint')], [qw/100g 100ml 1l 1kg serving/], 'food footprint: per 1kg');
is([get_pers_for_nutrient('food', 'fat')], [qw/100g 100ml 1l serving/], 'other food nutrients: no per 1kg');
is([get_pers_for_nutrient('petfood', 'crude-fat')], ['1kg'], 'pet food nutrients stay per 1kg');

# The web/API v2 parameters must accept a declaration per kilogram for the footprint of a food,
# but not for its other nutrients
my $product_ref = {product_type => 'food'};
assign_nutrition_values_from_request_parameters(
	{
		body_json => {
			'nutrition_input_sets_as_sold_1kg_nutrients_carbon-footprint_value_string' => '0.48',
			'nutrition_input_sets_as_sold_1kg_nutrients_carbon-footprint_unit' => 'kg',
			'nutrition_input_sets_as_sold_1kg_nutrients_fat_value_string' => '5',
			'nutrition_input_sets_as_sold_1kg_nutrients_fat_unit' => 'g',
		}
	},
	$product_ref,
	'off_europe',
	'packaging'
);
is(
	$product_ref->{nutrition}{input_sets},
	[carbon_set('1kg', 0.48, 'kg')],
	'web/API v2 records 0.48 kg CO2e per kg of food, and ignores the other nutrients per kg'
);

my $api_product = {product_type => 'food'};
assign_nutrition_values_from_request_object(
	{
		body_json => {
			product => {
				nutrition => {
					input_sets => [
						{
							source => 'packaging',
							preparation => 'as_sold',
							per => '1kg',
							nutrients => {'carbon-footprint' => {value_string => '0.48', unit => 'kg'}}
						}
					]
				}
			}
		},
		api_response => {}
	},
	$api_product
);
is(
	$api_product->{nutrition}{input_sets},
	[carbon_set('1kg', 0.48, 'kg')],
	'API v3 preserves the separate mass reference'
);
is(get_non_estimated_nutrient_per_100g_or_100ml_for_preparation($api_product, 'as_sold', 'carbon-footprint'),
	48, 'the normalized nutrient getter also converts a kilogram reference');

# The getter returns a value declared per kg per 100g.
# Values declared per serving or per 1l are returned as declared: converting them would change
# the values estimated from the ingredients (e.g. added-sugars), which is out of scope here.
for my $case (
	['1kg', 1000, 'g', 120, 12],
	['1kg', 0, 'g', 120, 12],    # the quantity of a per 1kg set is always set to 1000 g
	['serving', 30, 'g', 3.6, 3.6],
	['1l', 1, 'l', 120, 120],
	)
{
	my ($per, $quantity, $unit, $value, $expected) = @$case;
	my $set_ref = {
		source => 'packaging',
		preparation => 'as_sold',
		per => $per,
		per_quantity => $quantity,
		per_unit => $unit,
		nutrients => {sugars => {value => $value, unit => 'g'}}
	};
	is(
		get_non_estimated_nutrient_per_100g_or_100ml_for_preparation(
			{nutrition => {input_sets => [$set_ref]}},
			'as_sold', 'sugars'
		),
		$expected,
		"the getter returns $value g per $quantity $unit as $expected"
	);
}

# A product whose nutrition facts are declared per serving keeps the values estimated from its ingredients
{
	my $product = {
		product_type => 'food',
		nutrition => {
			input_sets => [
				{
					source => 'packaging',
					preparation => 'as_sold',
					per => 'serving',
					per_quantity => 240,
					per_unit => 'ml',
					nutrients => {sugars => {value => 12, unit => 'g'}}
				}
			]
		}
	};
	is(get_non_estimated_nutrient_per_100g_or_100ml_for_preparation($product, 'as_sold', 'sugars'),
		12, 'a declared per serving value is not converted');
}

my $csv_product = {product_type => 'food'};
assign_nutrition_values_from_imported_csv_product(
	{
		'nutrition.input_sets.packaging.as_sold.1kg.nutrients.carbon-footprint.value_string' => '0.48',
		'nutrition.input_sets.packaging.as_sold.1kg.nutrients.carbon-footprint.unit' => 'kg',
		'nutrition.input_sets.packaging.as_sold.1kg.nutrients.fat.value_string' => '5',
		'nutrition.input_sets.packaging.as_sold.1kg.nutrients.fat.unit' => 'g',
	},
	$csv_product
);
is(
	$csv_product->{nutrition}{input_sets},
	[carbon_set('1kg', 0.48, 'kg')],
	'CSV imports preserve the separate mass reference, and ignore the other nutrients per kg'
);

# Labels of the units of the carbon footprint
is(
	[map {$_->{label}} @{get_unit_options_for_nutrient('carbon-footprint')}],
	['kg CO₂e', 'g CO₂e', 'mg CO₂e'],
	'qualify the units of the footprint'
);
is([map {$_->{label}} @{get_unit_options_for_nutrient('fat')}], ['g', 'mg', 'mcg/µg'], 'other nutrients: unchanged');

# Render the real edit template: users can copy the package declaration directly.
{
	my %input_values = map {$_ => {value_string => '', unit => 'g'}} qw/100g 100ml 1l serving/;
	my $footprint_input_values = {%input_values, '1kg' => {value_string => '0.48', unit => 'kg'}};
	my $html = '';
	ok(
		process_template(
			'web/pages/product_edit/product_edit_form_display.tt.html',
			{
				errors_index => -1,
				nutrition_feature_enabled => 1,
				product_type => 'food',
				preparations => ['as_sold'],
				pers => [get_pers_for_product_type('food')],
				input_sets => {as_sold => {'1kg' => {shown => 1}, '100ml' => {shown => 1}}},
				nutrients => [
					{
						nid => 'fat',
						shown => 1,
						name => 'Fat',
						unit => 'g',
						units_options => get_unit_options_for_nutrient('fat'),
						input_sets => {as_sold => \%input_values}
					},
					{
						nid => 'carbon-footprint',
						shown => 1,
						name => 'Carbon footprint',
						# no global unit: the unit of each input set is chosen separately
						units_options => get_unit_options_for_nutrient('carbon-footprint'),
						input_sets => {as_sold => $footprint_input_values}
					}
				],
			},
			\$html,
			{lc => 'en'}
		),
		'render the product edit form'
	);
	like(
		$html,
		qr/id="nutrition_input_sets_as_sold_1kg_shown"[^>]*checked="checked"/,
		'show the kilogram reference containing the footprint'
	);
	like(
		$html,
		qr/name="nutrition_input_sets_as_sold_1kg_nutrients_carbon-footprint_value_string" value="0.48"/,
		'keep the package value in an editable field per kilogram'
	);
	like(
		$html,
		qr/name="nutrition_input_sets_as_sold_1kg_nutrients_carbon-footprint_unit">\s*<option value="kg" selected="selected" >kg CO₂e<\/option>/,
		'choose the unit of the footprint per kilogram, as kg CO2e'
	);
	like(
		$html,
		qr/name="nutrition_input_sets_as_sold_100g_nutrients_carbon-footprint_unit">\s*<option value="kg"\s*>kg CO₂e<\/option>\s*<option value="g" selected="selected" >g CO₂e<\/option>/,
		'keep the unit of the footprint per 100g separate'
	);
	unlike($html, qr/<option value="kg\/kg"/, 'do not offer a ratio among mass units');
	unlike($html, qr/mcg\/µg CO₂e/, 'do not offer the mcg alias for emissions');
	like($html, qr/nutrition_input_sets_as_sold_100g_nutrients_fat_value_string/, 'other nutrients: per 100g');
	unlike($html, qr/nutrition_input_sets_as_sold_1kg_nutrients_fat/, 'other nutrients: no input per 1kg');
	unlike($html, qr/id="global_nutrient_carbon-footprint_unit"/, 'no global unit for the footprint');
}

# Oatly has nutrition per volume and emissions per mass. No density is available.
for my $source ('packaging', 'manufacturer') {
	my $inputs = [carbon_set('1kg', 0.48, 'kg', $source), drink_set()];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{per}, '100ml', "$source footprint must not change the nutrition reference");
	is($aggregate->{nutrients}{fat}{value}, 2.8, 'keep nutrition per 100ml');
	ok(!exists $aggregate->{nutrients}{'carbon-footprint'}, 'never convert emissions per kg to emissions per volume');
	my $product = product_with_sets($inputs);
	my $table = data_to_display_nutrition_table($product, undef, {lc => 'en', cc => 'world'})->{nutrition_table};
	my ($column) = grep {$_->{per} eq '1kg'} @{$table->{header}{columns}};
	ok($column, 'show the original mass reference on the product page');
	my ($row) = grep {$_->{nid} eq 'carbon-footprint'} @{$table->{rows}};
	ok($row, 'show the footprint even when it cannot join the volume aggregate');

	if ($row) {
		is($row->{columns}[-1]{value}, '0.48 kg CO₂e', 'display the original footprint with its CO2e qualifier');
		is($row->{columns}[-1]{rdfa}, '', 'never mark a value per kg as RDFa per 100g');
	}

	my $request_ref = {lc => 'en', cc => 'world'};
	create_panel_from_json_template(
		'nutrition_facts_table',
		'api/knowledge-panels/health/nutrition/nutrition_facts_table.tt.json',
		{nutrition_table => $table},
		$product, 'en', 'world', {}, $request_ref
	);
	my $panel = $product->{knowledge_panels_en}{nutrition_facts_table};
	ok(!exists $panel->{json_error} && !exists $panel->{template_error}, 'render the actual nutrition knowledge panel');
	my $columns = $panel->{elements}[0]{table_element}{columns};
	ok($columns->[-1]{shown_by_default}, 'the original mass footprint is visible by default');

	ProductOpener::FoodProducts::add_labels_from_nutrition_data($product);
	ok(
		(grep {$_ eq 'en:carbon-footprint'} @{$product->{labels_tags} // []}),
		'keep the carbon footprint label for a declaration outside the aggregate'
	);
}

# The footprint per volume and the footprint per kg do not use the same declarations
{
	my $product = product_with_sets([carbon_set('100g', 31, 'g'), drink_set()]);
	is($product->{nutrition}{aggregated_set}{per}, '100ml', 'nutrition per 100ml');
	is($product->{nutrition}{aggregated_set}{nutrients}{'carbon-footprint'}{value},
		31, 'a footprint per 100g is merged with nutrition per 100ml, like all the other nutrients');
}

# An estimated footprint per volume must not hide the declared footprint per kg.
{
	my $inputs = [
		carbon_set('1kg', 0.48, 'kg', 'manufacturer'),
		drink_set({fat => {value => 2.8, unit => 'g'}}),
		drink_set({'carbon-footprint' => {value => 20, unit => 'g'}}, 'estimate'),
	];
	my $product = product_with_sets($inputs);
	my $table = data_to_display_nutrition_table($product, undef, {lc => 'en', cc => 'world'})->{nutrition_table};
	my ($row) = grep {$_->{nid} eq 'carbon-footprint'} @{$table->{rows}};
	ok($row, 'an estimated footprint cannot hide the declared footprint');
	is($row->{columns}[-1]{value}, '0.48 kg CO₂e', 'display the declared mass footprint alongside a volume estimate')
		if $row;
}

# A compatible declaration can still be used when a preferred source is per mass.
{
	my $inputs = [
		carbon_set('1kg', 0.48, 'kg', 'manufacturer'),
		drink_set({fat => {value => 2.8, unit => 'g'}, 'carbon-footprint' => {value => 50, unit => 'g'}})
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{nutrients}{'carbon-footprint'}{value}, 50, 'use compatible emissions per 100ml');
	is($aggregate->{nutrients}{'carbon-footprint'}{source},
		'packaging', 'skip an incompatible source before selecting a value');
}

# The estimate of the nutrition facts does not choose the reference of a footprint alone
{
	my $inputs = [
		drink_set({'carbon-footprint' => {value => 20, unit => 'g'}}),
		{
			source => 'estimate',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {sugars => {value => 5, unit => 'g'}}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{per}, '100ml', 'the footprint keeps its reference when it is the only declared nutrient');
	is($aggregate->{nutrients}{'carbon-footprint'}{value}, 20, 'keep the footprint per 100ml');
}

# The footprint is displayed only if the nutrient table of the country has a row for it
{
	local $ProductOpener::Display::nutrient_table = 'off_hk';
	my $product = product_with_sets([carbon_set('1kg', 0.48, 'kg'), drink_set()]);
	my $table = data_to_display_nutrition_table($product, undef, {lc => 'en', cc => 'hk'})->{nutrition_table};
	ok(!(grep {$_->{per} && $_->{per} eq '1kg'} @{$table->{header}{columns}}), 'no extra column without a row');
}

# A footprint that cannot be aggregated does not change the product
{
	my $serving_set = carbon_set('serving', 12, 'g');
	$serving_set->{per_quantity} = undef;
	my $product = {product_type => 'food', nutrition => {input_sets => [$serving_set]}};
	my $warnings = warnings {data_to_display_nutrition_table($product, undef, {lc => 'en', cc => 'world'})};
	is($warnings, [], 'no warning without aggregated set');
	ok(!exists $product->{nutrition}{aggregated_set}, 'do not create an aggregated set');
}

# The label is only added when the footprint can be displayed
{
	my $product = product_with_sets(
		[
			carbon_set('1kg', 0.48, 'kg'),
			{
				source => 'packaging',
				preparation => 'prepared',
				per => '100g',
				per_quantity => 100,
				per_unit => 'g',
				nutrients => {fat => {value => 2.8, unit => 'g'}}
			}
		]
	);
	is($product->{nutrition}{aggregated_set}{preparation}, 'prepared', 'prepared nutrition facts come first');
	ProductOpener::FoodProducts::add_labels_from_nutrition_data($product);
	ok(!(grep {$_ eq 'en:carbon-footprint'} @{$product->{labels_tags} // []}),
		'no label for a footprint that is not displayed');
	my $table = data_to_display_nutrition_table($product, undef, {lc => 'en', cc => 'world'})->{nutrition_table};
	ok(!(grep {$_->{nid} eq 'carbon-footprint'} @{$table->{rows}}), 'no row for a footprint that is not displayed');
	# the input sets are sorted: the prepared nutrition facts come first
	is(get_declared_carbon_footprint_input_set_index($product, 'as_sold'), 1, 'find the footprint as sold');
	is(get_declared_carbon_footprint_input_set_index($product, 'prepared'), undef, 'no footprint when prepared');
}

# An actual mass serving still produces the same normalized footprint.
for my $quantity (50, 200) {
	my $inputs = [
		carbon_set('1kg', 0.48, 'kg'),
		{
			source => 'manufacturer',
			preparation => 'as_sold',
			per => 'serving',
			per_quantity => $quantity,
			per_unit => 'g',
			nutrients => {fat => {value => 1, unit => 'g'}}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{nutrients}{'carbon-footprint'}{value},
		48, "a $quantity g serving does not change emissions per 100g");
}

done_testing();
