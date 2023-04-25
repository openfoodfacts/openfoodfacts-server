#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP', filter => "info";

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::ImportConvert qw/:all/;

init_emb_codes();

# dummy product for testing

my $product_ref = {
	lc => "es",
	total_weight => "Peso neto: 480 g (6 x 80 g) Peso neto escurrido: 336 g (6x56 g)",
};

clean_weights($product_ref);

diag explain $product_ref;

is($product_ref->{net_weight}, "480 g");

assign_value($product_ref, "energy_value", "2428.000");

is($product_ref->{energy_value}, "2428");

assign_value($product_ref, "fat_value", "2428.0300");

is($product_ref->{fat_value}, "2428.03");

assign_value($product_ref, "sugars_value", "10.6000");

is($product_ref->{sugars_value}, "10.6");

$product_ref->{some_field} = "Fabriqué en France par EMB59481 pour Auchan Production";

match_taxonomy_tags($product_ref, "some_field", "emb_codes",
	{split => ',|( \/ )|\r|\n|\+|:|;|=|\(|\)|\b(et|par|pour|ou)\b',});

is($product_ref->{emb_codes}, "EMB59481");

my @assign_quantity_tests = (

	["Champagne brut 35,5 CL", "Champagne brut", "35,5 CL"],
	[
		"NATILLAS DE SOJA SABOR VAINILLA CARREFOUR BIO 2X125G",
		"NATILLAS DE SOJA SABOR VAINILLA CARREFOUR BIO",
		"2 X 125 G"
	],
	["Barres de Céréales (8+4) x 25g", "Barres de Céréales (8+4) x 25g", undef],
);

foreach my $test_ref (@assign_quantity_tests) {

	$product_ref = {"product_name" => $test_ref->[0]};
	assign_quantity_from_field($product_ref, "product_name");
	is($product_ref->{product_name}, $test_ref->[1]);
	is($product_ref->{quantity}, $test_ref->[2]);

}

$product_ref = {"lc" => "fr", "product_name_fr" => "Soupe bio"};
@fields = qw(product_name_fr);
match_labels_in_product_name($product_ref);
is($product_ref->{labels}, 'en:organic') or diag explain $product_ref;

@fields = qw(quantity net_weight_value_unit);
$product_ref = {"lc" => "fr", net_weight_value_unit => "250 gr", quantity => "10.11.2019"};
clean_weights($product_ref);
is($product_ref->{quantity}, "250 g") or diag explain $product_ref;

$product_ref = {"lc" => "fr", net_weight_value_unit => "250 gr", quantity => "2 tranches"};
clean_weights($product_ref);
is($product_ref->{quantity}, "2 tranches (250 g)") or diag explain $product_ref;

$product_ref = {"lc" => "fr", emb_codes => "EMB 60282A - Gouvieux (Oise, France)"};
@fields = ("emb_codes");
clean_fields($product_ref);
is($product_ref->{emb_codes}, "EMB 60282A") or diag explain $product_ref;

# Test extract_nutrition_facts_from_text

my @tests = (
	[
		"fr",
		"Pour 100 g : Energie 750 kJ / 180 kcal Matières grasses 9.3 g dont acides gras saturés 3.4 g Glucides 9.1 g dont sucres 1.3 g Fibres alimentaires 2.7 g Protéines 12.7 g Sel 1 g",
		{
			'carbohydrates' => ['9.1', 'g', ''],
			'energy-kcal' => ['180', 'kcal', ''],
			'energy-kj' => ['750', 'kJ', ''],
			'fat' => ['9.3', 'g', ''],
			'fiber' => ['2.7', 'g', ''],
			'proteins' => ['12.7', 'g', ''],
			'salt' => ['1', 'g', ''],
			'saturated-fat' => ['3.4', 'g', ''],
			'sugars' => ['1.3', 'g', ''],
		}
	],
	[
		"fr", "pour 100g :
		Energie (kJ) : 1694
		Energie (kcal) : 401
		Graisses (g) : 5.1
		dont acides gras saturés (g) : 0.6
		Glucides (g) : 74.8
		dont sucres (g) : 7.3
		Fibres alimentaires (g) : 3.9
		Protéines (g) : 11.9
		Sodium (g) : 0,0048
		Sel (g) : 0.01",
		{
			'carbohydrates' => ['74.8', 'g', ''],
			'energy-kcal' => ['401', 'kcal', ''],
			'energy-kj' => ['1694', 'kJ', ''],
			'fat' => ['5.1', 'g', ''],
			'fiber' => ['3.9', 'g', ''],
			'proteins' => ['11.9', 'g', ''],
			'salt' => ['0.01', 'g', ''],
			'saturated-fat' => ['0.6', 'g', ''],
			'sodium' => ['0,0048', 'g', ''],
			'sugars' => ['7.3', 'g', '']
		}
	],
	[
		"fr", "pour 100g :
		Energie (kJ) :
		Energie (kcal) :
		Graisses (g) :
		dont acides gras saturés (g) :
		Glucides (g) :
		dont sucres (g) :
		Fibres alimentaires (g) :
		Protéines (g) :
		Sel (g) :", {}
	],
	[
		"fr", "pour 100g :
		Energie (kJ) : 2989
		Energie (kcal) : 727
		Graisses (g) : 80
		dont acides gras saturés (g) : 52
		Glucides (g) : 1
		dont sucres (g) : 0
		Fibres alimentaires (g) : Traces
		Protéines (g) : 0.7
		Sodium (g) : 0,79
		Sel (g) : 2",
		{
			'carbohydrates' => ['1', 'g', ''],
			'energy-kcal' => ['727', 'kcal', ''],
			'energy-kj' => ['2989', 'kJ', ''],
			'fat' => ['80', 'g', ''],
			'fiber' => ['0', 'g', '~'],
			'proteins' => ['0.7', 'g', ''],
			'salt' => ['2', 'g', ''],
			'saturated-fat' => ['52', 'g', ''],
			'sodium' => ['0,79', 'g', ''],
			'sugars' => ['0', 'g', '']
		}
	],

	["en", "per serving (20g) : energy 250 kj", {'energy-kj' => ['250', 'kJ', '']}, "serving", "20g"],
	["fr", "à la portion de 40 g: energie 250 kj", {'energy-kj' => ['250', 'kJ', '']}, "serving", "40 g"],
	["fr", "Par portion (40 g), energie 250 kj", {'energy-kj' => ['250', 'kJ', '']}, "serving", "40 g"],

	[
		"fr", "A la portion (0.025L) :
Energie (kJ) : 285
Energie (kcal) : 67
Graisses (g) : 0
dont acides gras saturés (g) : 0
Glucides (g) : 16.8
dont sucres (g) : 16.8
Fibres alimentaires (g) : 0
Protéines (g) : 0
Sel (g) : 0
Cette bouteille contient 20 portions de 25ml pour un verre de 200ml de sirop dilué (1 volume de sirop + 7 volumes d'eau).",
		{
			'carbohydrates' => ['16.8', 'g', ''],
			'energy-kcal' => ['67', 'kcal', ''],
			'energy-kj' => ['285', 'kJ', ''],
			'fat' => ['0', 'g', ''],
			'fiber' => ['0', 'g', ''],
			'proteins' => ['0', 'g', ''],
			'salt' => ['0', 'g', ''],
			'saturated-fat' => ['0', 'g', ''],
			'sugars' => ['16.8', 'g', '']
		},
		"serving",
		"0.025L"
	],

	[
		"fr",
		"Pour 100g : Energie 391 kJ/ 93kcal, Matières grasses 0.8 g dont Acides gras saturés 0.1 g, Glucides 12 g dont Sucres <0.5 g , Fibres alimentaires 6.3 g, Protéines 6.1 g, Sel 0.58 g",
		{
			'carbohydrates' => ['12', 'g', ''],
			'energy-kcal' => ['93', 'kcal', ''],
			'energy-kj' => ['391', 'kJ', ''],
			'fat' => ['0.8', 'g', ''],
			'fiber' => ['6.3', 'g', ''],
			'proteins' => ['6.1', 'g', ''],
			'salt' => ['0.58', 'g', ''],
			'saturated-fat' => ['0.1', 'g', ''],
			'sugars' => ['0.5', 'g', '<']
		}
	],
);

foreach my $test_ref (@tests) {

	my $nutrients_ref = {};
	my $nutrition_data_per;
	my $serving_size;
	extract_nutrition_facts_from_text($test_ref->[0], $test_ref->[1], $nutrients_ref, \$nutrition_data_per,
		\$serving_size);
	is($nutrition_data_per, $test_ref->[3]);
	is($serving_size, $test_ref->[4]);

	if (not is_deeply($nutrients_ref, $test_ref->[2])) {
		print STDERR "failed nutrients extraction for lc: $test_ref->[0] - text: $test_ref->[1]\n";
		# display the results in a format we can easily copy to the test
		my $results = "{";
		foreach my $nid (sort keys %$nutrients_ref) {
			$results
				.= " '"
				. $nid . "'=>['"
				. $nutrients_ref->{$nid}[0] . "','"
				. $nutrients_ref->{$nid}[1] . "','"
				. $nutrients_ref->{$nid}[2] . "'],";
		}
		$results =~ s/,$//;
		$results .= " }";
		print STDERR $results . "\n";
	}
}

# clean_fields tests

@tests = (

	# Lowercase ALL CAPS fields
	[
		{lc => "es", product_name_es => "NATILLAS DE SOJA SABOR VAINILLA"},
		{lc => "es", product_name_es => "Natillas de soja sabor vainilla"},
	],

	# Uppercase all lowercase fields

	[
		{lc => "es", product_name_es => "natillas de soja sabor vainilla"},
		{lc => "es", product_name_es => "Natillas de soja sabor vainilla"},
	],

	# Remove brand at end of product name
	[
		{lc => "es", product_name_es => "NATILLAS DE SOJA SABOR VAINILLA CARREFOUR", brands => "CARREFOUR"},
		{lc => "es", product_name_es => "Natillas de soja sabor vainilla", brands => "Carrefour"},
	],

	[
		{
			lc => "es",
			product_name_es => "NATILLAS DE SOJA SABOR VAINILLA CARREFOUR BIO",
			brands => "CARREFOUR, CARREFOUR BIO"
		},
		{lc => "es", product_name_es => "Natillas de soja sabor vainilla", brands => "Carrefour, Carrefour bio"},
	],

	# Brand with dots or other characters instead of spaces / dashes

	[
		{lc => "fr", product_name_fr => "Petit brie bons.mayennais", brands => "Bons mayennais"},
		{lc => "fr", product_name_fr => "Petit brie", brands => "Bons mayennais"},
	],

	[
		{lc => "fr", product_name_fr => "Petit brie bonsxmayennais", brands => "Bons mayennais"},
		{lc => "fr", product_name_fr => "Petit brie bonsxmayennais", brands => "Bons mayennais"},
	],

	# combine serving_size, serving_size_value, serving_size_unit (e.g. US import)

	[
		{lc => "en", serving_size_value => "10", serving_size_unit => "g"},
		{lc => "en", serving_size => "10 g", serving_size_value => "10", serving_size_unit => "g"},
	],

	[
		{lc => "en", serving_size => "1 biscuit", serving_size_value => "10", serving_size_unit => "g"},
		{lc => "en", serving_size => "1 biscuit (10 g)", serving_size_value => "10", serving_size_unit => "g"},
	],

	[
		{lc => "en", serving_size_value_unit => "1 biscuit", serving_size_value => "10", serving_size_unit => "g"},
		{
			lc => "en",
			serving_size_value_unit => "1 biscuit",
			serving_size => "1 biscuit (10 g)",
			serving_size_value => "10",
			serving_size_unit => "g"
		},
	],

	[
		{lc => "en", serving_size => "1 biscuit (10 g)", serving_size_value => "10", serving_size_unit => "g"},
		{lc => "en", serving_size => "1 biscuit (10 g)", serving_size_value => "10", serving_size_unit => "g"},
	],

	# Test unspecified values
	[
		{
			lc => "en",
			generic_name_en => "unspecified",
			labels => "non-specified",
			origins => "unknown",
			warning_en => "not specified"
		},
		{lc => "en", generic_name_en => "-", labels => "", origins => "", warning_en => "-"},
	],

	[
		{
			lc => "fr",
			preparation_fr => "non renseignée",
			categories => "non spécifiée",
			labels => "NON RENSEIGNES",
			conservation_conditions_fr => "non indiquées",
			origins => "n/a",
			ingredients_text_fr => "N/A"
		},
		{
			lc => "fr",
			preparation_fr => "-",
			categories => "",
			labels => "",
			conservation_conditions_fr => "-",
			origins => "",
			'ingredients_text_fr' => ''
		},
	],

	# Tags fields: separators should be normalized to a comma
	[
		{lc => "fr", packaging => "étui carton FSC + sachet individuel papier"},
		{lc => "fr", packaging => "étui carton FSC, sachet individuel papier"},
	],

	# Ingredients without separators
	[
		{
			lc => "fr",
			ingredients_text_fr =>
				"Ingrédients : Pur cacao de MadagascarŒufs fraisHuiles végétalesGélifiant végétalSucre"
		},
		{
			lc => "fr",
			ingredients_text_fr => "Pur cacao de Madagascar, Œufs frais, Huiles végétales, Gélifiant végétal, Sucre"
		},
	],

	# Broken HTML code: just remove the field
	[
		{
			lc => "fr",
			ingredients_text_fr =>
				"Ingrédients : -table\n\t{mso-displayed-decimal-separator:\"\\,\";\n\tmso-displayed-thousand-separator:\\00A0;}\n.font5\n\t{color:windowtext;\n\tfont-size:8.0pt;\n\tfont-weight:400;\n\tfont-style:normal;\n\ttext-decoration:none;\n\tfont-family:Calibri, sans-serif;\n\tmso-font-charset:0;}\n.font6\n\t{color:windowtext;\n\tfont-size:8.0pt;\n\tfont-weight:700;\n\tfont-style:normal;\n\ttext-decoration:none;\n\tfont-family:Calibri, sans-serif;\n\tmso-font-charset:0;}\ntd\n\t{padding:0px;\n\tmso-ignore:padding;\n\tcolor:black;\n\tfont-size:11.0pt;\n\tfont-weight:400;\n\tfont-style:normal;\n\ttext-decoration:none;\n\tfont-family:Calibri, sans-serif;\n\tmso-font-charset:0;\n\tmso-number-format:General;\n\ttext-align:general;\n\tvertical-align:bottom;\n\tborder:none;\n\tmso-background-source:auto;\n\tmso-pattern:auto;\n\tmso-protection:locked visible;\n\twhite-space:nowrap;\n\tmso-rotate:0;}\n.xl65\n\t{color:#713D39;\n\tfont-family:Calibri;\n\tmso-generic-font-family:auto;\n\tmso-font-charset:0;}\n.xl66\n\t{color:windowtext;\n\tfont-size:8.0pt;\n\ttext-align:left;\n\tvertical-align:middle;\n\tbackground:white;\n\tmso-pattern:black none;\n\twhite-space:normal;}\n\n\n\n\n\n\n \n \n \n \n \n  \n  \n   \n         haché végétal de SOJA Cuit * 100%  ((SOJA* 97,1%(Eau, protéines de SOJA*),\n   \n  \n  \n \n \n       SOJA naturellement fermenté* 2,9% (eau, fèves de SOJA 24%, , extrait de\n  champignons)).",
		},
		{lc => "fr", ingredients_text_fr => ""}
	],

);

foreach my $test_ref (@tests) {

	clean_fields($test_ref->[0]);
	is_deeply($test_ref->[0], $test_ref->[1]) or diag explain $test_ref->[0];

}

# test match_specific_taxonomy_tags / match_labels_in_product_name

$product_ref = {lc => "fr", product_name_fr => "NUGGETS DE POULET, poulet élevé sans traitement antibiotique"};

match_labels_in_product_name($product_ref);

is($product_ref->{labels}, undef) or diag explain $product_ref->{labels};

$product_ref = {
	product_name => "Nutella 40 g",
	quantity => "40 g",
};

remove_quantity_from_field($product_ref, "product_name");
is($product_ref->{product_name}, "Nutella");

$product_ref = {
	product_name => "Nutella (40g)",
	quantity => "(40g)",
};

remove_quantity_from_field($product_ref, "product_name");
is($product_ref->{product_name}, "Nutella");

$product_ref = {
	product_name => "Nutella[40g]",
	quantity => "[40g]",
};

remove_quantity_from_field($product_ref, "product_name");
is($product_ref->{product_name}, "Nutella");

$product_ref = {
	product_name => "Nutella[40g]",
	quantity => "40g",
};

remove_quantity_from_field($product_ref, "product_name");
is($product_ref->{product_name}, "Nutella");

$product_ref = {
	product_name => "Nutella 2x20g (80g)",
	quantity => "2x20g (80g)",
};

remove_quantity_from_field($product_ref, "product_name");
is($product_ref->{product_name}, "Nutella");

done_testing();
