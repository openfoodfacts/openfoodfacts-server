#!/usr/bin/perl -w

use Modern::Perl '2012';

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;

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


done_testing();
