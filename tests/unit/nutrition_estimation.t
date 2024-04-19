use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Ingredients
	qw/compute_ingredients_percent_estimates compute_ingredients_percent_min_max_values delete_ingredients_percent_values parse_ingredients_text_service/;
use ProductOpener::NutritionCiqual qw/load_ciqual_data/;
use ProductOpener::NutritionEstimation qw/estimate_nutrients_from_ingredients/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

load_ciqual_data();

my @tests = (
	{
		id => '100-percent-white-sugar',
		desc => '1 ingredient with exact match in CIQUAL',
		product => {lc => "en", ingredients_text => "white sugar"},
	},
	{
		id => '100-percent-sugar',
		desc => '1 ingredient with proxy match in CIQUAL',
		product => {lc => "en", ingredients_text => "sugar"},
	},
	{
		id => '50-percent-sugar-and-unknown-ingredients',
		desc => 'unknown ingredients',
		product => {lc => "en", ingredients_text => "sugar 50%, strange ingredient, stranger ingredient"},
	},
	{
		id => 'frik',
		desc => 'ingredient in CIQUAL table but not in CALNUT extended table',
		product => {lc => "en", ingredients_text => "frik"},
	},
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->{id};
	my $product_ref = $test_ref->{product};

	parse_ingredients_text_service($product_ref, {});
	if (compute_ingredients_percent_min_max_values(100, 100, $product_ref->{ingredients}) < 0) {
		delete_ingredients_percent_values($product_ref->{ingredients});
	}

	compute_ingredients_percent_estimates(100, $product_ref->{ingredients});

	my $results_ref = {
		ingredients => $product_ref->{ingredients},
		estimated_nutrients => estimate_nutrients_from_ingredients($product_ref->{ingredients}),
	};

	compare_to_expected_results($results_ref, "$expected_result_dir/$testid.json", $update_expected_results, $test_ref);
}

done_testing();
