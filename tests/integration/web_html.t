#!/usr/bin/perl -w

# Tests to find HTML changes for different types of pages of the website

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use File::Basename "dirname";

use Storable qw(dclone);

remove_all_users();

remove_all_products();

wait_application_ready();

my $ua = new_client();

my %create_user_args = (%default_user_form, (email => 'bob@gmail.com'));
create_user($ua, \%create_user_args);

# Create some products

my @products = (

	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000001',
			lang => 'en',
			lc => 'en',
			product_name_en => "Apple pie",
			brands => "Bob's pies",
			ingredients_text =>
				"Wheat flour, apples, sugar, butter, eggs, salt, palm oil, acidifier: citric acid, raising agent: sodium bicarbonate",
			ingredients_text_fr =>
				"Farine de blé, pommes, sucre, beurre, oeufs, sel, huile de palme, acidifiant: acide citrique, agent levant: bicarbonate de sodium",
			countries => "United States, India, Japan",
			labels => "Fair trade",
			categories => "Desserts, Pies, Apple pies",
			'nutriments_energy-kj' => 1000,
			'nutriments_energy-kcal' => 240,
			nutriments_fat => 10,
			'nutriments_saturated-fat' => 5,
			nutriments_carbohydrates => 30,
			nutriments_sugars => 20,
			nutriments_fiber => 2,
			nutriments_proteins => 3,
			nutriments_salt => 0.5,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000002',
			lang => 'fr',
			lc => 'en',
			product_name_fr => "Tarte aux pommes et aux framboise bio",
			product_name_en => "Organic apple and raspberry pie",
			brands => "Les tartes de Robert",
			ingredients_text_fr =>
				"Farine de blé, pommes, framboises 10%, sucre, beurre, oeufs, sel, huile de palme, acidifiant: acide citrique, agent levant: bicarbonate de sodium",
			ingredients_text_en =>
				"Wheat flour, apples, raspberries 10%, sugar, butter, eggs, salt, palm oil, acidifier: citric acid, raising agent: sodium bicarbonate",
			countries => "France, UK, Germany",
			labels => "Organic, Fair trade",
			categories => "Desserts, Pies, Apple pies",
			'nutriments_energy-kj' => 1200,
			'nutriments_energy-kcal' => 300,
			nutriments_fat => 12,
			'nutriments_saturated-fat' => 0.5,
			nutriments_carbohydrates => 30,
			nutriments_sugars => 25,
			nutriments_fiber => 4,
			nutriments_proteins => 3,
			nutriments_salt => 1,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000003',
			lang => 'en',
			lc => 'en',
			product_name_fr => "Duck salad",
			brands => "Bob's salads",
			ingredients_text => "Duck, salad, tomatoes, olive oil, vinegar, salt, pepper",
			ingredients_text_fr => "Canard, salade, tomates, huile d'olive, vinaigre, sel, poivre",
			countries => "France, Belgium, Switzerland",
			labels => "Free range duck",
			categories => "Salads, Duck salads",
			'nutriments_energy-kj' => 800,
			'nutriments_energy-kcal' => 200,
			nutriments_fat => 8,
			'nutriments_saturated-fat' => 2,
			nutriments_carbohydrates => 10,
			nutriments_sugars => 5,
			nutriments_fiber => 2,
			nutriments_proteins => 20,
			nutriments_salt => 1,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000004',
			lang => 'en',
			lc => 'en',
			product_name_en => "Very bad vanilla ice cream with lots of sugar and additives",
			brands => "Bob's ice creams",
			ingredients_text =>
				"Milk, sugar, glucose syrup, cream, whey powder, emulsifier: E471, stabilisers: E410, E412, E407, E407a, E466",
			ingredients_text_fr =>
				"Lait, sucre, sirop de glucose, crème, poudre de lactosérum, émulsifiant: E471, stabilisants: E410, E412, E407, E407a, E466",
			countries => "United States, UK, Canada",
			labels => "Very bad",
			categories => "Desserts, Ice creams, Vanilla ice creams",
			'nutriments_energy-kj' => 1500,
			'nutriments_energy-kcal' => 360,
			nutriments_fat => 15,
			'nutriments_saturated-fat' => 10,
			nutriments_carbohydrates => 40,
			nutriments_sugars => 30,
			nutriments_fiber => 0,
			nutriments_proteins => 5,
			nutriments_salt => 0.5,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000005',
			lang => 'en',
			lc => 'en',
			brands => "Alice's ice creams",
			product_name_en => "Very good vanilla ice cream with no sugar and no additives",
			ingredients_text => "Milk, cream, vanilla",
			ingredients_text_fr => "Lait, crème, vanille",
			countries => "France, Italy, Spain",
			labels => "Very good",
			categories => "Desserts, Ice creams, Vanilla ice creams",
			'nutriments_energy-kj' => 1000,
			'nutriments_energy-kcal' => 240,
			nutriments_fat => 10,
			'nutriments_saturated-fat' => 5,
			nutriments_carbohydrates => 30,
			nutriments_sugars => 20,
			nutriments_fiber => 2,
			nutriments_proteins => 3,
			nutriments_salt => 0.5,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000006',
			lang => 'en',
			lc => 'en',
			product_name_en => "Vegan pizza with basil and oregano",
			brands => "Bob's pizzas",
			ingredients_text => "Wheat flour, tomatoes, basil, oregano, olive oil, salt, yeast",
			ingredients_text_fr => "Farine de blé, tomates, basilic, origan, huile d'olive, sel, levure",
			countries => "Italy, Spain, Portugal",
			labels => "Vegan",
			categories => "Pizzas, Vegan pizzas",
			allergens => "Gluten",
			traces => "Soybeans",
			'nutriments_energy-kj' => 1200,
			'nutriments_energy-kcal' => 300,
			nutriments_fat => 12,
			'nutriments_saturated-fat' => 0.5,
			nutriments_carbohydrates => 30,
			nutriments_sugars => 25,
			nutriments_fiber => 4,
			nutriments_proteins => 3,
			nutriments_salt => 1,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000007',
			lang => 'en',
			lc => 'en',
			product_name_en => "Organic apple juice",
			brands => "Bob's juices",
			ingredients_text => "Apples",
			ingredients_text_fr => "Pommes",
			countries => "France, UK, Germany",
			labels => "Organic, Fair trade",
			categories => "Drinks, Juices, Apple juices",
			'nutriments_energy-kj' => 200,
			'nutriments_energy-kcal' => 50,
			nutriments_fat => 0,
			'nutriments_saturated-fat' => 0,
			nutriments_carbohydrates => 12,
			nutriments_sugars => 10,
			nutriments_fiber => 0,
			nutriments_proteins => 0,
			nutriments_salt => 0,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000008',
			lang => 'en',
			lc => 'en',
			product_name_en => "Organic apple and raspberry juice",
			brands => "Bob's juices",
			ingredients_text => "Apples, raspberries 10%",
			ingredients_text_fr => "Pommes, framboises 10%",
			countries => "France, UK, Germany",
			labels => "Organic, Fair trade",
			categories => "Drinks, Juices, Apple juices, Raspberry juices",
			'nutriments_energy-kj' => 250,
			'nutriments_energy-kcal' => 60,
			nutriments_fat => 0,
			'nutriments_saturated-fat' => 0,
			nutriments_carbohydrates => 15,
			nutriments_sugars => 12,
			nutriments_fiber => 1,
			nutriments_proteins => 0,
			nutriments_salt => 0,
		)
	},
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000009',
			lang => 'es',
			lc => 'es',
			product_name_es => "Tarta de manzana",
			brands => "Pablo's tartas",
			ingredients_text_es =>
				"Harina de trigo, manzanas, azúcar, mantequilla, huevos, sal, aceite de palma, acidificante: ácido cítrico, gasificante: bicarbonato de sodio",
			countries => "España, México, Argentina",
			labels => "Comercio justo",
			categories => "Postres",
			'nutriments_energy-kj' => 1000,
			'nutriments_energy-kcal' => 240,
			nutriments_fat => 10,
			'nutriments_saturated-fat' => 5,
			nutriments_carbohydrates => 30,
			nutriments_sugars => 20,
			nutriments_fiber => 2,
			nutriments_proteins => 3,
			nutriments_salt => 0.5,
		)
	},
	# Japanese Ramune lemonade
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000010',
			lang => 'ja',
			lc => 'ja',
			brands => "ラムネ",
			product_name_ja => "ラムネレモネード",
			ingredients_text_ja => "砂糖、レモン果汁、炭酸水、香料、着色料",
			countries => "日本",
			labels => "フェアトレード",
			categories => "飲み物, レモネード",
			'nutriments_energy-kj' => 200,
			'nutriments_energy-kcal' => 50,
			nutriments_fat => 0,
			'nutriments_saturated-fat' => 0,
			nutriments_carbohydrates => 12,
			nutriments_sugars => 10,
			nutriments_fiber => 0,
			nutriments_proteins => 0,
			nutriments_salt => 0,
		)
	},
	# Nutella like product
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000011',
			lang => 'it',
			lc => 'it',
			product_name_it => "Crema di nocciole",
			brands => "Bob's creme",
			ingredients_text_it =>
				"Zucchero, olio di palma, nocciole 13%, latte scremato in polvere 7.5%, cacao magro 7.4%, emulsionante: lecitine (soia), vanillina",
			countries => "Italia, Francia, Germania",
			labels => "Senza olio di palma",
			categories => "Dolci, Creme spalmabili, Creme di nocciole",
			'nutriments_energy-kj' => 2000,
			'nutriments_energy-kcal' => 480,
			nutriments_fat => 25,
			'nutriments_saturated-fat' => 10,
			nutriments_carbohydrates => 50,
			nutriments_sugars => 40,
			nutriments_fiber => 5,
			nutriments_proteins => 5,
			nutriments_salt => 0.5,
		)
	},
	# Olive oil
	{
		%{dclone(\%default_product_form)},
		(
			code => '3300000000012',
			lang => 'it',
			lc => 'it',
			product_name_it => "Olio d'oliva",
			brands => "Mario's olive oils",
			ingredients_text_it => "Olio d'oliva",
			countries => "Italia, Spagna, Grecia",
			labels => "Biologico",
			categories => "Condimenti, Oli, Oli d'oliva",
			'nutriments_energy-kj' => 8000,
			'nutriments_energy-kcal' => 2000,
			nutriments_fat => 100,
			'nutriments_saturated-fat' => 15,
			nutriments_carbohydrates => 0,
			nutriments_sugars => 0,
			nutriments_fiber => 0,
			nutriments_proteins => 0,
			nutriments_salt => 0,
		)
	},
);

foreach my $product_ref (@products) {
	edit_product($ua, $product_ref);
	# Sleep one second so that each product has a different last_modified_t
	# needed to get a predictive order of products in the index page
	sleep(1);
}

# Note: expected results are stored in json files, see execute_api_tests
my $tests_ref = [
	{
		test_case => 'world-index',
		path => '/?sort_by=last_modified_t',
		expected_type => 'html',
	},
	{
		test_case => 'world-index-signedin',
		path => '/?sort_by=last_modified_t',
		expected_type => 'html',
		ua => $ua,
	},
	{
		test_case => 'fr-index',
		subdomain => 'fr',
		path => '/?sort_by=last_modified_t',
		expected_type => 'html',
	},
	{
		test_case => 'world-product',
		path => '/product/3300000000001/apple-pie-bob-s-pies',
		expected_type => 'html',
	},
	{
		test_case => 'fr-product',
		subdomain => 'fr',
		path => '/produit/3300000000001/apple-pie-bob-s-pies',
		expected_type => 'html',
	},
	{
		test_case => 'fr-product-2',
		subdomain => 'fr',
		path => '/produit/3300000000002/tarte-aux-pommes-et-aux-framboise-bio-les-tartes-de-robert',
		expected_type => 'html',
	},
	{
		test_case => 'world-product-not-found',
		path => '/product/1000000000001/apple-pie',
		expected_type => 'html',
		expected_status_code => 404,
	},
	{
		test_case => 'world-categories',
		path => '/category/desserts',
		expected_type => 'html',
	},
	{
		test_case => 'fr-categories',
		subdomain => 'fr',
		path => '/categorie/desserts',
		expected_type => 'html',
	},
	{
		test_case => 'world-brands',
		path => '/brands',
		expected_type => 'html',
	},
	{
		test_case => 'fr-brands',
		subdomain => 'fr',
		path => '/marques',
		expected_type => 'html',
	},
	{
		test_case => 'world-labels',
		path => '/labels',
		expected_type => 'html',
	},
	{
		test_case => 'fr-labels',
		subdomain => 'fr',
		path => '/labels',
		expected_type => 'html',
	},
	{
		test_case => 'world-countries',
		path => '/countries',
		expected_type => 'html',
	},
	{
		test_case => 'fr-countries',
		subdomain => 'fr',
		path => '/pays',
		expected_type => 'html',
	},
	{
		test_case => 'world-label-organic',
		path => '/label/organic',
		expected_type => 'html',
	},
	{
		test_case => 'world-edit-product',
		path => '/cgi/product.pl?type=edit&code=3300000000001',
		expected_type => 'html',
		ua => $ua,
	},
	{
		test_case => 'fr-edit-product',
		path => '/cgi/product.pl?type=edit&code=3300000000002',
		expected_type => 'html',
		ua => $ua,
	},
	{
		test_case => 'world-search-form',
		path => '/cgi/search.pl',
		expected_type => 'html',
	},
	{
		test_case => 'fr-search-form',
		path => '/cgi/search.pl',
		expected_type => 'html',
	},
	{
		test_case => 'world-search-results',
		path => '/cgi/search.pl?search_terms=apple',
		expected_type => 'html',
	},
	{
		test_case => 'fr-search-results',
		path => '/cgi/search.pl?search_terms=tarte',
		expected_type => 'html',
	},
	{
		test_case => 'user-register',
		path => '/cgi/user.pl',
		expected_type => 'html',
	},
];

execute_api_tests(__FILE__, $tests_ref);

done_testing();
