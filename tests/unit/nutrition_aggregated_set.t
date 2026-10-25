#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Config qw/%options/;
use ProductOpener::Nutrition qw/:all/;
use ProductOpener::Food qw/check_availability_of_nutrients_needed_for_nutriscore/;

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

# GitHub issue #14505: Nutri-Score is not calculated when packaging provides only energy-kcal
# and an estimated nutrient set provides energy-kj
{
	# Case 1: Packaging contains energy-kcal = 450, no energy-kj.
	# Estimated nutrient set provides energy-kj = 1286.29.
	# Aggregation must preserve packaging energy and reject lower-priority estimated energy-kj.
	my $inputs = [
		{
			source => 'packaging',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kcal' => {value => 450, unit => 'kcal'},
				'fat' => {value => 17, unit => 'g'},
				'saturated-fat' => {value => 11, unit => 'g'},
				'sugars' => {value => 23, unit => 'g'},
				'proteins' => {value => 10, unit => 'g'},
				'sodium' => {value => 0.075, unit => 'g'},
			}
		},
		{
			source => 'estimate',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kj' => {value => 1286.29, unit => 'kJ'},
				'fat' => {value => 15, unit => 'g'},
				'sugars' => {value => 20, unit => 'g'},
			}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);

	# Energy is derived from packaging energy-kcal (int(450 * 4.184) = 1882 kJ)
	is($aggregate->{nutrients}{energy}{value}, 1882, 'energy value derived from packaging energy-kcal');
	is($aggregate->{nutrients}{energy}{unit}, 'kJ', 'energy unit is kJ');
	is($aggregate->{nutrients}{energy}{source}, 'packaging', 'energy source is packaging');
	is($aggregate->{nutrients}{'energy-kcal'}{value}, 450, 'energy-kcal preserved from packaging');
	is($aggregate->{nutrients}{'energy-kcal'}{source}, 'packaging', 'energy-kcal source is packaging');

	# Estimated energy-kj must NOT enter aggregated set when higher-priority energy exists
	ok(!exists $aggregate->{nutrients}{'energy-kj'}, 'lower-priority estimated energy-kj excluded from aggregate');

	# Nutri-Score availability check must succeed without mixed-sources rejection
	my $product_ref = {
		categories_tags => ['en:breakfast-cereals'],
		nutrition_score_debug => '',
		nutrition => {
			aggregated_set => $aggregate,
		},
	};
	my ($nutrients_available, $preparation, $estimated) = check_availability_of_nutrients_needed_for_nutriscore($product_ref);
	is($nutrients_available, 1, 'nutrients_available is 1 for Nutri-Score');
	is($estimated, 0, 'nutrients are not flagged as estimated');
	ok(!defined $product_ref->{nutrition_grades_tags} || $product_ref->{nutrition_grades_tags}[0] ne 'unknown',
		'nutrition_grades_tags is not set to unknown');
}

# Neighbouring Test 1: Existing valid packaging energy-kj remains correct when estimate exists
{
	my $inputs = [
		{
			source => 'packaging',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kj' => {value => 1883, unit => 'kJ'},
				'energy-kcal' => {value => 450, unit => 'kcal'},
			}
		},
		{
			source => 'estimate',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kj' => {value => 1200, unit => 'kJ'},
			}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{nutrients}{'energy-kj'}{value}, 1883, 'packaging energy-kj value preserved');
	is($aggregate->{nutrients}{'energy-kj'}{source}, 'packaging', 'packaging energy-kj source preserved');
	is($aggregate->{nutrients}{'energy-kcal'}{value}, 450, 'packaging energy-kcal value preserved');
	is($aggregate->{nutrients}{'energy-kcal'}{source}, 'packaging', 'packaging energy-kcal source preserved');
	is($aggregate->{nutrients}{energy}{value}, 1883, 'energy equals packaging energy-kj');
	is($aggregate->{nutrients}{energy}{source}, 'packaging', 'energy source is packaging');
}

# Neighbouring Test 2: kcal-only packaging data handled correctly with no lower-priority sets
{
	my $inputs = [
		{
			source => 'packaging',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kcal' => {value => 450, unit => 'kcal'},
			}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{nutrients}{'energy-kcal'}{value}, 450, 'energy-kcal preserved');
	is($aggregate->{nutrients}{'energy-kcal'}{source}, 'packaging', 'energy-kcal source is packaging');
	is($aggregate->{nutrients}{energy}{value}, 1882, 'energy derived in kJ');
	is($aggregate->{nutrients}{energy}{unit}, 'kJ', 'energy unit is kJ');
	is($aggregate->{nutrients}{energy}{source}, 'packaging', 'energy source is packaging');
	ok(!exists $aggregate->{nutrients}{'energy-kj'}, 'energy-kj does not exist in aggregate');
}

# Neighbouring Test 3: Estimated energy remains usable when no higher-priority energy information exists
{
	my $inputs = [
		{
			source => 'packaging',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'proteins' => {value => 10, unit => 'g'},
			}
		},
		{
			source => 'estimate',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kj' => {value => 1286.29, unit => 'kJ'},
			}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{nutrients}{'energy-kj'}{value}, 1286.29, 'estimated energy-kj populated when no higher-priority energy exists');
	is($aggregate->{nutrients}{'energy-kj'}{source}, 'estimate', 'energy-kj source is estimate');
	is($aggregate->{nutrients}{energy}{value}, 1286.29, 'energy populated from estimate');
	is($aggregate->{nutrients}{energy}{source}, 'estimate', 'energy source is estimate');
	is($aggregate->{nutrients}{proteins}{source}, 'packaging', 'proteins source preserved from packaging');
}

# Neighbouring Test 4: Existing source-priority behaviour is preserved (manufacturer vs packaging)
{
	my $inputs = [
		{
			source => 'manufacturer',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kcal' => {value => 200, unit => 'kcal'},
			}
		},
		{
			source => 'packaging',
			preparation => 'as_sold',
			per => '100g',
			per_quantity => 100,
			per_unit => 'g',
			nutrients => {
				'energy-kj' => {value => 1000, unit => 'kJ'},
			}
		}
	];
	my $aggregate = generate_nutrient_aggregated_set_from_sets($inputs);
	is($aggregate->{nutrients}{'energy-kcal'}{value}, 200, 'manufacturer energy-kcal preserved');
	is($aggregate->{nutrients}{'energy-kcal'}{source}, 'manufacturer', 'energy-kcal source is manufacturer');
	is($aggregate->{nutrients}{energy}{value}, 836, 'energy derived from manufacturer energy-kcal');
	is($aggregate->{nutrients}{energy}{source}, 'manufacturer', 'energy source is manufacturer');
	ok(!exists $aggregate->{nutrients}{'energy-kj'}, 'lower-priority packaging energy-kj excluded when manufacturer energy exists');
}

done_testing();
