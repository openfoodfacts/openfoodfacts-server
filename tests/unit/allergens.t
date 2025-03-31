#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';
use JSON;

use ProductOpener::Products qw/compute_languages/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/detect_allergens_from_text get_allergens_taxonomyid/;
use ProductOpener::Test qw/compare_to_expected_results init_expected_results/;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

my @tests = (
	# French basic allergens test
	[
		'fr-basic-allergens',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr =>
				"Eau, LAIT, farine de BLE, sucre, sel, _oeufs_, moutarde, _crustacés_, fruits à coque, _céleri_, POISSON, crème de cassis. Contient mollusques. Peut contenir des traces d'arachide, de _soja_, de LUPIN, et de sésame "
		}
	],

	# French ingredients with allergens
	[
		'fr-ingredients-allergens',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr => "Farine (blé), graines [sésame], condiments (moutarde), sucre de canne, lait de coco"
		}
	],

	# French multiple allergens
	[
		'fr-multiple-allergens',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr =>
				"Farine de blé et de lupin, épices (soja, moutarde et céleri), crème de cassis, traces de fruits à coques, d'arachide et de poisson"
		}
	],

	# French pizza ingredients
	[
		'fr-pizza-ingredients',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr =>
				"Garniture 61% : sauce tomate 32% (purée de tomate, eau, farine de blé, sel, amidon de maïs), mozzarella 26%, chiffonnade de jambon cuit standard 21% (jambon de porc, eau, sel, dextrose, sirop de glucose, stabilisant : E451, arômes naturels, gélifiant : E407, lactose, bouillon de porc, antioxydant : E316, conservateur : E250, ferments), champignons de Paris 15% (champignons, extrait naturel de champignon concentré), olives noires avec noyau (stabilisant : E579), roquette 0,6%, basilic et origan. Pourcentages exprimés sur la garniture. Pâte 39% : farine de blé, eau, levure boulangère, sel, farine de blé malté."
		}
	],

	# French traces
	[
		'fr-traces',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr =>
				"Traces éventuelles de céréales contenant du gluten, fruits à coques, arachide, soja et oeuf."
		}
	],

	# French scallops
	[
		'fr-noix-saint-jacques',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr => "Noix de Saint-Jacques"
		}
	],

	# French scallops abbreviated
	[
		'fr-noix-st-jacques',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr => "Noix de St-Jacques"
		}
	],

	# French scallops without "noix"
	[
		'fr-saint-jacques',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr => "Saint Jacques"
		}
	],

	# French scallops abbreviated without "noix"
	[
		'fr-st-jacques',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr => "St Jacques"
		}
	],

	# French wheat flour
	[
		'fr-farine-ble',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr => "Farine de blé 97%"
		}
	],

	# French wheat flour with allergens in allergens field
	[
		'fr-farine-ble-sulfites',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr => "Farine de blé 97%",
			allergens => "Sulfites"
		}
	],

	# French multiple allergens with traces
	[
		'fr-moutarde-ble-traces-oeufs',
		{
			lc => "fr",
			lang => "fr",
			ingredients_text_fr =>
				"farine de graines de moutarde, 100 % semoule de BLE dur de qualité supérieure Traces éventuelles d'oeufs"
		}
	],

	# French allergens field only
	[
		'fr-allergens-field-only',
		{
			lc => "fr",
			lang => "fr",
			allergens => "Lait de vache, autres fruits à coque, autres céréales contenant du gluten"
		}
	],

	# Finnish basic allergens
	[
		'fi-basic-allergens',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi =>
				"Vesi, MAITO, VEHNÄjauho, sokeri, suola, _kananmunat_, sinappi, _äyriäiset_, pähkinöitä, _selleri_, KALA, _nilviäisiä_. Saattaa sisältää pieniä määriä LUPIINEJA, maapähkinöitä, _soijaa_ ja seesamia "
		}
	],

	# Finnish ingredients with allergens
	[
		'fi-ingredients-allergens',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi => "Jauho (vehnä), siemenet [seesami], mausteet (sinappi), ruokosokeri, kookosmaito"
		}
	],

	# Finnish multiple allergens with traces
	[
		'fi-multiple-allergens-traces',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi =>
				"vehnä ja lupiinijauho, mausteet (soija, sinappi ja selleri), saattaa sisältää pieniä määriä pähkinöitä, maapähkinöitä ja kalaa"
		}
	],

	# Finnish pizza ingredients
	[
		'fi-pizza-ingredients',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi =>
				"Täyte 61% : tomaattikastike 32% (tomaattipyree, vesi, vehnäjauho, suola, maissitärkkelys), mozzarella 26%, kinkku 21% (siankinkku, vesi, suola, dekstroosi, glukoosisiirappi, stabilisointiaine : E451, luontaiset aromit, hyytelöimisaine : E407, laktoosi, sianlihaliemi, hapettumisenestoaine : E316, säilöntäaine : E250, hapatteet), herkkusienet 15% (herkkusienet, luontainen herkkusieniuute), mustat oliivit (stabilisointiaine : E579), sinappikaali 0,6%, basilika ja oregano."
		}
	],

	# Finnish traces
	[
		'fi-traces',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi =>
				"Saattaa sisältää muita gluteenia sisältäviä viljoja, pähkinöitä, maapähkinöitä, soijaa ja kananmunia."
		}
	],

	# Finnish wheat flour
	[
		'fi-vehnajauho',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi => "vehnäjauho 97%"
		}
	],

	# Finnish wheat flour with allergens in allergens field
	[
		'fi-vehnajauho-sulfiitteja',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi => "vehnäjauho 97%",
			allergens => "Sulfiitteja"
		}
	],

	# Finnish mustard and wheat with traces of eggs
	[
		'fi-sinappi-vehna-kananmuna',
		{
			lc => "fi",
			lang => "fi",
			ingredients_text_fi => "sinappijauhe, VEHNÄsuurimo. Saattaa sisältää kananmunaa"
		}
	],

	# Finnish allergens field only
	[
		'fi-allergens-field-only',
		{
			lc => "fi",
			lang => "fi",
			allergens => "Lehmänmaito, pähkinöitä, gluteenia sisältäviä viljoja."
		}
	],

	# French allergens with markup styles
	[
		'fr-allergens-markup',
		{
			lc => "fr",
			ingredients_text_fr => "Eau, BLE, _CELERI_, __GLUTEN__, _poisson_, FRAISE, _banane_, lupin, _mollusque_"
		}
	],

	# French salmon not highlighted
	[
		'fr-salmon-not-highlighted',
		{
			lc => "fr",
			ingredients_text_fr => "Filet de saumon sauvage certifié MSC, pêché en Pacifique Nord-est (100%)"
		}
	],

	# French allergens in ingredients and separate field
	[
		'fr-allergens-ingredients-and-field',
		{
			lc => "fr",
			ingredients_text_fr => "Saumon, oeufs, blé, chocolat",
			allergens => "Moutarde. Traces éventuelles de lupin"
		}
	],

	# French allergens and traces in separate fields
	[
		'fr-allergens-traces-fields',
		{
			lc => "fr",
			ingredients_text_fr => "Filet de saumon sauvage",
			allergens => "Céleri, crustacés et lupin. Peut contenir du soja, des sulfites et de la moutarde.",
			traces => "Oeufs"
		}
	],

	# French allergens uppercase format
	[
		'fr-allergens-uppercase',
		{
			lc => "fr",
			allergens =>
				"GLUTEN. TRACES POTENTIELLES: CRUSTACÉS, ŒUFS, POISSONS, SOJA, LAIT, FRUITS À COQUES, CÉLERI, MOUTARDE ET SULFITES."
		}
	],

	# English oat flakes
	[
		'en-oat-flakes',
		{
			lc => "en",
			lang => "en",
			ingredients_text_en => "Whole Grain Oat Flakes (65.0%)"
		}
	],

	# German with underscores
	[
		'de-underscores',
		{
			lc => "de",
			lang => "de",
			ingredients_text_de =>
				"Seitan 65% (_Weizen_eiweiß, Wasser), Rapsöl, Kidneybohnen, _Dinkel_vollkornmehl (_Weizen_art), Apfelessig, Gewürze, Tomatenmark, _Soja_soße (Wasser, _Soja_bohnen, Salz, _Weizen_mehl), Kartoffelstärke, Salz."
		}
	],

	# French salmon allergens and multiple traces
	[
		'fr-saumon-allergens-multiple-traces',
		{
			lc => "fr",
			ingredients_text_fr =>
				"Filet de saumon* 93%, jus de citron* 5%, sel marin, poivre*. *Ingrédients issus de l'agriculture biologique. Traces possibles de crustacés, mollusques, lait et gluten.",
			allergens => "poisson",
			traces => "crustacés, mollusques, lait, gluten"
		}
	]
);

foreach my $test_ref (@tests) {
	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

	# Run the test
	compute_languages($product_ref);
	detect_allergens_from_text($product_ref);

	# Remove any user-specific fields that might cause test failures
	if (exists $product_ref->{allergens_from_user}) {
		delete $product_ref->{allergens_from_user};
	}
	if (exists $product_ref->{traces_from_user}) {
		delete $product_ref->{traces_from_user};
	}

	# Compare with expected results
	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);
}

# Additional tests for get_allergens_taxonomyid
is(get_allergens_taxonomyid("en", "egg"), "en:eggs", "Testing get_allergens_taxonomyid for egg (en)");
is(get_allergens_taxonomyid("fr", "fromage"), "en:milk", "Testing get_allergens_taxonomyid for fromage (fr)");
is(get_allergens_taxonomyid("en", "tuna"), "en:fish", "Testing get_allergens_taxonomyid for tuna (en)");

# Get an allergens id from the ingredients taxonomy, using the allergens:en: property
is(get_allergens_taxonomyid("en", "monkfish"), "en:fish", "Testing get_allergens_taxonomyid for monkfish (en)");
is(get_allergens_taxonomyid("en", "en:monkfish"), "en:fish", "Testing get_allergens_taxonomyid for en:monkfish (en)");
is(get_allergens_taxonomyid("es", "en:monkfish"), "en:fish", "Testing get_allergens_taxonomyid for en:monkfish (es)");

# Ingredients that are not in the allergens taxonomy
is(get_allergens_taxonomyid("en", "pineapple"), "pineapple", "Testing get_allergens_taxonomyid for pineapple (en)");

# Ingredients that are not in the ingredients taxonomy
is(
	get_allergens_taxonomyid("en", "some very strange ingredient"),
	"some-very-strange-ingredient",
	"Testing get_allergens_taxonomyid for strange ingredient (en)"
);

done_testing();
