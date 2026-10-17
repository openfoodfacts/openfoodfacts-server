use ProductOpener::PerlStandards;
use Test2::V0;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use ProductOpener::Config qw(%options);
use ProductOpener::Paths qw(%BASE_DIRS);
use ProductOpener::Tags qw(build_tags_taxonomy retrieve_tags_taxonomy);
use ProductOpener::Ingredients qw(parse_ingredients_text_service);

my $tmp = tempdir(CLEANUP => 1);
local $BASE_DIRS{TAXONOMIES_SRC} = "$tmp/src";
local $BASE_DIRS{CACHE_BUILD} = "$tmp/cache";
local $BASE_DIRS{PUBLIC_DATA} = "$tmp/public";
local $options{product_type} = 'food';
local $ENV{TAXONOMY_NO_GET_FROM_CACHE} = 1;
make_path("$tmp/src/food", "$tmp/cache", "$tmp/public");
for my $name (qw(additives_classes additives minerals vitamins nucleotides other_nutritional_substances)) {
	open(my $out, '>:encoding(UTF-8)', "$tmp/src/$name.txt") or die $!;
	close($out) or die $!;
}
open(my $out, '>:encoding(UTF-8)', "$tmp/src/food/ingredients.txt") or die $!;
print $out <<'TAXONOMY';
stopwords:fr: de, d, et, dont, avec, autres
stopwords:en: and, of
synonyms:en: pasteurised, pasteurized

en: chicken
fr: poulet

en: rice
fr: riz

en: meat
fr: viande

en: animal derivatives
fr: sous-produits animaux

en: meat and animal derivatives
fr: viande et sous-produits animaux

en: E270, lactic acid

en: lactic ferments, lactic acid culture, cultures

en: vitamin and mineral blend, vitamin and mineral mix

en: milk

en: cream

en: pasteurized milk and cream

en: natural flavouring
fr: arôme naturel

en: natural apple flavouring
fr: arôme naturel de pomme

< en: natural flavouring
< en: natural apple flavouring
fr: arôme naturel de pomme avec autres arômes naturels

TAXONOMY
close($out) or die $!;
build_tags_taxonomy('ingredients', 1);
retrieve_tags_taxonomy('ingredients');

sub parse ($lc, $text) {
	my $product = {lc => $lc, ingredients_text => $text};
	parse_ingredients_text_service($product, {}, []);
	return $product->{ingredients};
}

for my $text ('viande et sous-produits animaux', 'viandes et sous-produits animaux') {
	my $ingredients = parse('fr', "$text (dont poulet 4%)");
	is(scalar @$ingredients, 1, "$text is a single declared compound");
	is($ingredients->[0]{id}, 'en:meat-and-animal-derivatives', "$text preserves canonical identity");
	is($ingredients->[0]{ingredients}[0]{id}, 'en:chicken', "$text preserves the child");
	is($ingredients->[0]{ingredients}[0]{percent}, 4, "$text preserves the child's percentage");
}
my $percentage = parse('fr', 'viandes et sous-produits animaux 95% (dont poulet 4%)');
is(scalar @$percentage, 1, 'a trailing percentage does not split a compound');
is($percentage->[0]{id}, 'en:meat-and-animal-derivatives', 'percentage compound keeps its canonical identity');
is($percentage->[0]{percent}, 95, 'percentage belongs to the whole compound');
is(
	[map {$_->{id}} @{parse('fr', "viandes et sous-produits d'animaux (dont poulet 4%)")}],
	['en:meat-and-animal-derivatives'],
	'other stopwords can vary without removing the conjunction'
);

is([map {$_->{id}} @{parse('fr', 'poulet et riz')}], ['en:chicken', 'en:rice'], 'ordinary coordination is split');
is(
	[map {$_->{id}} @{parse('en', 'lactic acid and cultures')}],
	['en:e270', 'en:lactic-ferments'],
	'removing and must not turn two ingredients into an undeclared compound'
);
is(
	[map {$_->{id}} @{parse('en', 'vitamin and mineral mix')}],
	['en:vitamin-and-mineral-blend'],
	'an explicitly declared compound synonym stays intact'
);

is(
	[map {$_->{id}} @{parse('en', 'pasteurised milk and cream')}],
	['en:pasteurized-milk-and-cream'],
	'a generated spelling synonym preserves the conjunction'
);

for my $text ("arôme naturel de pomme avec d'autres arômes naturels",
	'arôme naturel de pomme avec autres arômes naturels')
{
	is(
		[map {$_->{id}} @{parse('fr', $text)}],
		['fr:arome-naturel-de-pomme-avec-autres-aromes-naturels'],
		'a declared compound survives the parser normalization of other flavourings'
	);
}

done_testing;
