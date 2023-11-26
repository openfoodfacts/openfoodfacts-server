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

# vegan label but non-vegan ingredients
# unknown ingredient -> warnings
my $product_ref = {
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

# labels claim vs input nutrition data, based on EU regulation: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A02006R1924-20141213
# TODO TESTS WITH CATEGORIES AND ALL LABELS IN CASE TAXO CHANGE OVER TIME, SO THAT IT IS DETECTED WHEN RUNNING TESTS
# product quantity warnings and errors
# all labels and alerts maximum (minimum) when there are 2 levels and it should be below (above) an expected limitation
# all positives

# non-EU countries, should not raise facet
$product_ref = {
	countries_tags => ["en:united-states",],
	labels_tags => ["en:low-energy",],
	nutriments => {
		"energy-kcal_value" => 100,    # is above limitation
		"energy-kj_value" => 420,    # is not above limitation
	},
	quantity => "500 mg",
	},
	check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-energy-label-claim-but-energy-above-limitation',
	'non-EU countries, should not raise facet',
	0
	);

# solid
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => [
		"en:low-energy", "en:energy-free",
		"en:low-fat", "en:no-fat",
		"en:high-monounsaturated-fat", "en:rich-in-polyunsaturated-fatty-acids",
		"en:low-sugar", "en:no-sugar",
		"en:low-sodium", "en:low-salt",
		"en:very-low-sodium", "en:very-low-salt",
		"en:no-sodium", "en:no-salt",
		"en:no-added-sodium", "en:no-added-salt",
		"en:source-of-fibre", "en:high-fibres",
		"en:vitamin-a-source", "en:rich-in-vitamin-a",
		"en:vitamin-d-source", "en:rich-in-vitamin-d",
		"en:vitamin-e-source", "en:rich-in-vitamin-e",
		"en:vitamin-c-source", "en:rich-in-vitamin-c",
		"en:vitamin-b1-source", "en:rich-in-vitamin-b1",
		"en:vitamin-b2-source", "en:rich-in-vitamin-b2",
		"en:vitamin-b3-source", "en:rich-in-vitamin-b3",
		"en:vitamin-b6-source", "en:rich-in-vitamin-b6",
		"en:vitamin-b9-source", "en:rich-in-vitamin-b9",
		"en:vitamin-b12-source", "en:rich-in-vitamin-b12",
		"en:source-of-biotin", "en:high-in-biotin",
		"en:source-of-pantothenic-acid", "en:high-in-pantothenic-acid",
		"en:calcium-source", "en:high-in-calcium",
		"en:phosphore-source", "en:high-in-phosphore",
		"en:iron-source", "en:high-in-iron",
		"en:magnesium-source", "en:high-in-magnesium",
		"en:zinc-source", "en:high-in-zinc",
		"en:iodine-source", "en:high-in-iodine",
		"en:source-of-omega-3", "en:high-in-omega-3",
	],
	nutriments => {
		"energy-kcal_value" => 100,    # is above 40 and 4
		"energy-kj_value" => 420,    # is above 170 and 17
		fat_100g => 4,    # is above 3 and 0.5
		"monounsaturated-fat_100g" => 1,    # less than 45% of the fat
		"polyunsaturated-fat_100g" => 1,    # less than 45% of the fat
		sugars_100g => 6,    # above 5 and 0.5
		sodium_100g => 0.4,    # above 0.12 and 0.04 and 0.005
		salt_100g => 1,    # above 0.3 and 0.1 and 0.0125
		fiber_100g => 2,    # below 3 and 6
		"vitamin-a_100g" => 0.0007,    # below 0.0008 and 0.0016
		"vitamin-d_100g" => 0.000004,    # below 0.000005 and 0.00001
		"vitamin-e_100g" => 0.009,    # below 0.01 and 0.02
		"vitamin-c_100g" => 0.05,    # below 0.06 and 0.12
		"vitamin-b1_100g" => 0.0013,    # below 0.0014 and 0.0028
		"vitamin-b2_100g" => 0.0015,    # below 0.0016 and 0.0032
		"vitamin-b3_100g" => 0.017,    # below 0.018 and 0.036
		"vitamin-b6_100g" => 0.001,    # below 0.002 and 0.004
		"vitamin-b9_100g" => 0.0001,    # below 0.0002 and 0.0004
		"vitamin-b12_100g" => 0.0000009,    # below 0.000001 and 0.000002
		"biotin_100g" => 0.00014,    # below 0.00015 and 0.0003
		"pantothenic-acid_100g" => 0.005,    # below 0.006 and 0.012
		"calcium_100g" => 0.7,    # below 0.8 and 1.6
		"phosphorus_100g" => 0.7,    # below 0.8 and 1.6
		"iron_100g" => 0.013,    # below 0.014 and 0.028
		"magnesium_100g" => 0.2,    # below 0.3 and 0.6
		"zinc_100g" => 0.014,    # below 0.015 and 0.03
		"iodine_100g" => 0.00014,    # below 0.00015 and 0.0003
		"alpha-linolenic-acid_100g" => 0.2    # below 0.3 and 0.6
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
	'under limitation for high-monounsaturated label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-polyunsaturated-fatty-acids-label-claim-but-polyunsaturated-fat-under-limitation',
	'under limitation for high-polyunsaturated label', 1
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
	'en:vitamin-a-source-label-claim-but-vitamin-a-below-0.0008',
	'under limitation for vitamin-a source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-a-label-claim-but-vitamin-a-below-0.0016',
	'under limitation for rich in vitamin-a label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-d-source-label-claim-but-vitamin-d-below-5e-06',
	'under limitation for vitamin-d source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-d-label-claim-but-vitamin-d-below-1e-05',
	'under limitation for rich in vitamin-d label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-e-source-label-claim-but-vitamin-e-below-0.01',
	'under limitation for vitamin-e source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-e-label-claim-but-vitamin-e-below-0.02',
	'under limitation for rich in vitamin-e label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-c-source-label-claim-but-vitamin-c-below-0.06',
	'under limitation for vitamin-c source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-c-label-claim-but-vitamin-c-below-0.12',
	'under limitation for rich in vitamin-c label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b1-source-label-claim-but-vitamin-b1-below-0.0014',
	'under limitation for vitamin-b1 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b1-label-claim-but-vitamin-b1-below-0.0028',
	'under limitation for rich in vitamin-b1 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b2-source-label-claim-but-vitamin-b2-below-0.0016',
	'under limitation for vitamin-b3 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b2-label-claim-but-vitamin-b2-below-0.0032',
	'under limitation for rich in vitamin-b3 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b3-source-label-claim-but-vitamin-b3-below-0.018',
	'under limitation for vitamin-b3 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b3-label-claim-but-vitamin-b3-below-0.036',
	'under limitation for rich in vitamin-b3 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b6-source-label-claim-but-vitamin-b6-below-0.002',
	'under limitation for vitamin-b6 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b6-label-claim-but-vitamin-b6-below-0.004',
	'under limitation for rich in vitamin-b6 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b9-source-label-claim-but-vitamin-b9-below-0.0002',
	'under limitation for vitamin-b9 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b9-label-claim-but-vitamin-b9-below-0.0004',
	'under limitation for rich in vitamin-b9 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:vitamin-b12-source-label-claim-but-vitamin-b12-below-1e-06',
	'under limitation for vitamin-b12 source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-vitamin-b12-label-claim-but-vitamin-b12-below-2e-06',
	'under limitation for rich in vitamin-b12 label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-biotin-label-claim-but-biotin-below-0.00015',
	'under limitation for biotin source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-biotin-label-claim-but-biotin-below-0.0003',
	'under limitation for high in biotin label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:source-of-pantothenic-acid-label-claim-but-pantothenic-acid-below-0.006',
	'under limitation for pantothenic-acid source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-pantothenic-acid-label-claim-but-pantothenic-acid-below-0.012',
	'under limitation for high in pantothenic-acid label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:calcium-source-label-claim-but-calcium-below-0.8',
	'under limitation for calcium source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-calcium-label-claim-but-calcium-below-1.6',
	'under limitation for high in calcium label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:phosphore-source-label-claim-but-phosphorus-below-0.8',
	'under limitation for phosphore source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-phosphore-label-claim-but-phosphorus-below-1.6',
	'under limitation for high in phosphore label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:iron-source-label-claim-but-iron-below-0.014',
	'under limitation for iron source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-iron-label-claim-but-iron-below-0.028',
	'under limitation for high in iron label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:magnesium-source-label-claim-but-magnesium-below-0.3',
	'under limitation for magnesium source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-magnesium-label-claim-but-magnesium-below-0.6',
	'under limitation for high in magnesium label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:zinc-source-label-claim-but-zinc-below-0.015',
	'under limitation for zinc source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-zinc-label-claim-but-zinc-below-0.03',
	'under limitation for high in zinc label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:iodine-source-label-claim-but-iodine-below-0.00015',
	'under limitation for iodine source label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-in-iodine-label-claim-but-iodine-below-0.0003',
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
## same for poly-
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:high-monounsaturated-fat", "en:rich-in-polyunsaturated-fatty-acids",],
	nutriments => {
		"energy-kcal_value" => 200,    # needed to calculate computed energy values
		"energy-kj_value" => 840,    # needed to calculate computed energy values
		fat_100g => 4,
		fat_value => 4,    # needed to calculate computed energy values
		"monounsaturated-fat_100g" => 3,    # more than 45% of the fat
		"polyunsaturated-fat_100g" => 3,    # more than 45% of the fat
		"carbohydrates_value" => 10,    # needed to calculate computed energy values
		"proteins_value" => 40,    # needed to calculate computed energy values
								   # "energy-kcal_value_computed" => 276, # for information only
								   # "energy-kj_value_computed" => 1168, # for information only
	},
	quantity => "500 mg",
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:high-monounsaturated-fat-label-claim-but-monounsaturated-fat-under-limitation',
	'under limitation of total energy for high-monounsaturated label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:rich-in-polyunsaturated-fatty-acids-label-claim-but-polyunsaturated-fat-under-limitation',
	'under limitation of total energy for high-polyunsaturated label', 1
);
## same as previous for fibres
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:source-of-fibre", "en:high-fibres",],
	nutriments => {
		"energy-kcal_value" => 400,    # needed to calculate computed energy values
		"energy-kj_value" => 1800,    # needed to calculate computed energy values
		fat_value => 60,    # needed to calculate computed energy values
		"carbohydrates_value" => 60,    # needed to calculate computed energy values
		"proteins_value" => 60,    # needed to calculate computed energy values
								   # "energy-kcal_value_computed" => 1020, # for information only
								   # "energy-kj_value_computed" => 4260, # for information only
		fiber_100g => 7,    # above 6
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
## same as previous for proteins
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:source-of-proteins", "en:high-proteins",],
	nutriments => {
		"energy-kcal_value" => 400,    # needed to calculate computed energy values
		"energy-kj_value" => 1800,    # needed to calculate computed energy values
		fat_value => 60,    # needed to calculate computed energy values
		"carbohydrates_value" => 60,    # needed to calculate computed energy values
		"proteins_value" => 21,    # needed to calculate computed energy values
								   # "energy-kcal_value_computed" => 864, # for information only
								   # "energy-kj_value_computed" => 3597, # for information only
		proteins_100g => 21,    # above 20 and 12
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
	ingredients_tags => ["en:cane-sugar", "en:added-sugar", "en:disaccharide", "en:salt",],
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:no-added-sugar-label-claim-but-contains-added-sugar',
	'added sugar detected beside label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:no-added-sodium-or-no-added-salt-label-claim-but-sodium-or-salt-above-limitation',
	'added sodium detected beside label', 1
);
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:no-added-sodium-or-no-added-salt-label-claim-but-sodium-or-salt-above-limitation',
	'added salt detected beside label', 1
);

## omega-3, trigger with sum of epa and dha instead of ala
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:source-of-omega-3", "en:high-in-omega-3",],
	nutriments => {
		"eicosapentaenoic-acid_100g" => 0.01,
		"docosahexaenoic-acid_100g" => 0.01,    # sum is below 0.04 and 0.08
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
## low-fat + semi-skimmed-milk
$product_ref = {
	countries_tags => ["en:croatia",],
	labels_tags => ["en:low-fat",],
	nutriments => {
		fat_100g => 1.6,    # is above 1.5 (default limit) but below 1.8 (limit for skimmed-milk)
	},
	quantity => "1L",
	categories_tags => ["en:semi-skimmed-milks"],
};
check_quality_and_test_product_has_quality_tag(
	$product_ref,
	'en:low-fat-label-claim-but-fat-above-limitation',
	'below liitation for low fat label for skimmed-milk', 0
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

done_testing();
