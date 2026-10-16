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
	["sous-produits d'origine végétale bio", 'en:derivatives-of-vegetable-origin', undef, 'en:organic'],
	[
		'protéines végétales*. (*) ingrédients issus de l’agriculture biologique.', 'en:plant-protein',
		undef, 'en:organic'
	],
	)
{
	my ($text, $id, $processing, $labels) = @$case;
	my $ingredients = parse($text);
	is(scalar @$ingredients, 1, "$text is one ingredient");
	is($ingredients->[0]{id}, $id, "$text retains its specific identity");
	is($ingredients->[0]{processing}, $processing, "$text retains its processing");
	is($ingredients->[0]{labels}, $labels, "$text retains only its external labels");
}

my $children = parse("sous-produits d'origine végétale bio (protéines végétales 4%)");
is($children->[0]{id}, 'en:derivatives-of-vegetable-origin', 'parent keeps its identity');
is($children->[0]{ingredients}[0]{id}, 'en:plant-protein', 'child keeps its identity');
is($children->[0]{ingredients}[0]{percent}, 4, 'child keeps its percentage');
is($children->[0]{ingredients}[0]{labels}, undef, 'parent organic label does not leak into child');

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

done_testing;
