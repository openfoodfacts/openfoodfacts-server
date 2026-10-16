use ProductOpener::PerlStandards;
use Test2::V0;
use Storable qw(dclone);
use JSON::MaybeXS;
use Time::HiRes qw(time);
use ProductOpener::Config qw(%options);
use ProductOpener::Ingredients::Sections qw(split_ingredient_sections);
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

my $origin_field = {
	lc => 'fr',
	product_type => 'petfood',
	ingredients_text =>
		"Composition : poulet, riz\nConstituants analytiques : protéines 8%, matières grasses brutes 7%, "
		. 'cendres brutes 2%, cellulose brute 1%',
	origin_fr => 'Poulet : France',
	nutrition => {},
};
extract_ingredients_from_text($origin_field);
is($origin_field->{ingredients}[0]{origins}, 'en:france', 'the origin field still applies to sectioned ingredients');
is($origin_field->{ingredients_sections}[0]{ingredients}[0]{origins},
	'en:france', 'the origin field applies to the ingredients of their section');
is(scalar @{$origin_field->{specific_ingredients}}, 1, 'the origin field entry is not duplicated by the sections');

for my $heading ("Additifs nutritionnels\x{a0}: Vitamine E 100 mg",
	"Additifs nutritionnels\x{a0}(/kg)\x{a0}: Vitamine E 100 mg")
{
	my $spaced = {
		lc => 'fr',
		product_type => 'petfood',
		ingredients_text => "Composition : poulet, riz.\n"
			. "Constituants analytiques : protéines 8%, cendres brutes 2%, cellulose brute 1%.\n$heading",
		nutrition => {},
	};
	extract_ingredients_from_text($spaced);
	is(
		[map {$_->{type}} @{$spaced->{ingredients_sections}}],
		['ingredients', 'analytical', 'additives'],
		'a non-breaking space does not hide the additives heading'
	);
	ok((grep {$_->{id} eq 'en:vitamin-e'} nodes($spaced->{ingredients})), 'its additives are parsed');
}

for my $case (
	['fr', 'Composition : poulet, riz. Additifs nutritionnels (vitamine E, taurine)', 'en:vitamin-e'],
	['en', 'Composition : chicken, rice. Additives (E300, E321)', 'en:e300'],
	)
{
	my ($lc, $text, $id) = @$case;
	my $listed = {lc => $lc, product_type => 'petfood', ingredients_text => $text, nutrition => {}};
	extract_ingredients_from_text($listed);
	is([map {$_->{type}} @{$listed->{ingredients_sections}}], ['ingredients'], "$text has no additives heading");
	ok((grep {$_->{id} eq $id} nodes($listed->{ingredients})), "$text keeps its additives");
}

my $feed = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text => "Composition : chicken, rice.\n"
		. "Analytical constituents: protein 8%, ash 2%, fibre 1%.\n"
		. "Additives (per kg): Nutritional additives: Vitamin A 12000 IU\nTechnological additives: E330",
	nutrition => {},
};
extract_ingredients_from_text($feed);
is(
	[map {$_->{id}} @{$feed->{ingredients}}],
	['en:chicken', 'en:rice', 'en:vitamin-a', 'en:e330'],
	'qualified additives headings leave no word behind'
);

my $broken_enumeration = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text => "Salmon (20%), potato, peas, fish oil, palm and rapeseed\noil, yeast, minerals.\n"
		. 'Analytical constituents: protein 8%, ash 2%, fibre 1%',
	nutrition => {},
};
extract_ingredients_from_text($broken_enumeration);
my ($oil) = grep {$_->{id} eq 'en:oil'} @{$broken_enumeration->{ingredients}};
is(
	[map {$_->{id}} @{$oil->{ingredients} // []}],
	['en:palm-oil', 'en:rapeseed-oil'],
	'an enumeration broken by a line break is read as without it'
);

my $broken_traces = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text => "chicken, rice, minerals. May contain traces of milk, soy and\ngluten.\n"
		. 'Analytical constituents: protein 8%, ash 2%, fibre 1%',
	nutrition => {},
};
extract_ingredients_from_text($broken_traces);
is(
	[map {$_->{id}} @{$broken_traces->{ingredients}}],
	['en:chicken', 'en:rice', 'en:minerals'],
	'traces broken by a line break are not turned into ingredients'
);

my $vitamins = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text => "Chicken (min. 4%), cereals, minerals, vitamins (A, D3, E), antioxidants\n"
		. 'Analytical constituents: crude protein 8%, crude fat 7%, crude ash 2%, crude fibre 1%',
	nutrition => {},
};
extract_ingredients_from_text($vitamins);
is(scalar(grep {$_->{id} eq 'en:vitamins'} @{$vitamins->{ingredients}}), 1, 'a vitamin enumeration is expanded once');

my $allergens = {
	lc => 'fr',
	product_type => 'petfood',
	ingredients_text => "poulet, riz, Contient du lait, du soja et de la moutarde.\n"
		. 'Constituants analytiques : protéines 8%, matières grasses brutes 7%, cendres brutes 2%, cellulose brute 1%',
	nutrition => {},
};
extract_ingredients_from_text($allergens);
is(
	[map {$_->{id}} @{$allergens->{ingredients}}],
	['en:chicken', 'en:rice'],
	'an allergen statement is not turned into ingredients'
);

my $leading_phrase = {
	lc => 'fr',
	product_type => 'petfood',
	ingredients_text => "Farine de blé contient gluten, poulet 30%, riz\n"
		. 'Constituants analytiques : protéines 8%, matières grasses brutes 7%, cendres brutes 2%, cellulose brute 1%',
	nutrition => {},
};
extract_ingredients_from_text($leading_phrase);
is(
	[map {$_->{type}} @{$leading_phrase->{ingredients_sections} // []}],
	['ingredients', 'analytical'],
	'a leading allergen phrase does not hide the sections'
);
is(
	[map {$_->{id}} @{$leading_phrase->{ingredients}}],
	['en:chicken', 'en:rice'],
	'a leading allergen phrase does not bring the analytical constituents back as ingredients'
);

my @empty_section_errors;
my $empty_section = {
	lc => 'fr',
	product_type => 'petfood',
	ingredients_text => "Composition :\nConstituants analytiques : protéines 8%, matières grasses brutes 7%, "
		. 'cendres brutes 2%, cellulose brute 1%',
};
parse_ingredients_text_service($empty_section, {}, \@empty_section_errors);
is(\@empty_section_errors, [], 'a heading without a body is not a missing field');
is($empty_section->{ingredients_sections}[0]{ingredients}, [], 'a heading without a body has no ingredients');

my $product_fields = {
	lc => 'fr',
	product_type => 'petfood',
	ingredients_text => "Composition : poulet, riz, commerce équitable, arôme (lait)\n"
		. 'Constituants analytiques : protéines 8%, matières grasses brutes 7%, cendres brutes 2%, cellulose brute 1%',
	nutrition => {},
};
extract_ingredients_from_text($product_fields);
is($product_fields->{labels_tags}, ['en:fair-trade'], 'a label read in a section belongs to the product');
like($product_fields->{allergens_from_ingredients}, qr/en:milk/,
	'an allergen read in a section belongs to the product');

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

for my $case (
	['fr', '*' x 20000, 'asterisks'],
	['en', '_' x 20000, 'underscores'],
	['fr', 'protéines' . (' ' x 20000) . 'x', 'spaces after a nutrient'],
	['en', 'additives' . ('*' x 20000) . 'x', 'asterisks after a heading'],
	)
{
	my ($lc, $text, $description) = @$case;
	my $start = time;
	split_ingredient_sections($text, $lc);
	ok(time - $start < 1, "a long run of $description is split without rescanning it from each character");
}

my $language_field = {
	lc => 'fr',
	product_type => 'petfood',
	ingredients_text_fr => "Composition : poulet, riz\nConstituants analytiques : protéines 8%, "
		. 'matières grasses brutes 7%, cendres brutes 2%, cellulose brute 1%',
};
parse_ingredients_text_service($language_field, {}, []);
is(
	[map {$_->{type}} @{$language_field->{ingredients_sections} // []}],
	['ingredients', 'analytical'],
	'sections are read from the language specific field'
);

my $empty_key = {
	lc => 'fr',
	ingredients_text => 'poulet, riz',
	ingredients_sections => undef,
	ingredients_percent_analysis => 1,
	specific_ingredients => [{id => 'en:chicken', origins => 'en:france'}],
};
my $empty_key_updates = {};
parse_ingredients_text_service($empty_key, $empty_key_updates, []);
is($empty_key->{ingredients_percent_analysis}, 1, 'an empty sections key does not invalidate the percent analysis');
is(
	$empty_key->{specific_ingredients},
	[{id => 'en:chicken', origins => 'en:france'}],
	'an empty sections key does not reset the specific ingredients'
);
is($empty_key_updates->{ingredients_sections}, undef, 'an empty sections key is not reported as updated');

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

my $salmon = product('4047777023111');
analyze($salmon);
is(
	[map {$_->{type}} @{$salmon->{ingredients_sections} // []}],
	['ingredients', 'analytical'],
	'characteristic untitled analytical data is separated'
);
is(($salmon->{ingredients_sections} // [])->[1]{inferred}, 1, 'untitled boundary is explicitly marked inferred');
my @oil = grep {$_->{id} eq 'en:salmon-fish-oil'} nodes($salmon->{ingredients});
is(scalar @oil, 1, 'salmon oil is recognised independently');
is($oil[0]{percent}, 10, 'salmon oil retains its declared percentage');
is($salmon->{minerals_tags}, [], 'analytical mineral values do not become additive mineral tags');

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

for my $text (
	'protéines végétales 4%, eau, sel',
	"arôme : vanille, eau",
	"protéines 8%, calcium 1%, eau",
	"poulet, émincés de dinde : eau, sel",
	"cendres brutes 2%\ncellulose brute 1%",
	"protéines 8%\ncendres brutes 2%\ncendres brutes 1%"
	)
{
	my $control = {lc => 'fr', product_type => 'petfood', ingredients_text => $text};
	parse_ingredients_text_service($control, {}, []);
	is($control->{ingredients_sections},
		undef, 'ordinary ingredients and isolated nutrient words do not create sections');
}

my $english = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text => "chicken, salmon oil 10%\ncrude protein 8%\ncrude fat 7%\ncrude ash 2%\ncrude fibre 1%"
};
parse_ingredients_text_service($english, {}, []);
is(($english->{ingredients_sections} // [])->[1]{inferred}, 1, 'English analytical inference uses the same safeguards');

for my $case (
	['fr', "poulet\nCONSTITUANTS ANALYTIQUES\nProtéines brutes 8%\n_Additifs nutritionnels_\nTaurine : 660 mg"],
	['en', "chicken\nANALYTICAL CONSTITUENTS\nCrude protein 8%\nNUTRITIONAL ADDITIVES\nTaurine : 660 mg"],
	[
		'fr',
		"poulet\nConstituants analytiques : protéines 8%\n_Additifs nutritionnels_ (/kg): taurine 660 mg, vitamine E 15 mg",
		1
	],
	['en', "chicken\nAnalytical constituents: protein 8%\n_Additives_ (/kg): taurine 660 mg, vitamin E: 15 mg", 1]
	)
{
	my $feed = {lc => $case->[0], product_type => 'petfood', ingredients_text => $case->[1]};
	parse_ingredients_text_service($feed, {}, []);
	is(
		[map {$_->{type}} @{$feed->{ingredients_sections} // []}],
		['ingredients', 'analytical', 'additives'],
		'a separate additive heading does not require a colon'
	);
	my ($taurine) = grep {$_->{id} eq 'en:taurine'} nodes($feed->{ingredients});
	is(defined $taurine ? $taurine->{quantity} : undef, '660 mg', 'additive dosage after analytics is preserved');
	if ($case->[2]) {
		extract_additives_from_text($feed);
		ok(
			scalar(grep {$_ eq 'en:vitamin-e'} @{$feed->{vitamins_tags} // []}),
			'additive extraction uses the same emphasised heading boundary'
		);
	}
}

my $composition = {
	lc => 'en',
	product_type => 'petfood',
	ingredients_text => 'Composition: chicken, water. Meat content: 60%'
};
parse_ingredients_text_service($composition, {}, []);
is($composition->{specific_ingredients}[0]{percent}, 60, 'a single composition keeps its total-content declaration');

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

{
	local $options{product_type} = 'petfood';
	my $text = "Marketing words. Composition : saumon, riz, maïs.\nConstituants analytiques : protéines 30%, "
		. 'matières grasses brutes 10%, cendres brutes 8%, cellulose brute 1,5%';
	is(
		cut_ingredients_text_for_lang($text, 'fr'),
		do {
			local $options{product_type} = 'food';
			cut_ingredients_text_for_lang($text, 'fr');
		},
		'a trailing analytical block is cut like for any other product'
	);
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
$api->{ingredients_text} = 'sel';
parse_ingredients_text_service($api, $updated, []);
is($api->{ingredients_sections}, undef, 'replacing text clears stale sections');
$api->{ingredients_text} = '';
parse_ingredients_text_service($api, $updated, []);
is($api->{ingredients}, undef, 'empty text clears the legacy projection');
is($api->{ingredients_sections}, undef, 'empty text clears section output');

done_testing;
