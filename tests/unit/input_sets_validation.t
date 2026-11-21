#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Nutrition qw/:all/;
use ProductOpener::Display qw/data_to_display_nutrition_table/;
use ProductOpener::KnowledgePanels qw/create_panel_from_json_template/;
use ProductOpener::Lang qw/$lc/;

$lc = 'en';

# The source and the per of the input sets are used in field names and in the names
# displayed to everyone: the API only accepts letters, digits, _ and -
{
	my $product_ref = {product_type => 'food'};
	my $request_ref = {
		body_json => {
			product => {
				nutrition => {
					input_sets => [
						{
							source => 'my"source',
							preparation => 'as_sold',
							per => '100g',
							nutrients => {fat => {value_string => '3', unit => 'g'}}
						},
						{
							source => 'packaging',
							preparation => 'as_sold',
							per => '100g"x',
							nutrients => {fat => {value_string => '3', unit => 'g'}}
						},
						{
							source => 'manufacturer',
							preparation => 'as_sold',
							per => '100g',
							nutrients => {fat => {value_string => '3', unit => 'g'}}
						}
					]
				}
			}
		},
		api_response => {}
	};
	assign_nutrition_values_from_request_object($request_ref, $product_ref);
	is(
		$product_ref->{nutrition}{input_sets},
		[
			{
				source => 'manufacturer',
				preparation => 'as_sold',
				per => '100g',
				per_quantity => 100,
				per_unit => 'g',
				nutrients => {fat => {value => 3, value_string => '3', unit => 'g'}}
			}
		],
		'API v3 ignores an input set with an invalid source or per'
	);
	is(
		[map {$_->{message}{id}} @{$request_ref->{api_response}{errors}}],
		['unrecognized_value', 'unrecognized_value'],
		'API v3 reports the invalid source and per'
	);
}

# The names of the input sets are entered through the API and must not break the display
{
	my $product_ref = {
		product_type => 'food',
		nutrition => {
			input_sets => [
				{
					source => 'my"source<b>\\',
					preparation => 'as_sold',
					per => '100g',
					per_quantity => 100,
					per_unit => 'g',
					nutrients => {fat => {value => 3, value_string => '3', unit => 'g'}}
				}
			]
		}
	};
	my $table_data_ref = data_to_display_nutrition_table($product_ref, undef, {lc => 'en', cc => 'world'}, 1);
	my ($column) = grep {($_->{name} // '') =~ /my_source_b__/} @{$table_data_ref->{nutrition_table}{header}{columns}};
	ok($column, 'display the input set column');
	unlike($column->{name}, qr/["<>\\]/, 'only keep safe characters in the name of a column');
	create_panel_from_json_template('nutrition_facts_table',
		'api/knowledge-panels/health/nutrition/nutrition_facts_table.tt.json',
		$table_data_ref, $product_ref, 'en', 'world', {}, {lc => 'en', cc => 'world'});
	my $panel = $product_ref->{knowledge_panels_en}{nutrition_facts_table};
	ok(!exists $panel->{json_error}, 'a source with quotes does not break the nutrition panel');
}

done_testing();
