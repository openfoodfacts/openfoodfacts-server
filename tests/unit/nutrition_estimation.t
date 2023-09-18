use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Ingredients qw/:all/;
use ProductOpener::NutritionCiqual qw/:all/;
use ProductOpener::NutritionEstimation qw/:all/;
use ProductOpener::Test qw/:all/;

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

	print STDERR "ingredients_text: " . $product_ref->{ingredients_text} . " (" . $product_ref->{lc} . ")\n";

	parse_ingredients_text($product_ref);
	if (compute_ingredients_percent_values(100, 100, $product_ref->{ingredients}) < 0) {
		print STDERR "compute_ingredients_percent_values < 0, delete ingredients percent values\n";
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
