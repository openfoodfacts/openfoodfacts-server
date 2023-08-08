#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::PackagingStats qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::API qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my $packagings_materials_stats_ref = {};

# Add 1 product with 100% glass

add_product_materials_to_stats(
	"test",
	$packagings_materials_stats_ref,
	{
		code => 12345678901,
		countries_tags => ["en:world"],
		categories_tags => ["all"],
		packagings_materials => {
			'all' => {
				'weight' => 500,
				'weight_100g' => 1000,
				'weight_percent' => 100
			},
			'en:glass' => {
				'weight' => 500,
				'weight_100g' => 1000,
				'weight_percent' => 100
			}
		},
		packagings_materials_main => "en:glass",
	}
);

compare_to_expected_results(
	$packagings_materials_stats_ref,
	"$expected_result_dir/add_product_materials_to_stats_1_glass.json",
	$update_expected_results
);

# Add 1 product with 100% plastic

add_product_materials_to_stats(
	"test",
	$packagings_materials_stats_ref,
	{
		code => 12345678902,
		countries_tags => ["en:world"],
		categories_tags => ["all"],
		packagings_materials => {
			'all' => {
				'weight' => 50,
				'weight_100g' => 200,
				'weight_percent' => 100
			},
			'en:plastic' => {
				'weight' => 40,
				'weight_100g' => 160,
				'weight_percent' => 80
			},
			'en:glass' => {
				'weight' => 10,
				'weight_100g' => 40,
				'weight_percent' => 20
			},
		},
		packagings_materials_main => "en:plastic",
	}
);

compare_to_expected_results(
	$packagings_materials_stats_ref,
	"$expected_result_dir/add_product_materials_to_stats_1_glass_1_plastic.json",
	$update_expected_results
);

compute_stats_for_all_materials($packagings_materials_stats_ref, 0);    # 0 = keep individual values to ease debugging

compare_to_expected_results(
	$packagings_materials_stats_ref,
	"$expected_result_dir/compute_stats_for_all_materials_1_glass_1_plastic.json",
	$update_expected_results
);

done_testing();
