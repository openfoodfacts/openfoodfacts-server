#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::API qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

init_packaging_taxonomies_regexps();

# Tests for guess_language_of_packaging_text

is(guess_language_of_packaging_text("boîte", [qw(de es it fr)]), "fr");
is(guess_language_of_packaging_text("surgelé", [qw(de es it fr)]), "fr");
is(guess_language_of_packaging_text("something unknown", [qw(de es it fr)]), undef);

# Tests for get_checked_and_taxonomized_packaging_component_data

my @tests = (
	{
		lc => "en",
		input =>
			{"number_of_units" => 1, "shape" => "en:bottle", "material" => "en:glass", "weight_measured" => "55,40"},
		expected_output => {
			'material' => 'en:glass',
			'number_of_units' => 1,
			'shape' => 'en:bottle',
			'weight_measured' => 55.4,
		}
	},
	{
		desc => "Value 0 should be considered empty, all values are 0, return undef",
		lc => "en",
		input => {
			"number_of_units" => 0,
			"shape" => "0",
			"material" => "0",
			"weight_measured" => "0",
			"quantity_per_unit" => "0"
		},
		expected_output => undef,
	},
	{
		desc => "Value 0 should be considered empty, 1 value is not 0",
		lc => "en",
		input => {
			"number_of_units" => 0,
			"shape" => "bottle",
			"material" => "0",
			"weight_measured" => "0",
			"quantity_per_unit" => "0"
		},
		expected_output => {
			'shape' => 'en:bottle',
		}
	},
	{
		desc => "weights, float",
		lc => "en",
		input => {"weight_measured" => 21.5, "weight_specified" => 14.3},
		expected_output => {
			'weight_measured' => '21.5',
			'weight_specified' => '14.3'
		}
	},
	{
		desc => "weights, strings",
		lc => "en",
		input => {"weight_measured" => "21.5", "weight_specified" => "14.3"},
		expected_output => {
			'weight_measured' => '21.5',
			'weight_specified' => '14.3'
		}
	},
);

foreach my $test_ref (@tests) {
	$test_ref->{output} = get_checked_and_taxonomized_packaging_component_data($test_ref->{lc}, $test_ref->{input}, {});
	is_deeply($test_ref->{output}, $test_ref->{expected_output}, $test_ref->{desc}) or diag explain $test_ref;
}

# Tests for analyze_and_combine_packaging_data()

@tests = (

	[
		'packaging_text_en_glass_bottle',
		{
			lc => "en",
			packaging_text => "glass bottle"
		}
	],
	[
		'packaging_text_en_plastic_bottle',
		{
			lc => "en",
			packaging_text => "6 25cl transparent plastic bottle to recycle"
		}
	],
	[
		'packaging_text_fr_bouteille_en_plastique',
		{
			lc => "fr",
			packaging_text => "bouteille en plastique à jeter"
		}
	],
	[
		'packaging_text_fr_multiple',
		{
			lc => "fr",
			packaging_text => "barquette en plastique à jeter, film plastique à jeter, boîte en carton à recycler"
		}
	],
	[
		'packaging_text_fr_multiple_line_feeds',
		{
			lc => "fr",
			packaging_text => "barquette en plastique à jeter
film plastique à jeter
boîte en carton à recycler"
		}
	],
	[
		'packaging_text_fr_multiple_semi_colon',
		{
			lc => "fr",
			packaging_text => "barquette en plastique à jeter; film plastique à jeter; boîte en carton à recycler"
		}
	],
	[
		'packaging_text_fr_boite_cartonee_accents',
		{
			lc => "fr",
			packaging_text => "boîte cartonnée"
		}
	],
	[
		'packaging_text_fr_bouteille_pet',
		{
			lc => "fr",
			packaging_text => "bouteille PET"
		}
	],

	# Recycling instructions for the Netherlands
	# Tests for all types of conatiners
	[
		'packaging_text_nl_fles_glasbak',
		{
			lc => "nl",
			packaging_text => "fles in de glasbak"
		}
	],

	[
		'packaging_text_nl_doosje_oud_papier',
		{
			lc => "nl",
			packaging_text => "doosje bij oud papier"
		}
	],

	[
		'packaging_text_nl_over_plastic_afval',
		{
			lc => "nl",
			packaging_text => "overig bij plastic afval"
		}
	],
	[
		'packaging_text_nl_verpakking_bij_drankencartons',
		{
			lc => "nl",
			packaging_text => "verpakking bij drankencartons"
		}
	],

	[
		'packaging_text_nl_koffiepad_bij_gft',
		{
			lc => "nl",
			packaging_text => "koffiepad bij gft"
		}
	],

	[
		'packaging_text_nl_statiegeldfles',
		{
			lc => "nl",
			packaging_text => "statiegeldfles"
		}
	],

	[
		'packaging_text_nl_wel_pmd',
		{
			lc => "nl",
			packaging_text => "wel pmd"
		}
	],

	# some free texts in dutch
	[
		'packaging_text_nl_plastic_fles',
		{
			lc => "nl",
			packaging_text => "plastiek fles"
		}
	],

	[
		'packaging_text_nl_metalen_blikje',
		{
			lc => "nl",
			packaging_text => "metalen blikje"
		}
	],

	# three recycling instructions
	[
		'packaging_text_nl_three_instructions',
		{
			lc => "nl",
			packaging_text => "schaal bij plastic afval, folie bij plastic afval, karton bij oud papier"
		}
	],

	# sentence glazen pot + deksel
	[
		'packaging_text_nl_glazen_pot_met_deksel',
		{
			lc => "nl",
			packaging_text => "1 glazen pot, 1 metalen deksel"
		}
	],

	# check that we use the most specific material (e.g. PET instead of plastic)
	[
		'packaging_text_fr_bouteille_plastique_pet',
		{
			lc => "fr",
			packaging_text => "bouteille plastique PET"
		}
	],

	# Merge packaging text data with existing packagings structure
	# 20230213: packaging text is now ignored if there is an existing packagings structure
	[
		'merge_en_add_packaging',
		{
			lc => "en",
			packaging_text => "aluminium can",
			packagings => [
				{
					'shape' => 'en:box',
					'material' => 'en:cardboard',
				}
			]
		}
	],
	# 20230213: packaging text is now ignored if there is an existing packagings structure
	[
		'merge_en_merge_packaging_add_property',
		{
			lc => "en",
			packaging_text => "plastic box",
			packagings => [
				{
					'shape' => 'en:box',
					'units' => 2
				}
			]
		}
	],
	# 20230213: packaging text is now ignored if there is an existing packagings structure
	[
		'merge_en_merge_packaging_more_specific_property',
		{
			lc => "en",
			packaging_text => "rPET plastic box",
			packagings => [
				{
					'shape' => 'en:box',
					'material' => 'en:plastic',
				}
			]
		}
	],
	[
		'merge_en_merge_packaging_less_specific_property',
		{
			lc => "en",
			packaging_text => "plastic box",
			packagings => [
				{
					'shape' => 'en:box',
					'material' => 'en:recycled-plastic',
				}
			]
		}
	],
	# Note: as of 2022/11/29, packaging tags are not used as input anymore
	[
		'merge_en_merge_packaging_tag_and_packaging_text',
		{
			lc => "en",
			packaging => "plastic, box, paper bag",
			packaging_text => "plastic box",
		}
	],
	[
		'merge_en_merge_packaging_tag_and_packaging_text_2',
		{
			lc => "en",
			packaging => "PET, box, paper bag",
			packaging_text => "plastic box, kraft paper",
		}
	],

	# Plurals
	[
		'packaging_text_en_plurals',
		{
			lc => "en",
			packaging_text => "6 cans, 2 boxes, 2 knives, 3 spoons, 1 utensil"
		}
	],

	[
		'packaging_text_fr_bouteille_en_plastique_pet',
		{
			lc => "fr",
			packaging_text => "bouteille en plastique pet recyclé",
		}
	],

	# Quantity contained and number of units
	# the quantity contained must not be mistaken for the number of units

	[
		'packaging_text_en_quantity_6_plastic_bottles',
		{
			lc => "en",
			packaging_text => "6 plastic bottles"
		}
	],
	[
		'packaging_text_en_quantity_1_l_plastic_bottles',
		{
			lc => "en",
			packaging_text => "1 L plastic bottle"
		}
	],
	[
		'packaging_text_en_quantity_25_cl_bottles',
		{
			lc => "en",
			packaging_text => "25 cl bottle"
		}
	],
	[
		'packaging_text_fr_quantity_6_bouteilles_plastiques_de_25_cl',
		{
			lc => "fr",
			packaging_text => "6 bouteilles plastiques de 25 cl"
		}
	],

	# Packaging text with line feeds
	[
		'packaging_text_fr_line_feeds',
		{
			lc => "fr",
			packaging_text => "1 bouteille en plastique opaque PE-HD de 1L à recycler
1 bouchon en plastique opaque PE-HD à recycler
1 opercule en métal à recycler
1 étiquette en papier à recycler"
		}
	],
	# Some unknown shape
	[
		'packaging_text_fr_unknown_shape',
		{
			lc => "fr",
			packaging_text => "1 bouteille en plastique opaque PE-HD de 1L à recycler
1 bouchon en plastique opaque PE-HD à recycler
1 opercule à recycler
1 machin en papier à recycler"
		}
	],

	# Bio-based synonyms
	[
		'packaging_text_fr_biosource',
		{
			lc => "fr",
			packaging_text =>
				"1 bouteille en PET biosourcé, 1 couvercle en PET bio-sourcé, 1 cuillere en pet bio source",
		}
	],
	[
		'packaging_text_en_biobased',
		{
			lc => "en",
			packaging_text => "1 bio-based PET bottle, 1 bio-sourced PET lid",
		}
	],
	[
		'packaging_text_fr_1_etui',
		{
			lc => "fr",
			packaging_text => "1 étui en carton FSC à recycler, 2 etuis en plastique, 1 etui en métal",
		}
	],

	[
		'packaging_text_fr_1_etuit_spelling',
		{
			lc => "fr",
			packaging_text => "étuit en carton à recycler, bouteille en verre à recycler, capsule en métal à recycler",
		}
	],

	[
		'packaging_text_fr_opercule_en_aluminium',
		{
			lc => "fr",
			packaging_text => "opercule en aluminium",
		}
	],
	[
		'packaging_fr_redundant_entries',
		{
			lc => "fr",
			packaging_text =>
				"Verre; Couvercle; Plastique; Pot; Petit Format; couvercle en plastique; opercule aluminium; pot en verre",
		}
	],

	[
		'packaging_fr_coffee_capsules',
		{
			lc => "fr",
			packaging_text => "Capsules en aluminium à recycler",
			categories_tags => ["en:coffees"],
		}
	],

	[
		'packaging_fr_cartonnette',
		{
			lc => "fr",
			packaging_text => "1 cartonnette à recycler",
		}
	],

	[
		'packaging_en_cardboard',
		{
			lc => "en",
			packaging_text => "1 cardboard",
		}
	],

	[
		'packaging_en_cardboard_box',
		{
			lc => "en",
			packaging_text => "1 cardboard box",
		}
	],

	[
		'packaging_fr_support_carton',
		{
			lc => "fr",
			packaging_text => "1 support carton",
		}
	],

	# New packaging shapes from Citeo
	[
		'packaging_en_citeo_shapes',
		{
			lc => "en",
			packaging_text =>
				"Plastic tumbler; Wooden crate; Cardboard case; Strings; Plastic ties; Plastic blister wrap; paper basket; individual capsules",
		}
	],
	[
		'packaging_fr_citeo_shapes',
		{
			lc => "fr",
			packaging_text =>
				"Gobelet en plastique; cageots en bois; caisse en carton; ficelle; liens plastiques; blister en plastique; panier en papier; capsules individuelles",
		}
	],

	# Special test for cardboard that can be both a material and a shape
	[
		'en-cardboard-box-to-recycle',
		{
			lc => "en",
			packaging_text => "Cardboard box to recycle",
		}
	],

	# in glass container should trigger the glass material, which should then be overriden by its clear glass child
	[
		'en-clear-glass-bottle-in-glass-container',
		{
			lc => "en",
			packaging_text => "Clear glass bottle in glass container",
		}
	],

	[
		'en-1-pet-plastic-bottle',
		{
			lc => "en",
			packaging_text => "1 PET plastic bottle",
		}
	],

	# recycling code should apply to all languages
	[
		'en-aa-84-c-x',
		{
			lc => "aa",
			packaging_text => "84-C/X",
		}
	],

	# empty entry
	[
		'en-empty-entry',
		{
			lc => "en",
			packaging_text => "",
		}
	],

	[
		'en-unrecognized-elements',
		{
			lc => "en",
			packaging_text => "Some words that do not look like what we expect at all",
		}
	],

	# dots were not parsed correctly
	[
		'fr-dot-to-separate-components',
		{
			lc => "fr",
			packaging_text => "Film plastique à jeter. Étui carton à recycler.",
		}
	],

	# comma inside a number: don't split
	[
		'fr-comma-inside-a-number',
		{
			lc => "fr",
			packaging_text => "6 bouteilles en plastique transparent PET de 1,5 L à recycler",
		}
	],

	# comma without spaces, not in a number: split
	[
		'fr-comma-without-space',
		{
			lc => "fr",
			packaging_text => "1 boîte en métal,4 bouteilles (plastique).",
		}
	],

);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test

	# Response structure to keep track of warnings and errors
	# Note: currently some warnings and errors are added,
	# but we do not yet do anything with them
	my $response_ref = get_initialized_response();

	analyze_and_combine_packaging_data($product_ref, $response_ref);

	# Save the result

	if ($update_expected_results) {
		open(my $result, ">:encoding(UTF-8)", "$expected_result_dir/$testid.json")
			or die("Could not create $expected_result_dir/$testid.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close($result);
	}

	# Compare the result with the expected result

	if (open(my $expected_result, "<:encoding(UTF-8)", "$expected_result_dir/$testid.json")) {

		local $/;    #Enable 'slurp' mode
		my $expected_product_ref = $json->decode(<$expected_result>);
		is_deeply($product_ref, $expected_product_ref)
			or diag explain {
			testid => $testid,
			product_ref => $product_ref,
			expected_product_ref => $expected_product_ref
			};
	}
	else {
		fail("could not load $expected_result_dir/$testid.json");
		diag explain $product_ref;
	}
}

my $product_ref = {
	lc => "fr",
	packagings => [
		{
			shape => 'fr:bouteille',
			material => 'en:pet',
			recycling => 'à jeter'
		},
	],
};

ProductOpener::Packaging::canonicalize_packaging_components_properties($product_ref);

is_deeply(
	$product_ref->{packagings},
	[
		{
			'material' => 'en:pet-1-polyethylene-terephthalate',
			'recycling' => 'en:discard',
			'shape' => 'en:bottle'
		},
	]
) or diag explain $product_ref->{packagings};

# Agregate components by parent materials

$product_ref = {
	lc => "en",
	product_quantity => 200,
	packagings => [
		{
			material => 'pet',
		},
		{
			material => 'paper',
			weight_specified => 10,
		},
		{
			material => 'steel',
			weight_measured => 100,
			number_of_units => 5,
		},
		{
			material => 'aluminium',
			weight_measured => 10,
			number_of_units => 4,
		},
		{
			material => 'some unknown material',
			number_of_units => 2,
		},
	],
};

ProductOpener::Packaging::canonicalize_packaging_components_properties($product_ref);
ProductOpener::Packaging::aggregate_packaging_by_parent_materials($product_ref);
ProductOpener::Packaging::compute_weight_stats_for_parent_materials($product_ref);

is_deeply(
	$product_ref->{packagings_materials},
	{
		'all' => {
			'weight' => 550,
			'weight_100g' => '275',
			'weight_percent' => 100
		},
		'en:metal' => {
			'weight' => 540,
			'weight_100g' => '270',
			'weight_percent' => '98.1818181818182'
		},
		'en:paper-or-cardboard' => {
			'weight' => 10,
			'weight_100g' => '5',
			'weight_percent' => '1.81818181818182'
		},
		'en:plastic' => {},
		'en:unknown' => {}
	}

) or diag explain $product_ref->{packagings_materials};

# No product_quantity

$product_ref = {
	lc => "en",
	packagings => [
		{
			material => 'steel',
			weight_measured => 100,
			number_of_units => 5,
		},
	],
};

ProductOpener::Packaging::canonicalize_packaging_components_properties($product_ref);
ProductOpener::Packaging::aggregate_packaging_by_parent_materials($product_ref);
ProductOpener::Packaging::compute_weight_stats_for_parent_materials($product_ref);

is_deeply(
	$product_ref->{packagings_materials},
	{
		'all' => {
			'weight' => 500,
			'weight_percent' => 100
		},
		'en:metal' => {
			'weight' => 500,
			'weight_percent' => 100
		}
	}

) or diag explain $product_ref->{packagings_materials};

is($product_ref->{packagings_materials_main}, "en:metal");

# 0 product_quantity

$product_ref = {
	lc => "en",
	product_quantity => 0,
	packagings => [
		{
			material => 'steel',
			weight_measured => 100,
			number_of_units => 5,
		},
	],
};

ProductOpener::Packaging::canonicalize_packaging_components_properties($product_ref);
ProductOpener::Packaging::aggregate_packaging_by_parent_materials($product_ref);
ProductOpener::Packaging::compute_weight_stats_for_parent_materials($product_ref);

is_deeply(
	$product_ref->{packagings_materials},
	{
		'all' => {
			'weight' => 500,
			'weight_percent' => 100
		},
		'en:metal' => {
			'weight' => 500,
			'weight_percent' => 100
		}
	}

) or diag explain $product_ref->{packagings_materials};

# Empty product hash

$product_ref = {};

ProductOpener::Packaging::canonicalize_packaging_components_properties($product_ref);
ProductOpener::Packaging::aggregate_packaging_by_parent_materials($product_ref);
ProductOpener::Packaging::compute_weight_stats_for_parent_materials($product_ref);

is_deeply(
	$product_ref->{packagings_materials},
	{

	}

) or diag explain $product_ref->{packagings_materials};

done_testing();
