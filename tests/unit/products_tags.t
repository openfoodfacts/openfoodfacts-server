#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::ProductsTags qw/:all/;
use ProductOpener::Tags qw/init_emb_codes/;
use ProductOpener::Products qw/remove_fields/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results
	normalize_product_for_test_comparison/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

init_emb_codes();

my $product_ref = {test_tags => ['en:test']};

# verify has_tag works correctly
ok(has_tag($product_ref, 'test', 'en:test'), 'has_tag should be true');
ok(!has_tag($product_ref, 'test', 'de:mein-tag'), 'has_tag should be false');

# verify add_tag adds the new tag correctly
add_tag($product_ref, 'test', 'de:mein-tag');
ok(has_tag($product_ref, 'test', 'de:mein-tag'), 'has_tag should be true after add');

# verify remove_tag removes the new tag correctly
remove_tag($product_ref, 'test', 'de:mein-tag');
ok(!has_tag($product_ref, 'test', 'de:mein-tag'), 'has_tag should be false after remove');

# verify add_tag creates a new tags array if the matching tags field does not exist yet
add_tag($product_ref, 'nexist', 'en:test');
ok(has_tag($product_ref, 'nexist', 'en:test'), 'has_tag should be true after add');

# Test remove_fields

$product_ref
	= {"languages" => {}, "category_properties" => {}, "categories_properties" => {}, "name" => "test_prod"};
my $fields_to_remove = ["languages", "category_properties", "categories_properties"];

remove_fields($product_ref, $fields_to_remove);

foreach my $rem_field (@$fields_to_remove) {
	is($product_ref->{$rem_field}, undef);
}
is($product_ref->{name}, "test_prod");

# test add_tags_to_field

$product_ref = {lc => "fr",};

add_tags_to_field($product_ref, "fr", "categories", "pommes, bananes");

is(
	$product_ref,
	{
		'categories' => 'pommes, bananes',
		'lc' => 'fr',
		'categories_hierarchy' => [
			'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruit-based-foods-and-beverages', 'en:fruits-and-vegetables-based-foods',
			'en:fruit-based-foods', 'en:fruits',
			'en:tropical-fruits', 'en:apples',
			'en:bananas'
		],
		'categories_lc' => 'fr',
		'categories_tags' => [
			'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruit-based-foods-and-beverages', 'en:fruits-and-vegetables-based-foods',
			'en:fruit-based-foods', 'en:fruits',
			'en:tropical-fruits', 'en:apples',
			'en:bananas'
		],

	}
) or diag Dumper $product_ref;

compute_field_tags($product_ref, "fr", "categories");

delete($product_ref->{categories_debug_tags});
delete($product_ref->{categories_prev_hierarchy});
delete($product_ref->{categories_prev_tags});
delete($product_ref->{categories_next_hierarchy});
delete($product_ref->{categories_next_tags});

is(
	$product_ref,
	{
		'categories' => 'pommes, bananes',
		'categories_hierarchy' => [
			'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruit-based-foods-and-beverages', 'en:fruits-and-vegetables-based-foods',
			'en:fruit-based-foods', 'en:fruits',
			'en:tropical-fruits', 'en:apples',
			'en:bananas',
		],
		'categories_lc' => 'fr',
		'categories_tags' => [
			'en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruit-based-foods-and-beverages', 'en:fruits-and-vegetables-based-foods',
			'en:fruit-based-foods', 'en:fruits',
			'en:tropical-fruits', 'en:apples',
			'en:bananas',
		],
		'lc' => 'fr'
	}

) or diag Dumper $product_ref;

# foreach my $tag (@{$product_ref->{categories_tags}}) {
# 	print STDERR "tag: $tag\tlevel: " . $level{categories}{$tag} . "\n";
# }

add_tags_to_field($product_ref, "fr", "categories", "pommes, bananes");

is($product_ref->{categories}, "pommes, bananes");

add_tags_to_field($product_ref, "fr", "categories", "fraises");

is($product_ref->{categories},
	"Aliments et boissons à base de végétaux, Aliments d'origine végétale, Aliments et boissons à base de fruits, Aliments à base de fruits et de légumes, Aliments à base de fruits, Fruits, Fruits tropicaux, Pommes, Bananes, fraises"
);

add_tags_to_field($product_ref, "fr", "categories", "en:raspberries, en:plum");

compute_field_tags($product_ref, "fr", "categories");

is(
	[sort @{$product_ref->{categories_tags}}],
	[
		sort('en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruits-and-vegetables-based-foods', 'en:fruit-based-foods-and-beverages',
			'en:fruit-based-foods', 'en:fruits',
			'en:apples', 'en:berries',
			'en:tropical-fruits', 'en:bananas',
			'en:plums', 'en:raspberries',
			'en:strawberries',)
	]

) or diag Dumper $product_ref->{categories_tags};

add_tags_to_field($product_ref, "es", "categories", "naranjas, limones");
compute_field_tags($product_ref, "es", "categories");

is(
	[sort @{$product_ref->{categories_tags}}],
	[
		sort('en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruits-and-vegetables-based-foods', 'en:fruit-based-foods-and-beverages',
			'en:fruit-based-foods', 'en:fruits',
			'en:apples', 'en:berries',
			'en:citrus', 'en:tropical-fruits',
			'en:bananas', 'en:lemons',
			'en:oranges', 'en:plums',
			'en:raspberries', 'en:strawberries',
		)
	]

) or diag Dumper $product_ref->{categories_tags};

is($product_ref->{categories},
	"Alimentos y bebidas de origen vegetal, Alimentos de origen vegetal, Comida y bebida a base de frutas, Frutas y verduras y sus productos, Comida a base de frutas, Frutas, Frutas tropicales, Ciruelas, Manzanas, Plátanos, Frutas del bosque, Frambuesas, Fresas, naranjas, limones"
);

add_tags_to_field($product_ref, "it", "categories", "bogus, mele");
compute_field_tags($product_ref, "it", "categories");

is(
	[sort @{$product_ref->{categories_tags}}],
	[
		sort('en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruits-and-vegetables-based-foods', 'en:fruit-based-foods-and-beverages',
			'en:fruit-based-foods', 'en:fruits',
			'en:apples', 'en:berries',
			'en:citrus', 'en:tropical-fruits',
			'en:bananas', 'en:lemons',
			'en:oranges', 'en:plums',
			'en:raspberries', 'en:strawberries',
			'it:bogus')
	]

	#) or diag Dumper $product_ref->{categories_tags};
) or diag Dumper $product_ref;

$product_ref = {lc => "fr",};

add_tags_to_field($product_ref, "fr", "countries",
	"france, en:spain, deutschland, fr:bolivie, italie, de:suisse, colombia, bidon");

is(
	$product_ref,
	{
		'countries' => 'france, en:spain, deutschland, fr:bolivie, italie, de:suisse, colombia, bidon',
		'lc' => 'fr',
		'countries_hierarchy' => [
			'en:bolivia', 'en:colombia', 'en:france', 'en:italy',
			'en:spain', 'en:switzerland', 'fr:bidon', 'fr:deutschland'
		],
		'countries_lc' => 'fr',
		'countries_tags' => [
			'en:bolivia', 'en:colombia', 'en:france', 'en:italy',
			'en:spain', 'en:switzerland', 'fr:bidon', 'fr:deutschland'
		],

	}
) or diag Dumper($product_ref);

compute_field_tags($product_ref, "fr", "countries");

is($product_ref->{countries_tags},
	['en:bolivia', 'en:colombia', 'en:france', 'en:italy', 'en:spain', 'en:switzerland', 'fr:bidon', 'fr:deutschland',])
	or diag Dumper $product_ref->{countries_tags};

add_tags_to_field($product_ref, "es", "countries", "peru,bogus");
compute_field_tags($product_ref, "es", "countries");

is(
	$product_ref->{countries_tags},
	[
		'en:bolivia', 'en:colombia', 'en:france', 'en:italy', 'en:peru', 'en:spain',
		'en:switzerland', 'es:bogus', 'fr:bidon', 'fr:deutschland',
	]
) or diag Dumper $product_ref->{countries_tags};

$product_ref = {lc => "fr",};

add_tags_to_field($product_ref, "fr", "brands", "Baba, Bobo, nestlé, kelloggs");

is(
	$product_ref,
	{
		'brands' => 'Baba, Bobo, nestlé, kelloggs',
		'brands_lc' => 'xx',
		'brands_tags' => ['xx:kellogg-s', 'xx:nestle', 'xx:Baba', 'xx:Bobo'],
		'brands_hierarchy' => ['xx:kellogg-s', 'xx:nestle', 'xx:Baba', 'xx:Bobo'],
		'lc' => 'fr'
	}
) or diag Dumper($product_ref);

compute_field_tags($product_ref, "fr", "brands");

is($product_ref->{brands_tags}, ['xx:kellogg-s', 'xx:nestle', 'xx:Baba', 'xx:Bobo'])
	or diag Dumper $product_ref->{brands_tags};

add_tags_to_field($product_ref, "fr", "brands", "Bibi");

delete $product_ref->{brands_debug_tags};

is(
	$product_ref,
	{
		'brands' => 'Kellogg\'s, Nestlé, Baba, Bobo, Bibi',
		'brands_lc' => 'xx',
		'brands_tags' => ['xx:kellogg-s', 'xx:nestle', 'xx:Baba', 'xx:Bibi', 'xx:Bobo'],
		'brands_hierarchy' => ['xx:kellogg-s', 'xx:nestle', 'xx:Baba', 'xx:Bibi', 'xx:Bobo'],
		'lc' => 'fr'
	}
) or diag Dumper($product_ref);

compute_field_tags($product_ref, "fr", "brands");

delete $product_ref->{brands_debug_tags};

is($product_ref->{brands_tags}, ['xx:kellogg-s', 'xx:nestle', 'xx:Baba', 'xx:Bibi', 'xx:Bobo'])
	or diag Dumper $product_ref->{brands_tags};

ProductOpener::Tags::retrieve_tags_taxonomy("test");

$product_ref = {
	lc => "de",
	test => "Grünkohl, Äpfel, café, test",
};

compute_field_tags($product_ref, "de", "test");

is(
	$product_ref,
	{
		'lc' => 'de',
		'test' => "Gr\x{fc}nkohl, \x{c4}pfel, caf\x{e9}, test",
		'test_hierarchy' => ['en:kale', "de:caf\x{e9}", 'de:test', "de:Äpfel"],
		'test_lc' => 'de',
		'test_tags' => ['en:kale', "de:caf\x{e9}", 'de:test', "de:Äpfel"]
	}
) or diag Dumper $product_ref;

$product_ref = {"stores" => "Intermarché"};
compute_field_tags($product_ref, "fr", "stores");
is($product_ref->{stores_tags}, ["intermarche"]);
compute_field_tags($product_ref, "de", "stores");
is($product_ref->{stores_tags}, ["intermarche"]);

# Test add_tags_to_field

$product_ref = {
	lc => "fr",
	'categories_hierarchy' => ['en:meals',],
};

add_tags_to_field($product_ref, "fr", "categories", "pommes");
compute_field_tags($product_ref, "fr", "categories");

add_tags_to_field($product_ref, "en", "categories", "bananas");
compute_field_tags($product_ref, "en", "categories");

add_tags_to_field($product_ref, "en", "categories", "en:pears");
compute_field_tags($product_ref, "en", "categories");

add_tags_to_field($product_ref, "es", "categories", "en:peaches");
compute_field_tags($product_ref, "es", "categories");

is(
	[sort @{$product_ref->{categories_tags}}],
	[
		sort('en:plant-based-foods-and-beverages', 'en:plant-based-foods', 'en:fruits-and-vegetables-based-foods',
			'en:meals', 'en:fruit-based-foods-and-beverages', 'en:fruit-based-foods',
			'en:fruits', 'en:apples', 'en:peaches',
			'en:tropical-fruits', 'en:bananas', 'en:pears',
		)
	],
) or diag Dumper $product_ref;

$product_ref = {
	lc => "fr",
	categories => "pommes, bananes, en:pears, fr:fraises, es:limones",
};

compute_field_tags($product_ref, "fr", "categories");

is(
	[sort @{$product_ref->{categories_tags}}],
	[
		sort('en:plant-based-foods-and-beverages', 'en:plant-based-foods',
			'en:fruits-and-vegetables-based-foods', 'en:fruit-based-foods-and-beverages',
			'en:fruit-based-foods', 'en:fruits',
			'en:apples', 'en:berries',
			'en:citrus', 'en:tropical-fruits',
			'en:bananas', 'en:lemons',
			'en:pears', 'en:strawberries')
	]
) or diag Dumper $product_ref;

$product_ref = {
	'categories' =>
		"Plats pr\x{e9}par\x{e9}s, Plats pr\x{e9}par\x{e9}s au poisson, Plats \x{e0} base de p\x{e2}tes, Lasagnes pr\x{e9}par\x{e9}es, Plats au saumon",
	'categories_lc' => 'fr',
	'categories_tags' =>
		['en:meals', 'en:pasta-dishes', 'en:prepared-lasagne', 'en:meals-with-fish', 'en:meals-with-salmon',],
	lc => 'fr',
	lang => 'fr',
};

add_tags_to_field($product_ref, "en", "categories",
	"Meals,Pasta dishes,Prepared lasagne,Meals with fish,Meals with salmon");

is($product_ref->{categories_tags},
	['en:meals', 'en:pasta-dishes', 'en:prepared-lasagne', 'en:meals-with-fish', 'en:meals-with-salmon',])
	or diag Dumper $product_ref;

# get_all_tags_having_property
$product_ref = {
	'labels_tags' => ['en:fair-trade', 'en:non-fair-trade',],
	lc => 'en',
	lang => 'en',
};
is(
	get_all_tags_having_property($product_ref, "labels", "incompatible_with:en"),
	{
		'en:fair-trade' => 'labels:en:non-fair-trade',
		'en:non-fair-trade' => 'labels:en:fair-trade',
	}
);

# Tests for set_field_input_tags_for_source

my @tests = (
	['en-categories-coffee', 'en', 'categories', 'coffee'],

	['fr-categories-cafe-lait-xyz', 'fr', 'categories', 'café, lait, xyz'],

	['en-allergens-eggs-mustard-crab-xyz', 'en', 'allergens', 'eggs, mustard, crab, xyz'],

	['fr-allergens-oeufs-moutarde-crabe-xyz', 'fr', 'allergens', 'oeufs, moutarde, crabe, xyz',],

	['fr-allergens-oeuf-et-moutarde', 'fr', 'allergens', 'oeuf et moutarde',],

	['fr-allergens-peut-contenir-oeuf-et-moutarde', 'fr', 'allergens', 'peut contenir : oeuf et moutarde',],

	['fr-allergens-celeri-crustaces-et-lupin', 'fr', 'allergens', 'Céleri, crustacés et lupin.'],

	[
		'fr-allergens-celeri-crustaces-et-lupin-peut-contenir-oeuf-et-moutarde',
		'fr', 'allergens', 'Céleri, crustacés et lupin. Peut contenir oeuf et moutarde.'
	],

	[
		'en-add-categories-coffee',
		'en',
		'categories',
		'coffee, tea',
		1,
		{
			categories_tags => ['en:meals'],
			tags_sources => {categories => {packaging => {tags => ["en:coffee", "en:meals"]}}}
		}
	],
);

foreach my $test_ref (@tests) {

	my $testid = "set_field_input_tags_for_source-" . $test_ref->[0];

	my $tag_lc = $test_ref->[1];
	my $field = $test_ref->[2];
	my $input_tags = $test_ref->[3];
	my $add_tags = $test_ref->[4] // 0;
	my $product_ref = $test_ref->[5] // {};

	set_field_input_tags_for_source($product_ref, $tag_lc, $field, "packaging", $input_tags, $add_tags);

	normalize_product_for_test_comparison($product_ref);
	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json",
		$update_expected_results, {id => $testid});
}

done_testing();
