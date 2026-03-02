#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use ProductOpener::DataQuality qw/check_quality/;
use ProductOpener::DataQualityFood qw/:all/;
use ProductOpener::Tags qw/has_tag/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::FoodProducts qw/:all/;

sub check_quality_and_test_product_has_quality_tag($$$$) {
	my $product_ref = shift;
	my $tag = shift;
	my $reason = shift;
	my $yesno = shift;
	# Add default lc if not present to avoid warnings in processing
	$product_ref->{lc} //= 'en';
	specific_processes_for_food_product($product_ref);
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

# vegan label but non-vegan ingredients
# unknown ingredient -> warnings
my $product_ref = {
	labels_tags => ["en:vegetarian", "en:vegan",],
	ingredients_text_en => "Lentils, green bell pepper, totoro",
	lc => "en",
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
	ingredients_text_en => "Lentils, green bell pepper, chicken",
	lc => "en",
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
	ingredients_text => "Lentils, green bell pepper, honey",
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

# ignore compunds
$product_ref = {
	labels_tags => ["en:vegetarian", "en:vegan",],
	ingredients_text_en => "lentils, worcester sauce (vegetables), honey",
	lc => "en",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-non-vegan-ingredient',
	'en:vegan-label-but-non-vegan-ingredient', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-non-vegetarian-ingredient',
	'en:vegetarian-label-but-non-vegetarian-ingredient -- should not be raised when ingredient contain sub-ingredients',
	0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegan-label-but-could-not-confirm-for-all-ingredients',
	'en:vegan-label-but-could-not-confirm-for-all-ingredients -- should not be raised when ingredient contain sub-ingredients',
	0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vegetarian-label-but-could-not-confirm-for-all-ingredients',
	'en:vegetarian-label-but-could-not-confirm-for-all-ingredients -- should not be raised when ingredient contain sub-ingredients',
	0
);

# labels claim vs input nutrition data, based on EU regulation: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A02006R1924-20141213
# TODO TESTS WITH CATEGORIES AND ALL LABELS IN CASE TAXO CHANGE OVER TIME, SO THAT IT IS DETECTED WHEN RUNNING TESTS
# product quantity warnings and errors
# all labels and alerts maximum (minimum) when there are 2 levels and it should be below (above) an expected limitation
# all positives

# non-EU countries, should not raise facet
$product_ref = {
	countries_tags => ["en:united-states",],
	labels_tags => ["en:low-energy",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"energy-kj" => {
						value_string => "100",
						unit => "kJ"
					},
					"energy-kcal" => {
						value_string => "420",
						unit => "kcal"
					},
				}
			}
		]
	},
	quantity => "500 mg",
};

check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-energy-label-claim-but-energy-above-limitation',
	'non-EU countries, should not raise facet', 0
);

# solid
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => [
		"en:low-energy", "en:energy-free",
		"en:low-fat", "en:no-fat",
		"en:high-monounsaturated-fat", "en:rich-in-polyunsaturated-fatty-acids",
		"en:rich-in-unsaturated-fatty-acids", "en:low-content-of-saturated-fat",
		"en:saturated-fat-free", "en:low-sugar",
		"en:no-sugar", "en:low-sodium",
		"en:low-salt", "en:very-low-sodium",
		"en:very-low-salt", "en:no-sodium",
		"en:no-salt", "en:no-added-sodium",
		"en:no-added-salt", "en:source-of-fibre",
		"en:high-fibres", "en:vitamin-a-source",
		"en:rich-in-vitamin-a", "en:vitamin-d-source",
		"en:rich-in-vitamin-d", "en:vitamin-e-source",
		"en:rich-in-vitamin-e", "en:vitamin-c-source",
		"en:rich-in-vitamin-c", "en:vitamin-b1-source",
		"en:rich-in-vitamin-b1", "en:vitamin-b2-source",
		"en:rich-in-vitamin-b2", "en:vitamin-b3-source",
		"en:rich-in-vitamin-b3", "en:vitamin-b6-source",
		"en:rich-in-vitamin-b6", "en:vitamin-b9-source",
		"en:rich-in-vitamin-b9", "en:vitamin-b12-source",
		"en:rich-in-vitamin-b12", "en:source-of-biotin",
		"en:high-in-biotin", "en:source-of-pantothenic-acid",
		"en:high-in-pantothenic-acid", "en:calcium-source",
		"en:high-in-calcium", "en:phosphore-source",
		"en:high-in-phosphore", "en:iron-source",
		"en:high-in-iron", "en:magnesium-source",
		"en:high-in-magnesium", "en:zinc-source",
		"en:high-in-zinc", "en:iodine-source",
		"en:high-in-iodine", "en:source-of-omega-3",
		"en:high-in-omega-3",
	],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"energy-kcal" => {
						value => 100,    # is above 40 and 4
						unit => "kcal"
					},
					"energy-kj" => {
						value => 420,    # is above 170 and 17
						unit => "kJ"
					},
					"fat" => {
						value => 4,    # is above 3 and 0.5
						unit => "g"
					},
					"monounsaturated-fat" => {
						value => 1,    # less than 45% of the fat
						unit => "g"
					},
					"polyunsaturated-fat" => {
						value => 1,    # less than 45% of the fat
						unit => "g"
					},
					"unsaturated-fat" => {
						value => 1,    # less than 45% of the fat
						unit => "g"
					},
					"saturated-fat" => {
						value => 2,    # above 1.5
						unit => "g"
					},
					"sugars" => {
						value => 6,    # above 5 and 0.5
						unit => "g"
					},
					"sodium" => {
						value => 0.4,    # above 0.12 and 0.04 and 0.005
						unit => "g"
					},
					"salt" => {
						value => 1,    # above 0.3 and 0.1 and 0.0125
						unit => "g"
					},
					"fiber" => {
						value => 2,    # below 3 and 6
						unit => "g"
					},
					"vitamin-a" => {
						value => 0.00011,    # below 0.00012 and 0.00024 (15% of 800 µg and 1600 µg)
						unit => "g"
					},
					"vitamin-d" => {
						value => 0.00000074,    # below 0.00000075 and 0.0000015 (15% of 5 µg and 10 µg)
						unit => "g"
					},
					"vitamin-e" => {
						value => 0.0014,    # below 0.0015 and 0.003 (15% of 10 mg and 20 mg)
						unit => "g"
					},
					"vitamin-c" => {
						value => 0.008,    # below 0.009 and 0.018 (15% of 60 mg and 120 mg)
						unit => "g"
					},
					"vitamin-b1" => {
						value => 0.0002,    # below 0.00021 and 0.00042 (15% of 1.4 mg and 2.8 mg)
						unit => "g"
					},
					"vitamin-b2" => {
						value => 0.00023,    # below 0.00024 and 0.00048 (15% of 1.6 mg and 3.2 mg)
						unit => "g"
					},
					"vitamin-b3" => {
						value => 0.0026,    # below 0.0027 and 0.0054 (15% of 18 mg and 36 mg)
						unit => "g"
					},
					"vitamin-b6" => {
						value => 0.0002,    # below 0.0003 and 0.0006 (15% of 2 mg and 4 mg)
						unit => "g"
					},
					"vitamin-b9" => {
						value => 0.00002,    # below 0.00003 and 0.00006 (15% of 200 µg and 400 µg)
						unit => "g"
					},
					"vitamin-b12" => {
						value => 0.00000014,    # below 0.00000015 and 0.0000003 (15% of 1 µg and 2 µg)
						unit => "g"
					},
					"biotin" => {
						value => 0.0000224,    # below 0.0000225 and 0.000045 (15% of 0.15 mg and 0.3 mg)
						unit => "g"
					},
					"pantothenic-acid" => {
						value => 0.0008,    # below 0.0009 and 0.0018 (15% of 6 mg and 12 mg)
						unit => "g"
					},
					"calcium" => {
						value => 0.11,    # below 0.12 and 0.24 (15% of 800 mg and 1600 mg)
						unit => "g"
					},
					"phosphorus" => {
						value => 0.11,    # below 0.12 and 0.24 (15% of 800 mg and 1600 mg)
						unit => "g"
					},
					"iron" => {
						value => 0.002,    # below 0.0021 and 0.0042 (15% of 14 mg and 28 mg)
						unit => "g"
					},
					"magnesium" => {
						value => 0.044,    # below 0.045 and 0.09 (15% of 300 mg and 600 mg)
						unit => "g"
					},
					"zinc" => {
						value => 0.00224,    # below 0.00225 and 0.0045 (15% of 15 mg and 30 mg)
						unit => "g"
					},
					"iodine" => {
						value => 0.0000224,    # below 0.0000225 and 0.000045 (15% of 150 µg and 300 µg)
						unit => "g"
					},
					"alpha-linolenic-acid" => {
						value => 0.2,    # below 0.3 and 0.6
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "500 mg",
};

check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-energy-label-claim-but-energy-above-limitation',
	'above limitation for low energy label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:energy-free-label-claim-but-energy-above-limitation',
	'above limitation for energy free label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-fat-label-claim-but-fat-above-limitation',
	'above limitation for low fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:no-fat-label-claim-but-fat-above-0.5',
	'above limitation for no fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-monounsaturated-fat-label-claim-but-monounsaturated-fat-under-limitation',
	'under limitation for high-monounsaturated fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-polyunsaturated-fatty-acids-label-claim-but-polyunsaturated-fat-under-limitation',
	'under limitation for high-polyunsaturated fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-unsaturated-fatty-acids-label-claim-but-unsaturated-fat-under-limitation',
	'under limitation for unsaturated fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-saturated-fat-label-claim-but-fat-above-limitation',
	'under limitation for low saturated fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:saturated-fat-free-label-claim-but-fat-above-0.1',
	'above limitation for saturated fat free label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-sugar-label-claim-but-sugar-above-limitation',
	'above limitation for low sugar label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:sugar-free-label-claim-but-sugar-above-limitation',
	'above limitation for no sugar label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-sodium-or-low-salt-label-claim-but-sodium-or-salt-above-limitation',
	'above limitation for low sodium label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-sodium-or-low-salt-label-claim-but-sodium-or-salt-above-limitation',
	'above limitation for low salt label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:very-low-sodium-or-very-low-salt-label-claim-but-sodium-or-salt-above-limitation',
	'above limitation for very low sodium label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:very-low-sodium-or-very-low-salt-label-claim-but-sodium-or-salt-above-limitation',
	'above limitation for very low salt label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:sodium-free-or-salt-free-label-claim-but-sodium-or-salt-above-limitation',
	'above limitation for no sodium label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:sodium-free-or-salt-free-label-claim-but-sodium-or-salt-above-limitation',
	'above limitation for no salt label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:no-added-sodium-or-no-added-salt-label-claim-but-sodium-or-salt-above-limitation',
	'above limitation for no added salt label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-fibre-label-claim-but-fibre-below-limitation',
	'under limitation for source of fibres label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-fibres-label-claim-but-fibre-below-limitation',
	'under limitation for high-fibres label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-a-source-label-claim-but-vitamin-a-below-0.00012',
	'under limitation for vitamin-a source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-a-label-claim-but-vitamin-a-below-0.00024',
	'under limitation for rich in vitamin-a label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-d-source-label-claim-but-vitamin-d-below-7.5e-07',
	'under limitation for vitamin-d source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-d-label-claim-but-vitamin-d-below-1.5e-06',
	'under limitation for rich in vitamin-d label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-e-source-label-claim-but-vitamin-e-below-0.0015',
	'under limitation for vitamin-e source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-e-label-claim-but-vitamin-e-below-0.003',
	'under limitation for rich in vitamin-e label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-c-source-label-claim-but-vitamin-c-below-0.009',
	'under limitation for vitamin-c source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-c-label-claim-but-vitamin-c-below-0.018',
	'under limitation for rich in vitamin-c label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b1-source-label-claim-but-vitamin-b1-below-0.00021',
	'under limitation for vitamin-b1 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b1-label-claim-but-vitamin-b1-below-0.00042',
	'under limitation for rich in vitamin-b1 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b2-source-label-claim-but-vitamin-b2-below-0.00024',
	'under limitation for vitamin-b2 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b2-label-claim-but-vitamin-b2-below-0.00048',
	'under limitation for rich in vitamin-b2 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b3-source-label-claim-but-vitamin-b3-below-0.0027',
	'under limitation for vitamin-b3 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b3-label-claim-but-vitamin-b3-below-0.0054',
	'under limitation for rich in vitamin-b3 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b6-source-label-claim-but-vitamin-b6-below-0.0003',
	'under limitation for vitamin-b6 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b6-label-claim-but-vitamin-b6-below-0.0006',
	'under limitation for rich in vitamin-b6 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b9-source-label-claim-but-vitamin-b9-below-3e-05',
	'under limitation for vitamin-b9 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b9-label-claim-but-vitamin-b9-below-6e-05',
	'under limitation for rich in vitamin-b9 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b12-source-label-claim-but-vitamin-b12-below-1.5e-07',
	'under limitation for vitamin-b12 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b12-label-claim-but-vitamin-b12-below-3e-07',
	'under limitation for rich in vitamin-b12 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-biotin-label-claim-but-biotin-below-2.25e-05',
	'under limitation for biotin source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-biotin-label-claim-but-biotin-below-4.5e-05',
	'under limitation for high in biotin label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-pantothenic-acid-label-claim-but-pantothenic-acid-below-0.0009',
	'under limitation for pantothenic-acid source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-pantothenic-acid-label-claim-but-pantothenic-acid-below-0.0018',
	'under limitation for high in pantothenic-acid label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:calcium-source-label-claim-but-calcium-below-0.12',
	'under limitation for calcium source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-calcium-label-claim-but-calcium-below-0.24',
	'under limitation for high in calcium label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:phosphore-source-label-claim-but-phosphorus-below-0.12',
	'under limitation for phosphore source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-phosphore-label-claim-but-phosphorus-below-0.24',
	'under limitation for high in phosphore label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:iron-source-label-claim-but-iron-below-0.0021',
	'under limitation for iron source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-iron-label-claim-but-iron-below-0.0042',
	'under limitation for high in iron label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:magnesium-source-label-claim-but-magnesium-below-0.045',
	'under limitation for magnesium source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-magnesium-label-claim-but-magnesium-below-0.09',
	'under limitation for high in magnesium label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:zinc-source-label-claim-but-zinc-below-0.00225',
	'under limitation for zinc source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-zinc-label-claim-but-zinc-below-0.0045',
	'under limitation for high in zinc label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:iodine-source-label-claim-but-iodine-below-2.25e-05',
	'under limitation for iodine source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-iodine-label-claim-but-iodine-below-4.5e-05',
	'under limitation for high in iodine label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-omega-3-label-claim-but-ala-or-sum-of-epa-and-dha-below-limitation',
	'under limitation for source of omega-3 label', 1
);

check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-omega-3-label-claim-but-ala-or-sum-of-epa-and-dha-below-limitation',
	'under limitation for high in omega-3 label', 1
);

## en:high-monounsaturated-fat-label-claim-but-monounsaturated-fat-under-limitation
## due to monounsaturated providing less than 20% of total energy
## same for poly- (20% of total energy)
## same for saturated (10% of total energy)
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => [
		"en:high-monounsaturated-fat", "en:rich-in-polyunsaturated-fatty-acids",
		"en:rich-in-unsaturated-fatty-acids", "en:low-content-of-saturated-fat",
	],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"energy-kcal" => {
						value => 200,
						unit => "kcal"
					},
					"energy-kj" => {
						value => 840,
						unit => "kJ"
					},
					"fat" => {
						value => 4,    # more than 45% of the fat
						unit => "g"
					},
					"monounsaturated-fat" => {
						value => 3,    # more than 45% of the fat
						unit => "g"
					},
					"polyunsaturated-fat" => {
						value => 3,    # more than 45% of the fat
						unit => "g"
					},
					"unsaturated-fat" => {
						value => 3,    # more than 45% of the fat
						unit => "g"
					},
					"saturated-fat" => {
						value => 3,    # more than 45% of the fat
						unit => "g"
					},
					"carbohydrates" => {
						value => 10,
						unit => "g"
					},
					"proteins" => {
						value => 40,
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "500 mg",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-monounsaturated-fat-label-claim-but-monounsaturated-fat-under-limitation',
	'under limitation of total energy for high-monounsaturated fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-polyunsaturated-fatty-acids-label-claim-but-polyunsaturated-fat-under-limitation',
	'under limitation of total energy for high-polyunsaturated fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-unsaturated-fatty-acids-label-claim-but-unsaturated-fat-under-limitation',
	'under limitation of total energy for unsaturated fat label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-saturated-fat-label-claim-but-fat-above-limitation',
	'under limitation of total energy for saturated fat label', 1
);
## same as previous for fibres (1.5% and 3% of total energy))
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:source-of-fibre", "en:high-fibres",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"energy-kcal" => {
						value => 1020,
						unit => "kcal"
					},
					"energy-kj" => {
						value => 4260,
						unit => "kJ"
					},
					"fat" => {
						value => 60,
						unit => "g"
					},
					"carbohydrates" => {
						value => 60,
						unit => "g"
					},
					"proteins" => {
						value => 60,
						unit => "g"
					},
					"fiber" => {
						value => 7,    # above 6
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "500 mg",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-fibre-label-claim-but-fibre-below-limitation',
	'under limitation for source of fibres label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-fibres-label-claim-but-fibre-below-limitation',
	'under limitation for high-fibres label', 1
);
## same as previous for proteins (12% and 20% of total energy)
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:source-of-proteins", "en:high-proteins",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"energy-kcal" => {
						value => 864,
						unit => "kcal"
					},
					"energy-kj" => {
						value => 3587,
						unit => "kJ"
					},
					"fat" => {
						value => 60,
						unit => "g"
					},
					"carbohydrates" => {
						value => 60,
						unit => "g"
					},
					"proteins" => {
						value => 21,    # below 12% and 20%
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "500 mg",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-proteins-label-claim-but-proteins-below-limitation',
	'under limitation for source of proteins label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-proteins-label-claim-but-proteins-below-limitation',
	'under limitation for high-proteins label', 1
);

## no added sugar but added sugar ingredients
## same for salt, sodium
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:no-added-sugar", "en:no-added-sodium", "en:no-added-salt",],
	quantity => "500 mg",
	ingredients_text_en => "Cane sugar, salt, water",
	lc => "en",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:no-added-sugar-label-claim-but-contains-added-sugar',
	'added sugar detected beside label', 1
);

$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:no-added-sugar", "en:no-added-sodium", "en:no-added-salt",],
	quantity => "500 mg",
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"sodium" => {
						value => 1,
						unit => "g"
					},
					"salt" => {
						value => 2.5,    # above 0.0125
						unit => "g"
					},
				},
			},
		],
	},
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:no-added-sodium-or-no-added-salt-label-claim-but-sodium-or-salt-above-limitation',
	'added sodium detected beside label', 1
);

## omega-3, trigger with sum of epa and dha instead of ala
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:source-of-omega-3", "en:high-in-omega-3",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"eicosapentaenoic-acid" => {
						value => 0.01,    # sum is below 0.04 and 0.08
						unit => "g"
					},
					"docosahexaenoic-acid" => {
						value => 0.01,    # sum is below 0.04 and 0.08
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "500 mg",
};

check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-omega-3-label-claim-but-ala-or-sum-of-epa-and-dha-below-limitation',
	'under limitation for source of omega-3 label', 1
);

check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-omega-3-label-claim-but-ala-or-sum-of-epa-and-dha-below-limitation',
	'under limitation for high in omega-3 label', 1
);

# liquid
## low-energy liquid
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:low-energy",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"energy-kcal" => {
						value => 21,    # is above 20
						unit => "kcal"
					},
					"energy-kj" => {
						value => 81,    # is above 80
						unit => "kJ"
					},
				},
			},
		],
	},
	quantity => "1L",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-energy-label-claim-but-energy-above-limitation',
	'above limitation for low energy label', 1
);

## low-fat + semi-skimmed-milk
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:low-fat",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					fat => {
						value => 1.6,    # is above 1.5 (default limit) but below 1.8 (limit for skimmed-milk)
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "1L",
	categories_tags => ["en:semi-skimmed-milks"],
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-fat-label-claim-but-fat-above-limitation',
	'below limitation for low fat label for skimmed-milk', 0
);

## low saturated fat liquid
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:low-content-of-saturated-fat",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"saturated-fat" => {
						value => 0.8,    # above 0.75
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "1L",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-saturated-fat-label-claim-but-fat-above-limitation',
	'under limitation for low saturated fat label', 1
);

## low sugar liquid
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:low-sugar",],
	nutrition => {
		input_sets => [
			{
				preparation => "as_sold",
				per => "100g",
				per_quantity => 100,
				per_unit => "g",
				source => "packaging",
				source_description => "",
				nutrients => {
					"sugars" => {
						value => 3,    # above 2.5
						unit => "g"
					},
				},
			},
		],
	},
	quantity => "1L",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-sugar-label-claim-but-sugar-above-limitation',
	'above limitation for low sugar label', 1
);

## This claim shall not be used for natural mineral waters and other waters.
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:very-low-sodium", "en:very-low-salt",],
	quantity => "1,5 L",
	categories_tags => ["en:waters"],
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:very-low-sodium-or-very-low-salt-label-claim-but-sodium-or-salt-above-limitation',
	'label should not be triggered for waters category', 0
);

# check opposites labels, labels that should not appear at the same time on the same product
$product_ref = {labels_tags => ["en:pasteurized", "en:unpasteurized", "en:vegetarian"],};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:mutually-exclusive-tags-for-labels-non-vegetarian-and-labels-vegetarian',
	'having these labels should NOT trigger facet', 0
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:mutually-exclusive-tags-for-labels-pasteurized-and-labels-unpasteurized',
	'having these two labels should trigger facet', 1
);

done_testing();
