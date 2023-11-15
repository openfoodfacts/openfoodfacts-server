#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;

use ProductOpener::DataQuality qw/:all/;
use ProductOpener::DataQualityFood qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;

sub check_quality_and_test_product_has_quality_tag($$$$) {
	my $product_ref = shift;
	my $tag = shift;
	my $reason = shift;
	my $yesno = shift;
	ProductOpener::DataQuality::check_quality($product_ref);
	if ($yesno) {
		ok(has_tag($product_ref, 'data_quality', $tag), $reason)
			or diag explain {tag => $tag, yesno => $yesno, product => $product_ref};
	}
	else {
		ok(!has_tag($product_ref, 'data_quality', $tag), $reason)
			or diag explain {tag => $tag, yesno => $yesno, product => $product_ref};
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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

# ingredients-over-30-percent-digits - with more than 30%
$product_ref = {
	lc => 'de',
	ingredients_text => $over_30
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag($product_ref, 'data_quality', 'en:ingredients-over-30-percent-digits'),
	'product with more than 30% digits in the ingredients has tag ingredients-over-30-percent-digits'
) or diag explain $product_ref;

# ingredients-over-30-percent-digits - with exactly 30%
$product_ref = {
	lc => 'de',
	ingredients_text => $at_30
};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:ingredients-over-30-percent-digits'),
	'product with at most 30% digits in the ingredients has no ingredients-over-30-percent-digits tag'
) or diag explain $product_ref;

# ingredients-over-30-percent-digits - without a text
$product_ref = {lc => 'de'};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag($product_ref, 'data_quality', 'en:ingredients-over-30-percent-digits'),
	'product with no ingredients text has no ingredients-over-30-percent-digits tag'
) or diag explain $product_ref;

# issue 1466: Add quality facet for dehydrated products that are missing prepared values

$product_ref = {categories_tags => undef};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	!has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'product without dried category with no other qualities is not flagged for issue 1466'
) or diag explain $product_ref;

$product_ref = {categories_tags => ['en:dried-products-to-be-rehydrated']};
ProductOpener::DataQuality::check_quality($product_ref);
ok(
	has_tag(
		$product_ref, 'data_quality',
		'en:missing-nutrition-data-prepared-with-category-dried-products-to-be-rehydrated'
	),
	'dried product category with no other qualities is flagged for issue 1466'
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
ok(has_tag($product_ref, 'data_quality', 'en:all-ingredients-with-specified-percent')) or diag explain $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:sum-of-ingredients-with-unspecified-percent-lesser-than-10'))
	or diag explain $product_ref;

$product_ref = {
	lc => 'en',
	ingredients_text => 'Strawberries 90%, sugar 50%, water',
};
extract_ingredients_from_text($product_ref);
ProductOpener::DataQuality::check_quality($product_ref);
ok(has_tag($product_ref, 'data_quality', 'en:all-but-one-ingredient-with-specified-percent'))
	or diag explain $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:sum-of-ingredients-with-unspecified-percent-lesser-than-10'))
	or diag explain $product_ref;
ok(has_tag($product_ref, 'data_quality', 'en:sum-of-ingredients-with-specified-percent-greater-than-100'))
	or diag explain $product_ref;

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
	or diag explain $product_ref;

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
is($product_ref->{nutriments}{"energy-kj_value_computed"}, 1436);
ok(
	!has_tag($product_ref, 'data_quality', 'en:energy-value-in-kj-does-not-match-value-computed-from-other-nutrients'),
	'energy not matching nutrients but category possesses ignore_energy_calculated_error:en:yes tag'
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
	or diag explain $product_ref;

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
) or diag explain $product_ref;

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
) or diag explain $product_ref;

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
	'energy not matching nutrient')
	or diag explain $product_ref;

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
) or diag explain $product_ref;

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
# en:nutrition-values-are-all-identical
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
	'all identical values and above 1 in the nutrition table', 1
);
$product_ref = {
	nutriments => {
		"energy-kj_100g" => 1,
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
	'all identical values and above 1 in the nutrition table', 0
);
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
		"sodium_100g" => 1,
	}
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutrition-values-are-all-identical',
	'all identical values and above 1 in the nutrition table', 1
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
	nutrition_grade_fr => "d"
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
	nutrition_grade_fr => "d"
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
	]
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:nutri-score-grade-from-category-does-not-match-calculated-grade',
	'Calculate nutriscore grade should be the same as the one provided in the taxonomy for this category', 1
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
	nutrition_grade_fr => "c"
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
# vegan label but non-vegan ingredients
# unknown ingredient -> warnings
$product_ref = {
	labels_tags => ["en:vegetarian", "en:vegan",],
	ingredients => [
		{
			id => "en:lentils",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			id => "en:green-bell-pepper",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			id => "en:totoro",
		}
	],
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-non-vegan-ingredient',
	'raise error only when vegan is no and label is vegan', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-non-vegetarian-ingredient',
	'raise error only when vegetarian is no and label is vegan', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-could-not-confirm-for-all-ingredients',
	'raise warning because vegan or non-vegan is unknown for an ingredient', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-could-not-confirm-for-all-ingredients',
	'raise warning because vegetarian or non-vegetarian is unknown for an ingredient', 1
);
# non-vegan/non-vegetarian ingredient -> error
$product_ref = {
	labels_tags => ["en:vegetarian", "en:vegan",],
	ingredients => [
		{
			id => "en:lentils",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			id => "en:green-bell-pepper",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			id => "en:chicken",
			vegan => "no",
			vegetarian => "no"
		}
	],
};
ProductOpener::DataQuality::check_quality($product_ref);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-non-vegan-ingredient',
	'raise error only when vegan is no and label is vegan', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-non-vegetarian-ingredient',
	'raise error only when vegetarian is no and label is vegan', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-could-not-confirm-for-all-ingredients',
	'raise warning because vegan or non-vegan is unknown for an ingredient', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-could-not-confirm-for-all-ingredients',
	'raise warning because vegetarian or non-vegetarian is unknown for an ingredient', 0
);
# non-vegan/vegatarian ingredient -> error
$product_ref = {
	labels_tags => ["en:vegetarian", "en:vegan",],
	ingredients => [
		{
			id => "en:lentils",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			id => "en:green-bell-pepper",
			vegan => "yes",
			vegetarian => "yes"
		},
		{
			id => "en:honey",
			vegan => "no",
			vegetarian => "yes"
		}
	],
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-non-vegan-ingredient',
	'raise error only when vegan is no and label is vegan', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-non-vegetarian-ingredient',
	'raise error only when vegetarian is no and label is vegan', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-could-not-confirm-for-all-ingredients',
	'raise warning because vegan or non-vegan is unknown for an ingredient', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-could-not-confirm-for-all-ingredients',
	'raise warning because vegetarian or non-vegetarian is unknown for an ingredient', 0
);
done_testing();
