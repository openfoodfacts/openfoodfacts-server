use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Ingredients::Sections qw(split_ingredient_sections);

for my $case (
	[
		'fr',
		"Composition : poulet, riz\nConstituants analytiques : protéines 8%\nAdditifs par kg : taurine 660 mg",
		['ingredients', 'analytical', 'additives']
	],
	[
		'en',
		"Ingredients: chicken, rice\nAnalytical constituents: protein 8%\nAdditives (per kg): taurine 660 mg",
		['ingredients', 'analytical', 'additives']
	],
	['fr', "Recette poulet : poulet 4%, eau.\nRecette dinde : dinde 4%, eau.", ['recipe', 'recipe']],
	['en', 'With Chicken Ingredients: chicken. With Salmon Ingredients: salmon.', ['recipe', 'recipe']],
	[
		'fr',
		"viande, céréales.\n33% de croquettes rouges et 67% de croquettes brunes dans le produit fini.",
		['ingredients', 'mixture']
	],
	)
{
	my ($lc, $text, $types) = @$case;
	my $sections = split_ingredient_sections($text, $lc);
	is([map {$_->{type}} @{$sections // []}], $types, 'explicit headings separate the declared sections');
	is(join('', map {$_->{text}} @$sections), $text, 'section spans preserve the complete source text');
}

for my $text (
	'protéines végétales 4%, eau, sel',
	'arôme : vanille, eau',
	'poulet, émincés de dinde : eau, sel',
	'Décomposition : poulet, riz'
	)
{
	is(split_ingredient_sections($text, 'fr'), undef, 'an ingredient phrase does not become a heading');
}

done_testing;
