use ProductOpener::PerlStandards;
use Test2::V0;
use Storable qw(dclone);
use JSON::MaybeXS;
use ProductOpener::Config qw(%options);
use ProductOpener::Recipes qw(compute_product_recipe);
use ProductOpener::Ingredients qw(
	clean_ingredients_text cut_ingredients_text_for_lang parse_ingredients_text_service
	extract_ingredients_from_text extract_additives_from_text detect_allergens_from_text
);

open(my $input, '<:raw', 'tests/unit/inputs/ingredient_sections/products.json') or die $!;
my $cases = JSON::MaybeXS->new->utf8->decode(do {local $/; <$input>});
close($input) or die $!;
my %products = map {$_->{code} => $_} @$cases;

sub product ($code) {
	my $case = $products{$code};
	return {
		code => $code,
		lc => $case->{lc},
		product_type => 'petfood',
		ingredients_text => $case->{text},
		nutrition => {},
	};
}

sub analyze ($product) {
	clean_ingredients_text($product);
	extract_ingredients_from_text($product);
	extract_additives_from_text($product);
	detect_allergens_from_text($product);
	return;
}

sub nodes ($ingredients) {
	my @nodes;
	for my $ingredient (@{$ingredients // []}) {
		push @nodes, $ingredient, nodes($ingredient->{ingredients});
	}
	return @nodes;
}

my $junior = product('3560071504397');
analyze($junior);
my $junior_recipe;
my $junior_warnings = warnings {$junior_recipe = compute_product_recipe($junior, ['en:meat'])};
is($junior_recipe, undef, 'a product with several unweighted recipes has no recipe to compute');
is(scalar @$junior_warnings, 0, 'and computing it does not warn');
my @recipes = grep {$_->{type} eq 'recipe'} @{$junior->{ingredients_sections} // []};
is(scalar @recipes, 4, 'Junior retains its four separate recipes');
is(
	[map {$_->{type}} @{$junior->{ingredients_sections} // []}],
	['recipe', 'recipe', 'recipe', 'recipe', 'analytical', 'additives'],
	'analytical and additive sections remain separate'
);
is(scalar(grep {$_->{text} =~ /^(?:_?[EÉ]mincés|_?Constituants|_?Additifs)/i} nodes($junior->{ingredients})),
	0, 'section headings are not ingredients');
ok(scalar(grep {$_->{id} eq 'en:vitamin-e'} nodes($junior->{ingredients})), 'additives following analytics survive');
ok(
	scalar(grep {$_ eq 'en:vitamin-e'} @{$junior->{vitamins_tags} // []}),
	'additive extraction retains the vitamin after analytics'
);
is($junior->{ingredients_percent_analysis}, undef, 'unweighted recipes have no global percentage estimate');
is(scalar(grep {defined $_->{percent} || defined $_->{percent_estimate}} nodes($junior->{ingredients})),
	0, 'legacy projection does not expose recipe-local percentages as whole-product values');
ok(scalar(grep {defined $_->{percent} && $_->{percent} == 36} map {nodes($_->{ingredients})} @recipes),
	'section trees preserve the declared recipe-local percentages');
is(ProductOpener::Ingredients::estimate_ingredients_matching_function($junior, sub {return 1}),
	undef, 'derived quantitative estimates are indeterminate for unweighted recipes');

my $saved_sections = dclone($junior->{ingredients_sections} // []);
my $saved_ingredients = dclone($junior->{ingredients});
analyze($junior);
is($junior->{ingredients_sections}, $saved_sections, 'full reanalysis keeps section metadata stable');
is($junior->{ingredients}, $saved_ingredients, 'full reanalysis keeps the legacy projection stable');
is($junior->{ingredients_text}, $products{'3560071504397'}{text}, 'section parsing preserves source text');

my $mix = product('3560071001612');
analyze($mix);
is(
	[map {$_->{type}} @{$mix->{ingredients_sections} // []}],
	['ingredients', 'mixture'],
	'croquette proportions are represented as a mixture annotation'
);
is(scalar(grep {$_->{text} =~ /^croquettes/i} nodes($mix->{ingredients})),
	0, 'the mixture paragraph creates no extra ingredients');

my $english_mix = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text =>
		"meat, cereals.\n33% red kibbles, 33% brown kibbles and 34% green kibbles in the finished product."
};
parse_ingredients_text_service($english_mix, {}, []);
is(
	[map {$_->{type}} @{$english_mix->{ingredients_sections} // []}],
	['ingredients', 'mixture'],
	'English kibble descriptions are also mixture annotations'
);
is(scalar(grep {$_->{text} =~ /kibbles/i} nodes($english_mix->{ingredients})),
	0, 'English mixture descriptions do not create ingredients');

my $capitalised_mix = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text =>
		"meat, cereals.\n33% Red Kibbles, 33% Brown Kibbles and 34% Green Kibbles in the Finished Product."
};
parse_ingredients_text_service($capitalised_mix, {}, []);
is(
	[map {$_->{type}} @{$capitalised_mix->{ingredients_sections} // []}],
	['ingredients', 'mixture'],
	'mixture keywords are matched whatever their case'
);

my $fancy = product('8850011072792');
analyze($fancy);
is(scalar(grep {$_->{type} eq 'recipe'} @{$fancy->{ingredients_sections} // []}),
	3, 'glued English headings retain all three recipes');
is(scalar(grep {$_->{text} =~ /With Grilled|Ingredients/i} nodes($fancy->{ingredients})),
	0, 'glued headings do not remain inside ingredient names');

my $organic = product('3560070260645');
analyze($organic);
my @organic_recipes = grep {$_->{type} eq 'recipe'} @{$organic->{ingredients_sections} // []};
is(scalar @organic_recipes, 2, 'organic variety pack retains both recipes');
is(
	[map {$_->{ingredients}[0]{labels}} @organic_recipes],
	['en:organic', 'en:organic'],
	'global organic footnote still qualifies ingredients in every recipe'
);

for my $text ('poulet, émincés de dinde : eau, sel') {
	my $control = {lc => 'fr', product_type => 'petfood', ingredients_text => $text};
	parse_ingredients_text_service($control, {}, []);
	is($control->{ingredients_sections},
		undef, 'ordinary ingredients and isolated nutrient words do not create sections');
}

{
	local $options{product_type} = 'petfood';
	my $ocr = product('3560071504397');
	$ocr->{ingredients_text} = cut_ingredients_text_for_lang($ocr->{ingredients_text}, 'fr');
	analyze($ocr);
	is(scalar(grep {$_->{type} eq 'recipe'} @{$ocr->{ingredients_sections} // []}),
		4, 'OCR cutting preserves recipe headings');
	ok(scalar(grep {$_->{id} eq 'en:vitamin-e'} nodes($ocr->{ingredients})),
		'OCR cutting preserves additives after analytics');
}

for my $code ('3560071504397', '3560071001612') {
	my $text = $products{$code}{text};
	is(cut_ingredients_text_for_lang("Marketing words. Composition :\n$text", 'fr', 'petfood'),
		$text, 'OCR cutting removes the prefix before a composition with recipes or a mixture');
}

for my $heading ('Composition :', 'COMPOSITION') {
	my $text = "Recette poulet : poulet, riz\nRecette poisson : poisson, riz";
	is(cut_ingredients_text_for_lang("Marketing words. $heading\n  $text", 'fr', 'petfood'),
		$text, 'OCR cutting removes the prefix and indentation before the first recipe');
}

for my $text ($products{'8850011072792'}{text}, 'With tuna INGREDIENTS: chicken. With salmon INGREDIENTS: fish') {
	is(cut_ingredients_text_for_lang($text, 'en', 'petfood'),
		$text, 'OCR cutting preserves the Ingredients word inside the first English recipe heading');
}

my $updated = {};
my $api = product('3560071504397');
$api->{ingredients_percent_analysis} = 1;
$api->{estimate_ingredients_percent_service} = 'product_opener';
parse_ingredients_text_service($api, $updated, []);
ok($updated->{ingredients_sections}, 'parse service declares the new top-level output');
is($api->{ingredients_percent_analysis}, undef, 'parse-only API clears obsolete global percentage analysis');
is($api->{estimate_ingredients_percent_service}, undef, 'parse-only API clears obsolete estimator metadata');
ok($updated->{ingredients_percent_analysis}, 'parse-only API reports the cleared percentage field');

done_testing;
