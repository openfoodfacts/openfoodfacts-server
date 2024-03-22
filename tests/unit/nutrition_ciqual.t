use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::NutritionCiqual qw/:all/;
use ProductOpener::Test qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# this test will just load ciqual data and verify we get expected structure for some values
load_ciqual_data();

compare_to_expected_results($ciqual_data{40601}, "$expected_result_dir/40601-offal-cooked-average.json",
	$update_expected_results);
compare_to_expected_results($ciqual_data{31016}, "$expected_result_dir/31016-white-sugar.json",
	$update_expected_results);

done_testing();
