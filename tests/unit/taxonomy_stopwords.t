use ProductOpener::PerlStandards;
use Test2::V0;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use ProductOpener::Config qw(%options);
use ProductOpener::Paths qw(%BASE_DIRS);
use ProductOpener::Store qw(retrieve_config store_config);
use ProductOpener::Tags qw(build_tags_taxonomy canonicalize_taxonomy_tag retrieve_tags_taxonomy exists_taxonomy_tag is_a
	remove_stopwords_from_start_or_end_of_string);

my $tmp = tempdir(CLEANUP => 1);
local $BASE_DIRS{TAXONOMIES_SRC} = "$tmp/src";
local $BASE_DIRS{CACHE_BUILD} = "$tmp/cache";
local $BASE_DIRS{PUBLIC_DATA} = "$tmp/public";
local $options{product_type} = 'food';
local $ENV{TAXONOMY_NO_GET_FROM_CACHE} = 1;
make_path("$tmp/src/food", "$tmp/cache", "$tmp/public");

sub source ($name, $text) {
	open(my $out, '>:encoding(UTF-8)', "$tmp/src/$name") or die $!;
	print $out $text;
	close($out) or die $!;
	return;
}

for my $name (qw(additives_classes additives minerals vitamins amino_acids nucleotides other_nutritional_substances)) {
	source("$name.txt", '');
}
source('vitamins.txt', "stopwords:fr: de, d\nstopwords:en: a, and, from\n");
my $concepts = <<'TAXONOMY';
en: animal derivatives
fr: sous-produits animaux

en: meat and animal derivatives
fr: viande et sous-produits animaux

en: vitamin D
fr: vitamine D, d, de d et

en: vitamin A and D

en: juice concentrate

en: juice from concentrate

< en: juice from concentrate
en: lemon juice from concentrate
TAXONOMY

# The first build primes both regexp caches with a narrower stopword list.
source('food/ingredients.txt', $concepts);
build_tags_taxonomy('ingredients', 1);
is(ProductOpener::Tags::remove_stopwords('ingredients', 'fr', 'de-poisson'), 'poisson', 'prime normalized stopwords');
is(remove_stopwords_from_start_or_end_of_string('ingredients', 'fr', 'de poisson'), 'poisson', 'prime text stopwords');

my @compiled;
for my $position ('late', 'early') {
	my $declaration = "stopwords:fr: et\n\n";
	source('food/ingredients.txt', $position eq 'early' ? $declaration . $concepts : $concepts . "\n" . $declaration);
	build_tags_taxonomy('ingredients', 1);
	for my $id ('en:vitamin-d', 'en:vitamin-a-and-d', 'en:juice-concentrate', 'en:juice-from-concentrate') {
		ok(exists_taxonomy_tag('ingredients', $id), "$position normalization does not merge $id");
	}
	ok(is_a('ingredients', 'en:lemon-juice-from-concentrate', 'en:juice-from-concentrate'),
		"$position normalization preserves the declared parent");
	for my $phrase ('', 'et') {
		my $exists;
		canonicalize_taxonomy_tag('fr', 'ingredients', $phrase, \$exists);
		is($exists, 0, "$position normalization never matches an empty generated synonym: $phrase");
	}
	is(
		canonicalize_taxonomy_tag('fr', 'ingredients', 'viandes et sous-produits animaux'),
		'en:meat-and-animal-derivatives',
		"$position stopwords preserve the plural compound during compilation"
	);
	is(ProductOpener::Tags::remove_stopwords('ingredients', 'fr', 'de-et-poisson'),
		'poisson', "$position normalized list is complete");
	is(remove_stopwords_from_start_or_end_of_string('ingredients', 'fr', 'et poisson'),
		'poisson', "$position text list is complete");
	push @compiled, retrieve_config("$tmp/cache/taxonomies-result/ingredients.result");
	ok(!exists $compiled[-1]{synonyms}{fr}{''}, "$position compilation exports no empty synonym");
	is($compiled[-1]{stopwords}{fr}, ['de', 'd', 'et'], "$position declarations are collected once");
}
is($compiled[0], $compiled[1], 'moving a stopword declaration preserves the compiled taxonomy');

# Reload the saved taxonomy after another compilation has populated both caches.
source('food/ingredients.txt', $concepts);
build_tags_taxonomy('ingredients', 1);
ProductOpener::Tags::remove_stopwords('ingredients', 'fr', 'de-poisson');
remove_stopwords_from_start_or_end_of_string('ingredients', 'fr', 'de poisson');
store_config("$tmp/cache/taxonomies-result/ingredients.result", $compiled[0]);
retrieve_tags_taxonomy('ingredients');
is(ProductOpener::Tags::remove_stopwords('ingredients', 'fr', 'et-poisson'),
	'poisson', 'reloading replaces normalized stopwords');
is(remove_stopwords_from_start_or_end_of_string('ingredients', 'fr', 'et poisson'),
	'poisson', 'reloading replaces text stopwords');
is(
	canonicalize_taxonomy_tag('fr', 'ingredients', 'viandes et sous-produits animaux'),
	'en:meat-and-animal-derivatives',
	'plural recognition survives cache reload'
);

done_testing;
