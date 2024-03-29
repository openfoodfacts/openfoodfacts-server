#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';
#use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/detect_allergens_from_text extract_ingredients_from_text/;
use ProductOpener::Products qw/compute_languages/;

# dummy product for testing

my @tests = (
	[{lc => "fr", ingredients_text => "lait demi-écrémé 67%"}, ["en:milk",]],
	[{lc => "fr", ingredients_text => "Eau, gluten et dérivés"}, ["en:gluten",]],
	[
		{
			lc => "fr",
			ingredients_text => "NOIX DE SAINT-JACQUES MARINÉES: blabla, do not match the title of the product"
		},
		["en:molluscs"]
	],
	[
		{
			lc => "fr",
			ingredients_text =>
				"NOIX DE SAINT-JACQUES sans corail (8.6 %), ingredients in lower case too, match the ingredient"
		},
		["en:molluscs",]
	],
	[
		{
			lc => "fr",
			ingredients_text => "Noix de Saint-Jacques marinées (8.6 %), ingredients in lower case too, no match"
		},
		["en:molluscs"]
	],
	[
		{lc => "fr", ingredients_text => "GRAINES DE SESAME grillées, ingredients in lower case too"},
		["en:sesame-seeds",]
	],
	[{lc => "fr", ingredients_text => "FRUITS A COQUE 10%, ingredients in lower case too"}, ["en:nuts",]],
	[{lc => "fr", ingredients_text => "FRUITS A COQUE - Something else, ingredients in lower case too"}, ["en:nuts",]],

	[
		{
			lc => "es",
			ingredients_text =>
				"Harina de trigo 59%, margarina [grasa de palma, agua, aceite de colza, sal, emulgente: monoglicéridos y diglicéridos de ácidos grasos, corrector de acidez: ácido cítrico, colorante: carotenos], azúcar 17,8%, dextrosa, sal, gasificantes: carbonatos de sodio, aroma. Puede contener trazas de leche."
		},
		["en:gluten",],
		["en:milk"]
	],
	[
		{
			lc => "es",
			ingredients_text =>
				"Chocolate 48% [azúcar, pasta de cacao, manteca de cacao, lactosa, materia grasa láctea anhidra, leche desnatada en polvo, emulgente: lecitinas (girasol), aroma], harina de trigo, azúcar, mantequilla concentrada 6,5%, jarabe de glucosa y fructosa, sal, gasificantes: carbonatos de amonio - carbonatos de sodio - difosfatos, acidulante: ácido cítrico. Puede contener trazas de huevo y frutos de cáscara."
		},
		["en:gluten", "en:milk"],
		["en:eggs", "en:nuts"]
	],

	[{lc => "fi", ingredients_text => "kevytmaito 67%"}, ["en:milk",]],
	[{lc => "fi", ingredients_text => "Vesi, gluteeni ja sen johdannaiset"}, ["en:gluten",]],
	[{lc => "fi", ingredients_text => "MARINOITUJA SIMPUKOITA: blabla, älä poimi tuotteen nimeä"}, []],
	[
		{
			lc => "fi",
			ingredients_text => "KAMPASIMPUKOITA ilman mätiä (8.6 %), ainesosat myös pienellä, poimi ainesosa"
		},
		["en:molluscs",]
	],
	[
		{
			lc => "fi",
			ingredients_text => "Marinoituja kampasimpukoita (8.6 %), ainesosat myös pienellä, ei poimintaa"
		},
		[]
	],
	[{lc => "fi", ingredients_text => "grillattuja SEESAMINSIEMENIÄ, aineosia myös pienellä"}, ["en:sesame-seeds",]],
	[{lc => "fi", ingredients_text => "PÄHKINÖITÄ 10%, aineosia myös pienellä"}, ["en:nuts",]],
	[{lc => "fi", ingredients_text => "PÄHKINÄT - Jotain muuta, aineosia myös pienellä"}, ["en:nuts",]],

	[
		{
			lc => "de",
			ingredients_text =>
				"Zucker, Gewürze, Antioxidations-mittel: Ascorbinsâure, Konservierungsstoff: Natriumnitrit. Kann Spuren von Senf und Sellerie enthalten."
		},
		[],
		["en:celery", "en:mustard"]
	],
	[
		{lc => "it", ingredients_text => "Puo contenere tracce di frutta a guscio, sesamo, soia e uova"},
		[], ["en:eggs", "en:nuts", "en:sesame-seeds", "en:soybeans"]
	],

	[{lc => "fr", traces => "Traces de lait"}, [], ["en:milk"]],
	[
		{lc => "fr", traces => "Peut contenir des traces de lait et d'autres fruits à coques"},
		[], ["en:milk", "en:nuts"]
	],
	[{lc => "fr", traces => "Lait, Gluten"}, [], ["en:gluten", "en:milk"]],
	[
		{lc => "fr", ingredients_text => "Traces possibles : céleri", traces => "Lait, Gluten"},
		[], ["en:celery", "en:gluten", "en:milk"]
	],
	[
		{
			lc => "fr",
			ingredients_text => "Traces éventuelles de moutarde, sésame et céleri",
			traces => "Lait, Gluten"
		},
		[],
		["en:celery", "en:gluten", "en:milk", "en:mustard", "en:sesame-seeds"]
	],

	[{lc => "fr", traces => "noisettes et produits à base de noisettes"}, [], ["en:nuts"]],
	[{lc => "es", ingredients_text => "traza de nueces"}, [], ["en:nuts"]],
	[{lc => "es", traces => "contiene leche y productos derivados"}, [], ["en:milk"]],
	[{lc => "es", traces => "contiene leche y productos derivados incluida lactosa"}, [], ["en:milk"]],

	[
		{
			lc => "fr",
			ingredients_text => "Sucre. Fabriqué dans un atelier qui manipule du lait, de la moutarde et du céleri."
		},
		[],
		["en:celery", "en:milk", "en:mustard"]
	],

	[{lc => "fr", ingredients_text => "amidon de blé. traces de _céleri_."}, ["en:gluten"], ["en:celery"]],
	[{lc => "fr", ingredients_text => "Traces éventuelles de : épeautre."}, [], ["en:gluten"]],

	[{lc => "fr", ingredients_text => "Contient du _lait_."}, ["en:milk"], []],
	[
		{lc => "fr", ingredients_text => "Contient du lait, du soja et de la moutarde."},
		["en:milk", "en:mustard", "en:soybeans"], []
	],
	[
		{lc => "en", ingredients_text => "Contains soy, milk and hazelnut. May contain celery."},
		["en:milk", "en:nuts", "en:soybeans"],
		["en:celery"]
	],
	[
		{
			lc => "en",
			ingredients_text => "Chocolate. Contains milk, hazelnuts and other nuts. May contain celery and mustard."
		},
		["en:milk", "en:nuts"],
		["en:celery", "en:mustard"]
	],

	# Currently not supported
	# [ { lc => "de", ingredients_text => "kann Haselnüsse und andere schalenfrüchte enthalten",}, [], ["en:nuts"] ],

	[{lc => "de", ingredients_text => "Kann spuren von Erdnüssen"}, [], ["en:peanuts"]],
	[
		{
			lc => "en",
			ingredients_text =>
				"salt, egg, spice. allergen advice: for allergens including cereals containing gluten, see ingredients in bold. May contain traces of nuts."
		},
		['en:eggs'],
		['en:nuts']
	],
	[
		{
			lc => "fr",
			ingredients_text =>
				"sucre, lécithine de soja, sel. Allergènes : voir les ingrédients en gras. Traces éventuelles de gluten et de fruits à coque."
		},
		['en:soybeans'],
		['en:gluten', 'en:nuts']
	],

	# Use the ingredients taxonomy to add allergens
	[{lc => "fr", ingredients_text => "semoule de blé dur, pousses de soja"}, ["en:gluten"], []],

	# Japanese allergens are in parenthesis
	[
		{
			lc => "ja",
			ingredients_text => "香料 (ラッカセイ, 種実類,魚)"
		},
		["en:peanuts",],    # allergens
		["en:fish", "en:nuts", "en:peanuts",],    # traces
	],
	# Japanese allergens are in parenthesis with specific words
	[
		{
			lc => "ja",
			ingredients_text => "ミートボール(一部に卵・グルテン・乳成分・大豆を含む)."
		},
		["en:eggs", "en:gluten", "en:milk", "en:soybeans",],    # allergens
		[],    # traces
	],
	# Japanese allergens are in parenthesis with other specific words
	[
		{
			lc => "ja",
			ingredients_text => "香料(乳由来)."
		},
		["en:milk",],    # allergens
		[],    # traces
	],
	# allergens in parenthesis should not change the nova score but should appear in allergens
	[
		{
			lc => "hr",
			ingredients_text => "Krupica od durum pšenice (gluten), voda."
		},
		["en:gluten",],    # allergens
		[],    # traces
	],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];
	my $expected_traces_tags = $test_ref->[2];

	$product_ref->{"ingredients_text_" . $product_ref->{lc}} = $product_ref->{ingredients_text};

	compute_languages($product_ref);
	extract_ingredients_from_text($product_ref);
	detect_allergens_from_text($product_ref);

	is_deeply($product_ref->{allergens_tags}, $expected_tags) or diag explain $product_ref;

	if (defined $expected_traces_tags) {
		is_deeply($product_ref->{traces_tags}, $expected_traces_tags) or diag explain $product_ref;
	}
}

done_testing();
