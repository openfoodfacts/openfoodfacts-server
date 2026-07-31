#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Store qw/get_fileid get_string_id_for_lang/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results
	normalize_product_for_test_comparison/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

init_emb_codes();

ok(is_a("categories", "en:beers", "en:beverages"), 'en:beers is a child of en:beverages');
ok(!is_a("categories", "en:beers", "en:milks"), 'en:beers is not a child of en:milk');

# verify known Wikidata ID is converted to the taxonomy tag
is(canonicalize_taxonomy_tag('en', 'categories', 'wikidata:en:Q470974'),
	'fr:fitou', '"wikidata:en:Q470974" should be canonicalized to "fr:fitou"');

# verify known Wikidata URL is converted to the taxonomy tag
is(canonicalize_taxonomy_tag('en', 'categories', 'https://www.wikidata.org/wiki/Q470974'),
	'fr:fitou', 'Wikidata URL "https://www.wikidata.org/wiki/Q470974" should be canonicalized to "fr:fitou"');

is(display_taxonomy_tag("en", "categories", "en:beverages"), "Beverages");
is(display_taxonomy_tag("fr", "categories", "en:beverages"), "Boissons");
is(display_taxonomy_tag("en", "categories", "en:doesnotexist"), "doesnotexist");
is(display_taxonomy_tag("fr", "categories", "en:doesnotexist"), "en:doesnotexist");

is(display_taxonomy_tag_link("fr", "categories", "en:doesnotexist"),
	'<a href="/facets/categories/en:doesnotexist" class="tag user_defined" lang="en">en:doesnotexist</a>');

is(display_tags_hierarchy_taxonomy("fr", "categories", ["en:doesnotexist"]),
	'<a href="/facets/categories/en:doesnotexist" class="tag user_defined" lang="en">en:doesnotexist</a>');

is(
	display_tags_hierarchy_taxonomy("en", "categories", ["en:doesnotexist"]),
	'<a href="/facets/categories/doesnotexist" class="tag user_defined">doesnotexist</a>'
);

# 2024/08: brands are now taxonomized using the xx: prefix

is canonicalize_taxonomy_tag('en', 'brands', 'some brand'), 'xx:some brand';
is canonicalize_taxonomy_tag('en', 'brands', 'xx:some-brand'), 'xx:some-brand';
is canonicalize_taxonomy_tag('en', 'brands', 'xx:Some brand'), 'xx:Some brand';
is canonicalize_taxonomy_tag('xx', 'brands', 'some brand'), 'xx:some brand';
is get_taxonomyid("en", "some brand"), "some brand";
is [gen_tags_hierarchy_taxonomy("en", "brands", "some brand, xx:some-other-brand")],
	['xx:some brand', 'xx:some-other-brand'];

my @tags = ();

# ingredients taxonomy (@2021-09-03):
# en:salt is at top-level (4)?
# en:orange is child of en:fruit AND en:citrus-fruit (3)
# en:citrus-fruit is child of en:fruit (2) and (3)
# en:fruit is at top-level (4)
# en:fruit-juice is child of en:fruit (3)
# en:orange-juice is child of en:orange AND en:fruit-juice (2)
# en:concentrated-orange-juice is child of en:orange-juice (1)
# en:sugar is at the top-level (4)?

@tags = gen_tags_hierarchy_taxonomy("en", "ingredients", "en:concentrated-orange-juice, en:sugar, en:salt, en:orange");

is(
	\@tags,
	[
		'en:fruit', 'en:added-sugar', 'en:citrus-fruit', 'en:disaccharide',
		'en:juice', 'en:sugar', 'en:fruit-juice', 'en:orange',
		'en:salt', 'en:orange-juice', 'en:concentrated-orange-juice'
	]
) or diag Dumper(\@tags);

# foreach my $tag (@tags) {
# 	print STDERR "tag: $tag\tlevel: " . $level{ingredients}{$tag} . "\n";
# }

@tags = gen_ingredients_tags_hierarchy_taxonomy("en", "en:concentrated-orange-juice, en:sugar, en:salt, en:orange");

is(
	\@tags,
	[
		'en:concentrated-orange-juice', 'en:fruit', 'en:citrus-fruit', 'en:juice',
		'en:fruit-juice', 'en:orange', 'en:orange-juice', 'en:sugar',
		'en:added-sugar', 'en:disaccharide', 'en:salt'
	]
) or diag Dumper(\@tags);

ProductOpener::Tags::retrieve_tags_taxonomy("test");

is(get_property("test", "en:meat", "vegan:en"), "no");
is($properties{test}{"en:meat"}{"vegan:en"}, "no");
is(get_inherited_property("test", "en:meat", "vegan:en"), "no");
is(get_property("test", "en:beef", "vegan:en"), undef);
is(get_property_with_fallbacks("test", "en:meat", "vegan:en"), "no", "get_property_with_fallback: no need of fallback");
is(get_property_with_fallbacks("test", "en:meat", "vegan:fr"), "no", "get_property_with_fallback: fallback to en");
is(get_property_with_fallbacks("test", "en:meat", "vegan:fr", ["de",]),
	undef, "get_property_with_fallback: fallback to lang with no value");
is(get_property_with_fallbacks("test", "en:meat", "vegan:fr", []),
	undef, "get_property_with_fallback: no fallback lang");
is(get_property_with_fallbacks("test", "en:meat", "vegan:en", "[]"),
	"no", "get_property_with_fallback: no fallback lang but no need of it");
is(
	get_property_with_fallbacks("test", "en:lemon-yogurts", "description:nl", ["fr", "en"]),
	"un yaourt avec du citron",
	"get_property_with_fallback: french first"
);
is(get_inherited_property("test", "en:beef", "vegan:en"), "no");
is(get_inherited_property("test", "en:fake-meat", "vegan:en"), "yes");
is(get_inherited_property("test", "en:fake-duck-meat", "vegan:en"), "yes");
is(get_inherited_property("test", "en:yogurts", "vegan:en"), undef);
is(get_inherited_property("test", "en:unknown", "vegan:en"), undef);
is(get_inherited_property("test", "en:roast-beef", "carbon_footprint_fr_foodges_value:fr"), 15);
is(get_inherited_property("test", "en:fake-duck-meat", "carbon_footprint_fr_foodges_value:fr"), undef);

is(get_inherited_property("test", "en:fake-duck-meat", "carbon_footprint_fr_foodges_value:fr"), undef);

is(get_inherited_properties("test", "fr:yaourts-au-citron-alleges", []),
	{}, "Getting an empty list of property returns an empty hashmap");
is(get_inherited_properties("test", "en:fake-meat", ["vegan:en"]), {"vegan:en" => "yes"}, "Getting only one property");
is(
	get_inherited_properties("test", "en:lemon-yogurts", ["color:en", "description:fr", "non-existing", "another:fr"]),
	{"color:en" => "yellow", "description:fr" => "un yaourt avec du citron"},
	"Getting multiple properties at once"
);
is(
	get_inherited_properties("test", "fr:yaourts-au-citron-alleges", ["color:en", "description:fr"]),
	{"color:en" => "yellow", "description:fr" => "for light yogurts with lemon"},
	"Getting multiple properties with one inherited and one where we use language fallback"
);
is(
	get_inherited_properties("test", "fr:yaourts-au-fruit-de-la-passion-alleges", ["color:en", "description:fr"]),
	{"description:fr" => "un yaourt de n'importe quel type"},
	"Getting multiple properties with one undef in the path and an inherited one"
);

is(get_tags_grouped_by_property("test", [], "color:en", ["description:fr"], ["flavour:en"]),
	{}, "get_tags_grouped_by_property for no tagids gives empty hashmap");
is(
	get_tags_grouped_by_property(
		"test", ["en:passion-fruit-yogurts", "fr:yaourts-au-citron-alleges"],
		"color:en", [], []
	),
	{
		'undef' => {
			'en:passion-fruit-yogurts' => {}
		},
		'yellow' => {
			'fr:yaourts-au-citron-alleges' => {}
		},
	},
	"get_tags_grouped_by_property with grouping on color:en, no additional property"
);
is(
	get_tags_grouped_by_property(
		"test",
		["en:passion-fruit-yogurts", "fr:yaourts-a-la-myrtille", "fr:yaourts-au-citron-alleges", "en:lemon-yogurts"],
		"color:en", ["description:fr"], ["flavour:en"],
	),
	{
		'undef' => {
			'en:passion-fruit-yogurts' => {
				'flavour:en' => 'passion fruit',
			}
		},
		'white' => {
			'fr:yaourts-a-la-myrtille' => {
				'flavour:en' => 'blueberry',
			}
		},
		'yellow' => {
			'en:lemon-yogurts' => {
				'description:fr' => 'un yaourt avec du citron',
				'flavour:en' => 'lemon',
			},
			'fr:yaourts-au-citron-alleges' => {
				'description:fr' => 'for light yogurts with lemon',
				'flavour:en' => 'lemon',
			}
		},
	},
	"get_tags_grouped_by_property with grouping on color:en"
);

my $yuka_uuid = "yuka.R452afga432";
my $tagtype = "editors";

is(get_fileid($yuka_uuid), $yuka_uuid);

my $display_tag = display_tag($tagtype, $yuka_uuid);
my $newtagid = canonicalize_tag($tagtype, $yuka_uuid);

is($display_tag, $yuka_uuid);
is($newtagid, $yuka_uuid);

# make sure synonyms are not counted as existing tags
is(exists_taxonomy_tag("additives", "en:n"), '');
is(exists_taxonomy_tag("additives", "en:no"), '');
is(exists_taxonomy_tag("additives", "en:e330"), 1);

is(get_inherited_property("ingredients", "en:milk", "vegetarian:en"), "yes");
is(get_property("ingredients", "en:milk", "vegan:en"), "no");
is(get_inherited_property("ingredients", "en:milk", "vegan:en"), "no");

is(display_taxonomy_tag("en", "ingredients_analysis", "en:non-vegan"), "Non-vegan");

is(canonicalize_taxonomy_tag("de", "test", "Grünkohl"), "en:kale");
is(display_taxonomy_tag("de", "test", "en:kale"), "Grünkohl");
is(display_taxonomy_tag_link("de", "test", "en:kale"),
	'<a href="/facets//Grünkohl" class="tag well_known">Grünkohl</a>');    # "test" taxonomy causes warning in Tags.pm
is(
	display_tags_hierarchy_taxonomy("de", "test", ["en:kale"]),
	'<a href="/facets//Grünkohl" class="tag well_known">Grünkohl</a>'
);
is(canonicalize_taxonomy_tag("fr", "test", "Pâte de cacao"), "fr:Pâte de cacao");
is(display_taxonomy_tag("fr", "test", "fr:Pâte de cacao"), "Pâte de cacao");
is(get_taxonomyid("en", "pâte de cacao"), "pâte de cacao");
is(get_taxonomyid("de", "pâte de cacao"), "pâte de cacao");
is(get_taxonomyid("fr", "fr:pâte de cacao"), "fr:pâte de cacao");
is(get_taxonomyid("fr", "de:pâte"), "de:pâte");
is(get_taxonomyid("de", "de:pâte"), "de:pâte");

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
is(ProductOpener::Tags::remove_stopwords("ingredients", "en", "edible-vegetable-oil"), "vegetable-oil");

my $tag_ref = get_taxonomy_tag_and_link_for_lang("fr", "categories", "en:strawberry-yogurts");
is(
	$tag_ref,
	{
		'css_class' => 'tag known ',
		'display' => "Yaourts \x{e0} la fraise",
		'display_lc' => 'fr',
		'html_lang' => ' lang="fr"',
		'known' => 1,
		'tagid' => 'en:strawberry-yogurts',
		'tagurl' => 'Yaourts%20%C3%A0%20la%20fraise'
	}
) or diag Dumper $tag_ref;

is(get_string_id_for_lang("fr", "Yaourts à la fraise"), "yaourts-a-la-fraise");

@tags = gen_tags_hierarchy_taxonomy("en", "labels", "gmo free and organic");

is(\@tags, ['en:organic', 'en:no-gmos',]) or diag Dumper(\@tags);

@tags = gen_tags_hierarchy_taxonomy("fr", "labels", "commerce équitable, label rouge et bio");

is(\@tags, ['en:fair-trade', 'en:organic', 'fr:label-rouge',]) or diag Dumper(\@tags);

@tags = gen_tags_hierarchy_taxonomy("fr", "labels", "Déconseillé aux enfants et aux femmes enceintes");

is(\@tags, ['en:not-advised-for-specific-people', 'en:not-advised-for-children-and-pregnant-women'])
	or diag Dumper(\@tags);

@tags = gen_tags_hierarchy_taxonomy("fr", "traces", "MOUTARDE ET SULFITES");

is(\@tags, ['en:mustard', 'en:sulphur-dioxide-and-sulphites']) or diag Dumper(\@tags);

is(canonicalize_taxonomy_tag("fr", "test", "yaourts au maracuja"), "en:passion-fruit-yogurts");
is(canonicalize_taxonomy_tag("fr", "test", "yaourt banane"), "en:banana-yogurts");
is(canonicalize_taxonomy_tag("fr", "test", "yogourts à la banane"), "en:banana-yogurts");
is(canonicalize_taxonomy_tag("fr", "labels", "european v-label vegetarian"), "en:european-vegetarian-union-vegetarian");

is(canonicalize_taxonomy_tag("fr", "labels", "pur jus"), "en:pure-juice");
# should not be matched to "pur jus" in French and return "en:pure-juice"
is(canonicalize_taxonomy_tag("en", "labels", "au jus"), "en:au jus");

$tag_ref = get_taxonomy_tag_and_link_for_lang("fr", "labels", "en:organic");
is(
	$tag_ref,
	{
		'css_class' => 'tag known ',
		'display' => 'Bio',
		'display_lc' => 'fr',
		'html_lang' => ' lang="fr"',
		'known' => 1,
		'tagid' => 'en:organic',
		'tagurl' => 'Bio'
	}
) or diag Dumper $tag_ref;

$tag_ref = get_taxonomy_tag_and_link_for_lang("fr", "labels", "fr:some unknown label");
is(
	$tag_ref,
	{
		'css_class' => 'tag user_defined ',
		'display' => 'some unknown label',
		'display_lc' => 'fr',
		'html_lang' => ' lang="fr"',
		'known' => 0,
		'tagid' => 'fr:some unknown label',
		'tagurl' => 'some%20unknown%20label'
	}

) or diag Dumper $tag_ref;

# Test we have the right links for xx: entries
$tag_ref = get_taxonomy_tag_and_link_for_lang("fr", "test", "en:smartphones");
is(
	$tag_ref,
	{
		'tagurl' => 'T%C3%A9l%C3%A9phones%20intelligents',
		'tagid' => 'en:smartphones',
		'display_lc' => 'fr',
		'known' => 1,
		'css_class' => 'tag known ',
		'display' => "T\x{e9}l\x{e9}phones intelligents",
		'html_lang' => ' lang="fr"'
	}

) or diag Dumper $tag_ref;

$tag_ref = get_taxonomy_tag_and_link_for_lang("de", "test", "en:smartphones");
is(
	$tag_ref,
	{
		'display' => 'Smartphones',
		'css_class' => 'tag known ',
		'html_lang' => ' lang="de"',
		'known' => 1,
		'display_lc' => 'de',
		'tagid' => 'en:smartphones',
		'tagurl' => 'Smartphones'
	}

) or diag Dumper $tag_ref;

# check that %tags_texts is populated on demand
ProductOpener::Tags::init_tags_texts();
# Assumes we will always have french additive texts for E100.
like($tags_texts{'fr'}{'additives'}{'e100'}, qr/curcumine/, 'e100 text contains "curcumine"')
	or diag Dumper($tags_texts{'fr'}{'additives'}{'e100'});

# Test default or language-less xx: values
# see https://github.com/openfoodfacts/openfoodfacts-server/issues/3872

is(canonicalize_taxonomy_tag("fr", "test", "french entry"), "fr:french-entry");
is(canonicalize_taxonomy_tag("fr", "test", "fr:french entry"), "fr:french-entry");
is(canonicalize_taxonomy_tag("en", "test", "french entry"), "en:french entry");
is(canonicalize_taxonomy_tag("en", "test", "en:french-entry"), "en:french-entry");
is(canonicalize_taxonomy_tag("es", "test", "french entry"), "es:french entry");
is(canonicalize_taxonomy_tag("es", "test", "es:french-entry"), "es:french-entry");
is(canonicalize_taxonomy_tag("de", "test", "french entry"), "de:french entry");
is(canonicalize_taxonomy_tag("it", "test", "nl:french-entry"), "nl:french-entry");

is(canonicalize_taxonomy_tag("fr", "test", "french entry with default value"), "fr:french-entry-with-default-value");
is(canonicalize_taxonomy_tag("en", "test", "french entry with default value"), "fr:french-entry-with-default-value");
is(canonicalize_taxonomy_tag("es", "test", "french entry with default value"), "fr:french-entry-with-default-value");
is(canonicalize_taxonomy_tag("de", "test", "french entry with default value"), "fr:french-entry-with-default-value");
is(canonicalize_taxonomy_tag("de", "test", "special value for German 2"), "fr:french-entry-with-default-value");

is(canonicalize_taxonomy_tag("en", "test", "language less entry"), "xx:language-less-entry");
is(canonicalize_taxonomy_tag("fr", "test", "language less entry"), "xx:language-less-entry");
is(canonicalize_taxonomy_tag("de", "test", "language less entry"), "xx:language-less-entry");
is(canonicalize_taxonomy_tag("nl", "test", "xx:language less entry"), "xx:language-less-entry");
is(canonicalize_taxonomy_tag("de", "test", "special value for German 3"), "xx:language-less-entry");

is(display_taxonomy_tag("fr", "test", "fr:french-entry"), "French entry");
is(display_taxonomy_tag("fr", "test", "french entry"), "French entry");
is(display_taxonomy_tag("de", "test", "fr:french-entry"), "Special value for German");
is(display_taxonomy_tag("de", "test", "French entry"), "French entry");

is(display_taxonomy_tag("fr", "test", "fr:french-entry-with-default-value"), "French entry with default value");
is(display_taxonomy_tag("en", "test", "fr:french-entry-with-default-value"), "French entry with default value");
is(display_taxonomy_tag("es", "test", "fr:french-entry-with-default-value"), "French entry with default value");
is(display_taxonomy_tag("de", "test", "fr:french-entry-with-default-value"), "Special value for German 2");

is(display_taxonomy_tag("fr", "test", "language less entry"), "Language-less entry");
is(display_taxonomy_tag("fr", "test", "xx:language-less-entry"), "Language-less entry");
is(display_taxonomy_tag("fr", "test", "en:language less entry"), "Language-less entry");
is(display_taxonomy_tag("en", "test", "en:language less entry"), "Language-less entry");
is(display_taxonomy_tag("de", "test", "xx:language-less-entry"), "Special value for German 3");

is(
	display_tags_hierarchy_taxonomy(
		"fr", "test", ["fr:french-entry", "fr:french-entry-with-default-value", "xx:language-less-entry"]
	),
	'<a href="/facets//French entry" class="tag well_known">French entry</a>, <a href="/facets//French entry with default value" class="tag well_known">French entry with default value</a>, <a href="/facets//Language-less entry" class="tag well_known">Language-less entry</a>'
);

is(
	display_tags_hierarchy_taxonomy(
		"es", "test", ["fr:french-entry", "fr:french-entry-with-default-value", "xx:language-less-entry"]
	),
	'<a href="/facets//fr:French entry" class="tag user_defined" lang="fr">fr:French entry</a>, <a href="/facets//French entry with default value" class="tag well_known">French entry with default value</a>, <a href="/facets//Language-less entry" class="tag well_known">Language-less entry</a>'
);

is(
	display_tags_hierarchy_taxonomy(
		"de", "test", ["fr:french-entry", "fr:french-entry-with-default-value", "xx:language-less-entry"]
	),
	'<a href="/facets//Special value for German" class="tag well_known">Special value for German</a>, <a href="/facets//Special value for German 2" class="tag well_known">Special value for German 2</a>, <a href="/facets//Special value for German 3" class="tag well_known">Special value for German 3</a>'
);

is(display_taxonomy_tag("fr", "test", "es:french-entry-with-default-value"), "French entry with default value");

my $value = display_tags_hierarchy_taxonomy("fr", "test",
	["fr:french-entry", "es:french-entry-with-default-value", "xx:language-less-entry"]);

is($value,
	'<a href="/facets//French entry" class="tag well_known">French entry</a>, <a href="/facets//French entry with default value" class="tag well_known">French entry with default value</a>, <a href="/facets//Language-less entry" class="tag well_known">Language-less entry</a>'
);

# Double synonym: zumo/jugo and soja/soya
is(canonicalize_taxonomy_tag('es', 'ingredients', 'jugo de soya'), 'en:soy-base');

# check that properties are taxonomized if their name match a previously loaded taxonomy
is(get_property("additives", "en:e170i", "additives_classes:en"), "en:colour, en:stabiliser");

# test list_taxonomy_tags_in_language

is(
	list_taxonomy_tags_in_language(
		"en", "labels",
		[
			"fr:un label français inconnu",
			"en:organic",
			"en:A New English label",
			"missing language prefix",
			"en:Fair Trade",
			"en:one-percent-for-the-planet"
		]
	),
	"fr:un label français inconnu, Organic, A New English label, missing language prefix, Fair trade, one-percent-for-the-planet"
);

is(
	list_taxonomy_tags_in_language(
		"fr", "labels",
		[
			"fr:un label français inconnu",
			"en:organic",
			"en:A New English label",
			"missing language prefix",
			"en:Fair Trade",
			"en:one-percent-for-the-planet"
		]
	),
	"un label français inconnu, Bio, en:A New English label, missing language prefix, Commerce équitable, en:one-percent-for-the-planet"
);

is(
	list_taxonomy_tags_in_language(
		"es", "labels",
		[
			"fr:un label français inconnu",
			"en:organic",
			"en:A New English label",
			"missing language prefix",
			"en:Fair Trade",
			"en:one-percent-for-the-planet"
		]
	),
	"fr:un label français inconnu, Ecológico, en:A New English label, missing language prefix, Comercio justo, en:one-percent-for-the-planet"
);

# canonicalize_taxonomy_tag can now return 0 or 1 to indicate if the tag matched an existing taxonomy entry

my $exists;

is(canonicalize_taxonomy_tag("fr", "test", "Yaourts au citron", \$exists), "en:lemon-yogurts");
is($exists, 1);

is(canonicalize_taxonomy_tag("fr", "test", "Yaourts au citron qui n'existe pas", \$exists),
	"fr:Yaourts au citron qui n'existe pas");
is($exists, 0);

is(canonicalize_taxonomy_tag('fr', 'categories', 'café'), "en:coffees");

# Tests to verify we match the xx:Ä Märket entry
is(canonicalize_taxonomy_tag('sv', 'test', 'A Market'), "sv:ä-märket");    # matches the xx: entry which is unaccented
is(canonicalize_taxonomy_tag('sv', 'test', 'Ä Märket'), "sv:ä-märket");
is(canonicalize_taxonomy_tag('en', 'test', 'Ä Märket'), "sv:ä-märket");
is(canonicalize_taxonomy_tag('en', 'test', 'A-MArket'), "sv:ä-märket");
is(canonicalize_taxonomy_tag('en', 'test', 'en:Ä Märket'), "sv:ä-märket");
is(canonicalize_taxonomy_tag('en', 'test', 'en:A MArket'), "sv:ä-märket");
is(canonicalize_taxonomy_tag('en', 'test', 'en:a-market'), "sv:ä-märket");
is(canonicalize_taxonomy_tag('de', 'test', 'Ä Märket'), "sv:ä-märket")
	;    # no unaccent in German, but need to deaccent to match the xx: entry

is(display_taxonomy_tag("fr", "test", "sv:ä-märket"), "Ä-märket");

# Tags images
is(get_tag_image("en", "labels", "en:usda-organic"), "/images/lang/en/labels/usda-organic.90x90.svg");
is(get_tag_image("sv", "labels", "sv:ä-märket"), "/images/lang/sv/labels/ä-märket.85x90.png");   # file name is accented
is(get_tag_image("fr", "labels", "fr:commerce-equitable"), "/images/lang/fr/labels/commerce-equitable.96x90.png")
	;    # file name is unaccented, unaccented language
is(get_tag_image("fr", "labels", "fi:sydänmerkki"), "/images/lang/fi/labels/sydanmerkki.90x90.svg")
	;    # file name is unaccented, accented language

# strings with multiple tags separated by /
is(canonicalize_taxonomy_tag('en', 'packaging_materials', 'Plastic/PET'), "en:pet-1-polyethylene-terephthalate");
is(canonicalize_taxonomy_tag('en', 'packaging_materials', 'Plastic / other plastics'), "en:o-7-other-plastics");
is(canonicalize_taxonomy_tag('en', 'packaging_materials', 'Plastic/PET'), "en:pet-1-polyethylene-terephthalate");
is(canonicalize_taxonomy_tag('en', 'packaging_materials', 'Plastic / Metal'), "en:Plastic / Metal"); # Cannot be matched
is(canonicalize_taxonomy_tag('fr', 'packaging_shapes', 'Ustensiles / couverts / fourchette'), "en:fork");
# 2023/03/28 - following test does not yet work
#is(canonicalize_taxonomy_tag('fr', 'packaging_shapes', 'Ustensiles (fourchette, couteau, cuillère)'), "en:utensils");
is(canonicalize_taxonomy_tag('fr', 'packaging_shapes', 'Plat (Bol, Saladier, Terrine, …)'), "en:dish");
is(canonicalize_taxonomy_tag('fr', 'packaging_materials', 'Gaz / CO2 - Dioxide de carbone (gaz carbonique)'),
	"en:co2-carbon-dioxide");

# test the generation of regexps matching tags

my $regexps_ref = generate_regexps_matching_taxonomy_entries("test", "list_of_regexps", {});
compare_to_expected_results($regexps_ref, "$expected_result_dir/regexps.json", $update_expected_results);

# xx: entries for ingredients should be used to match in all languages
is(canonicalize_taxonomy_tag('pl', 'ingredients', 'Lactobacillus bulgaricus'), "en:lactobacillus-bulgaricus");

# return the first matching property
is(get_property_from_tags("test", undef, "vegan:en"), undef);
is(get_property_from_tags("test", [], "vegan:en"), undef);
is(get_property_from_tags("test", ["en:vegetable", "en:meat"], "vegan:en"), "yes");
is([get_inherited_property_from_tags("test", ["en:something-unknown", "en:beef", "en:vegetable"], "vegan:en")],
	["no", 'en:beef']);
is(
	get_matching_regexp_property_from_tags(
		"test", ["en:something-unknown", "en:beef", "en:vegetable"],
		"vegan:en", "yes"
	),
	"yes"
);
# no entry matches the property (en:beef only has an inherited property)
is(
	get_matching_regexp_property_from_tags(
		"test", ["en:something-unknown", "en:beef", "en:vegetable"],
		"vegan:en", "no"
	),
	undef
);
is(
	get_matching_regexp_property_from_tags(
		"test", ["en:something-unknown", "en:meat", "en:vegetable"],
		"vegan:en", "no"
	),
	"no"
);

# Test get_knowledge_content subroutine

ProductOpener::Tags::load_knowledge_content();

# a match is expected here, as lang-default/fr/knowledge_panels/additives/en_e100_world.html exists
is(
	get_knowledge_content("additives", "en:e100", "fr", "world"),
	"<p>La curcumine ne présente pas de risques connus pour la santé.</p>"
);
# no content exists for fr country, but we should fallback on world
is(
	get_knowledge_content("additives", "en:e100", "fr", "fr"),
	"<p>La curcumine ne présente pas de risques connus pour la santé.</p>"
);
# No content exists for en language, undef is expected
is(get_knowledge_content("additives", "en:e100", "en", "world"), undef);

is(country_to_cc('en:france'), 'fr');
is(country_to_cc('en:world'), 'world');
is(country_to_cc('unknown'), undef);
is(country_to_cc(undef), undef);
is(cc_to_country('fr'), 'en:france');
is(cc_to_country('unknown'), '');
is(cc_to_country(undef), '');

is(get_taxonomy_tag_path("test", "en:lemon-yogurts"), ["en:yogurts", "en:lemon-yogurts"]);

is(display_taxonomy_tag("en", "ingredients", "en:apple"), "apple");

done_testing();
