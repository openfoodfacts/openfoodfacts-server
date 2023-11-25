#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use JSON;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::API qw/:all/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

load_agribalyse_data();
load_ecoscore_data();

init_packaging_taxonomies_regexps();

# Taxonomy tags used by EcoScore.pm that should not be renamed
# (or that should be renamed in the code and tests as well).

my %tags = (
	labels => [

		# Production system
		"fr:nature-et-progres",
		"fr:bio-coherence",
		"en:demeter",

		"fr:ab-agriculture-biologique",
		"en:eu-organic",
		#"en:sustainable-fishing-method",

		"fr:haute-valeur-environnementale",
		"en:utz-certified",
		"en:rainforest-alliance",
		"en:fairtrade-international",
		"fr:bleu-blanc-coeur",
		"fr:label-rouge",
		"en:sustainable-seafood-msc",
		"en:responsible-aquaculture-asc",

		# Threatened species
		"en:roundtable-on-sustainable-palm-oil",

	],
	categories => ["en:beef", "en:lamb-meat", "en:veal-meat",],
);

foreach my $tagtype (keys %tags) {

	foreach my $tagid (@{$tags{$tagtype}}) {
		is(canonicalize_taxonomy_tag("en", $tagtype, $tagid), $tagid);
	}
}

my @tests = (

	[
		'empty-product',
		{
			lc => "en",
		}
	],
	[
		'unknown-category',
		{
			lc => "en",
			categories_tags => ["en:some-unknown-category"],
		}
	],
	[
		'known-category-butters',
		{
			lc => "en",
			categories_tags => ["en:butters"],
		}
	],
	[
		'exempted-category-sodas',
		{
			lc => "en",
			categories_tags => ["en:sodas"],
		}
	],
	[
		'label-organic',
		{
			lc => "en",
			categories_tags => ["en:butters"],
			labels_tags => ["fr:ab-agriculture-biologique"],
		}
	],
	# Labels can have cumulative points, except some labels that can't be cumulated (e.g. MSC + ASC, or AB Bio + EU Organic)
	[
		'label-ab-hve',
		{
			lc => "en",
			categories_tags => ["en:butters"],
			labels_tags => ["fr:ab-agriculture-biologique", "fr:haute-valeur-environnementale"],
		}
	],
	[
		'label-msc-asc',
		{
			lc => "en",
			categories_tags => ["en:butters"],
			labels_tags => ["en:sustainable-seafood-msc", "en:responsible-aquaculture-asc"],
		}
	],
	[
		'label-ab-hve-msc-asc',
		{
			lc => "en",
			categories_tags => ["en:butters"],
			labels_tags => [
				"fr:ab-agriculture-biologique", "fr:haute-valeur-environnementale",
				"en:sustainable-seafood-msc", "en:responsible-aquaculture-asc"
			],
		}
	],
	[
		'known-category-margarines',
		{
			lc => "en",
			categories_tags => ["en:margarines"],
		}
	],
	[
		'ingredient-palm-oil',
		{
			lc => "en",
			categories_tags => ["en:margarines"],
			ingredients_analysis_tags => ["en:palm-oil"],
		}
	],
	[
		'ingredient-palm-oil-rspo',
		{
			lc => "en",
			categories_tags => ["en:margarines"],
			ingredients_analysis_tags => ["en:palm-oil"],
			labels_tags => ["en:roundtable-on-sustainable-palm-oil"],
		}
	],

	# Origins of ingredients

	[
		'origins-of-ingredients-specified',
		{
			lc => "en",
			categories_tags => ["en:jams"],
			ingredients_text => "60% apricots (France), 30% cane sugar (Martinique), lemon juice (Italy)",
		}
	],
	[
		'origins-of-ingredients-not-specified',
		{
			lc => "en",
			categories_tags => ["en:jams"],
			ingredients_text => "60% apricots, 30% cane sugar, lemon juice",
		}
	],
	[
		'origins-of-ingredients-partly-specified',
		{
			lc => "en",
			categories_tags => ["en:jams"],
			ingredients_text => "60% apricots (France), 30% cane sugar, lemon juice",
		}
	],
	[
		'origins-of-ingredients-specified-multiple',
		{
			lc => "en",
			categories_tags => ["en:jams"],
			ingredients_text =>
				"60% apricots (France, Spain), 30% cane sugar (Martinique, Guadeloupe, Dominican Republic), lemon juice",
		}
	],
	[
		'origins-of-ingredients-in-origins-field',
		{
			lc => "en",
			categories_tags => ["en:jams"],
			origins_tags => ["en:france"],
			ingredients_text => "60% apricots, 30% cane sugar (Martinique), lemon juice",
		}
	],
	[
		'origins-of-ingredients-in-origins-field-multiple',
		{
			lc => "en",
			categories_tags => ["en:jams"],
			origins_tags => ["en:france", "en:dordogne", "en:belgium"],
			ingredients_text => "60% apricots, 30% cane sugar (Martinique), lemon juice",
		}
	],

	[
		'origins-of-ingredients-nested',
		{
			lc => "en",
			categories_tags => ["en:cheeses"],
			ingredients_text => "Milk, salt, coloring: E160b",
		}
	],

	[
		'origins-of-ingredients-nested-2',
		{
			lc => "en",
			categories_tags => ["en:cheeses"],
			ingredients_text => "Milk, chocolate (cocoa, cocoa butter, sweetener: aspartame), salt",
		}
	],

	[
		'origins-of-ingredients-unknown-origin',
		{
			lc => "en",
			categories_tags => ["en:cheeses"],
			ingredients_text => "Milk (origin: Milky way)",
		}
	],

	[
		'origins-of-ingredients-unspecified-origin',
		{
			lc => "en",
			categories_tags => ["en:cheeses"],
			origins_tags => ["en:unspecified"],
			ingredients_text => "Milk",
		}
	],

	# Packaging adjustment

	[
		'packaging-en-pet-bottle',
		{
			lc => "en",
			categories_tags => ["en:beverages", "en:orange-juices"],
			packaging_text => "PET bottle"
		}
	],

	# plastic should be mapped to the en:other-plastics value

	[
		'packaging-en-plastic-bottle',
		{
			lc => "en",
			categories_tags => ["en:beverages", "en:orange-juices"],
			packaging_text => "Plastic bottle"
		}
	],

	[
		'packaging-en-multiple',
		{
			lc => "en",
			categories_tags => ["en:beverages", "en:orange-juices"],
			packaging_text => "1 cardboard box, 1 plastic film wrap, 6 33cl steel beverage cans"
		}
	],

	[
		'packaging-en-multiple-over-maximum-malus',
		{
			lc => "en",
			categories_tags => ["en:biscuits"],
			packaging_text => "1 plastic box, 1 plastic film wrap, 12 individual plastic bags"
		}
	],

	[
		'packaging-en-unspecified-material-bottle',
		{
			lc => "en",
			categories_tags => ["en:beverages", "en:orange-juices"],
			packaging_text => "bottle"
		}
	],

	[
		'packaging-en-unspecified-material-can',
		{
			lc => "en",
			categories_tags => ["en:beverages", "en:orange-juices"],
			packaging_text => "can"
		}
	],

	[
		'packaging-unspecified',
		{
			lc => "en",
			categories_tags => ["en:milks"],
		}
	],

	[
		'packaging-unspecified-no-a-eco-score',
		{
			lc => "en",
			categories_tags => ["en:baguettes"],
			ingredients_text => "Wheat (France)",
			labels_tags => ["fr:ab-agriculture-biologique"],
		}
	],

	[
		'packaging-fr-new-shapes',
		{
			lc => "fr",
			categories_tags => ["en:baguettes"],
			ingredients_text => "Blé (France)",
			packaging_text =>
				"1 caisse en carton, 1 paille, 2 couverts en métal, 1 gobelet en plastique, 1 enveloppe papier",
		}
	],

	# Sodas: no Eco-Score

	[
		'category-without-ecoscore-sodas',
		{
			lc => "en",
			categories_tags => ["en:sodas"],
			ingredients_text => "Water, sugar",
		}
	],

	# Packaging bulk

	[
		'packaging-en-bulk',
		{
			lc => "en",
			categories_tags => ["en:beverages", "en:orange-juices"],
			packaging_text => "bulk"
		}
	],

	# Sum of bonuses greater than 25

	[
		'sum-of-bonuses-greater-than-25',
		{
			lc => "fr",
			categories_tags => ["en:chicken-breasts"],
			packaging_text => "vrac",
			labels_tags => ["en:demeter"],
			ingredients_text => "Poulet (origine France)",
		},
	],

	# downgrade from B to A when the product contains non-recyclable and non-biodegradable materials

	[
		'carrots',
		{
			lc => "fr",
			categories_tags => ["en:carrots"],
			packaging_text => "vrac",
			labels_tags => ["en:demeter"],
			ingredients_text => "Carottes (origine France)",
		},
	],

	[
		'carrots-plastic',
		{
			lc => "fr",
			categories_tags => ["en:carrots"],
			packaging_text => "Barquette en plastique",
			labels_tags => ["en:demeter"],
			ingredients_text => "Carottes (origine France)",
		},
	],

	# Label ratio = sheet ratio (0.1) : no downgrade if non recyclable

	[
		'grade-a-with-recyclable-label',
		{
			lc => "fr",
			categories_tags => ["en:carrots"],
			packaging_text => "1 Pot verre A recycler, 1 Couvercle acier A recycler,1 Etiquette Polypropylène A jeter",
			labels_tags => ["en:eu-organic"],
			origins_tags => ["en:france"],
			ingredients_text => "Aubergine 60%, Pomme de terre 39%, Huile de colza 1%",
		},
	],

	[
		'grade-a-with-non-recyclable-label',
		{
			lc => "fr",
			categories_tags => ["en:carrots"],
			packaging_text => "1 Pot verre A recycler, 1 Couvercle acier A recycler,1 Etiquette plastique A jeter",
			labels_tags => ["en:eu-organic"],
			origins_tags => ["en:france"],
			ingredients_text => "Aubergine 60%, Pomme de terre 39%, Huile de colza 1%",
		},
	],

	# Milks should be considered as beverages for the Eco-Score

	[
		'milk',
		{
			lc => "fr",
			categories_tags => ["en:milks"],
			packaging_text => "1 bouteille en plastique PET, 1 bouchon PEHD",
			labels_tags => ["en:eu-organic"],
			ingredients_text => "Lait (origine : Bretagne)",
		},
	],

	# Energy drinks should not have an Eco-Score (like waters and sodas)

	[
		'energy-drink',
		{
			lc => "fr",
			categories_tags => ["en:energy-drinks"],
			packaging_text => "1 bouteille en plastique PET, 1 bouchon PEHD",
			ingredients_text => "Eau, caféine",
		},
	],

	# Fresh fruits and vegetables should not have an Eco-Score (at least until we handle seasonality)

	[
		'fresh-vegetable',
		{
			lc => "en",
			categories_tags => ["en:fresh-vegetables", "en:fresh-tomatoes", "en:tomatoes"],
			packaging_text => "1 plastic film",
			ingredients_text => "Tomatoes",
		},
	],

	[
		'frozen-vegetable',
		{
			lc => "en",
			categories_tags => ["en:frozen-vegetables", "en:frozen-carrots", "en:carrots"],
			packaging_text => "1 plastic film",
			ingredients_text => "Carrots",
		},
	],

	# Foie gras should not use the "Duck, liver, raw" Agribalyse category which has a very small impact (modeled after chicken liver)
	[
		'foie-gras',
		{
			lc => "fr",
			categories_tags => ["en:foies-gras"],
			packaging_text => "1 pot en verre, 1 couvercle en acier",
			ingredients_text => "Foie gras de canard",
		},
	],

	# UK product
	[
		'uk-milk',
		{
			lc => "en",
			categories_tags => ["en:milks"],
			packaging_text => "1 PET plastic bottle, 1 PEHD bottle cap",
			ingredients_text => "Milk (England)",
		},
	],

	# Agribalyse score is 0 (which is valid)
	[
		'lamb-leg',
		{
			lc => "en",
			categories_tags => ["en:lamb-leg"],
			ingredients_text => "Fresh lamb leg (Great Britain)",
		},
	],

	# FR: verseur en plastique
	[
		'fr-verseur-en-plastique',
		{
			lc => "fr",
			categories_tags => ["en:olive-oils"],
			ingredients_text =>
				"Huile d'olive de catégorie supérieure obtenue directement des olives et uniquement par des procédés mécaniques.",
			packaging_text => "1 bouteille verre de 6g, verseur plastique de 3g, capsule métal de 1g"
		},
	],

	# Labels that indicate the origin of some ingredients
	[
		"fr-viande-porcine-francaise",
		{
			lc => "fr",
			categories => "endives au jambon",
			ingredients_text => "endives 40%, jambon cuit, jaunes d'oeufs, sel",
			labels => "viande porcine française, oeufs de France",
		}
	],

	# Label that indicates the origin of an ingredient, but no ingredient list
	# (common for products with only 1 ingredient like eggs)
	[
		"fr-oeufs-de-france",
		{
			lc => "fr",
			categories => "oeufs",
			labels => "oeufs de France",
		}
	],

	# Keep track of old ecoscore score and add tags if it has changed
	[
		'track-ecoscore-changes',
		{
			lc => "fr",
			categories_tags => ["en:foies-gras"],
			packaging_text => "1 pot en verre, 1 couvercle en acier",
			ingredients_text => "Foie gras de canard",
			ecoscore_data => {
				grade => "d",
				score => 20,
				agribalyse => {
					code => "old"
				}
			}
		},
	],

	# Score changed but same grade
	[
		'track-ecoscore-same-grade',
		{
			lc => "fr",
			categories_tags => ["en:foies-gras"],
			packaging_text => "1 pot en verre, 1 couvercle en acier",
			ingredients_text => "Foie gras de canard",
			ecoscore_data => {
				grade => "e",
				score => 20,
				agribalyse => {
					version => "2.9"
				}
			}
		},
	],

	# Don't create data or tags if no change
	[
		'track-ecoscore-no-change',
		{
			lc => "fr",
			categories_tags => ["en:foies-gras"],
			packaging_text => "1 pot en verre, 1 couvercle en acier",
			ingredients_text => "Foie gras de canard",
			ecoscore_data => {
				grade => "e",
				score => 18
			}
		},
	],

	# Tags and previous data are retained on subsequent updates even if score is different
	[
		'track-ecoscore-tags-retained',
		{
			lc => "fr",
			categories_tags => ["en:foies-gras"],
			packaging_text => "1 pot en verre, 1 couvercle en acier",
			ingredients_text => "Foie gras de canard",
			ecoscore_data => {
				grade => "e",
				score => 19,
				version => "3.1",
				previous_data => {
					grade => "d",
					score => 20,
					version => "3.0"
				}
			},
			misc_tags => ["en:ecoscore-changed", "en:ecoscore-grade-changed"]
		},
	],

	# Quinoa - has a new category code
	[
		'agribalyse-updated-category',
		{
			lc => "fr",
			categories_tags => ["en:quinoa"],
		},
	],

	# Skyr
	[
		'skyr',
		{
			lc => "en",
			categories_tags => ["en:skyrs"],
		},
	],

	# Yogurt
	[
		'yogurt',
		{
			lc => "en",
			categories_tags => ["en:yogurts"],
		},
	],

	# Calvados with no ingredients, Eco-Score should pick up origins from the category en:calvados origins:en property
	[
		'calvados-no-ingredients-no-origins',
		{
			lc => "en",
			categories_tags => ["en:calvados"],
		},
	],
	[
		'calvados-ingredients-no-origins',
		{
			lc => "en",
			ingredients_text => "wine",
			categories_tags => ["en:calvados"],
		},
	],

);

my $json = JSON->new->allow_nonref->canonical;

foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test

	if (defined $product_ref->{labels}) {
		compute_field_tags($product_ref, $product_ref->{lc}, "labels");
	}

	if (defined $product_ref->{categories}) {
		compute_field_tags($product_ref, $product_ref->{lc}, "categories");
	}

	# Parse the ingredients (and extract the origins), and compute the ingredients percent
	extract_ingredients_from_text($product_ref);

	# Response structure to keep track of warnings and errors
	# Note: currently some warnings and errors are added,
	# but we do not yet do anything with them
	my $response_ref = get_initialized_response();
	analyze_and_combine_packaging_data($product_ref, $response_ref);

	compute_ecoscore($product_ref);

	# Save the result

	if ($update_expected_results) {
		open(my $result, ">:encoding(UTF-8)", "$expected_result_dir/$testid.json")
			or die("Could not create $expected_result_dir/$testid.json: $!\n");
		print $result $json->pretty->encode($product_ref);
		close($result);
	}

	# Compare the result with the expected result

	if (open(my $expected_result, "<:encoding(UTF-8)", "$expected_result_dir/$testid.json")) {

		local $/;    #Enable 'slurp' mode
		my $expected_product_ref = $json->decode(<$expected_result>);
		is_deeply($product_ref, $expected_product_ref) or diag explain $product_ref;
	}
	else {
		fail("could not load $expected_result_dir/$testid.json");
		diag explain $product_ref;
	}
}

#

done_testing();
