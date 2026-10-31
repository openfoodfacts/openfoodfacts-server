use ProductOpener::PerlStandards;
use Test2::V0;
use ProductOpener::Tags qw(canonicalize_taxonomy_tag get_inherited_property is_a);
use ProductOpener::Ingredients qw(parse_ingredients_text_service detect_allergens_from_text);

for my $case (
	['en', 'concentrated pomegranate juice', 'en:concentrated-pomegranate-juice'],
	['en', 'pomegranate juice concentrate', 'en:concentrated-pomegranate-juice'],
	['en', 'pomegranate juice concentrates', 'en:concentrated-pomegranate-juice'],
	['en', 'animal derivatives', 'en:animal-derivatives'],
	['en', 'animal by-products', 'en:animal-derivatives'],
	['fr', 'sous-produits animaux', 'en:animal-derivatives'],
	['fr', 'sous produits animaux', 'en:animal-derivatives'],
	['fr', "sous-produits d'origine animale", 'en:animal-derivatives'],
	['en', 'fish derivatives', 'en:fish-derivatives'],
	['en', 'fish by-products', 'en:fish-derivatives'],
	['fr', 'sous-produits de poissons', 'en:fish-derivatives'],
	['fr', 'sous-produits de poisson', 'en:fish-derivatives'],
	['fr', 'sous produits de poissons', 'en:fish-derivatives'],
	['en', 'fish and fish derivatives', 'en:fish-and-fish-derivatives'],
	['en', 'fish and fish by-products', 'en:fish-and-fish-derivatives'],
	['fr', 'poissons et sous-produits de poissons', 'en:fish-and-fish-derivatives'],
	['fr', 'poisson et sous-produits de poisson', 'en:fish-and-fish-derivatives'],
	)
{
	my ($lc, $text, $expected) = @$case;
	my $exists;
	my $id = canonicalize_taxonomy_tag($lc, 'ingredients', $text, \$exists);
	is([$id, $exists], [$expected, 1], "$text identifies a known ingredient");
}

for my $case (
	['en:concentrated-pomegranate-juice', 'en:pomegranate-juice'],
	['en:meat-and-animal-derivatives', 'en:animal'],
	['en:animal-derivatives', 'en:animal'],
	['en:fish-derivatives', 'en:animal-derivatives'],
	['en:fish-derivatives', 'en:animal'],
	['en:fish-derivatives', 'en:fish'],
	['en:fish-and-fish-derivatives', 'en:animal'],
	['en:fish-and-fish-derivatives', 'en:fish'],
	['en:krill', 'en:crustacean'],
	)
{
	my ($id, $parent) = @$case;
	ok(is_a('ingredients', $id, $parent), "$id inherits from $parent");
}

is(
	canonicalize_taxonomy_tag('en', 'ingredients', 'pomegranate juice from concentrate'),
	'en:pomegranate-juice-from-concentrate',
	'reconstituted pomegranate juice keeps its separate identity'
);
ok(!is_a('ingredients', 'en:concentrated-pomegranate-juice', 'en:pomegranate-juice-from-concentrate'),
	'pomegranate concentrate is not reconstituted juice');

for my $text ('pomegranate juice concentrate', 'pomegranate juice concentrates') {
	my $product = {lc => 'en', ingredients_text => $text};
	parse_ingredients_text_service($product, {}, []);
	is(
		[map {$_->{id}} @{$product->{ingredients}}],
		['en:concentrated-pomegranate-juice'],
		"$text remains concentrated juice after parsing"
	);
}

for my $case (
	['en:meat-and-animal-derivatives', 'no'],
	['en:animal-derivatives', 'no'],
	['en:fish-derivatives', 'no'],
	['en:fish-and-fish-derivatives', 'no'],
	['en:derivatives-of-vegetable-origin', 'yes'],
	['en:krill', 'no'],
	)
{
	my ($id, $expected) = @$case;
	for my $property ('vegan:en', 'vegetarian:en') {
		is(get_inherited_property('ingredients', $id, $property), $expected, "$id has $property = $expected");
	}
}

is(get_inherited_property('ingredients', 'en:krill', 'allergens:en'),
	'en:crustaceans', 'krill inherits the crustacean allergen');

for my $case (
	['en', 'fish derivatives', 'en:fish-derivatives', 'en:fish'],
	['fr', 'sous-produits de poissons', 'en:fish-derivatives', 'en:fish'],
	['en', 'fish and fish derivatives', 'en:fish-and-fish-derivatives', 'en:fish'],
	['fr', 'poissons et sous-produits de poissons', 'en:fish-and-fish-derivatives', 'en:fish'],
	['en', 'krill', 'en:krill', 'en:crustaceans'],
	)
{
	my ($lc, $text, $expected_id, $allergen) = @$case;
	my $product = {lc => $lc, ingredients_text => $text};
	parse_ingredients_text_service($product, {}, []);
	is([map {$_->{id}} @{$product->{ingredients}}], [$expected_id], "$text remains a single parsed ingredient");

	# Project only the parsed ingredients so text matching cannot hide a missing taxonomy allergen.
	my $allergen_product = {lc => $lc, ingredients => $product->{ingredients}};
	detect_allergens_from_text($allergen_product);
	is($allergen_product->{allergens_tags}, [$allergen], "$text projects its allergen from the taxonomy");
}

done_testing;
