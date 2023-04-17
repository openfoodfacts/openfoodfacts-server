use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::NutritionCiqual qw/:all/;
use ProductOpener::Test qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

load_ciqual_data();

compare_to_expected_results($ciqual_data{40601}, "$expected_result_dir/40601.json", $update_expected_results);

done_testing();
