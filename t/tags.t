#!/usr/bin/perl -w

use Modern::Perl '2017';

use utf8;

use Test::More;
#use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::Store qw/:all/;

init_emb_codes();

ok (is_a( "categories", "en:beers", "en:beverages"), 'en:beers is a child of en:beverages');
ok (! is_a( "categories", "en:beers", "en:milks"), 'en:beers is not a child of en:milk');

my $product_ref = {
	test_tags => [ 'en:test' ]
};

# verify has_tag works correctly
ok( has_tag($product_ref, 'test', 'en:test'), 'has_tag should be true' );
ok( !has_tag($product_ref, 'test', 'de:mein-tag'), 'has_tag should be false' );

# verify add_tag adds the new tag correctly
add_tag($product_ref, 'test', 'de:mein-tag');
ok( has_tag($product_ref, 'test', 'de:mein-tag'), 'has_tag should be true after add' );

# verify remove_tag removes the new tag correctly
remove_tag($product_ref, 'test', 'de:mein-tag');
ok( !has_tag($product_ref, 'test', 'de:mein-tag'), 'has_tag should be false after remove' );

# verify add_tag creates a new tags array if the matching tags field does not exist yet
add_tag($product_ref, 'nexist', 'en:test');
ok( has_tag($product_ref, 'nexist', 'en:test'), 'has_tag should be true after add' );

# verify known Wikidata ID is converted to the taxonomy tag
is( canonicalize_taxonomy_tag('en', 'categories', 'wikidata:en:Q470974'), 'fr:fitou', '"wikidata:en:Q470974" should be canonicalized to "fr:fitou"' );

# verify known Wikidata URL is converted to the taxonomy tag
is( canonicalize_taxonomy_tag('en', 'categories', 'https://www.wikidata.org/wiki/Q470974'), 'fr:fitou', 'Wikidata URL "https://www.wikidata.org/wiki/Q470974" should be canonicalized to "fr:fitou"' );

is (display_taxonomy_tag("en", "categories", "en:beverages"), "Beverages");
is (display_taxonomy_tag("fr", "categories", "en:beverages"), "Boissons");
is (display_taxonomy_tag("en", "categories", "en:doesnotexist"), "Doesnotexist");
is (display_taxonomy_tag("fr", "categories", "en:doesnotexist"), "en:doesnotexist");

is (display_taxonomy_tag_link("fr", "categories", "en:doesnotexist"), '<a href="/categorie/en:doesnotexist" class="tag user_defined" lang="en">en:doesnotexist</a>');

is (display_tags_hierarchy_taxonomy("fr", "categories", ["en:doesnotexist"]), '<a href="/categorie/en:doesnotexist" class="tag user_defined" lang="en">en:doesnotexist</a>');

is (display_tags_hierarchy_taxonomy("en", "categories", ["en:doesnotexist"]), '<a href="/category/doesnotexist" class="tag user_defined">Doesnotexist</a>');

# test canonicalize_taxonomy_tags


# test add_tags_to_field

$product_ref = {
	lc => "fr",
};

add_tags_to_field($product_ref, "fr", "categories", "pommes, bananes");

is_deeply($product_ref,
{
	'categories' => 'pommes, bananes',
	'lc' => 'fr',
	'categories_hierarchy' => [
		'en:plant-based-foods-and-beverages',
		'en:plant-based-foods',
		'en:fruits-and-vegetables-based-foods',
		'en:fruits-based-foods',
		'en:fruits',
		'en:apples',
		'en:tropical-fruits',
		'en:bananas'
	],
	'categories_lc' => 'fr',
	'categories_tags' => [
		'en:plant-based-foods-and-beverages',
		'en:plant-based-foods',
		'en:fruits-and-vegetables-based-foods',
		'en:fruits-based-foods',
		'en:fruits',
		'en:apples',
		'en:tropical-fruits',
		'en:bananas'
	],

}
) or diag explain $product_ref;

compute_field_tags($product_ref, "fr", "categories");

delete($product_ref->{categories_debug_tags});
delete($product_ref->{categories_prev_hierarchy});
delete($product_ref->{categories_prev_tags});
delete($product_ref->{categories_next_hierarchy});
delete($product_ref->{categories_next_tags});

is_deeply($product_ref,
{
	'categories' => 'pommes, bananes',
	'categories_hierarchy' => [
		'en:plant-based-foods-and-beverages',
		'en:plant-based-foods',
		'en:fruits-and-vegetables-based-foods',
		'en:fruits-based-foods',
		'en:fruits',
		'en:apples',
		'en:tropical-fruits',
		'en:bananas',
	],
	'categories_lc' => 'fr',
	'categories_tags' => [
		'en:plant-based-foods-and-beverages',
		'en:plant-based-foods',
		'en:fruits-and-vegetables-based-foods',
		'en:fruits-based-foods',
		'en:fruits',
		'en:apples',
		'en:tropical-fruits',
		'en:bananas',
	],
	'lc' => 'fr'
}

) or diag explain $product_ref;

foreach my $tag (@{$product_ref->{categories_tags}}) {

	print STDERR "tag: $tag\tlevel: " . $level{categories}{$tag} . "\n";
}

add_tags_to_field($product_ref, "fr", "categories", "pommes, bananes");

is($product_ref->{categories}, "pommes, bananes");

add_tags_to_field($product_ref, "fr", "categories", "fraises");

is($product_ref->{categories}, "Aliments et boissons à base de végétaux, Aliments d'origine végétale, Aliments à base de fruits et de légumes, Fruits et produits dérivés, Fruits, Pommes, Fruits tropicaux, Bananes, fraises");

add_tags_to_field($product_ref, "fr", "categories", "en:raspberries, en:plum");

compute_field_tags($product_ref, "fr", "categories");

is_deeply($product_ref->{categories_tags},
[
	'en:plant-based-foods-and-beverages',
	'en:plant-based-foods',
	'en:fruits-and-vegetables-based-foods',
	'en:fruits-based-foods',
	'en:fruits',
	'en:apples',
	'en:berries',
	'en:tropical-fruits',
	'en:bananas',
	'en:plums',
	'en:raspberries',
	'en:strawberries',
]

) or diag explain $product_ref->{categories_tags};

add_tags_to_field($product_ref, "es", "categories", "naranjas, limones");
compute_field_tags($product_ref, "es", "categories");


is_deeply($product_ref->{categories_tags},
[
	'en:plant-based-foods-and-beverages',
	'en:plant-based-foods',
	'en:fruits-and-vegetables-based-foods',
	'en:fruits-based-foods',
	'en:fruits',
	'en:apples',
	'en:berries',
	'en:citrus',
	'en:tropical-fruits',
	'en:bananas',
	'en:lemons',
	'en:oranges',
	'en:plums',
	'en:raspberries',
	'en:strawberries',
]

) or diag explain $product_ref->{categories_tags};

is($product_ref->{categories}, "Alimentos y bebidas de origen vegetal, Alimentos de origen vegetal, Frutas y verduras y sus productos, Frutas y sus productos, Frutas, Manzanas, Frutas del bosque, Frutas tropicales, Plátanos, Ciruelas, Frambuesas, Fresas, naranjas, limones");

add_tags_to_field($product_ref, "it", "categories", "bogus, mele");
compute_field_tags($product_ref, "it", "categories");

is_deeply($product_ref->{categories_tags},
[
	'en:plant-based-foods-and-beverages',
	'en:plant-based-foods',
	'en:fruits-and-vegetables-based-foods',
	'en:fruits-based-foods',
	'en:fruits',
	'en:apples',
	'en:berries',
	'en:citrus',
	'en:tropical-fruits',
	'en:bananas',
	'en:lemons',
	'en:oranges',
	'en:plums',
	'en:raspberries',
	'en:strawberries',
	'it:bogus',
]

#) or diag explain $product_ref->{categories_tags};
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
};

add_tags_to_field($product_ref, "fr", "countries", "france, en:spain, deutschland, fr:bolivie, italie, de:suisse, colombia, bidon");

is_deeply($product_ref,
{
	'countries' => 'france, en:spain, deutschland, fr:bolivie, italie, de:suisse, colombia, bidon',
	'lc' => 'fr',
	'countries_hierarchy' => [
		'en:bolivia',
		'en:colombia',
		'en:france',
		'en:italy',
		'en:spain',
		'en:switzerland',
		'fr:bidon',
		'fr:deutschland'
	],
	'countries_lc' => 'fr',
	'countries_tags' => [
		'en:bolivia',
		'en:colombia',
		'en:france',
		'en:italy',
		'en:spain',
		'en:switzerland',
		'fr:bidon',
		'fr:deutschland'
	],


}) or diag explain($product_ref);


compute_field_tags($product_ref, "fr", "countries");

is_deeply($product_ref->{countries_tags},
[
	'en:bolivia',
	'en:colombia',
	'en:france',
	'en:italy',
	'en:spain',
	'en:switzerland',
	'fr:bidon',
	'fr:deutschland',
]
)  or diag explain $product_ref->{countries_tags};

add_tags_to_field($product_ref, "es", "countries", "peru,bogus");
compute_field_tags($product_ref, "es", "countries");

is_deeply($product_ref->{countries_tags},
[
	'en:bolivia',
	'en:colombia',
	'en:france',
	'en:italy',
	'en:peru',
	'en:spain',
	'en:switzerland',
	'es:bogus',
	'fr:bidon',
	'fr:deutschland',
]
)  or diag explain $product_ref->{countries_tags};


$product_ref = {
	lc => "fr",
};

add_tags_to_field($product_ref, "fr", "brands", "Baba, Bobo");

is_deeply($product_ref,
{
	'brands' => 'Baba, Bobo',
	'brands_tags' => [
		'baba',
		'bobo'
	],

	'lc' => 'fr'
}) or diag explain($product_ref);


compute_field_tags($product_ref, "fr", "brands");

is_deeply($product_ref->{brands_tags},
[
	'baba',
	'bobo',
]
)  or diag explain $product_ref->{brands_tags};

add_tags_to_field($product_ref, "fr", "brands", "Bibi");

delete $product_ref->{brands_debug_tags};

is_deeply($product_ref,
{
	'brands' => 'Baba, Bobo, Bibi',
	'brands_tags' => [
		'baba',
		'bobo',
		'bibi',
	],

	'lc' => 'fr'
}) or diag explain($product_ref);


compute_field_tags($product_ref, "fr", "brands");

delete $product_ref->{brands_debug_tags};

is_deeply($product_ref->{brands_tags},
[
	'baba',
	'bobo',
	'bibi',
]
)  or diag explain $product_ref->{brands_tags};

my @tags = ();

@tags = gen_tags_hierarchy_taxonomy("en", "ingredients", "en:concentrated-orange-juice, en:sugar, en:salt, en:orange");

is_deeply (\@tags, [
	'en:fruit',
	'en:citrus-fruit',
	'en:fruit-juice',
	'en:salt',
	'en:sugar',
	'en:orange',
	'en:orange-juice',
	'en:concentrated-orange-juice'
]
) or diag explain(\@tags);


foreach my $tag (@tags) {

	print STDERR "tag: $tag\tlevel: " . $level{ingredients}{$tag} . "\n";
}


@tags = gen_ingredients_tags_hierarchy_taxonomy("en", "en:concentrated-orange-juice, en:sugar, en:salt, en:orange");

is_deeply (\@tags, [
	'en:concentrated-orange-juice',
	'en:fruit',
	'en:citrus-fruit',
	'en:fruit-juice',
	'en:orange',
	'en:orange-juice',
	'en:sugar',
	'en:salt',
]
) or diag explain(\@tags);

ProductOpener::Tags::retrieve_tags_taxonomy("test");

is(get_property("test","en:meat","vegan:en"), "no");
is($properties{test}{"en:meat"}{"vegan:en"}, "no");
is(get_inherited_property("test","en:meat","vegan:en"), "no");
is(get_property("test","en:beef","vegan:en"), undef);
is(get_inherited_property("test","en:beef","vegan:en"), "no");
is(get_inherited_property("test","en:fake-meat","vegan:en"), "yes");
is(get_inherited_property("test","en:fake-duck-meat","vegan:en"), "yes");
is(get_inherited_property("test","en:yogurts","vegan:en"), undef);
is(get_inherited_property("test","en:unknown","vegan:en"), undef);
is(get_inherited_property("test","en:roast-beef","carbon_footprint_fr_foodges_value:fr"), 15);
is(get_inherited_property("test","en:fake-duck-meat","carbon_footprint_fr_foodges_value:fr"), undef);

my $yuka_uuid = "yuka.R452afga432";
my $tagtype = "editors";

is(get_fileid($yuka_uuid), $yuka_uuid);

my $display_tag  = canonicalize_tag2($tagtype, $yuka_uuid);
my $newtagid = get_fileid($display_tag);

is($display_tag, $yuka_uuid);
is($newtagid, $yuka_uuid);

# make sure synonyms are not counted as existing tags
is(exists_taxonomy_tag("additives", "en:n"), '');
is(exists_taxonomy_tag("additives", "en:no"), '');
is(exists_taxonomy_tag("additives", "en:e330"), 1);

is(get_inherited_property("ingredients","en:milk","vegetarian:en"), "yes");
is(get_property("ingredients","en:milk","vegan:en"), "no");
is(get_inherited_property("ingredients","en:milk","vegan:en"), "no");
is(get_inherited_property("ingredients","en:semi-skimmed-milk","vegetarian:en"), "yes");
is(get_inherited_property("ingredients","en:semi-skimmed-milk","vegan:en"), "no");

is(display_taxonomy_tag("en", "ingredients_analysis", "en:non-vegan"), "Non-vegan");

is(canonicalize_taxonomy_tag("de","test","Grünkohl"), "en:kale");
is(display_taxonomy_tag("de","test","en:kale"), "Grünkohl");
is(display_taxonomy_tag_link("de","test","en:kale"), '<a href="//gr%C3%BCnkohl" class="tag well_known">Grünkohl</a>'); # "test" taxonomy causes warning in Tags.pm
is(display_tags_hierarchy_taxonomy("de","test",["en:kale"]), '<a href="//gr%C3%BCnkohl" class="tag well_known">Grünkohl</a>');
is(canonicalize_taxonomy_tag("fr","test","Pâte de cacao"), "fr:Pâte de cacao");
is(display_taxonomy_tag("fr","test","fr:Pâte de cacao"), "Pâte de cacao");
is(get_taxonomyid("en","pâte de cacao"), "pate-de-cacao");
is(get_taxonomyid("de","pâte de cacao"), "pâte-de-cacao");
is(get_taxonomyid("fr","fr:pâte de cacao"), "fr:pate-de-cacao");
is(get_taxonomyid("fr","de:pâte"), "de:pâte");
is(get_taxonomyid("de","de:pâte"), "de:pâte");

$product_ref = {
	lc => "de",
	test => "Grünkohl, Äpfel, café, test",
};

compute_field_tags($product_ref, "de", "test");

is_deeply($product_ref,
	{
		'lc' => 'de',
		'test' => "Gr\x{fc}nkohl, \x{c4}pfel, caf\x{e9}, test",
		'test_hierarchy' => [
			'en:kale',
			"de:caf\x{e9}",
			'de:test',
			"de:\x{c4}pfel"
		],
		'test_lc' => 'de',
		'test_tags' => [
			'en:kale',
			"de:caf\x{e9}",
			'de:test',
			"de:\x{e4}pfel"
		]
	}
) or diag explain $product_ref;


$product_ref = { "stores" => "Intermarché" };
compute_field_tags($product_ref, "fr", "stores");
is_deeply($product_ref->{stores_tags}, ["intermarche"]);
compute_field_tags($product_ref, "de", "stores");
is_deeply($product_ref->{stores_tags}, ["intermarche"]);

is(canonicalize_taxonomy_tag("en", "test", "kefir 2.5%"), "en:kefir-2-5");
is(canonicalize_taxonomy_tag("en", "test", "kefir 2,5%"), "en:kefir-2-5");
is(canonicalize_taxonomy_tag("fr", "test", "kefir 2,5%"), "en:kefir-2-5");
is(canonicalize_taxonomy_tag("fr", "test", "kéfir 2.5%"), "en:kefir-2-5");

# Following should be 2.5% instead of 2.5 % for English
is(display_taxonomy_tag("en", "test", "en:kefir-2-5"), "Kefir 2.5 %");
is(display_taxonomy_tag("de", "test", "en:kefir-2-5"), "Kefir 2.5 %");
# Following string has a lower comma ‚ instead of a normal comma
is(display_taxonomy_tag("fr", "test", "en:kefir-2-5"), "Kéfir 2‚5 %");

is(ProductOpener::Tags::remove_stopwords("ingredients", "fr", "correcteurs-d-acidite"), "correcteurs-acidite");
is(ProductOpener::Tags::remove_stopwords("ingredients", "fr", "yaourt-a-la-fraise"), "yaourt-fraise");
is(ProductOpener::Tags::remove_stopwords("ingredients", "fr", "du-miel"), "miel");
is(ProductOpener::Tags::remove_stopwords("ingredients", "fr", "fruits-en-proportion-variable"), "fruits");
is(ProductOpener::Tags::remove_stopwords("ingredients", "fr", "des-de-tomate"), "des-de-tomate");

my $tag_ref = get_taxonomy_tag_and_link_for_lang("fr", "categories", "en:strawberry-yogurts");
is_deeply($tag_ref, {
		'css_class' => 'tag known ',
		'display' => "Yaourts \x{e0} la fraise",
		'display_lc' => 'fr',
		'html_lang' => ' lang="fr"',
		'known' => 1,
		'tagid' => 'en:strawberry-yogurts',
		'tagurl' => 'yaourts-a-la-fraise'
	}
) or diag explain $tag_ref;

is(get_string_id_for_lang("fr", "Yaourts à la fraise"), "yaourts-a-la-fraise");


@tags = gen_tags_hierarchy_taxonomy("en", "labels", "gmo free and organic");

is_deeply (\@tags, [
		'en:organic',
		'en:no-gmos',
	]
) or diag explain(\@tags);

@tags = gen_tags_hierarchy_taxonomy("fr", "labels", "commerce équitable, label rouge et bio");

is_deeply (\@tags, [
		'en:organic',
		'en:fair-trade',
		'fr:label-rouge',
	]
) or diag explain(\@tags);

@tags = gen_tags_hierarchy_taxonomy("fr", "labels", "Déconseillé aux enfants et aux femmes enceintes");

is_deeply (\@tags, [
		'en:not-advised-for-specific-people',
		'en:not-advised-for-children-and-pregnant-women'
	]
) or diag explain(\@tags);

@tags = gen_tags_hierarchy_taxonomy("fr", "traces", "MOUTARDE ET SULFITES");

is_deeply (\@tags, [
	'en:mustard',
	'en:sulphur-dioxide-and-sulphites'
]
) or diag explain(\@tags);

is_deeply(canonicalize_taxonomy_tag("fr", "test", "yaourts au maracuja"), "en:passion-fruit-yogurts");
is_deeply(canonicalize_taxonomy_tag("fr", "test", "yaourt banane"), "en:banana-yogurts");
is_deeply(canonicalize_taxonomy_tag("fr", "test", "yogourts à la banane"), "en:banana-yogurts");
is_deeply(canonicalize_taxonomy_tag("fr", "labels", "european v-label vegetarian"), "en:european-vegetarian-union-vegetarian");

is_deeply(canonicalize_taxonomy_tag("fr", "labels", "pur jus"), "en:pure-juice");
# should not be matched to "pur jus" in French and return "en:pure-juice"
is_deeply(canonicalize_taxonomy_tag("en", "labels", "au jus"), "en:au jus");

# Test add_tags_to_field

$product_ref = {
	lc => "fr",
	'categories_hierarchy' => [
		'en:meals',
	],
};


add_tags_to_field($product_ref, "fr", "categories", "pommes");
compute_field_tags($product_ref, "fr", "categories");

add_tags_to_field($product_ref, "en", "categories", "bananas");
compute_field_tags($product_ref, "en", "categories");

add_tags_to_field($product_ref, "en", "categories", "en:pears");
compute_field_tags($product_ref, "en", "categories");

add_tags_to_field($product_ref, "es", "categories", "en:peaches");
compute_field_tags($product_ref, "es", "categories");

is_deeply($product_ref->{categories_tags},  [
		'en:plant-based-foods-and-beverages',
		'en:plant-based-foods',
		'en:fruits-and-vegetables-based-foods',
		'en:meals',
		'en:fruits-based-foods',
		'en:fruits',
		'en:apples',
		'en:peaches',
		'en:tropical-fruits',
		'en:bananas',
		'en:pears',
	],
) or diag explain $product_ref;

$product_ref = {
	lc => "fr",
	categories => "pommes, bananes, en:pears, fr:fraises, es:limones",
};

compute_field_tags($product_ref, "fr", "categories");

is_deeply($product_ref->{categories_tags}, [
	'en:plant-based-foods-and-beverages',
	'en:plant-based-foods',
	'en:fruits-and-vegetables-based-foods',
	'en:fruits-based-foods',
	'en:fruits',
	'en:apples',
	'en:berries',
	'en:citrus',
	'en:tropical-fruits',
	'en:bananas',
	'en:lemons',
	'en:pears',
	'en:strawberries'
]) or diag explain $product_ref;

$product_ref = {
	'categories' => "Plats pr\x{e9}par\x{e9}s, Plats pr\x{e9}par\x{e9}s au poisson, Plats \x{e0} base de p\x{e2}tes, Lasagnes pr\x{e9}par\x{e9}es, Plats au saumon",
	'categories_lc' => 'fr',
	'categories_tags' => [
		'en:meals',
		'en:pasta-dishes',
		'en:prepared-lasagne',
		'en:meals-with-fish',
		'en:meals-with-salmon',
	],
	lc => 'fr',
	lang => 'fr',
};

add_tags_to_field($product_ref, "en", "categories", "Meals,Pasta dishes,Prepared lasagne,Meals with fish,Meals with salmon");

is_deeply($product_ref->{categories_tags},
[
	'en:meals',
	'en:pasta-dishes',
	'en:prepared-lasagne',
	'en:meals-with-fish',
	'en:meals-with-salmon',
]
) or diag explain $product_ref;

$tag_ref = get_taxonomy_tag_and_link_for_lang("fr","labels","en:organic");
is_deeply($tag_ref,
{
	'css_class' => 'tag known ',
	'display' => 'Bio',
	'display_lc' => 'fr',
	'html_lang' => ' lang="fr"',
	'known' => 1,
	'tagid' => 'en:organic',
	'tagurl' => 'bio'
}
)
or diag explain $tag_ref;

$tag_ref = get_taxonomy_tag_and_link_for_lang("fr","labels","fr:some unknown label");
is_deeply($tag_ref,
{
	'css_class' => 'tag user_defined ',
	'display' => 'some unknown label',
	'display_lc' => 'fr',
	'html_lang' => ' lang="fr"',
	'known' => 0,
	'tagid' => 'fr:some unknown label',
	'tagurl' => 'some-unknown-label'
}
)
or diag explain $tag_ref;

# check that %tags_texts is populated on demand
ProductOpener::Tags::init_tags_texts();
# Assumes we will always have french additive texts for E100.
like($tags_texts{'fr'}{'additives'}{'e100'}, qr/curcumine/, 'e100 text contains "curcumine"') or diag explain($tags_texts{'fr'}{'additives'}{'e100'});

# Test default or language-less xx: values
# see https://github.com/openfoodfacts/openfoodfacts-server/issues/3872

is (canonicalize_taxonomy_tag("fr","test","french entry"), "fr:french-entry");
is (canonicalize_taxonomy_tag("fr","test","fr:french entry"), "fr:french-entry");
is (canonicalize_taxonomy_tag("en","test","french entry"), "en:french entry");
is (canonicalize_taxonomy_tag("en","test","en:french-entry"), "en:french-entry");
is (canonicalize_taxonomy_tag("es","test","french entry"), "es:french entry");
is (canonicalize_taxonomy_tag("es","test","es:french-entry"), "es:french-entry");
is (canonicalize_taxonomy_tag("de","test","french entry"), "de:french entry");
is (canonicalize_taxonomy_tag("it","test","nl:french-entry"), "nl:french-entry");

is (canonicalize_taxonomy_tag("fr","test","french entry with default value"), "fr:french-entry-with-default-value");
is (canonicalize_taxonomy_tag("en","test","french entry with default value"), "fr:french-entry-with-default-value");
is (canonicalize_taxonomy_tag("es","test","french entry with default value"), "fr:french-entry-with-default-value");
is (canonicalize_taxonomy_tag("de","test","french entry with default value"), "fr:french-entry-with-default-value");
is (canonicalize_taxonomy_tag("de","test","special value for German 2"), "fr:french-entry-with-default-value");

is (canonicalize_taxonomy_tag("en","test","language less entry"), "xx:language-less-entry");
is (canonicalize_taxonomy_tag("fr","test","language less entry"), "xx:language-less-entry");
is (canonicalize_taxonomy_tag("de","test","language less entry"), "xx:language-less-entry");
is (canonicalize_taxonomy_tag("nl","test","xx:language less entry"), "xx:language-less-entry");
is (canonicalize_taxonomy_tag("de","test","special value for German 3"), "xx:language-less-entry");

is(display_taxonomy_tag("fr","test","fr:french-entry"), "French entry");
is(display_taxonomy_tag("fr","test","french entry"), "French entry");
is(display_taxonomy_tag("de","test","fr:french-entry"), "Special value for German");
is(display_taxonomy_tag("de","test","french entry"), "French entry");

is(display_taxonomy_tag("fr","test","fr:french-entry-with-default-value"), "French entry with default value");
is(display_taxonomy_tag("en","test","fr:french-entry-with-default-value"), "French entry with default value");
is(display_taxonomy_tag("es","test","fr:french-entry-with-default-value"), "French entry with default value");
is(display_taxonomy_tag("de","test","fr:french-entry-with-default-value"), "Special value for German 2");

is(display_taxonomy_tag("fr","test","language less entry"), "Language-less entry");
is(display_taxonomy_tag("fr","test","xx:language-less-entry"), "Language-less entry");
is(display_taxonomy_tag("fr","test","en:language less entry"), "Language-less entry");
is(display_taxonomy_tag("en","test","en:language less entry"), "Language-less entry");
is(display_taxonomy_tag("de","test","xx:language-less-entry"), "Special value for German 3");

is ( display_tags_hierarchy_taxonomy("fr","test",["fr:french-entry", "fr:french-entry-with-default-value", "xx:language-less-entry"]), '<a href="//french-entry" class="tag well_known">French entry</a>, <a href="//french-entry-with-default-value" class="tag well_known">French entry with default value</a>, <a href="//language-less-entry" class="tag well_known">Language-less entry</a>');

is ( display_tags_hierarchy_taxonomy("es","test",["fr:french-entry", "fr:french-entry-with-default-value", "xx:language-less-entry"]), '<a href="//fr:french-entry" class="tag user_defined" lang="fr">fr:French entry</a>, <a href="//french-entry-with-default-value" class="tag well_known">French entry with default value</a>, <a href="//language-less-entry" class="tag well_known">Language-less entry</a>');

is ( display_tags_hierarchy_taxonomy("de","test",["fr:french-entry", "fr:french-entry-with-default-value", "xx:language-less-entry"]), '<a href="//special-value-for-german" class="tag well_known">Special value for German</a>, <a href="//special-value-for-german-2" class="tag well_known">Special value for German 2</a>, <a href="//special-value-for-german-3" class="tag well_known">Special value for German 3</a>');

is(display_taxonomy_tag("fr","test","es:french-entry-with-default-value"), "French entry with default value");

my $value = display_tags_hierarchy_taxonomy("fr", "test", ["fr:french-entry", "es:french-entry-with-default-value", "xx:language-less-entry"]);

is ($value, '<a href="//french-entry" class="tag well_known">French entry</a>, <a href="//french-entry-with-default-value" class="tag well_known">French entry with default value</a>, <a href="//language-less-entry" class="tag well_known">Language-less entry</a>');

# Remove tags
$value =~ s/<(([^>]|\n)*)>//g;

$product_ref->{"test"} = $value;
compute_field_tags($product_ref, "fr", "test");

is_deeply ($product_ref->{test_tags}, 
[
   'fr:french-entry',
   'fr:french-entry-with-default-value',
   'xx:language-less-entry'
]
) or diag explain $product_ref->{test_tags};

done_testing();
