#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;

use ProductOpener::DataQuality qw/check_quality/;
use ProductOpener::DataQualityFood qw/:all/;
use ProductOpener::Tags qw/has_tag/;
use ProductOpener::Ingredients qw/extract_ingredients_from_text/;

sub check_quality_and_test_product_has_quality_tag($$$$) {
	my $product_ref = shift;
	my $tag = shift;
	my $reason = shift;
	my $yesno = shift;
	ProductOpener::DataQuality::check_quality($product_ref);
	if ($yesno) {
		ok(has_tag($product_ref, 'data_quality', $tag), $reason)
			or diag Dumper {tag => $tag, yesno => $yesno, product => $product_ref};
	}
	else {
		ok(!has_tag($product_ref, 'data_quality', $tag), $reason)
			or diag Dumper {tag => $tag, yesno => $yesno, product => $product_ref};
	}

	return;
}

sub product_with_energy_has_quality_tag($$$) {
	my $energy = shift;
	my $reason = shift;
	my $yesno = shift;

	my $product_ref = {
		lc => "de",
		nutriments => {
			energy_100g => $energy
		}
	};

	check_quality_and_test_product_has_quality_tag($product_ref, 'en:nutrition-value-over-3800-energy', $reason,
		$yesno);

	return;
}

# en:nutrition-value-over-3800-energy - does not add tag, if there is no nutriments.
my $product_ref_without_nutriments = {lc => "de"};
check_quality_and_test_product_has_quality_tag(
	$product_ref_without_nutriments,
	'en:nutrition-value-over-3800-energy',
	'product does not have en:nutrition-value-over-3800-energy tag as it has no nutrients', 0
);

# en:nutrition-value-over-3800-energy - does not add tag, if there is no energy.
my $product_ref_without_energy_value = {
	lc => "de",
	nutriments => {}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref_without_energy_value,
	'en:nutrition-value-over-3800-energy',
	'product does not have en:nutrition-value-over-3800-energy tag as it has no energy_value', 0
);

# en:nutrition-value-over-3800-energy - does not add tag, if energy_value is below 3800 - 3799
product_with_energy_has_quality_tag(3799,
	'product does not have en:nutrition-value-over-3800-energy tag as it has an energy_value below 3800: 3799', 0);

# en:nutrition-value-over-3800-energy - does not add tag, if energy_value is below 3800 - 40
product_with_energy_has_quality_tag(40,
	'product does not have en:nutrition-value-over-3800-energy tag as it has an energy_value below 3800: 40', 0);

# en:nutrition-value-over-3800-energy - does not add tag, if energy_value is equal 3800
product_with_energy_has_quality_tag(3800,
	'product does not have en:nutrition-value-over-3800-energy tag as it has an energy_value of 3800: 3800', 0);

# en:nutrition-value-over-3800-energy - does add tag, if energy_value is above 3800
product_with_energy_has_quality_tag(3801,
	'product does have en:nutrition-value-over-3800-energy tag as it has an energy_value of 3800: 3801', 1);

# ingredients-de-over-30-percent-digits - with more than 30%
my $over_30 = '(52,3 0) 0,2 (J 23 (J 2,3 g 0,15 g';
my $at_30 = '123abcdefg';
my $product_ref = {
	lc => 'de',
	languages_codes => {
		de => 1
	},
	ingredients_text_de => $over_30
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag($product_ref, 'data_quality', 'en:ingredients-de-over-30-percent-digits'),
	'product with more than 30% digits in the language-specific ingredients has tag ingredients-over-30-percent-digits'
) or diag Dumper $product_ref;

# ingredients-de-over-30-percent-digits - with exactly 30%
$product_ref = {
	lc => 'de',
	languages_codes => {
		de => 1
	},
	ingredients_text_de => $at_30
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:ingredients-de-over-30-percent-digits'),
	'product with at most 30% digits in the language-specific ingredients has no ingredients-over-30-percent-digits tag'
) or diag Dumper $product_ref;

# ingredients-de-over-30-percent-digits - without a text
$product_ref = {
	lc => 'de',
	languages_codes => {
		de => 1
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:ingredients-de-over-30-percent-digits'),
	'product with no language-specific ingredients text has no ingredients-over-30-percent-digits tag'
) or diag Dumper $product_ref;

# ingredients-over-30-percent-digits - with more than 30%
$product_ref = {
	lc => 'de',
	ingredients_text => $over_30
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag($product_ref, 'data_quality', 'en:ingredients-over-30-percent-digits'),
	'product with more than 30% digits in the ingredients has tag ingredients-over-30-percent-digits'
) or diag Dumper $product_ref;

# ingredients-over-30-percent-digits - with exactly 30%
$product_ref = {
	lc => 'de',
	ingredients_text => $at_30
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:ingredients-over-30-percent-digits'),
	'product with at most 30% digits in the ingredients has no ingredients-over-30-percent-digits tag'
) or diag Dumper $product_ref;

# ingredients-over-30-percent-digits - without a text
$product_ref = {lc => 'de'};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:ingredients-over-30-percent-digits'),
	'product with no ingredients text has no ingredients-over-30-percent-digits tag'
) or diag Dumper $product_ref;

# issue 1466: Add quality facet for dehydrated products that are missing prepared values

$product_ref = {categories_tags => undef};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'product without dried category with no other qualities is not flagged for issue 1466'
) or diag Dumper $product_ref;

$product_ref = {categories_tags => ['en:dried-products-to-be-rehydrated']};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with no other qualities is flagged for issue 1466'
) or diag Dumper $product_ref;

# positive control 1
$product_ref = {
	categories_tags => ['en:dried-products-to-be-rehydrated'],
	nutrition_data_prepared => 'on',
	nutriments => {
		energy_prepared_100g => 5
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with prepared data is not flagged for issue 1466'
) or diag Dumper $product_ref;

# positive control 2
$product_ref = {
	categories_tags => ['en:dried-products-to-be-rehydrated'],
	nutrition_data_prepared => 'on',
	nutriments => {
		energy_prepared_100g => 5,
		fat_prepared_100g => 2.7
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with 2 prepared data values is not flagged for issue 1466'
) or diag Dumper $product_ref;

$product_ref = {
	categories_tags => ['en:dried-products-to-be-rehydrated'],
	nutrition_data_prepared => 'on',
	nutriments => undef
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with undefined nutriments hash is flagged for issue 1466'
) or diag Dumper $product_ref;

$product_ref = {
	categories_tags => ['en:dried-products-to-be-rehydrated'],
	nutrition_data_prepared => 'on',
	nutriments => {
		energy => 46
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with nutriments hash with unrelated data is flagged for issue 1466'
) or diag Dumper $product_ref;

$product_ref = {
	categories_tags => ['en:dried-products-to-be-rehydrated'],
	nutriments => {
		energy_prepared_100g => 5
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with nutrition_data_prepared off is flagged for issue 1466'
) or diag Dumper $product_ref;

$product_ref = {
	categories_tags => ['en:dried-products-to-be-rehydrated'],
	nutrition_data_prepared => 'on',
	nutriments => {
		energy_prepared_100g => 5
	},
	no_nutrition_data => 'on'

};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with no nutrition data checked prepared data is flagged for issue 1466'
) or diag Dumper $product_ref;

$product_ref = {
	categories_tags => ['en:dried-products-to-be-rehydrated'],
	nutrition_data_prepared => 'on',
	nutriments => {
		energy_prepared_100g => 5
	},
	no_nutrition_data => 'on'

};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with no nutrition data checked prepared data is flagged for issue 1466'
) or diag Dumper $product_ref;

use Log::Any::Adapter 'TAP', filter => "none";

check_quality_and_test_product_has_quality_tag(
	{
		'ecoscore_data' => {
			'adjustments' => {
				'origins_of_ingredients' => {
					'aggregated_origins' => [
						{
							'origin' => 'en:unknown',
							'percent' => 100
						}
					],
					'epi_score' => 0,
					'epi_value' => -5,
					'origins_from_origins_field' => ['en:unknown'],
					'transportation_score' => 0,
					'transportation_value' => 0,
					'value' => -5,
					'warning' => 'origins_are_100_percent_unknown'
				},
			}
		}
	},
	"en:ecoscore-origins-of-ingredients-origins-are-100-percent-unknown",
	"origins 100 percent unknown",
	1
);

# Specified percent of ingredients

$product_ref = {
	lc => 'en',
	ingredients_text => 'Strawberries 100%',
};
extract_ingredients_from_text($product_ref);
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:all-ingredients-with-specified-percent')) or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:sum-of-ingredients-with-unspecified-percent-lesser-than-10'))
	or diag Dumper $product_ref;

$product_ref = {
	lc => 'en',
	ingredients_text => 'Strawberries 90%, sugar 50%, water',
};
extract_ingredients_from_text($product_ref);
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:all-but-one-ingredient-with-specified-percent'))
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:sum-of-ingredients-with-unspecified-percent-lesser-than-10'))
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:sum-of-ingredients-with-specified-percent-greater-than-100'))
	or diag Dumper $product_ref;

# energy does not match nutrients
$product_ref = {
	nutriments => {
		"energy-kj_value" => 5,
		"carbohydrates_value" => 10,
		"fat_value" => 20,
		"proteins_value" => 30,
		"fiber_value" => 2,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
is($product_ref->{nutriments}{"energy-kj_value_computed"}, 1436);
ok(has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrients')
	or diag Dumper $product_ref;

# energy does not match nutrients but this alert is ignored for this category
$product_ref = {
	categories_tags => ['en:squeezed-lemon-juices'],
	nutriments => {
		"energy-kj_value" => 5,
		"carbohydrates_value" => 10,
		"fat_value" => 20,
		"proteins_value" => 30,
		"fiber_value" => 2,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrients but category possesses ignore_energy_calculated_error:en:yes tag'
) or diag Dumper $product_ref;

$product_ref = {
	categories_tags => ['en:sweeteners'],
	nutriments => {
		"energy-kj_value" => 550,
		"carbohydrates_value" => 10,
		"fat_value" => 20,
		"proteins_value" => 30,
		"fiber_value" => 2,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
is($product_ref->{nutriments}{"energy-kj_value_computed"}, 1436);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrients but category possesses ignore_energy_calculated_error:en:yes tag'
) or diag Dumper $product_ref;

$product_ref = {
	categories_tags => ['en:sweet-spreads'],
	nutriments => {
		"energy-kj_value" => 8,
		"fat_value" => 0.5,
		"saturated-fat_value" => 0.1,
		"carbohydrates_value" => 0.5,
		"sugars_value" => 0.5,
		"proteins_value" => 0.5,
		"salt_value" => 0.01,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrients but energy is lower than 55 kj'
) or diag Dumper $product_ref;

# energy matches nutrients
$product_ref = {
	nutriments => {
		"energy-kj_value" => 1435,
		"carbohydrates_value" => 10,
		"fat_value" => 20,
		"proteins_value" => 30,
		"fiber_value" => 2,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy matching nutrients'
) or diag Dumper $product_ref;

# Polyols in general contribute energy
$product_ref = {
	nutriments => {
		"energy-kj_value" => 0,
		"carbohydrates_value" => 100,
		"polyols_value" => 100,
		"fat_value" => 0,
		"proteins_value" => 0,
		"fiber_value" => 0,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrients - polyols')
	or diag Dumper $product_ref;

# Erythritol is a polyol which does not contribute to energy
$product_ref = {
	nutriments => {
		"energy-kj_value" => 0,
		"carbohydrates_value" => 100,
		"polyols_value" => 100,
		"erythritol_value" => 100,
		"fat_value" => 0,
		"proteins_value" => 0,
		"fiber_value" => 0,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy matching nutrient - erythritol'
) or diag Dumper $product_ref;

# Erythritol is a polyol which does not contribute to energy
# If we do not have a value for polyols but we have a value for erythritol,
# we should assume that the polyols are equal to erythritol when we check the nutrients to energy computation
$product_ref = {
	nutriments => {
		"energy-kj_value" => 0,
		"carbohydrates_value" => 100,
		"erythritol_value" => 100,
		"fat_value" => 0,
		"proteins_value" => 0,
		"fiber_value" => 0,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy matching nutrient - erythritol without polyols'
) or diag Dumper $product_ref;

# Polyols in general contribute energy
$product_ref = {
	nutriments => {
		"energy-kj_value" => 0,
		"carbohydrates_value" => 100,
		"polyols_value" => 100,
		"fat_value" => 0,
		"proteins_value" => 0,
		"fiber_value" => 0,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrient but lower than 55 kj')
	or diag Dumper $product_ref;

# Erythritol is a polyol which does not contribute to energy
$product_ref = {
	nutriments => {
		"energy-kj_value" => 0,
		"carbohydrates_value" => 100,
		"polyols_value" => 100,
		"erythritol_value" => 100,
		"fat_value" => 0,
		"proteins_value" => 0,
		"fiber_value" => 0,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrient'
) or diag Dumper $product_ref;

# en:nutrition-value-negative-$nid should be raised - for nutriments (except nutriments containing "nutrition-score") below 0
$product_ref = {
	nutriments => {
		"proteins_100g" => -1,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-negative-proteins',
	'nutriment should have positive value (except nutrition-score)', 1
);

# en:nutrition-value-negative-$nid should NOT be raised - for nutriments containing "nutrition-score" and below 0
$product_ref = {
	nutriments => {
		"nutrition-score-fr_100g" => -1,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-negative-nutrition-score-fr',
	'nutriment should have positive value (except nutrition-score)', 0
);

# serving size should contains digits
$product_ref = {serving_size => "serving_size"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:serving-size-is-missing-digits',
	'serving size should contains digits', 1
);
$product_ref = {serving_size => "120g"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:serving-size-is-missing-digits',
	'serving size should contains digits', 0
);

# serving size is missing
$product_ref = {
	nutrition_data => "on",
	nutrition_data_per => "serving"
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-missing-serving-size',
	'serving size should be provided if "per serving" is selected', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-0',
	'serving size equal to 0 is unexpected', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-not-recognized',
	'serving size cannot be parsed', 0
);
# serving size equal to 0
$product_ref = {
	nutrition_data => "on",
	nutrition_data_per => "serving",
	serving_quantity => "0",
	serving_size => "0g"
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-missing-serving-size',
	'serving size should be provided if "per serving" is selected', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-0',
	'serving size equal to 0 is unexpected', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-not-recognized',
	'serving size cannot be parsed', 0
);
# serving size cannot be parsed
$product_ref = {
	nutrition_data => "on",
	nutrition_data_per => "serving",
	serving_size => "1 container"
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-missing-serving-size',
	'serving size should be provided if "per serving" is selected', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-0',
	'serving size equal to 0 is unexpected', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-not-recognized',
	'serving size cannot be parsed', 1
);
# last 3 tests should not appears when expected serving size is provided
$product_ref = {
	nutrition_data => "on",
	nutrition_data_per => "serving",
	serving_quantity => "50",
	serving_size => "50 mL"
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-missing-serving-size',
	'serving size should be provided if "per serving" is selected', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-0',
	'serving size equal to 0 is unexpected', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-not-recognized',
	'serving size cannot be parsed', 0
);

# serving size not recognized (leading to undefined serving quantity)
$product_ref = {serving_size => "50",};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-data-per-serving-serving-quantity-is-not-recognized',
	'serving size is not recognized', 1
);

# percentage for ingredient is higher than 100% in extracted ingredients from the picture
$product_ref = {
	ingredients => [
		{
			percent => 110,
			percent_estimate => 100
		},
		{
			percent => 5,
			percent_estimate => 0
		},
		{
			percent_estimate => 0
		}
	],
	ingredients_with_specified_percent_n => 2
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:ingredients-extracted-ingredient-from-picture-with-more-than-100-percent',
	'percentage should not be above 100, error when extracting the ingredients from the picture', 1
);
$product_ref = {
	ingredients => [
		{
			percent => 1.1,
			percent_estimate => 1.1
		},
		{
			percent => 5,
			percent_estimate => 0
		},
		{
			percent_estimate => 0
		}
	],
	ingredients_with_specified_percent_n => 2
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:ingredients-extracted-ingredient-from-picture-with-more-than-100-percent',
	'percentage should not be above 100, error when extracting the ingredients from the picture', 0
);

# en:nutrition-3-or-more-values-are-identical
$product_ref = {
	nutriments => {
		"carbohydrates_100g" => 0,
		"fat_100g" => 0,
		"proteins_100g" => 0,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-3-or-more-values-are-identical',
	'3 or more identical values and above 1 in the nutrition table', 0
);
$product_ref = {
	nutriments => {
		"carbohydrates_100g" => 1,
		"fat_100g" => 2,
		"proteins_100g" => 3,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-3-or-more-values-are-identical',
	'3 or more identical values and above 1 in the nutrition table', 0
);
$product_ref = {
	nutriments => {
		"carbohydrates_100g" => 3,
		"fat_100g" => 3,
		"proteins_100g" => 3,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-3-or-more-values-are-identical',
	'3 or more identical values and above 1 in the nutrition table', 1
);
## en:nutrition-values-are-all-identical but equal to 0
$product_ref = {
	nutriments => {
		"energy-kj_100g" => 0,
		"energy-kcal_100g" => 0,
		"fat_100g" => 0,
		"saturated-fat_100g" => 0,
		"carbohydrates_100g" => 0,
		"sugars_100g" => 0,
		"fibers_100g" => 0,
		"proteins_100g" => 0,
		"salt_100g" => 0,
		"sodium_100g" => 0,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-values-are-all-identical',
	'all identical values and above 1 in the nutrition table 1', 0
);
$product_ref = {
	nutriments => {
		"energy-kj_100g" => 2,
		"energy-kcal_100g" => 2,
		"fat_100g" => 2,
		"saturated-fat_100g" => 2,
		"carbohydrates_100g" => 2,
		"sugars_100g" => 2,
		"fibers_100g" => 2,
		"proteins_100g" => 2,
		"salt_100g" => 2,
		"sodium_100g" => 0.8,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-values-are-all-identical',
	'all identical values and above 1 in the nutrition table 2', 1
);
## should have enough input nutriments
$product_ref = {
	nutriments => {
		"energy-kj_100g" => 2,
		"salt_100g" => 2,
		"sodium_100g" => 0.8,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-values-are-all-identical',
	'all identical values and above 1 in the nutrition table BUT not enough nutriments given', 0
);

# sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars
$product_ref = {nutriments => {}};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);
$product_ref = {
	nutriments => {
		"sugars_100g" => 1,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);
$product_ref = {
	nutriments => {
		"fructose_100g" => 1,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);
$product_ref = {
	nutriments => {
		"sugars_100g" => 2,
		"fructose_100g" => 1,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);
$product_ref = {
	nutriments => {
		"sugars_100g" => 0,
		"fructose_100g" => 2,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 1
);
$product_ref = {
	nutriments => {
		"sugars_100g" => 1,
		"fructose_100g" => 1,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);
$product_ref = {
	nutriments => {
		"sugars_100g" => 20,
		"fructose_100g" => 1,
		"glucose_100g" => 1,
		"maltose_100g" => 1,
		"lactose_100g" => 1,
		"sucrose_100g" => 1,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);
$product_ref = {
	nutriments => {
		"sugars_100g" => 1,
		"fructose_100g" => 1,
		"glucose_100g" => 1,
		"maltose_100g" => 1,
		"lactose_100g" => 1,
		"sucrose_100g" => 1,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 1
);
$product_ref = {
	nutriments => {
		"sugars_100g" => 20,
		"fructose_100g" => 4,
		"glucose_100g" => 4,
		"maltose_100g" => 4,
		"lactose_100g" => 4,
		"sucrose_100g" => 4,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-fructose-plus-glucose-plus-maltose-plus-lactose-plus-sucrose-greater-than-sugars',
	'sum of fructose plus glucose plus maltose plus lactose plus sucrose cannot be greater than sugars', 0
);

# salt_100g is very small warning (may be in mg)
## lower than 0.001
$product_ref = {
	nutriments => {
		salt_100g => 0.0009,    # lower than 0.001
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-under-0-001-g-salt',
	'value for salt is lower than 0.001g', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-under-0-01-g-salt',
	'value for salt is lower than 0.001g, should not trigger warning for 0.01', 0
);
## lower than 0.01
$product_ref = {
	nutriments => {
		salt_100g => 0.009,    # lower than 0.01
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-under-0-001-g-salt',
	'value for salt is above 0.001g', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-under-0-01-g-salt',
	'value for salt is lower than 0.001g, and above 0.01', 1
);
## above 0.01
$product_ref = {
	nutriments => {
		salt_100g => 0.02,    # above 0.01
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-under-0-001-g-salt',
	'value for salt is above 0.001g', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-value-under-0-01-g-salt',
	'value for salt is above 0.001g', 0
);

# testing of ProductOpener::DataQualityFood::check_quantity subroutine
$product_ref = {quantity => "300g"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e',
	'quantity does not contain e', 0);
$product_ref = {quantity => "1 verre"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e',
	'quantity does not contain e', 0);
$product_ref = {quantity => "1 litre"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e',
	'quantity does not contain e', 0);
$product_ref = {quantity => "225 g ℮"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e', 'quantity does not contain e',
	0);
$product_ref = {quantity => "300ge"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e', 'quantity contains e', 1);
$product_ref = {quantity => "300mge"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e', 'quantity contains e', 1);
$product_ref = {quantity => "300 mg e"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e', 'quantity contains e', 1);
$product_ref = {quantity => "200 g e (2x100g)"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e', 'quantity contains e', 1);
$product_ref = {quantity => "1kge35.27oz"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e', 'quantity contains e', 1);
$product_ref = {quantity => "300 ml e / 342 g"};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:quantity-contains-e', 'quantity contains e', 1);

# testing of ProductOpener::DataQualityFood::check_nutrition_data kJ vs kcal
$product_ref = {
	nutriments => {
		"energy-kj_value" => 686,
		"energy-kcal_value" => 165,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-value-in-kcal-greater-than-in-kj',
	'1 kcal = 4.184 kJ', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-value-in-kcal-does-not-match-value-in-kj',
	'1 kcal = 4.184 kJ, value in kJ is between 165*3.7-2=608.5 and 165*4.7+2=777.5', 0
);
$product_ref = {
	nutriments => {
		"energy-kj_value" => 100,
		"energy-kcal_value" => 200,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-value-in-kcal-greater-than-in-kj',
	'1 kcal = 4.184 kJ', 1
);
$product_ref = {
	nutriments => {
		"energy-kj_value" => 496,
		"energy-kcal_value" => 105,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-value-in-kcal-does-not-match-value-in-kj',
	'1 kcal = 4.184 kJ, value in kJ is larger than 105*4.7+2=495.5', 1
);
$product_ref = {
	nutriments => {
		"energy-kj_value" => 386,
		"energy-kcal_value" => 105,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-value-in-kcal-does-not-match-value-in-kj',
	'1 kcal = 4.184 kJ, value in kJ is lower than 105*3.7-2=495.5', 1
);
$product_ref = {
	nutriments => {
		"energy-kj_value" => 165,
		"energy-kcal_value" => 686,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-value-in-kcal-greater-than-in-kj',
	'1 kcal = 4.184 kJ', 1
);
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-value-in-kcal-and-kj-are-reversed',
	'1 kcal = 4.184 kJ, value in kcal is between 165*3.7-2=608.5 and 165*4.7+2=777.5', 1
);

# nutrition - saturated fat is greater than fat
## trigger the error because saturated-fat_100g is greated than fat
$product_ref = {
	nutriments => {
		fat_100g => 0,
		"saturated-fat_100g" => 1,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-saturated-fat-greater-than-fat',
	'saturated fat greater than fat', 1
);
## if undefined fat, error should not be triggered
$product_ref = {
	nutriments => {
		"saturated-fat_100g" => 1,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-saturated-fat-greater-than-fat',
	'saturated fat may be greater than fat but fat is missing', 0
);

# category with expected nutriscore grade. Prerequisite: "expected_nutriscore_grade:en:c" under "en:Extra-virgin olive oils" category, in the taxonomy
# category with expected nutriscore grade. Different nutriscore grade as compared to the expected nutriscore grade
$product_ref = {
	categories_tags => [
		'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
		'en:fats', 'en:vegetable-fats',
		'en:olive-tree-products', 'en:vegetable-oils',
		'en:olive-oils', 'en:virgin-olive-oils',
		'en:extra-virgin-olive-oils'
	],
	nutrition_grade_fr => "d",
	nutriscore => {
		2023 => {"nutrients_available" => 1,},
	},
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutri-score-grade-from-category-does-not-match-calculated-grade',
	'Calculate nutriscore grade should be the same as the one provided in the taxonomy for this category', 1
);
# category with expected nutriscore grade. Different nutriscore grade as compared to the expected nutriscore grade. Two specific categories
$product_ref = {
	categories_tags => [
		"en:plant-based-foods-and-beverages", "en:plant-based-foods",
		"en:desserts", "en:fats",
		"en:frozen-foods", "en:vegetable-fats",
		"en:frozen-desserts", "en:olive-tree-products",
		"en:vegetable-oils", "en:ice-creams-and-sorbets",
		"en:olive-oils", "en:ice-creams",
		"en:ice-cream-tubs", "en:virgin-olive-oils",
		"en:extra-virgin-olive-oils", "fr:glace-aux-calissons"
	],
	nutrition_grade_fr => "d",
	nutriscore => {
		2023 => {"nutrients_available" => 1,},
	},
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutri-score-grade-from-category-does-not-match-calculated-grade',
	'Calculate nutriscore grade should be the same as the one provided in the taxonomy for this category even if some other categories tags do not have expected nutriscore grade',
	1
);
# category with expected nutriscore grade. Not calculated (missing nutriscore grade)
$product_ref = {
	categories_tags => [
		'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
		'en:fats', 'en:vegetable-fats',
		'en:olive-tree-products', 'en:vegetable-oils',
		'en:olive-oils', 'en:virgin-olive-oils',
		'en:extra-virgin-olive-oils'
	],
	nutriscore => {
		2023 => {"nutrients_available" => 0,},
	},
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutri-score-grade-from-category-does-not-match-calculated-grade',
	'Calculate nutriscore grade should be the same as the one provided in the taxonomy for this category', 0
);
# category with expected nutriscore grade. Same nutriscore grade as compared to the expected nutriscore grade
$product_ref = {
	categories_tags => [
		'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
		'en:fats', 'en:vegetable-fats',
		'en:olive-tree-products', 'en:vegetable-oils',
		'en:olive-oils', 'en:virgin-olive-oils',
		'en:extra-virgin-olive-oils'
	],
	nutrition_grade_fr => "c",
	nutriscore => {
		2023 => {"nutrients_available" => 1,},
	},
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutri-score-grade-from-category-does-not-match-calculated-grade',
	'Calculate nutriscore grade should be the same as the one provided in the taxonomy for this category', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutri-score-grade-from-category-does-not-match-calculated-grade',
	'Calculate nutriscore grade should be the same as the one provided in the taxonomy for this category', 0
);

# category with expected ingredient. Prerequisite: "expected_ingredients:en: en:olive-oil" under "en:Extra-virgin olive oils" category, in the taxonomy
# category with expected ingredient. Missing ingredients
$product_ref = {
	categories_tags => [
		'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
		'en:fats', 'en:vegetable-fats',
		'en:olive-tree-products', 'en:vegetable-oils',
		'en:olive-oils', 'en:virgin-olive-oils',
		'en:extra-virgin-olive-oils'
	],
	# Missing ingredients
	# ingredients => [
	# 	{id => "en:olive-oil"}
	# ]
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:ingredients-single-ingredient-from-category-missing',
	'We expect the ingredient given in the taxonomy for this product', 1
);
# category with expected ingredient. More than one ingredient
$product_ref = {
	categories_tags => [
		'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
		'en:fats', 'en:vegetable-fats',
		'en:olive-tree-products', 'en:vegetable-oils',
		'en:olive-oils', 'en:virgin-olive-oils',
		'en:extra-virgin-olive-oils'
	],
	ingredients => [{id => "en:extra-virgin-olive-oil"}, {id => "en:virgin-olive-oil"}]
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:ingredients-single-ingredient-from-category-does-not-match-actual-ingredients',
	'We expect the ingredient given in the taxonomy for this product', 1
);
# category with expected ingredient. Single ingredient that is a child of the expected one.
$product_ref = {
	categories_tags => [
		'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
		'en:fats', 'en:vegetable-fats',
		'en:olive-tree-products', 'en:vegetable-oils',
		'en:olive-oils', 'en:virgin-olive-oils',
		'en:extra-virgin-olive-oils'
	],
	ingredients => [{id => 'en:extra-virgin-olive-oil'}]
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:ingredients-single-ingredient-from-category-does-not-match-actual-ingredients',
	'We expect the ingredient given in the taxonomy for this product', 0
);
# category with expected ingredient. Single ingredient that is a child of the expected one. Two specific categories
$product_ref = {
	categories_tags => [
		"en:plant-based-foods-and-beverages", "en:plant-based-foods",
		"en:desserts", "en:fats",
		"en:frozen-foods", "en:vegetable-fats",
		"en:frozen-desserts", "en:olive-tree-products",
		"en:vegetable-oils", "en:ice-creams-and-sorbets",
		"en:olive-oils", "en:ice-creams",
		"en:ice-cream-tubs", "en:virgin-olive-oils",
		"en:extra-virgin-olive-oils", "fr:glace-aux-calissons"
	],
	ingredients => [{id => 'en:extra-virgin-olive-oil'}]
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:ingredients-single-ingredient-from-category-does-not-match-actual-ingredients',
	'We expect the ingredient given in the taxonomy for this product', 0
);
# category with expected ingredient. Single ingredient identical as expected one
$product_ref = {
	categories_tags => [
		"en:plant-based-foods-and-beverages", "en:plant-based-foods",
		"en:desserts", "en:fats",
		"en:frozen-foods", "en:vegetable-fats",
		"en:frozen-desserts", "en:olive-tree-products",
		"en:vegetable-oils", "en:ice-creams-and-sorbets",
		"en:olive-oils", "en:ice-creams",
		"en:ice-cream-tubs", "en:virgin-olive-oils",
		"en:extra-virgin-olive-oils", "fr:glace-aux-calissons"
	],
	ingredients => [{id => 'en:olive-oil'}]
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:ingredients-single-ingredient-from-category-does-not-match-actual-ingredients',
	'We expect the ingredient given in the taxonomy for this product', 0
);
# product quantity warnings and errors
$product_ref = {product_quantity => "123456789",};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:product-quantity-over-10kg',
	'raise warning because the product quantity is above 10000g', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:product-quantity-over-30kg',
	'raise error because the product quantity is above 30000g', 1
);
# product quantity warnings and errors
$product_ref = {product_quantity => "20000",};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:product-quantity-over-10kg',
	'raise warning because the product quantity is above 10000g', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:product-quantity-over-30kg',
	'raise error because the product quantity is above 30000g', 0
);
$product_ref = {
	product_quantity => "0.001",
	quantity => "1 mg",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:product-quantity-under-1g',
	'raise warning because the product quantity is under 1g', 1
);
check_quality_and_test_product_has_quality_tag($product_ref, 'en:product-quantity-in-mg',
	'raise warning because the product quantity is in mg', 1);

# Brands - Detected category from brand
$product_ref = {brands_tags => ["bledina", "camel", "purina", "yves-rocher",],};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:detected-category-from-brand-baby-foods',
	'Detected category from brand - Baby', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:detected-category-from-brand-cigarettes',
	'Detected category from brand - Cigarettes', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:detected-category-from-brand-pet-foods',
	'Detected category from brand - Pet Foods', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:detected-category-from-brand-beauty',
	'Detected category from brand - Beauty', 1
);

# Nutrition errors - sugar + starch > carbohydrates
## without "<" symbol
$product_ref = {
	nutriments => {
		"carbohydrates_100g" => 1,
		"sugars_100g" => 2,
		"starch_100g" => 3,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:nutrition-sugars-plus-starch-greater-than-carbohydrates'),
	'sum of sugars and starch greater carbohydrates')
	or diag Dumper $product_ref;
## with "<" symbol
$product_ref = {
	nutriments => {
		"carbohydrates_100g" => 1,
		"sugars_100g" => 1,
		"sugars_modifier" => "<",
		"starch_100g" => 1,
		"starch_modifier" => "<",
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:nutrition-sugars-plus-starch-greater-than-carbohydrates'),
	'sum of sugars and starch greater carbohydrates, presence of "<" symbol,  and sugars or starch is smaller than carbohydrates'
) or diag Dumper $product_ref;
## sugar or starch is greater than carbohydrates, with "<" symbol
$product_ref = {
	nutriments => {
		"carbohydrates_100g" => 3,
		"sugars_100g" => 1,
		"starch_100g" => 5,
		"starch_modifier" => "<",
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag($product_ref, 'data_quality', 'en:nutrition-sugars-plus-starch-greater-than-carbohydrates'),
	'sum of sugars and starch greater carbohydrates, presence of "<" symbol, and sugars or starch is greater than carbohydrates'
) or diag Dumper $product_ref;
## should not be triggered
$product_ref = {
	nutriments => {
		"carbohydrates_100g" => 3,
		"sugars_100g" => 2,
		"starch_100g" => 1,
	}
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(!has_tag($product_ref, 'data_quality', 'en:nutrition-sugars-plus-starch-greater-than-carbohydrates'),
	'sum of sugars and starch greater carbohydrates')
	or diag Dumper $product_ref;

# unexpected character in ingredients
$product_ref = {
	languages_codes => {
		en => 1
	},
	lc => 'en',
	ingredients_text_en => 'AaaAAa, BbbBBB, $, @, !, ?, Https://,',
};
ProductOpener::DataQuality::check_quality($product_ref);

ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-5-vowels'), '5 vowel in a row')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-5-consonants'), '5 consonants in a row')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-4-repeated-chars'), '4 repeated characters')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-unexpected-chars-currencies'), '$')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-unexpected-chars-arobase'), '@')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-unexpected-chars-exclamation-mark'), '!')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-unexpected-chars-question-mark'), '?')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-ending-comma'), ',')
	or diag Dumper $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:ingredients-en-unexpected-url'), 'detected url')
	or diag Dumper $product_ref;

# jam and related categories and fruit (specific ingredients) content
## missing specific ingredients
$product_ref = {
	categories_tags => ["en:jams"],
	countries_tags => ["en:slovenia",],
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:missing-specific-ingredient-for-this-category'),
	'specific ingredients missing')
	or diag Dumper $product_ref;
## missing specific ingredients for fruit
$product_ref = {
	categories_tags => ["en:jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:other",
			ingredient => "other",
			quantity => "50 g",
			quantity_g => 50,
			text => "other",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:missing-specific-ingredient-for-this-category'),
	'specific ingredients but en:fruit missing')
	or diag Dumper $product_ref;
## specific ingredients for fruit ok
$product_ref = {
	categories_tags => ["en:jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "50 g",
			quantity_g => 50,
			text => "Prepared with 50g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(!has_tag($product_ref, 'data_quality', 'en:missing-fruit-content-for-jams-or-jellies'),
	'specific ingredients with en:fruit ok')
	or diag Dumper $product_ref;
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-35-for-category-jams'
	),
	'en:fruit content ok'
) or diag Dumper $product_ref;
## specific ingredients for fruit is given but content is too small
$product_ref = {
	categories_tags => ["en:jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "5 g",
			quantity_g => 5,
			text => "Prepared with 5g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(!has_tag($product_ref, 'data_quality', 'en:missing-fruit-content-for-jams-or-jellies'),
	'specific ingredients with en:fruit ok')
	or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-35-for-category-jams'
	),
	'en:fruit content too small'
) or diag Dumper $product_ref;
## specific ingredients for fruit is given but content is too small with more specific category
$product_ref = {
	categories_tags => ["en:jams", "en:redcurrants-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "10 g",
			quantity_g => 10,
			text => "Prepared with 10g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-35-for-category-jams'
	),
	'en:fruit content too small for jam but has more specific category with smaller threshold'
) or diag Dumper $product_ref;
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-redcurrants-jams'
	),
	'en:fruit content too small'
) or diag Dumper $product_ref;
## specific ingredients for fruit is given but content is too small for jams but high enough for more specific category
$product_ref = {
	categories_tags => ["en:jams", "en:redcurrants-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "30 g",
			quantity_g => 30,
			text => "Prepared with 30g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-35-for-category-jams'
	),
	'en:fruit content too small for jam but has more specific category with smaller threshold'
) or diag Dumper $product_ref;
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-redcurrants-jams'
	),
	'en:fruit content too small'
) or diag Dumper $product_ref;
## extra jams
$product_ref = {
	categories_tags => ["en:extra-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "1 g",
			quantity_g => 1,
			text => "Prepared with 1g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-45-for-category-extra-jams'
	),
	'en:fruit content too small extra jams'
) or diag Dumper $product_ref;
## Blackcurrant jams
$product_ref = {
	categories_tags => ["en:blackcurrant-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "2 g",
			quantity_g => 3,
			text => "Prepared with 2g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-blackcurrant-jams'
	),
	'en:fruit content too small blackcurrant jams'
) or diag Dumper $product_ref;
## ginger jams
$product_ref = {
	categories_tags => ["en:ginger-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "3 g",
			quantity_g => 3,
			text => "Prepared with 3g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-15-for-category-ginger-jams'
	),
	'en:fruit content too small ginger jams'
) or diag Dumper $product_ref;
## quince jams
$product_ref = {
	categories_tags => ["en:quince-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "4 g",
			quantity_g => 4,
			text => "Prepared with 4g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-quince-jams'
	),
	'en:fruit content too small quince jams'
) or diag Dumper $product_ref;
## rosehip jams
$product_ref = {
	categories_tags => ["en:rosehip-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "5 g",
			quantity_g => 5,
			text => "Prepared with 5g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-rosehip-jams'
	),
	'en:fruit content too small rosehip jams'
) or diag Dumper $product_ref;
## Sea-buckthorn jams
$product_ref = {
	categories_tags => ["en:sea-buckthorn-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "6 g",
			quantity_g => 6,
			text => "Prepared with 6g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-sea-buckthorn-jams'
	),
	'en:fruit content too small sea-buckthorn jams'
) or diag Dumper $product_ref;
## marmalades
$product_ref = {
	categories_tags => ["en:marmalades"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "7 g",
			quantity_g => 7,
			text => "Prepared with 7g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-20-for-category-marmalades'
	),
	'en:fruit content too small marmalades jams'
) or diag Dumper $product_ref;
## citrus jams
$product_ref = {
	categories_tags => ["en:citrus-jams"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "8 g",
			quantity_g => 8,
			text => "Prepared with 8g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-20-for-category-citrus-jams'
	),
	'en:fruit content too small citrus jams'
) or diag Dumper $product_ref;
## blackcurrants jellies
$product_ref = {
	categories_tags => ["en:blackcurrants-jellies"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "9 g",
			quantity_g => 9,
			text => "Prepared with 9g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-blackcurrants-jellies'
	),
	'en:fruit content too small blackcurrants jellies'
) or diag Dumper $product_ref;
## passion fruit jellies
$product_ref = {
	categories_tags => ["en:passion-fruit-jellies"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "1 g",
			quantity_g => 1,
			text => "Prepared with 1g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-6-for-category-passion-fruit-jellies'
	),
	'en:fruit content too small passion fruit jellies'
) or diag Dumper $product_ref;
## Quince jellies
$product_ref = {
	categories_tags => ["en:quince-jellies"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "10 g",
			quantity_g => 10,
			text => "Prepared with 10g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-quince-jellies'
	),
	'en:fruit content too small quince jellies'
) or diag Dumper $product_ref;
## Redcurrants jellies
$product_ref = {
	categories_tags => ["en:redcurrants-jellies"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "11 g",
			quantity_g => 11,
			text => "Prepared with 11g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-redcurrants-jellies'
	),
	'en:fruit content too small redcurrants jellies'
) or diag Dumper $product_ref;
## sea-buckthorn jellies
$product_ref = {
	categories_tags => ["en:sea-buckthorn-jellies"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "12 g",
			quantity_g => 12,
			text => "Prepared with 12g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-25-for-category-sea-buckthorn-jellies'
	),
	'en:fruit content too small sea-buckthorn jellies'
) or diag Dumper $product_ref;
## chestnut spreads
$product_ref = {
	categories_tags => ["en:chestnut-spreads"],
	countries_tags => ["en:slovenia",],
	specific_ingredients => [
		{
			id => "en:fruit",
			ingredient => "fruit",
			quantity => "13 g",
			quantity_g => 13,
			text => "Prepared with 13g of fruit per 100g",
		},
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:specific-ingredient-fruit-quantity-is-below-the-minimum-value-of-38-for-category-chestnut-spreads'
	),
	'en:fruit content too small chestnut-spreads'
) or diag Dumper $product_ref;

# Test case for fiber content
$product_ref = {
	nutriments => {
		fiber_100g => 5,
		'soluble-fiber_100g' => 3,
		'insoluble-fiber_100g' => 3,
	},
	data_quality_errors_tags => [],
};

ProductOpener::DataQuality::check_quality($product_ref);

ok(
	has_tag($product_ref, 'data_quality_errors', 'en:nutrition-soluble-fiber-plus-insoluble-fiber-greater-than-fiber'),
	'Soluble fiber + Insoluble fiber exceeds total fiber'
) or diag Dumper $product_ref;

done_testing();
