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
stopwords:fr: de, au
stopwords:en: and

en: chocolate
fr: chocolat

en: milk
fr: lait

en: sugar
fr: sucre

< en: chocolate
en: milk chocolate
fr: chocolat au lait

en: fat

en: oil

en: palm oil and fat

< en: palm oil and fat
en: palm oil

< en: palm oil
en: palm

< en: oil
en: rapeseed oil

en: rapeseed, rape

en: soya, soja

< en: oil
en: soya oil

< en: oil
en: sample seed oil

en: walnut

< en: walnut
en: walnut oil

en: sunflower

< en: oil
en: sunflower oil

en: juice
fr: jus

en: apple
fr: pomme

< en: juice
en: apple juice
fr: jus de pomme
TAXONOMY
close($out) or die $!;
build_tags_taxonomy('ingredients', 1);
retrieve_tags_taxonomy('ingredients');

for my $case (
	['fr', 'chocolat (sucre, lait)', 'en:milk', 'context does not invent a synonym by removing au', 1],
	['en', 'fat (palm oil)', 'en:palm-oil', 'a generated compound synonym does not broaden a known child'],
	['en', 'oil (palm)', 'en:palm-oil', 'the preparsed oil identity is preserved'],
	['en', 'oil (rapeseed)', 'en:rapeseed-oil', 'an explicit oil name remains recognized'],
	['en', 'oil (walnut)', 'en:walnut-oil', 'parent context can refine a known child'],
	['en', 'oil (sunflower, unknown)', 'en:sunflower-oil', 'an explicit oil name does not need a raw-source parent'],
	['en', 'juice (apple, water)', 'en:apple-juice', 'an explicit juice name does not need a raw-source parent'],
	['fr', 'jus (pomme, eau)', 'en:apple-juice', 'French of connectors can identify a declared juice name'],
	['en', 'oil (sample seed, water)', 'en:sample-seed-oil', 'parent context still identifies an unknown child'],
	['en', 'oil (soja, water)', 'en:soya-oil', 'parent context preserves a declared soya synonym'],
	['en', 'oil (rape, water)', 'en:rapeseed-oil', 'parent context preserves a declared rapeseed synonym'],
	)
{
	my $product = {lc => $case->[0], ingredients_text => $case->[1]};
	parse_ingredients_text_service($product, {}, []);
	my $index = $case->[4] // 0;
	is($product->{ingredients}[0]{ingredients}[$index]{id}, $case->[2], $case->[3]);
}

done_testing;
