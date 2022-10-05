#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;

use ProductOpener::DataQuality qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;

sub check_quality_and_test_product_has_quality_tag($$$$) {
	my $product_ref = shift;
	my $tag = shift;
	my $reason = shift;
	my $yesno = shift;
	ProductOpener::DataQuality::check_quality($product_ref);
	if ($yesno) {
		ok(has_tag($product_ref, 'data_quality', $tag), $reason) or diag explain $product_ref;
	}
	else {
		ok(!has_tag($product_ref, 'data_quality', $tag), $reason) or diag explain $product_ref;
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

done_testing();
