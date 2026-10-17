use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Ingredients qw(parse_ingredients_text_service extract_ingredients_from_text);

sub parse ($text) {
	my $product = {lc => 'fr', ingredients_text => $text};
	parse_ingredients_text_service($product, {}, []);
	return $product->{ingredients};
}

for my $case (
	["sous-produits d'origine végétale", 'en:derivatives-of-vegetable-origin'],
	["sous produits d'origine végétale", 'en:derivatives-of-vegetable-origin'],
	['sous-produits d’origine végétale', 'en:derivatives-of-vegetable-origin'],
	['protéines végétales', 'en:plant-protein'],
	['extraits de protéines végétales', 'en:plant-protein', 'en:extract'],
	['protéines végétales bio', 'en:plant-protein', undef, 'en:organic'],
	['extraits de protéines végétales bio', 'en:plant-protein', 'en:extract', 'en:organic'],
	['protéines végétales origine France', 'en:plant-protein', undef, undef, 'en:france'],
	[
		"sous-produits d'origine végétale origine France", 'en:derivatives-of-vegetable-origin', undef, undef,
		'en:france'
	],
	['extraits de protéines végétales bio origine France', 'en:plant-protein', 'en:extract', 'en:organic', 'en:france'],
	["sous-produits d'origine végétale bio", 'en:derivatives-of-vegetable-origin', undef, 'en:organic'],
	[
		'protéines végétales*. (*) ingrédients issus de l’agriculture biologique.', 'en:plant-protein',
		undef, 'en:organic'
	],
	)
{
	my ($text, $id, $processing, $labels, $origin) = @$case;
	my $ingredients = parse($text);
	is(scalar @$ingredients, 1, "$text is one ingredient");
	is($ingredients->[0]{id}, $id, "$text retains its specific identity");
	is($ingredients->[0]{processing}, $processing, "$text retains its processing");
	is($ingredients->[0]{labels}, $labels, "$text retains only its external labels");
	is($ingredients->[0]{origins}, $origin, "$text retains its geographic origin") if defined $origin;
}

my $children = parse("sous-produits d'origine végétale bio (protéines végétales 4%)");
is($children->[0]{id}, 'en:derivatives-of-vegetable-origin', 'parent keeps its identity');
is($children->[0]{ingredients}[0]{id}, 'en:plant-protein', 'child keeps its identity');
is($children->[0]{ingredients}[0]{percent}, 4, 'child keeps its percentage');
is($children->[0]{ingredients}[0]{labels}, undef, 'parent organic label does not leak into child');

for my $case (
	['huiles végétales (tournesol, colza, maïs)', 'en:vegetable-oil', qw(en:sunflower-oil en:colza-oil en:corn-oil)],
	[
		'huiles végétales (olive, noisette, sésame, argan)',
		'en:vegetable-oil',
		qw(en:olive-oil en:hazelnut-oil en:sesame-oil en:argan-oil)
	],
	['protéines végétales (blé, pois, maïs)', 'en:plant-protein', qw(en:wheat-protein en:pea-protein en:corn-protein)],
	['extraits végétaux (citron, carotte)', 'en:vegetable-extract', qw(en:lemon-extract en:carrot-extract)],
	)
{
	my ($text, $parent_id, @child_ids) = @$case;
	my $parent = parse($text)->[0];
	is($parent->{id}, $parent_id, "$text keeps its plant identity");
	is([map {$_->{id}} @{$parent->{ingredients}}], \@child_ids, "$text children compose with its generic name");
}

for my $case (
	['lait origine France', 'en:milk', 'en:france'],
	['lait entier origine France', 'en:whole-milk', 'en:france'],
	['viande bovine origine France', 'en:beef-meat', 'en:france'],
	['miel origine Espagne', 'en:honey', 'en:spain'],
	)
{
	my ($text, $id, $origin) = @$case;
	my $ingredients = parse($text);
	is($ingredients->[0]{id}, $id, "$text is not turned into an origin-specific name");
	is($ingredients->[0]{origins}, $origin, "$text keeps its geographic origin");
}

my $ordinary = parse("tomates bio (origine Italie), huile d'olive (origine Espagne)");
is([map {$_->{origins}} @$ordinary], ['en:italy', 'en:spain'], 'geographic origins still attach to ingredients');
is($ordinary->[0]{labels}, 'en:organic', 'ordinary organic labels are retained');

my $product = {lc => 'fr', ingredients_text => 'extraits de protéines végétales', nutrition => {}};
extract_ingredients_from_text($product);
is($product->{ingredients}[0]{vegan}, 'yes', 'plant protein retains its vegan property');
is($product->{ingredients}[0]{vegetarian}, 'yes', 'plant protein retains its vegetarian property');

my $emulsifier = {
	lc => 'fr',
	ingredients_text => "mono- et diglycérides d'acides gras d'origine végétale",
	nutrition => {},
};
extract_ingredients_from_text($emulsifier);
is($emulsifier->{ingredients}[0]{vegan}, 'yes', 'explicit vegetable origin survives a specific taxonomy identity');
is($emulsifier->{ingredients}[0]{vegetarian}, 'yes', 'explicit vegetable origin retains vegetarian information');

my $mixed = {
	lc => 'fr',
	ingredients_text => "sucre, mono- et diglycérides d'acides gras d'origine végétale ou animale, sel",
	nutrition => {},
};
extract_ingredients_from_text($mixed);
is([map {$_->{id}} @{$mixed->{ingredients}}], ['en:sugar', 'en:e471', 'en:salt'], 'a mixed origin keeps the name');
is($mixed->{ingredients}[1]{labels}, undef, 'a mixed plant and animal origin is not a vegan label');
isnt($mixed->{ingredients}[1]{vegan}, 'yes', 'a mixed plant and animal origin is not a vegan claim');
is($mixed->{ingredients}[1]{origins}, undef, 'a mixed plant and animal origin is not a geographic origin');

my $inline = {lc => 'fr', ingredients_text => 'huile végétale origine France et gélatine', nutrition => {}};
extract_ingredients_from_text($inline);
is($inline->{ingredients}[0]{vegan}, 'yes', 'a plant name keeps its claim');
is($inline->{ingredients}[1]{vegan}, 'no', 'a plant claim does not reach the next ingredient');
is($inline->{ingredients}[1]{origins}, undef, 'an inline origin does not reach the next ingredient');

is(scalar @{parse(join(' et ', ('huile végétale') x 40))},
	40, 'a long coordinated list of plant names stays quick to parse');

for my $text ('colorant végétal', 'extraits végétaux', 'bouillon végétal') {
	my $kept = {lc => 'fr', ingredients_text => $text, nutrition => {}};
	extract_ingredients_from_text($kept);
	is($kept->{ingredients}[0]{vegan}, 'yes', "$text keeps what its dietary word claims");
}

my $broth = parse('bouillon de légumes bio (sel, farine de riz, légumes, huile de tournesol)')->[0];
is($broth->{id}, 'en:vegetable-broth', 'the broth keeps its identity');
is(
	[map {$_->{id}} @{$broth->{ingredients}}],
	[qw(en:salt en:rice-flour en:vegetable en:sunflower-oil)],
	'a child that only gives the generic name back is not turned into its parent'
);

done_testing;
