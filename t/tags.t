#!/usr/bin/perl -w

use Modern::Perl '2012';

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP', filter => "none";;

use ProductOpener::Tags qw/:all/;


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
   'lc' => 'fr'
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
     'en:tropical-fruits',
     'en:apples',
     'en:bananas',
   ],
   'categories_lc' => 'fr',
   'categories_tags' => [
     'en:plant-based-foods-and-beverages',
     'en:plant-based-foods',
     'en:fruits-and-vegetables-based-foods',
     'en:fruits-based-foods',
     'en:fruits',
     'en:tropical-fruits',
     'en:apples',
     'en:bananas',
   ],
   'lc' => 'fr'
 }

) or diag explain $product_ref;

add_tags_to_field($product_ref, "fr", "categories", "pommes, bananes");

is($product_ref->{categories}, "pommes, bananes");

add_tags_to_field($product_ref, "fr", "categories", "fraises");

is($product_ref->{categories}, "Aliments et boissons à base de végétaux, Aliments d'origine végétale, Aliments à base de fruits et de légumes, Fruits et produits dérivés, Fruits, Fruits tropicaux, Pommes, Bananes, fraises");

add_tags_to_field($product_ref, "fr", "categories", "en:raspberries, en:plum");

compute_field_tags($product_ref, "en", "categories");

is_deeply($product_ref->{categories_tags},
 [
   'en:plant-based-foods-and-beverages',
   'en:plant-based-foods',
   'en:fruits-and-vegetables-based-foods',
   'en:fruits-based-foods',
   'en:fruits',
   'en:tropical-fruits',
   'en:apples',
   'en:bananas',
   'en:berries',
   'en:plums',
   'en:raspberries'
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
   'en:tropical-fruits',
   'en:apples',
   'en:bananas',
   'en:berries',
   'en:citrus',
   'en:lemons',
   'en:oranges',
   'en:plums',
   'en:raspberries'
 ]

) or diag explain $product_ref->{categories_tags};

is($product_ref->{categories}, "Alimentos y bebidas de origen vegetal, Alimentos de origen vegetal, Frutas y verduras y sus productos, Frutas y sus productos, Frutas, Frutas tropicales, Manzanas, Plátanos, Frutas del bosque, Ciruelas, Frambuesas, naranjas, limones");

add_tags_to_field($product_ref, "it", "categories", "bogus, limone");
compute_field_tags($product_ref, "it", "categories");

is_deeply($product_ref->{categories_tags},
 [
   'en:plant-based-foods-and-beverages',
   'en:plant-based-foods',
   'en:fruits-and-vegetables-based-foods',
   'en:fruits-based-foods',
   'en:fruits',
   'en:tropical-fruits',
   'en:apples',
   'en:bananas',
   'en:berries',
   'en:citrus',
   'en:lemons',
   'en:oranges',
   'en:plums',
   'en:raspberries',
   'it:bogus',
 ]

) or diag explain $product_ref->{categories_tags};


$product_ref = {
        lc => "fr",
};

add_tags_to_field($product_ref, "fr", "countries", "france, en:spain, deutschland, fr:bolivie, italie, de:suisse, colombia, bidon");

is_deeply($product_ref,
{
   'countries' => 'france, en:spain, deutschland, fr:bolivie, italie, de:suisse, colombia, bidon',
   'lc' => 'fr'
}) or diag explain($product_ref);


compute_field_tags($product_ref, "fr", "countries");

is_deeply($product_ref->{countries_tags},
[
   'en:bolivia',
   'en:colombia',
   'en:france',
   'en:germany',
   'en:italy',
   'en:spain',
   'en:switzerland',
   'fr:bidon'
]
)  or diag explain $product_ref->{countries_tags};

add_tags_to_field($product_ref, "es", "countries", "peru,bogus");
compute_field_tags($product_ref, "es", "countries");

is_deeply($product_ref->{countries_tags},
[
   'en:bolivia',
   'en:colombia',
   'en:france',
   'en:germany',
   'en:italy',
   'en:peru',
   'en:spain',
   'en:switzerland',
   'es:bogus',
   'fr:bidon'
]
)  or diag explain $product_ref->{countries_tags};


$product_ref = {
        lc => "fr",
};

add_tags_to_field($product_ref, "fr", "brands", "Baba, Bobo");

is_deeply($product_ref,
{
   'brands' => 'Baba, Bobo',
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
     'bobo'
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
   'en:orange',
   'en:salt',
   'en:sugar',
   'en:orange-juice',
   'en:concentrated-orange-juice'
 ]
 ) or diag explain(\@tags);;

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
 ) or diag explain(\@tags);;


done_testing();
