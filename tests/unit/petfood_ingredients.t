use ProductOpener::PerlStandards;
use Test2::V0;
use Cwd qw(abs_path);
use ProductOpener::Paths qw(get_files_for_taxonomy get_path_for_taxonomy_file);
use ProductOpener::Tags qw(canonicalize_taxonomy_tag display_taxonomy_tag exists_taxonomy_tag);
use ProductOpener::Ingredients qw(parse_ingredients_text_service);

is(
	[map {abs_path(get_path_for_taxonomy_file($_))} get_files_for_taxonomy('ingredients', 'petfood')],
	[map {abs_path(get_path_for_taxonomy_file($_))} get_files_for_taxonomy('ingredients', 'food')],
	'food and petfood select the same ingredient sources'
);

for my $case (
	['fr', 'poulet', 'en:chicken'],
	['fr', 'dinde', 'en:turkey'],
	['fr', 'poisson', 'en:fish'],
	['fr', 'viande et sous-produits animaux', 'en:meat-and-animal-derivatives'],
	['en', 'krill', 'en:krill'],
	['fr', "sous-produits d'origine végétale", 'en:derivatives-of-vegetable-origin'],
	['fr', 'huile de saumon', 'en:salmon-fish-oil'],
	['de', 'Lachsöl', 'en:salmon-fish-oil'],
	)
{
	is(canonicalize_taxonomy_tag($case->[0], 'ingredients', $case->[1]), $case->[2],
		"$case->[1] has a shared identity");
}

is(
	lc(display_taxonomy_tag('fr', 'ingredients', 'en:salmon-fish-oil')),
	'huile de saumon',
	'the existing salmon oil entry receives the petfood translations'
);
is(canonicalize_taxonomy_tag('en', 'ingredients', 'en:salmon-oil'),
	'en:salmon-fish-oil', 'the former petfood salmon oil ID canonicalizes to the food entry');
ok(!exists_taxonomy_tag('ingredients', 'en:salmon-oil'), 'salmon oil has a single canonical entry');

todo 'Shared taxonomy stopword normalization needs the compiler fix in PR #14938' => sub {
	is(
		canonicalize_taxonomy_tag('fr', 'ingredients', 'viandes et sous-produits animaux'),
		'en:meat-and-animal-derivatives',
		'the plural still identifies the complete compound'
	);

	my $product = {lc => 'fr', ingredients_text => 'viandes et sous-produits animaux'};
	parse_ingredients_text_service($product, {}, []);
	is(
		[map {$_->{id}} @{$product->{ingredients}}],
		['en:meat-and-animal-derivatives'],
		'the plural remains a single ingredient'
	);
};

done_testing;
