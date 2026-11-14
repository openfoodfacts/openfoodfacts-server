#!/usr/bin/perl -w

# Tests for ProductOpener::TagsRules
# 1. Validates all the rules files in rules/ and runs their inline test fixtures
# 2. Tests the semantics of the engine with rules and products defined in this file

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use Clone qw/clone/;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsRules qw/:all/;

# ---------------------------------------------------------------------------
# 1. Rules files in rules/
# ---------------------------------------------------------------------------

foreach my $product_type (sort grep {-d "$BASE_DIRS{RULES}/$_"} qw(food beauty petfood product)) {

	my $ruleset_ref = load_tags_rules("$BASE_DIRS{RULES}/$product_type");

	is($ruleset_ref->{errors}, [], "rules/$product_type: all rules are valid")
		or diag(join("\n", @{$ruleset_ref->{errors}}));

	ok(scalar @{$ruleset_ref->{rules}} > 0, "rules/$product_type: rules are loaded") if $product_type eq "food";

	foreach my $rule_ref (@{$ruleset_ref->{rules}}) {

		my $rule_id = $rule_ref->{id};

		foreach my $expected ("match", "no_match") {
			my $i = 0;
			foreach my $fixture_ref (@{$rule_ref->{tests}{$expected} // []}) {
				$i++;
				my $product_ref = build_product_from_tags_rules_fixture($fixture_ref);
				my $result_ref
					= evaluate_tags_rules($product_ref, {rules => $ruleset_ref, rule_ids => [$rule_id]});

				# The rule matches if it adds all its tags
				my $added = 1;
				foreach my $field (keys %{$rule_ref->{add}}) {
					foreach my $tag (@{$rule_ref->{add}{$field}}) {
						my $rules_ref = $result_ref->{added}{$field}{$tag} // [];
						$added = 0 if not grep {$_ eq $rule_id} @$rules_ref;
					}
				}

				my $test_name = "rule $rule_id: $expected test $i";
				if ($expected eq "match") {
					ok($added, $test_name) or diag(Dumper({fixture => $fixture_ref, result => $result_ref}));
				}
				else {
					ok(!$added, $test_name) or diag(Dumper({fixture => $fixture_ref, result => $result_ref}));
				}
			}
		}
	}
}

# ---------------------------------------------------------------------------
# 2. Engine semantics
# ---------------------------------------------------------------------------

sub write_rules_dir ($files_ref) {
	my $dir = tempdir(CLEANUP => 1);
	foreach my $file (keys %$files_ref) {
		my $path = "$dir/$file";
		(my $parent = $path) =~ s/\/[^\/]+$//;
		make_path($parent);
		open(my $out, ">:encoding(UTF-8)", $path) or die("cannot write $path: $!");
		print $out $files_ref->{$file};
		close($out);
	}
	return $dir;
}

# Minimal test fixtures: each rule needs a match test, the engine tests below test the semantics
my $engine_rules_yaml = <<'YAML';
exclusive:
  - [en:wholemeal-rye-crispbreads, en:wholemeal-wheat-crispbreads]

rules:
  - id: first
    description: first ingredient
    if: {categories: en:crispbreads, ingredients: {first: en:wholemeal-flour}}
    add: {categories: en:crispbreads-wholemeal}
    tests: {match: [{categories: en:crispbreads, ingredients: [en:wholemeal-rye-flour]}]}

  - id: in-first
    description: in the 2 first ingredients
    if: {categories: en:crispbreads, ingredients: {in_first: {n: 2, of: en:whole-wheat-flour}}}
    add: {categories: en:wholemeal-wheat-crispbreads}
    tests: {match: [{categories: en:crispbreads, ingredients: [en:water, en:whole-wheat-flour]}]}

  - id: percent-declared
    description: declared percent
    if: {categories: en:biscuits, ingredients: {percent: {of: en:wholemeal-flour, min: 50, use: declared}}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, ingredients: [{id: en:whole-wheat-flour, percent: 60}]}]}

  - id: percent-estimate
    description: estimated percent, nested ingredients
    if: {categories: en:biscuits, ingredients: {percent: {of: en:wholemeal-flour, min: 50, use: estimate}}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, ingredients: [{id: en:whole-wheat-flour, percent_estimate: 60}]}]}

  - id: percent-any
    description: declared or estimated percent
    if: {categories: en:biscuits, ingredients: {percent: {of: en:wholemeal-flour, max: 20}}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, ingredients: [{id: en:whole-wheat-flour, percent: 10}]}]}

  - id: count-of
    description: count of distinct ingredients
    if: {categories: en:biscuits, ingredients: {count_of: {of: en:fruit, min: 2}}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, ingredients: [en:apple, en:pear]}]}

  - id: known
    description: all ingredients known
    if: {categories: en:biscuits, ingredients: {known: true}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, ingredients: [en:sugar]}]}

  - id: contains
    description: contains at any depth
    if: {categories: en:biscuits, ingredients: {contains: en:fruit}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, ingredients: [en:apple]}]}

  - id: name
    description: name per language
    if: {categories: en:biscuits, name: {fr: '\bcomplet\b', de: 'vollkorn'}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, product_name_fr: Biscuit complet}]}

  - id: name-any
    description: name in any language
    if: {categories: en:biscuits, name: {any: 'p[eé]pite'}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, product_name_xx: pepite}]}

  - id: ingredients-text
    description: ingredients text
    if: {categories: en:biscuits, ingredients_text: {fr: 'farine compl[eè]te'}}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, ingredients_text_fr: Farine complète}]}

  - id: nutrients
    description: nutrients
    if: {categories: en:dark-chocolates, nutrients: {cocoa: {min: 30, max: 64.9}}}
    add: {categories: en:semi-sweet-dark-chocolates}
    tests: {match: [{categories: en:dark-chocolates, nutrients: {cocoa: 50}}]}

  - id: nested
    description: all, any, not and unless
    if:
      categories: en:biscuits
      any:
        - labels: en:organic
        - all:
            - countries: en:france
            - not: {brands: xx:some-brand}
    unless:
      - labels: en:fair-trade
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits, labels: en:organic}]}

  - id: exact
    description: categories exact
    if: {categories: en:biscuits, categories_exact: en:biscuits}
    add: {categories: en:wholemeal-wheat-biscuits}
    tests: {match: [{categories: en:biscuits}]}

  - id: colas
    description: colas
    if: {categories: en:colas}
    add: {categories: en:caffeinated-colas}
    tests: {match: [{categories: en:colas}]}

  - id: pasteurized
    description: incompatible_with property
    if: {categories: en:cheeses}
    add: {categories: en:pasteurized-cheeses}
    tests: {match: [{categories: en:cheeses}]}

  - id: warning
    description: data quality warning
    if: {categories: en:sweet-mustards, name: {fr: 'moutarde douce'}}
    add: {data_quality_warnings: en:sweet-mustards-named-mild-mustard}
    tests: {match: [{categories: en:sweet-mustards, product_name_fr: Moutarde douce}]}
YAML

my $engine_rules_dir = write_rules_dir({"food/categories/engine.yml" => $engine_rules_yaml});
my $engine_rules_ref = load_tags_rules("$engine_rules_dir/food");
is($engine_rules_ref->{errors}, [], "engine test rules are valid") or diag(join("\n", @{$engine_rules_ref->{errors}}));

# Return 1 if the rule adds its tag to the product
sub rule_adds ($rule_id, $product_ref) {
	my $result_ref = evaluate_tags_rules($product_ref, {rules => $engine_rules_ref, rule_ids => [$rule_id]});
	return (grep {$_ eq $rule_id} map {@$_} map {values %$_} values %{$result_ref->{added}}) ? 1 : 0;
}

sub fixture (%fields) {
	return build_product_from_tags_rules_fixture(\%fields);
}

my @semantics_tests = (
	# first: is_a, so children of the ingredient match too
	[first => 1, fixture(categories => "en:crispbreads", ingredients => ["en:whole-wheat-flour", "en:salt"])],
	[first => 0, fixture(categories => "en:crispbreads", ingredients => ["en:salt", "en:whole-wheat-flour"])],
	[first => 0, fixture(categories => "en:crispbreads")],
	# The required category, or a descendant
	[first => 1, fixture(categories => "en:rye-crispbreads", ingredients => ["en:wholemeal-rye-flour"])],
	[first => 0, fixture(categories => "en:breads", ingredients => ["en:wholemeal-rye-flour"])],

	[
		'in-first' => 1,
		fixture(categories => "en:crispbreads", ingredients => ["en:water", "en:whole-wheat-flour", "en:salt"])
	],
	[
		'in-first' => 0,
		fixture(categories => "en:crispbreads", ingredients => ["en:water", "en:salt", "en:whole-wheat-flour"])
	],

	# percent declared: estimates are not used
	[
		'percent-declared' => 1,
		fixture(categories => "en:biscuits", ingredients => [{id => "en:whole-wheat-flour", percent => 50}])
	],
	[
		'percent-declared' => 0,
		fixture(categories => "en:biscuits", ingredients => [{id => "en:whole-wheat-flour", percent_estimate => 70}])
	],
	# percents of several matching ingredients are added, also in sub-ingredients
	[
		'percent-declared' => 1,
		fixture(
			categories => "en:biscuits",
			ingredients => [
				{id => "en:whole-wheat-flour", percent => 30},
				{id => "en:flour", percent => 40, ingredients => [{id => "en:wholemeal-rye-flour", percent => 25}]}
			]
		)
	],
	# a matching ingredient without a declared percent: unknown, so no match
	[
		'percent-declared' => 0,
		fixture(
			categories => "en:biscuits",
			ingredients => [{id => "en:whole-wheat-flour", percent => 60}, {id => "en:wholemeal-rye-flour"}]
		)
	],
	[
		'percent-estimate' => 1,
		fixture(
			categories => "en:biscuits",
			ingredients => [{id => "en:whole-wheat-flour", percent => 40, percent_estimate => 55}]
		)
	],
	[
		'percent-estimate' => 0,
		fixture(categories => "en:biscuits", ingredients => [{id => "en:whole-wheat-flour", percent => 55}])
	],
	# max: no matching ingredient -> 0%
	['percent-any' => 1, fixture(categories => "en:biscuits", ingredients => ["en:sugar"])],
	['percent-any' => 0, fixture(categories => "en:biscuits")],
	[
		'percent-any' => 0,
		fixture(categories => "en:biscuits", ingredients => [{id => "en:whole-wheat-flour", percent_estimate => 30}])
	],

	# count_of: distinct ingredients, at any depth
	[
		'count-of' => 1,
		fixture(
			categories => "en:biscuits",
			ingredients => ["en:apple", {id => "en:filling", ingredients => ["en:pear"]}]
		)
	],
	['count-of' => 0, fixture(categories => "en:biscuits", ingredients => ["en:apple", "en:apple"])],

	# known: all ingredients at all depths are in the taxonomy
	['known' => 1, fixture(categories => "en:biscuits", ingredients => ["en:sugar", "en:salt"])],
	['known' => 0, fixture(categories => "en:biscuits", ingredients => ["en:sugar", "fr:ingredient inconnu"])],
	[
		'known' => 0,
		fixture(categories => "en:biscuits", ingredients => [{id => "en:sugar", ingredients => ["fr:inconnu"]}])
	],
	['known' => 0, fixture(categories => "en:biscuits", ingredients => [])],

	# contains: at any depth
	[
		'contains' => 1,
		fixture(categories => "en:biscuits", ingredients => [{id => "en:filling", ingredients => ["en:apple"]}])
	],
	['contains' => 0, fixture(categories => "en:biscuits", ingredients => ["en:sugar"])],

	# name: per language, case and accent insensitive, product_name and generic_name
	['name' => 1, fixture(categories => "en:biscuits", product_name_fr => "BISCUIT COMPLET")],
	['name' => 0, fixture(categories => "en:biscuits", product_name_fr => "Biscuits complets")],    # \b
	['name' => 1, fixture(categories => "en:biscuits", generic_name_fr => "Biscuit au blé complet")],
	['name' => 1, fixture(categories => "en:biscuits", product_name_de => "Vollkornkekse")],
	# the regexp for fr does not apply to other languages
	['name' => 0, fixture(categories => "en:biscuits", product_name_en => "Biscuit complet")],
	# product_name (without language) is in the main language of the product
	['name' => 1, fixture(categories => "en:biscuits", lc => "fr", product_name => "Biscuit complet")],
	['name' => 0, fixture(categories => "en:biscuits", lc => "en", product_name => "Biscuit complet")],
	['name-any' => 1, fixture(categories => "en:biscuits", product_name_it => "Pépite")],
	['name-any' => 1, fixture(categories => "en:biscuits", lc => "fr", product_name => "Pépite")],
	['name-any' => 0, fixture(categories => "en:biscuits", product_name_it => "Biscotti")],

	['ingredients-text' => 1, fixture(categories => "en:biscuits", ingredients_text_fr => "FARINE COMPLETE de blé")],
	['ingredients-text' => 0, fixture(categories => "en:biscuits", ingredients_text_en => "farine complète")],

	# nutrients: from the aggregated set, per 100g as sold
	['nutrients' => 1, fixture(categories => "en:dark-chocolates", nutrients => {cocoa => 64.9})],
	['nutrients' => 0, fixture(categories => "en:dark-chocolates", nutrients => {cocoa => 70})],
	['nutrients' => 0, fixture(categories => "en:dark-chocolates")],
	[
		'nutrients' => 0,
		{
			categories_tags => ["en:dark-chocolates"],
			nutrition => {
				aggregated_set => {per => "100g", preparation => "prepared", nutrients => {cocoa => {value => 50}}}
			}
		}
	],
	# "< 60": the value could be lower than the min
	[
		'nutrients' => 0,
		{
			categories_tags => ["en:dark-chocolates"],
			nutrition => {aggregated_set => {per => "100g", nutrients => {cocoa => {value => 60, modifier => "<"}}}}
		}
	],

	# nested all / any / not, and unless
	['nested' => 1, fixture(categories => "en:biscuits", labels => "en:eu-organic")],
	['nested' => 1, fixture(categories => "en:biscuits", countries => "en:france")],
	['nested' => 0, fixture(categories => "en:biscuits", countries => "en:france", brands => ["xx:Some Brand"])],
	['nested' => 0, fixture(categories => "en:biscuits", countries => "en:germany")],
	['nested' => 0, fixture(categories => "en:biscuits", labels => ["en:organic", "en:fair-trade"])],

	# categories_exact: input tags, not descendants
	['exact' => 1, fixture(categories => "en:biscuits")],
	['exact' => 0, fixture(categories => "en:chocolate-biscuits")],
	[
		'exact' => 0,
		{
			categories_tags => ["en:biscuits", "en:chocolate-biscuits"],
			tags_sources => {categories => {packaging => {tags => ["en:chocolate-biscuits"]}}}
		}
	],

	# Flat rules: tags from the rules source are ignored
	[
		'colas' => 1,
		{
			categories_tags => ["en:beverages", "en:colas"],
			tags_sources => {categories => {packaging => {tags => ["en:colas"]}}}
		}
	],
	[
		'colas' => 0,
		{
			categories_tags => ["en:beverages", "en:colas"],
			tags_sources => {
				categories => {packaging => {tags => ["en:beverages"]}, rules => {tags => ["en:colas"]}}
			}
		}
	],
	# tags_sources are recomputed with parents: categories_tags is not used when there are tags_sources
	[
		'colas' => 1,
		{
			categories_tags => [],
			tags_sources => {categories => {packaging => {tags => ["en:cola-with-sugar"]}}}
		}
	],

	# Data quality warnings
	['warning' => 1, fixture(categories => "en:sweet-mustards", product_name_fr => "Moutarde douce")],
	['warning' => 0, fixture(categories => "en:mustards", product_name_fr => "Moutarde douce")],
);

foreach my $test_ref (@semantics_tests) {
	my ($rule_id, $expected, $product_ref) = @$test_ref;
	is(rule_adds($rule_id, $product_ref), $expected, "rule $rule_id: " . ($expected ? "match" : "no match"))
		or diag(Dumper($product_ref));
}

# Already in the target category: nothing added, reported in already
{
	my $result_ref = evaluate_tags_rules(
		fixture(categories => ["en:colas", "en:caffeinated-colas"]),
		{rules => $engine_rules_ref, rule_ids => ["colas"]}
	);
	is($result_ref->{added}, {}, "already in the target category: nothing added");
	is($result_ref->{already}, {colas => ["en:caffeinated-colas"]}, "already in the target category: reported");
	is($result_ref->{matched}, ["colas"], "already in the target category: matched");
}

# Conflicts with an existing category (exclusive group): warning instead of the category
{
	my $result_ref
		= evaluate_tags_rules(
		fixture(categories => ["en:wholemeal-rye-crispbreads"], ingredients => ["en:water", "en:whole-wheat-flour"]),
		{rules => $engine_rules_ref, rule_ids => ["in-first"]});
	is(
		$result_ref->{added},
		{data_quality_warnings => {"en:category-rules-conflict" => ["in-first"]}},
		"exclusive group conflict: warning, no category"
	) or diag(Dumper($result_ref));
	is(
		$result_ref->{conflicts},
		[{rule => "in-first", tag => "en:wholemeal-wheat-crispbreads", with => ["en:wholemeal-rye-crispbreads"]}],
		"exclusive group conflict: reported"
	);
}

# Conflicts from the incompatible_with:en property of the taxonomy
{
	my $result_ref = evaluate_tags_rules(
		fixture(categories => ["en:cheeses", "en:unpasteurised-cheeses"]),
		{rules => $engine_rules_ref, rule_ids => ["pasteurized"]}
	);
	is($result_ref->{added}{categories}, undef, "incompatible_with conflict: no category") or diag(Dumper($result_ref));
	is(
		$result_ref->{added}{data_quality_warnings},
		{"en:category-rules-conflict" => ["pasteurized"]},
		"incompatible_with conflict: warning"
	);
}

# Conflicts between categories added by 2 rules: none is added
{
	my $result_ref = evaluate_tags_rules(
		fixture(
			categories => ["en:crispbreads"],
			ingredients => ["en:wholemeal-rye-flour", "en:whole-wheat-flour"]
		),
		{rules => $engine_rules_ref, rule_ids => ["first", "in-first"]}
	);
	# en:crispbreads-wholemeal (first) does not conflict, en:wholemeal-wheat-crispbreads (in-first) does not either
	is(
		$result_ref->{added}{categories},
		{"en:crispbreads-wholemeal" => ["first"], "en:wholemeal-wheat-crispbreads" => ["in-first"]},
		"2 rules without conflict"
	);
}
{
	my $two_rules_dir = write_rules_dir(
		{
			"food/categories/two.yml" => <<'YAML'
exclusive:
  - [en:wholemeal-rye-crispbreads, en:wholemeal-wheat-crispbreads]
rules:
  - id: rye
    description: rye
    if: {categories: en:crispbreads, ingredients: {contains: en:wholemeal-rye-flour}}
    add: {categories: en:wholemeal-rye-crispbreads}
    tests: {match: [{categories: en:crispbreads}]}
  - id: wheat
    description: wheat
    if: {categories: en:crispbreads, ingredients: {contains: en:whole-wheat-flour}}
    add: {categories: en:wholemeal-wheat-crispbreads}
    tests: {match: [{categories: en:crispbreads}]}
YAML
		}
	);
	my $two_rules_ref = load_tags_rules("$two_rules_dir/food");
	my $result_ref
		= evaluate_tags_rules(
		fixture(categories => ["en:crispbreads"], ingredients => ["en:wholemeal-rye-flour", "en:whole-wheat-flour"]),
		{rules => $two_rules_ref});
	is($result_ref->{added}{categories}, undef, "2 rules adding exclusive categories: none is added")
		or diag(Dumper($result_ref));
	is(
		$result_ref->{added}{data_quality_warnings},
		{"en:category-rules-conflict" => ["rye", "wheat"]},
		"2 rules adding exclusive categories: warning"
	);
}

# apply_tags_rules_to_product: rules source, categories_tags, misc tags, idempotence
{
	my $product_ref = {
		lc => "en",
		tags_sources => {categories => {packaging => {tags => ["en:colas"], last_updated_t => 1000}}},
		misc_tags => ["en:some-other-misc-tag"],
	};
	apply_tags_rules_to_product($product_ref, {rules => $engine_rules_ref});

	is($product_ref->{tags_sources}{categories}{rules}{tags},
		["en:caffeinated-colas"], "apply: tags in the rules source");
	is(
		$product_ref->{tags_sources}{categories}{rules}{rules},
		{"en:caffeinated-colas" => ["colas"]},
		"apply: rule ids in the rules source"
	);
	ok((grep {$_ eq "en:caffeinated-colas"} @{$product_ref->{categories_tags}}), "apply: categories_tags regenerated");
	is(
		$product_ref->{misc_tags},
		["en:some-other-misc-tag", "en:tags-added-by-rules", "en:tags-rule-colas"],
		"apply: misc tags"
	);
	is($product_ref->{tags_sources}{categories}{packaging}{last_updated_t}, 1000, "apply: other sources unchanged");

	# Second application: nothing changes, last_updated_t is kept
	$product_ref->{tags_sources}{categories}{rules}{last_updated_t} = 1234;
	my $before_ref = clone($product_ref);
	apply_tags_rules_to_product($product_ref, {rules => $engine_rules_ref});
	is($product_ref, $before_ref, "apply twice: no change, last_updated_t kept");

	# The rule does not match anymore: the source and the misc tags are removed
	$product_ref->{tags_sources}{categories}{packaging}{tags} = ["en:beverages"];
	apply_tags_rules_to_product($product_ref, {rules => $engine_rules_ref});
	is($product_ref->{tags_sources}{categories}{rules}, undef, "apply: rules source removed when no rule matches");
	ok(!(grep {$_ eq "en:caffeinated-colas"} @{$product_ref->{categories_tags}}), "apply: categories_tags updated");
	is($product_ref->{misc_tags}, ["en:some-other-misc-tag"], "apply: misc tags removed");

	# Product with no rules and no misc tags: no misc_tags field created
	my $other_product_ref = {lc => "en", categories_tags => ["en:beverages"]};
	apply_tags_rules_to_product($other_product_ref, {rules => $engine_rules_ref});
	is($other_product_ref, {lc => "en", categories_tags => ["en:beverages"]}, "apply: no rule, no change");
}

# apply: data quality warnings are not stored in tags_sources, add_tags_rules_data_quality_tags adds them
{
	my $product_ref = fixture(categories => "en:sweet-mustards", product_name_fr => "Moutarde douce");
	apply_tags_rules_to_product($product_ref, {rules => $engine_rules_ref});
	is($product_ref->{tags_sources}, undef, "apply: data quality warnings are not stored in tags_sources");
	is($product_ref->{misc_tags}, ["en:tags-rule-warning"], "apply: misc tag for the warning rule");

	$product_ref->{data_quality_warnings_tags} = [];
	add_tags_rules_data_quality_tags($product_ref, {rules => $engine_rules_ref});
	is(
		$product_ref->{data_quality_warnings_tags},
		["en:sweet-mustards-named-mild-mustard"],
		"add_tags_rules_data_quality_tags"
	);
}

# ---------------------------------------------------------------------------
# 3. Validation
# ---------------------------------------------------------------------------

my @validation_tests = (
	[
		"unknown tag",
		"if: {categories: en:colas}\n  add: {categories: en:not-a-real-category-xyz}",
		qr/does not exist in the categories taxonomy/
	],
	[
		"add not under the required category",
		"if: {categories: en:colas}\n  add: {categories: en:biscuits}",
		qr/must be a descendant of the required categories/
	],
	[
		"invalid regexp",
		"if: {categories: en:colas, name: {fr: '(unclosed'}}\n  add: {categories: en:caffeinated-colas}",
		qr/invalid regular expression/
	],
	[
		"unknown data quality warning",
		"if: {categories: en:colas}\n  add: {data_quality_warnings: en:not-a-real-warning-xyz}",
		qr/does not exist in the data_quality taxonomy/
	],
	[
		"unknown condition",
		"if: {categories: en:colas, colour: red}\n  add: {categories: en:caffeinated-colas}",
		qr/unknown condition 'colour'/
	],
	[
		"unknown ingredients condition",
		"if: {categories: en:colas, ingredients: {last: en:water}}\n  add: {categories: en:caffeinated-colas}",
		qr/ingredients: unknown condition 'last'/
	],
	[
		"no required category",
		"if: {labels: en:organic}\n  add: {categories: en:caffeinated-colas}",
		qr/top-level 'categories' condition/
	],
	[
		"unknown ingredient",
		"if: {categories: en:colas, ingredients: {first: en:not-an-ingredient-xyz}}\n  add: {categories: en:caffeinated-colas}",
		qr/does not exist in the ingredients taxonomy/
	],
	[
		"non canonical tag",
		"if: {categories: en:cola}\n  add: {categories: en:caffeinated-colas}",
		qr/is not the canonical id, use 'en:colas'/
	],
);

foreach my $test_ref (@validation_tests) {
	my ($name, $rule_yaml, $expected_error) = @$test_ref;
	my $dir = write_rules_dir(
		{
			"food/categories/invalid.yml" => <<"YAML"
- id: invalid-rule
  description: invalid rule
  $rule_yaml
  tests: {match: [{categories: en:colas}]}
YAML
		}
	);
	my $ruleset_ref = load_tags_rules("$dir/food");
	ok((grep {$_ =~ $expected_error} @{$ruleset_ref->{errors}}), "validation: $name")
		or diag(Dumper($ruleset_ref->{errors}));
	is(scalar @{$ruleset_ref->{rules}}, 0, "validation: $name: the invalid rule is skipped");
}

# Duplicate ids, missing tests
{
	my $dir = write_rules_dir(
		{
			"food/categories/a.yml" => <<'YAML',
- id: same-id
  description: a
  if: {categories: en:colas}
  add: {categories: en:caffeinated-colas}
  tests: {match: [{categories: en:colas}]}
YAML
			"food/categories/b.yml" => <<'YAML',
- id: same-id
  description: b
  if: {categories: en:colas}
  add: {categories: en:caffeinated-colas}
  tests: {match: [{categories: en:colas}]}
- id: no-tests
  description: no tests
  if: {categories: en:colas}
  add: {categories: en:caffeinated-colas}
YAML
		}
	);
	my $ruleset_ref = load_tags_rules("$dir/food");
	ok((grep {/rule same-id: duplicate rule id/} @{$ruleset_ref->{errors}}), "validation: duplicate rule id")
		or diag(Dumper($ruleset_ref->{errors}));
	ok((grep {/rule no-tests: tests: at least one 'match'/} @{$ruleset_ref->{errors}}), "validation: tests required");
	is([map {$_->{id}} @{$ruleset_ref->{rules}}], ["same-id"], "validation: only the first valid rule is loaded");
}

# Required categories (used for the batch reprocessing queries)
is(
	[tags_rules_required_categories($engine_rules_ref)],
	["en:biscuits", "en:cheeses", "en:colas", "en:crispbreads", "en:dark-chocolates", "en:sweet-mustards"],
	"tags_rules_required_categories"
);

done_testing();
