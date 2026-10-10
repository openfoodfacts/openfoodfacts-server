#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Config qw/%options/;
use ProductOpener::Nutrition qw/:all/;

# Concentrations and dimensionless values do not change with the quantity of product
for my $unit ('%', '% vol', '', 'mmol/l') {
	for my $per_case (['1kg', 1000, 'g', '100g'], ['serving', 30, 'g', '100g'], ['1l', 1000, 'ml', '100ml']) {
		my ($per, $quantity, $per_unit, $wanted_per) = @$per_case;
		my $nutrient = {value => 30, unit => $unit};
		ProductOpener::Nutrition::convert_nutrient_to_100g($nutrient, $per, $quantity, $per_unit, $wanted_per);
		is($nutrient->{value}, 30, "a '$unit' value stays constant when changing from per $per to $wanted_per");
	}
}
{
	my $nutrient = {value => 3, unit => 'g'};
	ProductOpener::Nutrition::convert_nutrient_to_100g($nutrient, 'serving', 30, 'g', '100g');
	is($nutrient->{value}, 10, 'a mass is scaled to the wanted reference');
}

# Pet food is aggregated per 1kg: a value declared per 100g is multiplied by 10
{
	local $options{product_type} = 'petfood';
	my $inputs = [
		{
			source => 'packaging',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'calcium' => {value => 0.5, unit => 'g'},
				'energy-kcal' => {value => 380, unit => 'kcal'},
				'crude-protein' => {value => 25, unit => '%'},
			}
		},
		{
			source => 'manufacturer',
			preparation => 'as_sold',
			per => 'serving',
			per_quantity => 30,
			per_unit => 'g',
			nutrients => {'crude-ash' => {value => 6, unit => '%'}}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{per}, '1kg', 'pet food aggregated set per 1kg');
	is($aggregate->{nutrients}{calcium}{value}, 5, 'a mass per 100g is multiplied by 10 for a kilogram');
	is($aggregate->{nutrients}{'energy-kcal'}{value}, 3800, 'an energy per 100g is multiplied by 10 for a kilogram');
	is($aggregate->{nutrients}{'crude-protein'}{value}, 25, 'a percentage per 100g does not change');
	is($aggregate->{nutrients}{'crude-ash'}{value}, 6, 'a percentage per serving does not change');
}

done_testing();
