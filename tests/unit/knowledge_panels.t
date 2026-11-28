#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use JSON::MaybeXS;
use Data::Dumper;
$Data::Dumper::Terse = 1;

my $json = JSON::MaybeXS->new->allow_nonref->canonical;

use ProductOpener::KnowledgePanels qw/:all/;
use ProductOpener::LoadData qw/load_data/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results normalize_product_for_test_comparison/;
use ProductOpener::API qw/get_initialized_response/;
use ProductOpener::Display qw/$knowledge_panels_options_ref/;
use ProductOpener::Products qw/analyze_and_enrich_product_data/;
use ProductOpener::Tags qw/get_property/;
use boolean qw/true/;
use ProductOpener::Config qw/%options/;

is(
	ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline('
test
muti-line string
a slash A / B and anti-slash \
HTML <a href="https://url.com">test</a>
'),
	'"\ntest\nmuti-line string\na slash A / B and anti-slash \\\\\nHTML <a href=\"https://url.com\">test</a>\n"'
);

is(
	ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline(
		'<a href="https://agribalyse.ademe.fr/app/aliments/[% product.environmental_score_data.agribalyse.code %]">'),
	'"<a href=\"https://agribalyse.ademe.fr/app/aliments/[% product.environmental_score_data.agribalyse.code %]\">"'
);

# The escaped value has to be valid JSON on its own: it is interpolated into a JSON string in the
# panel, and the panel is not built at all if it does not parse.
# JSON does not allow the control characters unescaped inside a string, and the backslash has to be
# escaped before the quote, otherwise the escaper used to leave a quote unescaped when the value
# already contained a backslash.

foreach my $test_case (
	['a plain value', 'a value', '"a value"'],
	['a quote', 'say "hello"', '"say \\"hello\\""'],
	['a trailing backslash', 'a value\\', '"a value\\\\"'],
	['a backslash before a quote', 'a\\"b', '"a\\\\\\"b"'],
	['a tab', "a\tvalue", '"a\\u0009value"'],
	['a control character', "a\x01value", '"a\\u0001value"'],
	['a newline', "a\nvalue", '"a\\nvalue"'],
	['a carriage return', "a\rvalue", '"a\\nvalue"'],
	# \R matches the vertical tab and the form feed too, and they become \n
	['a vertical tab', "a\x0bvalue", '"a\\nvalue"'],
	['a form feed', "a\x0cvalue", '"a\\nvalue"'],
	['a delete character', "a\x7fvalue", '"a\\u007fvalue"'],
	['an undefined value', undef, '""'],
	)
{
	my ($desc, $value, $expected) = @{$test_case};
	my $escaped = ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline($value);
	is($escaped, $expected, "$desc is escaped for a JSON string");

	my $ok = eval {decode_json('{"h":' . $escaped . '}')->{h}; 1};
	ok($ok, "$desc produces valid JSON") or diag($@);
}

# The same for the variant that collapses whitespace: the value must still be valid JSON

foreach my $test_case (
	['a tab', "a\t\tvalue", '"a value"'],
	['a control character', "a\x01value", '"a\\u0001value"'],
	['a backslash before a quote', 'a\\"b', '"a\\\\\\"b"'],
	)
{
	my ($desc, $value, $expected) = @{$test_case};
	my $escaped
		= ProductOpener::KnowledgePanels::convert_multiline_string_to_singleline_without_line_breaks_and_extra_spaces(
		$value);
	is($escaped, $expected, "$desc is escaped for a JSON string (without line breaks)");
}

load_data();

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	{
		'id' => 'en-nutriscore-serving-size-error',
		'product' => {
			lc => "en",
			categories => "biscuits",
			categories_tags => ["en:biscuits"],
			nutrition_data_per => "serving",
			serving_size => "20",
			ingredients_text => "100% fruits",
			nutrition => {
				aggregated_set => {
					nutrients => {
						energy => {
							value => 2591
						},
						fat => {
							value => 50
						},
						"saturated-fat" => {
							value => 9.7
						},
						sugars => {
							value => 5.1
						},
						salt => {
							value => 0
						},
						sodium => {
							value => 0
						},
						proteins => {
							value => 29
						},
						fiber => {
							value => 5.5
						}
					}
				}
			}
		},
		target_lc => 'fr',
		target_cc => 'fr'
	},
	# root panel with ingredients and nutrition first, then collapsed health and environment cards
	{
		'id' => 'en-ingredients-nutrition-first',
		'product' => {
			lc => "en",
			categories => "biscuits",
			categories_tags => ["en:biscuits"],
			ingredients_text => "wheat flour, sugar, palm oil, hazelnuts, emulsifier: soy lecithin",
			nutrition => {
				aggregated_set => {
					preparation => "as_sold",
					per => "100g",
					nutrients => {
						energy => {value => 2252},
						fat => {value => 30.9},
						"saturated-fat" => {value => 10.6},
						sugars => {value => 56.3},
						salt => {value => 0.107},
						sodium => {value => 0.0428},
						proteins => {value => 6.3},
						fiber => {value => 3.4},
					}
				}
			}
		},
		options => {activate_knowledge_panels_ingredients_nutrition_first => 1},
		target_lc => 'en',
		target_cc => 'world'
	},
	# added sugars tests
	# english test with "with added sugar" ingredient
	{
		'id' => 'en-ingredients-with-added-sugar',
		'product' => {
			lc => "en",
			ingredients_text => "Sugar, wheat flour, butter",
		},
		target_lc => 'en',
		target_cc => 'us'
	},
	# added sugars in input nutrition facts
	{
		'id' => 'en-nutrition-facts-added-sugars',
		'product' => {
			lc => "en",
			ingredients_text => "Sugar, wheat flour, butter",
			nutrition => {
				input_sets => [
					{
						preparation => "as_sold",
						per => "100g",
						per_quantity => "100",
						per_unit => "g",
						source => "packaging",
						nutrients => {
							"added-sugars" => {
								value_string => "20",
								value => 20,
								unit => "g",
							},
						}
					}
				]
			},
		},
		target_lc => 'en',
		target_cc => 'us'
	},
	# "no nutrition facts on the packaging" is ticked: no action to add the nutrition facts
	{
		'id' => 'en-no-nutrition-data-on-packaging',
		'product' => {
			lc => "en",
			ingredients_text => "Sugar, wheat flour, butter",
			nutrition => {
				no_nutrition_data_on_packaging => true,
			},
		},
		target_lc => 'en',
		target_cc => 'us'
	},
	# NOVA markers in ingredients
	{
		'id' => 'en-nova-markers',
		'product' => {
			lc => "en",
			ingredients_text =>
				"Hydrolised wheat flour, emulsifier: soy lecithin, baking powder, rice starch, barley malt extract, colour: caramel, acidifier: citric acid, soy proteins, refined palm oil",
		},
		target_lc => 'en',
		target_cc => 'us'
	},
	# NOVA group not computed because too many ingredients are not recognized:
	# the NOVA panel and attribute should explain why
	{
		'id' => 'en-nova-too-many-unknown-ingredients',
		'product' => {
			lc => "en",
			categories_tags => ["en:cheeses"],
			ingredients_text => "some ingredient that we do not recognize",
		},
		target_lc => 'en',
		target_cc => 'us'
	},
);

foreach my $test_ref (@tests) {

	my $testid = $test_ref->{"id"};
	my $product_ref = $test_ref->{"product"};
	my $target_lc = $test_ref->{"target_lc"};
	my $target_cc = $test_ref->{"target_cc"};

	# Run the test

	# Response structure to keep track of warnings and errors
	# Note: currently some warnings and errors are added,
	# but we do not yet do anything with them
	my $response_ref = get_initialized_response();

	analyze_and_enrich_product_data($product_ref, $response_ref);
	my $options_ref = {};
	my $request_ref = {};
	initialize_knowledge_panels_options($options_ref, $request_ref);
	%$options_ref = (%$options_ref, %{$test_ref->{options} // {}});

	create_knowledge_panels($product_ref, $target_lc, $target_cc, $options_ref, $request_ref);

	normalize_product_for_test_comparison($product_ref);
	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

# Additives flagged by ANSES get a source line, read from the additive's own taxonomy entry only
{
	my $product_ref = {lc => "en", ingredients_text => "sugar, colour: e100, acid: e330, stabiliser: e450iv"};
	analyze_and_enrich_product_data($product_ref, get_initialized_response());
	my $options_ref = {};
	initialize_knowledge_panels_options($options_ref, {});
	create_knowledge_panels($product_ref, "en", "world", $options_ref, {});
	my $anses_source_url
		= "https://www.anses.fr/fr/content/rapport-oqali-bilan-et-%C3%A9volution-de-lutilisation-des-additifs-dans-les-produits-transform%C3%A9s";
	my $e100_elements_ref = $product_ref->{knowledge_panels_en}{"additive_en:e100"}{elements};
	is(scalar @$e100_elements_ref, 2, "flagged additive has the functions and ANSES elements");
	is(
		$e100_elements_ref->[1]{text_element},
		{
			html =>
				"The French food safety agency (ANSES) lists this additive among the additives that should be monitored. Additives on this list meet at least one of these criteria: some people may consume more than the acceptable daily intake; there is no legal maximum amount in foods; the acceptable daily intake was lowered after a recent re-evaluation; or the additive can be present as nanoparticles. Being on this list does not mean the additive is unsafe at usual levels of consumption.",
			source_text => "ANSES - Oqali (2019)",
			source_url => $anses_source_url,
			source_language => "fr",
		},
		"flagged additive ANSES element"
	);
	is(
		scalar(
			grep {($_->{text_element}{source_url} // "") eq $anses_source_url}
				@{$product_ref->{knowledge_panels_en}{"additive_en:e330"}{elements}}
		),
		0,
		"unflagged additive has no ANSES element"
	);
	is(
		scalar(
			grep {($_->{text_element}{source_url} // "") eq $anses_source_url}
				@{$product_ref->{knowledge_panels_en}{"additive_en:e450iv"}{elements} // []}
		),
		0,
		"unflagged child of a flagged additive has no ANSES element"
	);
	is(get_property("additives", "en:e450", "anses_additives_of_interest:en"), "yes", "flag on the parent");
	is(get_property("additives", "en:e450iv", "anses_additives_of_interest:en"),
		undef, "flag not inherited by the child");

	like(
		$e100_elements_ref->[0]{text_element}{html},
		qr{<strong>Functions</strong>:</p>\n<ul>\n<li><strong>Colour</strong>: \S.*</li>\n</ul>},
		"additive lists its function with its purpose"
	);
}

# Additive functions come from the additive's own entry, else from its parent
{
	my $product_ref = {lc => "en", ingredients_text => "sugar, colour: e100i, stabiliser: e450iv"};
	analyze_and_enrich_product_data($product_ref, get_initialized_response());
	my $options_ref = {};
	initialize_knowledge_panels_options($options_ref, {});
	create_knowledge_panels($product_ref, "en", "world", $options_ref, {});
	my %functions = map {
		my $id = $_;
		$id => [map {$_->{text_element}{html} =~ m{<li><strong>([^<]+)</strong>}g}
				@{$product_ref->{knowledge_panels_en}{"additive_$id"}{elements} // []}]
	} ("en:e100i", "en:e450iv");
	is(
		\%functions,
		{
			"en:e100i" => ["Colour"],
			"en:e450iv" => ["Emulsifier", "Humectant", "Sequestrant", "Stabiliser", "Thickener"],
		},
		"own functions, or the parent's when the additive has none"
	);
}

# The root panel lists ingredients and nutrition first only when the option is set
foreach my $ingredients_nutrition_first (0, 1) {
	my $product_ref = {
		lc => "en",
		categories_tags => ["en:biscuits"],
		ingredients_text => "wheat flour, sugar",
		nutrition => {aggregated_set => {nutrients => {energy => {value => 2000}, sugars => {value => 20}}}},
	};
	analyze_and_enrich_product_data($product_ref, get_initialized_response());
	my $options_ref = {};
	initialize_knowledge_panels_options($options_ref, {});
	$options_ref->{activate_knowledge_panels_ingredients_nutrition_first} = $ingredients_nutrition_first;
	create_knowledge_panels($product_ref, "en", "world", $options_ref, {});
	my $panels_ref = $product_ref->{knowledge_panels_en};
	my @root_ids = map {$_->{panel_element}{panel_id}} @{$panels_ref->{root}{elements}};
	my @health_ids = map {@{$_->{panel_group_element}{panel_ids} // []}} @{$panels_ref->{health_card}{elements}};
	my $health_lists_ingredients = (grep {$_ eq "ingredients"} @health_ids) ? 1 : 0;

	if ($ingredients_nutrition_first) {
		is(
			\@root_ids,
			[qw/ingredients_card nutrition_card health_card environment_card product_card report_problem_card/],
			"root panel order with ingredients and nutrition first"
		);
		ok(!$panels_ref->{health_card}{expanded}, "health card collapsed");
		ok(!$panels_ref->{environment_card}{expanded}, "environment card collapsed");
		ok(!$panels_ref->{report_problem_card}{expanded}, "report a problem card collapsed");
		like($panels_ref->{health_card}{title_element}{subtitle}, qr/Nutri-Score/, "health card summary");
		is($health_lists_ingredients, 0, "ingredients only in the ingredients card");
	}
	else {
		is(\@root_ids, [qw/health_card environment_card report_problem_card product_card/], "default root panel order");
		ok(!defined $panels_ref->{ingredients_card}, "no ingredients card by default");
		ok(!defined $panels_ref->{nutrition_card}, "no nutrition card by default");
		ok(!defined $panels_ref->{health_card}{title_element}{subtitle}, "no health card summary by default");
		is($health_lists_ingredients, 1, "ingredients in the health card by default");
	}
}

# Open Products Facts: no empty health card for products like toilet paper or batteries
# https://github.com/openfoodfacts/openfoodfacts-server/issues/12683
{
	local $options{product_type} = "product";

	my $options_ref = {};
	my $request_ref = {};
	initialize_knowledge_panels_options($options_ref, $request_ref);

	my $product_ref = {code => "3596710478163", lc => "en", categories_tags => ["en:toilet-papers"]};
	is(
		ProductOpener::KnowledgePanels::create_health_card_panel(
			$product_ref, "en", "world", $options_ref, $request_ref
		),
		0,
		"no health card without a health recommendation"
	);
	is($product_ref->{knowledge_panels_en}{health_card}, undef);

	create_knowledge_panels($product_ref, "en", "world", $options_ref, $request_ref);
	is($product_ref->{knowledge_panels_en}{health_card}, undef);
	unlike($json->encode($product_ref->{knowledge_panels_en}{root}),
		qr/health_card/, "the root panel does not link to the health card");

	# The health card is still created when we have a health recommendation (e.g. the tobacco health warning)
	$product_ref = {code => "3596710478164", lc => "en", knowledge_panels_en => {recommendation_health => {}}};
	is(
		ProductOpener::KnowledgePanels::create_health_card_panel(
			$product_ref, "en", "world", $options_ref, $request_ref
		),
		1,
		"health card with a health recommendation"
	);
	ok(defined $product_ref->{knowledge_panels_en}{health_card});
}

subtest 'nutriscore knowledge panel not-applicable category explanation' => sub {
	use ProductOpener::Display qw/data_to_display_nutriscore/;

	my $product_ref = {
		code => '123456789',
		misc_tags => ['en:nutriscore-not-applicable'],
		nutrition_grades_tags => ['not-applicable'],
		nutriscore_data => {
			nutriscore_not_applicable_for_category => 'en:baby-foods',
		},
		nutriscore => {
			'2023' => {
				grade => 'not-applicable',
				not_applicable_category => 'en:baby-foods',
			},
		},
	};

	# Test Display::data_to_display_nutriscore in en
	my $data_en = data_to_display_nutriscore($product_ref, '2023', 'en');
	is($data_en->{nutriscore_grade}, 'not-applicable', 'grade is not-applicable');
	is($data_en->{nutriscore_unknown_reason_short}, 'Not applicable for the category: Baby foods',
		'reason short in en');
	is(
		$data_en->{nutriscore_warnings},
		['Nutri-Score cannot currently be calculated for this product category: Baby foods.'],
		'warning contains category explanation in en'
	);

	# Test Display::data_to_display_nutriscore in fr
	my $data_fr = data_to_display_nutriscore($product_ref, '2023', 'fr');
	is(
		$data_fr->{nutriscore_unknown_reason_short},
		'Non applicable pour la catégorie : Aliments pour bébé',
		'reason short in fr'
	);
	is(
		$data_fr->{nutriscore_warnings},
		['Le Nutri-Score ne peut pas être calculé actuellement pour cette catégorie de produits : Aliments pour bébé.'],
		'warning contains category explanation in fr'
	);

	# Test Knowledge Panel generation with create_nutriscore_2023_panel
	my $options_ref = {};
	my $request_ref = {};
	initialize_knowledge_panels_options($options_ref, $request_ref);

	ProductOpener::KnowledgePanels::create_nutriscore_2023_panel($product_ref, 'en', 'world', $options_ref,
		$request_ref);
	my $panel_en = $product_ref->{knowledge_panels_en}{nutriscore_2023};
	ok(defined $panel_en, 'nutriscore_2023 panel created in en');
	is(
		$panel_en->{title_element}{subtitle},
		'Not applicable for the category: Baby foods',
		'panel subtitle contains category explanation in en'
	);
	is(
		$panel_en->{elements}[0]{text_element}{html},
		"Nutri-Score cannot currently be calculated for this product category: Baby foods.\n                    ",
		'panel warning element explains category exclusion'
	);

	# Test fallback when category is missing
	my $product_no_cat = {
		code => '987654321',
		misc_tags => ['en:nutriscore-not-applicable'],
		nutrition_grades_tags => ['not-applicable'],
		nutriscore => {
			'2023' => {
				grade => 'not-applicable',
			},
		},
	};
	my $data_fallback = data_to_display_nutriscore($product_no_cat, '2023', 'en');
	is(
		$data_fallback->{nutriscore_unknown_reason_short},
		'Not applicable for the category',
		'fallback short explanation'
	);
	is(
		$data_fallback->{nutriscore_warnings},
		['Nutri-Score not applicable for this product category.'],
		'fallback warning message'
	);

	ProductOpener::KnowledgePanels::create_nutriscore_2023_panel($product_no_cat, 'en', 'world', $options_ref,
		$request_ref);
	my $panel_no_cat = $product_no_cat->{knowledge_panels_en}{nutriscore_2023};
	is($panel_no_cat->{title_element}{subtitle}, 'Not applicable for the category', 'fallback panel subtitle');
	is(
		$panel_no_cat->{elements}[0]{text_element}{html},
		"Nutri-Score not applicable for this product category.\n                    ",
		'fallback panel warning'
	);

	# Test precedence in data_to_display_nutriscore: version-specific category takes precedence
	my $product_mixed = {
		misc_tags => ['en:nutriscore-not-applicable'],
		nutrition_grades_tags => ['not-applicable'],
		nutriscore_data => {
			nutriscore_not_applicable_for_category => 'en:baby-foods',
		},
		nutriscore => {
			'2023' => {
				grade => 'not-applicable',
				not_applicable_category => 'en:alcoholic-beverages',
			},
		},
	};
	my $data_mixed_2023 = data_to_display_nutriscore($product_mixed, '2023', 'en');
	is(
		$data_mixed_2023->{nutriscore_unknown_reason_short},
		'Not applicable for the category: Alcoholic beverages',
		'data_to_display_nutriscore prefers 2023 category over legacy nutriscore_data'
	);
	my $data_mixed_2021 = data_to_display_nutriscore($product_mixed, '2021', 'en');
	is(
		$data_mixed_2021->{nutriscore_unknown_reason_short},
		'Not applicable for the category: Baby foods',
		'data_to_display_nutriscore for 2021 falls back to legacy nutriscore_data'
	);
};
foreach my $analyzed (0, 1) {
	my $product_ref = {lc => "en"};
	if ($analyzed) {
		$product_ref->{categories_tags} = ["en:biscuits"];
		$product_ref->{ingredients_text} = "wheat flour, sugar";
		analyze_and_enrich_product_data($product_ref, get_initialized_response());
	}
	$knowledge_panels_options_ref = {};
	initialize_knowledge_panels_options($knowledge_panels_options_ref, {});
	$knowledge_panels_options_ref->{activate_knowledge_panels_simplified} = 1;
	create_knowledge_panels($product_ref, "en", "world", $knowledge_panels_options_ref, {});
	my $panels_ref = $product_ref->{knowledge_panels_en};
	foreach my $panel_id ("origins_of_ingredients", "origins_of_ingredients_simplified") {
		is(defined $panels_ref->{$panel_id} ? 1 : 0, $analyzed, "$panel_id panel analyzed=$analyzed");
	}
	my @listed_ids
		= map {@{$_->{panel_group_element}{panel_ids} // []}} @{$panels_ref->{environment_card_simplified}{elements}};
	is((grep {$_ eq "origins_of_ingredients_simplified"} @listed_ids) ? 1 : 0,
		$analyzed, "environment_card_simplified lists the origins panel analyzed=$analyzed");
}

# A product with only ingredients (e.g. Open Beauty Facts) gets no empty health or nutrition card
{
	local $options{product_type} = "beauty";
	my $product_ref = {code => "3596710478165", lc => "en", knowledge_panels_en => {ingredients => {}}};
	my $options_ref = {activate_knowledge_panels_ingredients_nutrition_first => 1};
	is(ProductOpener::KnowledgePanels::create_health_card_panel($product_ref, "en", "world", $options_ref, {}),
		0, "no health card when only the ingredients are left");
	ok(!defined $product_ref->{knowledge_panels_en}{nutrition_card}, "no nutrition card without nutrition panels");
}

done_testing();
