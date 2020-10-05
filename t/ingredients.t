#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

init_emb_codes();

# dummy product for testing

my $product_ref = {
	lc => "fr",
	ingredients_text => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is($product_ref->{ingredients_n}, 19);

my $expected_product_ref =
{
	'ingredients' => [
		{
			'id' => 'en:flour',
			'percent' => '12',
			'rank' => 1,
			'text' => 'farine',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:chocolate',
			'ingredients' => [
				{
					'id' => 'en:cocoa-butter',
					'percent' => '15',
					'text' => 'beurre de cacao'
				},
				{
					'id' => 'en:sugar',
					'percent' => '10',
					'text' => 'sucre'
				},
				{
					'id' => 'en:milk-proteins',
					'text' => "prot\x{e9}ines de lait"
				},
				{
					'id' => 'en:egg',
					'percent' => '1',
					'text' => 'oeuf'
				}
			],
			'rank' => 2,
			'text' => 'chocolat',
			'vegan' => 'maybe',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:emulsifier',
			'ingredients' => [
				{
					'id' => 'en:e463',
					'text' => 'e463'
				}
			],
			'rank' => 3,
			'text' => "\x{e9}mulsifiants"
		},
		{
			'from_palm_oil' => 'maybe',
			'id' => 'en:e432',
			'rank' => 4,
			'text' => 'e432',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'from_palm_oil' => 'maybe',
			'id' => 'en:e472',
			'rank' => 5,
			'text' => 'e472',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:acidity-regulator',
			'ingredients' => [
				{
					'id' => 'en:e322',
					'text' => 'e322'
				},
				{
					'id' => 'en:e333',
					'text' => 'e333'
				}
			],
			'rank' => 6,
			'text' => "correcteurs d'acidit\x{e9}"
		},
		{
			'id' => 'en:e474',
			'rank' => 7,
			'text' => 'e474',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'id' => 'en:e475',
			'rank' => 8,
			'text' => 'e475',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:acid',
			'ingredients' => [
				{
					'id' => 'en:e330',
					'text' => 'acide citrique'
				},
				{
					'id' => 'en:e338',
					'text' => 'acide phosphorique'
				}
			],
			'rank' => 9,
			'text' => 'acidifiant'
		},
		{
			'id' => 'en:salt',
			'rank' => 10,
			'text' => 'sel',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa-butter',
			'percent' => '15',
			'text' => 'beurre de cacao',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sugar',
			'percent' => '10',
			'text' => 'sucre',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:milk-proteins',
			'text' => "prot\x{e9}ines de lait",
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:egg',
			'percent' => '1',
			'text' => 'oeuf',
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e463',
			'text' => 'e463',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e322',
			'text' => 'e322',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'id' => 'en:e333',
			'text' => 'e333',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e330',
			'text' => 'acide citrique',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e338',
			'text' => 'acide phosphorique',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
	'ingredients_analysis_tags' => [
		'en:may-contain-palm-oil',
		'en:non-vegan',
		'en:maybe-vegetarian'
	],
	'ingredients_hierarchy' => [
		'en:flour',
		'en:chocolate',
		'en:emulsifier',
		'en:e432',
		'en:e472',
		'en:acidity-regulator',
		'en:e474',
		'en:e475',
		'en:acid',
		'en:salt',
		'en:cocoa-butter',
		'en:cocoa',
		'en:sugar',
		'en:milk-proteins',
		'en:protein',
		'en:animal-protein',
		'en:egg',
		'en:e463',
		'en:e322',
		'en:e333',
		'en:e330',
		'en:e338'
	],
	'ingredients_n' => 19,
	'ingredients_n_tags' => [
		'19',
		'11-20'
	],
	'ingredients_original_tags' => [
		'en:flour',
		'en:chocolate',
		'en:emulsifier',
		'en:e432',
		'en:e472',
		'en:acidity-regulator',
		'en:e474',
		'en:e475',
		'en:acid',
		'en:salt',
		'en:cocoa-butter',
		'en:sugar',
		'en:milk-proteins',
		'en:egg',
		'en:e463',
		'en:e322',
		'en:e333',
		'en:e330',
		'en:e338'
	],
	'ingredients_tags' => [
		'en:flour',
		'en:chocolate',
		'en:emulsifier',
		'en:e432',
		'en:e472',
		'en:acidity-regulator',
		'en:e474',
		'en:e475',
		'en:acid',
		'en:salt',
		'en:cocoa-butter',
		'en:cocoa',
		'en:sugar',
		'en:milk-proteins',
		'en:protein',
		'en:animal-protein',
		'en:egg',
		'en:e463',
		'en:e322',
		'en:e333',
		'en:e330',
		'en:e338'
	],
	'ingredients_text' => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], prot\x{e9}ines de lait, oeuf 1%) - \x{e9}mulsifiants : E463, E432 et E472 - correcteurs d'acidit\x{e9} : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel",
	'lc' => 'fr',
	'known_ingredients_n' => 22,
	'unknown_ingredients_n' => 0
};

delete $product_ref->{nutriments};
is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);




$product_ref = {
	lc => "fr",
	ingredients_text => "graisse de palmiste"
};

extract_ingredients_from_text($product_ref);
extract_ingredients_classes_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

#ingredients_from_palm_oil_tags: [
#"huile-de-palme"
#],

#diag explain $product_ref;


$expected_product_ref =
{
	'additives_n' => 0,
	'additives_old_n' => 0,
	'additives_old_tags' => [],
	'additives_original_tags' => [],
	'additives_tags' => [],
	'amino_acids_tags' => [],
	'ingredients' => [
		{
			'from_palm_oil' => 'yes',
			'id' => 'en:palm-kernel-fat',
			'rank' => 1,
			'text' => 'graisse de palmiste',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
	'ingredients_analysis_tags' => [
		'en:palm-oil',
		'en:vegan',
		'en:vegetarian'
	],
	'ingredients_from_or_that_may_be_from_palm_oil_n' => 1,
	'ingredients_from_palm_oil_n' => 1,
	'ingredients_from_palm_oil_tags' => [
		'huile-de-palme'
	],
	'ingredients_hierarchy' => [
		'en:palm-kernel-fat',
		'en:oil-and-fat',
		'en:vegetable-oil-and-fat',
		'en:palm-kernel-oil-and-fat'
	],
	'ingredients_n' => 1,
	'ingredients_n_tags' => [
		'1',
		'1-10'
	],
	'ingredients_original_tags' => [
		'en:palm-kernel-fat'
	],
	'ingredients_tags' => [
		'en:palm-kernel-fat',
		'en:oil-and-fat',
		'en:vegetable-oil-and-fat',
		'en:palm-kernel-oil-and-fat'
	],
	'ingredients_text' => 'graisse de palmiste',
	'ingredients_that_may_be_from_palm_oil_n' => 0,
	'ingredients_that_may_be_from_palm_oil_tags' => [],
	'lc' => 'fr',
	'minerals_tags' => [],
	'nucleotides_tags' => [],
	'other_nutritional_substances_tags' => [],
	'unknown_ingredients_n' => 0,
	'known_ingredients_n' => 4,
	'vitamins_tags' => []
};



delete $product_ref->{additives_prev_original_tags};
delete $product_ref->{additives_prev_tags};
delete $product_ref->{additives_prev};
delete $product_ref->{additives_prev_n};
delete $product_ref->{minerals_prev_original_tags};
delete $product_ref->{vitamins_prev_tags};
delete $product_ref->{nucleotides_prev_tags};
delete $product_ref->{amino_acids_prev_tags};
delete $product_ref->{minerals_prev_tags};
delete $product_ref->{minerals_prev};

delete $product_ref->{nutriments};
is_deeply($product_ref, $expected_product_ref) || diag explain $product_ref;



$product_ref = {
	lc => "fr",
	ingredients_text => "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentré 1.4% (équivalent jus d'orange 7.8%), pulpe d'orange concentrée 0.6% (équivalent pulpe d'orange 2.6%), gélifiant (pectines), acidifiant (acide citrique), correcteurs d'acidité (citrate de calcium, citrate de sodium), arôme naturel d'orange, épaississant (gomme xanthane)), chocolat 24.9% (sucre, pâte de cacao, beurre de cacao, graisses végétales (illipe, mangue, sal, karité et palme en proportions variables), arôme, émulsifiant (lécithine de soja), lactose et protéines de lait), farine de blé, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre à lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, émulsifiant (lécithine de soja)."
};

extract_ingredients_from_text($product_ref);

delete $product_ref->{additives_prev_original_tags};
delete $product_ref->{additives_prev_tags};
delete $product_ref->{additives_prev};
delete $product_ref->{additives_prev_n};
delete $product_ref->{minerals_prev_original_tags};
delete $product_ref->{vitamins_prev_tags};
delete $product_ref->{nucleotides_prev_tags};
delete $product_ref->{amino_acids_prev_tags};
delete $product_ref->{minerals_prev_tags};
delete $product_ref->{minerals_prev};

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

$expected_product_ref =
{
	'ingredients' => [
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'fr:Marmelade d\'oranges',
			'ingredients' => [
				{
					'id' => 'en:glucose-fructose-syrup',
					'text' => 'sirop de glucose-fructose'
				},
				{
					'id' => 'en:sugar',
					'text' => 'sucre'
				},
				{
					'id' => 'en:orange-pulp',
					'percent' => '4.5',
					'text' => 'pulpe d\'orange'
				},
				{
					'id' => 'en:concentrated-orange-juice',
					'ingredients' => [],
					'percent' => '1.4',
					'text' => "jus d'orange concentr\x{e9}"
				},
				{
					'id' => 'en:orange-pulp',
					'ingredients' => [],
					'percent' => '0.6',
					'processing' => 'en:concentrated',
					'text' => 'pulpe d\'orange'
				},
				{
					'id' => 'en:gelling-agent',
					'ingredients' => [
						{
							'id' => 'en:e440a',
							'text' => 'pectines'
						}
					],
					'text' => "g\x{e9}lifiant"
				},
				{
					'id' => 'en:acid',
					'ingredients' => [
						{
							'id' => 'en:e330',
							'text' => 'acide citrique'
						}
					],
					'text' => 'acidifiant'
				},
				{
					'id' => 'en:acidity-regulator',
					'ingredients' => [
						{
							'id' => 'en:e333',
							'text' => 'citrate de calcium'
						},
						{
							'id' => 'en:sodium-citrate',
							'text' => 'citrate de sodium'
						}
					],
					'text' => "correcteurs d'acidit\x{e9}"
				},
				{
					'id' => 'en:natural-orange-flavouring',
					'text' => "ar\x{f4}me naturel d'orange"
				},
				{
					'id' => 'en:thickener',
					'ingredients' => [
						{
							'id' => 'en:e415',
							'text' => 'gomme xanthane'
						}
					],
					'text' => "\x{e9}paississant"
				}
			],
			'percent' => '41',
			'rank' => 1,
			'text' => 'Marmelade d\'oranges'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:chocolate',
			'ingredients' => [
				{
					'id' => 'en:sugar',
					'text' => 'sucre'
				},
				{
					'id' => 'en:cocoa-paste',
					'text' => "p\x{e2}te de cacao"
				},
				{
					'id' => 'en:cocoa-butter',
					'text' => 'beurre de cacao'
				},
				{
					'id' => 'en:illipe-oil',
					'text' => "graisses v\x{e9}g\x{e9}tales d'illipe"
				},
				{
					'id' => 'en:mango-kernel-oil',
					'text' => "graisses v\x{e9}g\x{e9}tales de mangue"
				},
				{
					'id' => 'en:shorea-robusta-seed-oil',
					'text' => "graisses v\x{e9}g\x{e9}tales de sal"
				},
				{
					'id' => 'en:shea-butter',
					'text' => "graisses v\x{e9}g\x{e9}tales de karit\x{e9}"
				},
				{
					'id' => 'en:palm-fat',
					'text' => "graisses v\x{e9}g\x{e9}tales de palme"
				},
				{
					'id' => 'en:flavouring',
					'text' => "ar\x{f4}me"
				},
				{
					'id' => 'en:emulsifier',
					'ingredients' => [
						{
							'id' => 'en:soya-lecithin',
							'text' => "l\x{e9}cithine de soja"
						}
					],
					'text' => "\x{e9}mulsifiant"
				},
				{
					'id' => 'en:lactose-and-milk-proteins',
					'text' => "lactose et prot\x{e9}ines de lait"
				}
			],
			'percent' => '24.9',
			'rank' => 2,
			'text' => 'chocolat',
			'vegan' => 'maybe',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:wheat-flour',
			'rank' => 3,
			'text' => "farine de bl\x{e9}",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sugar',
			'rank' => 4,
			'text' => 'sucre',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:egg',
			'rank' => 5,
			'text' => 'oeufs',
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:glucose-fructose-syrup',
			'rank' => 6,
			'text' => 'sirop de glucose-fructose',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'from_palm_oil' => 'no',
			'id' => 'en:colza-oil',
			'rank' => 7,
			'text' => 'huile de colza',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:raising-agent',
			'ingredients' => [
				{
					'id' => 'en:e503ii',
					'text' => 'carbonate acide d\'ammonium'
				},
				{
					'id' => 'en:e450i',
					'text' => 'diphosphate disodique'
				},
				{
					'id' => 'en:e500ii',
					'text' => 'carbonate acide de sodium'
				}
			],
			'rank' => 8,
			'text' => "poudre \x{e0} lever"
		},
		{
			'id' => 'en:salt',
			'rank' => 9,
			'text' => 'sel',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:emulsifier',
			'ingredients' => [
				{
					'id' => 'en:soya-lecithin',
					'text' => "l\x{e9}cithine de soja"
				}
			],
			'rank' => 10,
			'text' => "\x{e9}mulsifiant"
		},
		{
			'id' => 'en:glucose-fructose-syrup',
			'text' => 'sirop de glucose-fructose',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sugar',
			'text' => 'sucre',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:orange-pulp',
			'percent' => '4.5',
			'text' => 'pulpe d\'orange',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:concentrated-orange-juice',
			'percent' => '1.4',
			'text' => "jus d'orange concentr\x{e9}",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:orange-pulp',
			'percent' => '0.6',
			'processing' => 'en:concentrated',
			'text' => 'pulpe d\'orange',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:gelling-agent',
			'text' => "g\x{e9}lifiant"
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:acid',
			'text' => 'acidifiant'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:acidity-regulator',
			'text' => "correcteurs d'acidit\x{e9}"
		},
		{
			'id' => 'en:natural-orange-flavouring',
			'text' => "ar\x{f4}me naturel d'orange",
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:thickener',
			'text' => "\x{e9}paississant"
		},
		{
			'id' => 'en:sugar',
			'text' => 'sucre',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa-paste',
			'text' => "p\x{e2}te de cacao",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa-butter',
			'text' => 'beurre de cacao',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'from_palm_oil' => 'no',
			'id' => 'en:illipe-oil',
			'text' => "graisses v\x{e9}g\x{e9}tales d'illipe",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'from_palm_oil' => 'no',
			'id' => 'en:mango-kernel-oil',
			'text' => "graisses v\x{e9}g\x{e9}tales de mangue",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'from_palm_oil' => 'no',
			'id' => 'en:shorea-robusta-seed-oil',
			'text' => "graisses v\x{e9}g\x{e9}tales de sal",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'from_palm_oil' => 'no',
			'id' => 'en:shea-butter',
			'text' => "graisses v\x{e9}g\x{e9}tales de karit\x{e9}",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'from_palm_oil' => 'yes',
			'id' => 'en:palm-fat',
			'text' => "graisses v\x{e9}g\x{e9}tales de palme",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:flavouring',
			'text' => "ar\x{f4}me",
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:emulsifier',
			'text' => "\x{e9}mulsifiant"
		},
		{
			'id' => 'en:lactose-and-milk-proteins',
			'text' => "lactose et prot\x{e9}ines de lait",
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e503ii',
			'text' => 'carbonate acide d\'ammonium',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e450i',
			'text' => 'diphosphate disodique',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e500ii',
			'text' => 'carbonate acide de sodium',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:soya-lecithin',
			'text' => "l\x{e9}cithine de soja",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e440a',
			'text' => 'pectines',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e330',
			'text' => 'acide citrique',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e333',
			'text' => 'citrate de calcium',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sodium-citrate',
			'text' => 'citrate de sodium'
		},
		{
			'id' => 'en:e415',
			'text' => 'gomme xanthane',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:soya-lecithin',
			'text' => "l\x{e9}cithine de soja",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
	'ingredients_analysis_tags' => [
		'en:palm-oil',
		'en:non-vegan',
		'en:vegetarian-status-unknown'
	],
	'ingredients_hierarchy' => [
		'fr:Marmelade d\'oranges',
		'en:chocolate',
		'en:wheat-flour',
		'en:cereal',
		'en:flour',
		'en:wheat',
		'en:cereal-flour',
		'en:sugar',
		'en:egg',
		'en:glucose-fructose-syrup',
		'en:glucose',
		'en:fructose',
		'en:colza-oil',
		'en:oil-and-fat',
		'en:vegetable-oil-and-fat',
		'en:rapeseed-oil',
		'en:raising-agent',
		'en:salt',
		'en:emulsifier',
		'en:orange-pulp',
		'en:fruit',
		'en:citrus-fruit',
		'en:orange',
		'en:concentrated-orange-juice',
		'en:fruit-juice',
		'en:orange-juice',
		'en:gelling-agent',
		'en:acid',
		'en:acidity-regulator',
		'en:natural-orange-flavouring',
		'en:flavouring',
		'en:natural-flavouring',
		'en:thickener',
		'en:cocoa-paste',
		'en:cocoa',
		'en:cocoa-butter',
		'en:illipe-oil',
		'en:vegetable-fat',
		'en:mango-kernel-oil',
		'en:vegetable-oil',
		'en:shorea-robusta-seed-oil',
		'en:shea-butter',
		'en:palm-fat',
		'en:palm-oil-and-fat',
		'en:lactose-and-milk-proteins',
		'en:protein',
		'en:animal-protein',
		'en:milk-proteins',
		'en:lactose',
		'en:e503ii',
		'en:e503',
		'en:e450i',
		'en:e450',
		'en:e500ii',
		'en:e500',
		'en:soya-lecithin',
		'en:e322',
		'en:e322i',
		'en:e440a',
		'en:e330',
		'en:e333',
		'en:sodium-citrate',
		'en:minerals',
		'en:sodium',
		'en:e415'
	],
	'ingredients_n' => 41,
	'ingredients_n_tags' => [
		'41',
		'41-50'
	],
	'ingredients_original_tags' => [
		'fr:Marmelade d\'oranges',
		'en:chocolate',
		'en:wheat-flour',
		'en:sugar',
		'en:egg',
		'en:glucose-fructose-syrup',
		'en:colza-oil',
		'en:raising-agent',
		'en:salt',
		'en:emulsifier',
		'en:glucose-fructose-syrup',
		'en:sugar',
		'en:orange-pulp',
		'en:concentrated-orange-juice',
		'en:orange-pulp',
		'en:gelling-agent',
		'en:acid',
		'en:acidity-regulator',
		'en:natural-orange-flavouring',
		'en:thickener',
		'en:sugar',
		'en:cocoa-paste',
		'en:cocoa-butter',
		'en:illipe-oil',
		'en:mango-kernel-oil',
		'en:shorea-robusta-seed-oil',
		'en:shea-butter',
		'en:palm-fat',
		'en:flavouring',
		'en:emulsifier',
		'en:lactose-and-milk-proteins',
		'en:e503ii',
		'en:e450i',
		'en:e500ii',
		'en:soya-lecithin',
		'en:e440a',
		'en:e330',
		'en:e333',
		'en:sodium-citrate',
		'en:e415',
		'en:soya-lecithin'
	],
	'ingredients_tags' => [
		'fr:marmelade-d-oranges',
		'en:chocolate',
		'en:wheat-flour',
		'en:cereal',
		'en:flour',
		'en:wheat',
		'en:cereal-flour',
		'en:sugar',
		'en:egg',
		'en:glucose-fructose-syrup',
		'en:glucose',
		'en:fructose',
		'en:colza-oil',
		'en:oil-and-fat',
		'en:vegetable-oil-and-fat',
		'en:rapeseed-oil',
		'en:raising-agent',
		'en:salt',
		'en:emulsifier',
		'en:orange-pulp',
		'en:fruit',
		'en:citrus-fruit',
		'en:orange',
		'en:concentrated-orange-juice',
		'en:fruit-juice',
		'en:orange-juice',
		'en:gelling-agent',
		'en:acid',
		'en:acidity-regulator',
		'en:natural-orange-flavouring',
		'en:flavouring',
		'en:natural-flavouring',
		'en:thickener',
		'en:cocoa-paste',
		'en:cocoa',
		'en:cocoa-butter',
		'en:illipe-oil',
		'en:vegetable-fat',
		'en:mango-kernel-oil',
		'en:vegetable-oil',
		'en:shorea-robusta-seed-oil',
		'en:shea-butter',
		'en:palm-fat',
		'en:palm-oil-and-fat',
		'en:lactose-and-milk-proteins',
		'en:protein',
		'en:animal-protein',
		'en:milk-proteins',
		'en:lactose',
		'en:e503ii',
		'en:e503',
		'en:e450i',
		'en:e450',
		'en:e500ii',
		'en:e500',
		'en:soya-lecithin',
		'en:e322',
		'en:e322i',
		'en:e440a',
		'en:e330',
		'en:e333',
		'en:sodium-citrate',
		'en:minerals',
		'en:sodium',
		'en:e415'
	],
	'ingredients_text' => "Marmelade d'oranges 41% (sirop de glucose-fructose, sucre, pulpe d'orange 4.5%, jus d'orange concentr\x{e9} 1.4% (\x{e9}quivalent jus d'orange 7.8%), pulpe d'orange concentr\x{e9}e 0.6% (\x{e9}quivalent pulpe d'orange 2.6%), g\x{e9}lifiant (pectines), acidifiant (acide citrique), correcteurs d'acidit\x{e9} (citrate de calcium, citrate de sodium), ar\x{f4}me naturel d'orange, \x{e9}paississant (gomme xanthane)), chocolat 24.9% (sucre, p\x{e2}te de cacao, beurre de cacao, graisses v\x{e9}g\x{e9}tales (illipe, mangue, sal, karit\x{e9} et palme en proportions variables), ar\x{f4}me, \x{e9}mulsifiant (l\x{e9}cithine de soja), lactose et prot\x{e9}ines de lait), farine de bl\x{e9}, sucre, oeufs, sirop de glucose-fructose, huile de colza, poudre \x{e0} lever (carbonate acide d'ammonium, diphosphate disodique, carbonate acide de sodium), sel, \x{e9}mulsifiant (l\x{e9}cithine de soja).",
	'known_ingredients_n' => 64,
	'lc' => 'fr',
	'unknown_ingredients_n' => 1
};




is_deeply($product_ref->{ingredients_original_tags}, $expected_product_ref->{ingredients_original_tags}) || diag explain $product_ref->{ingredients_original_tags};

delete $product_ref->{nutriments};
is_deeply($product_ref, $expected_product_ref) || diag explain $product_ref;


# test synonyms for flavouring/flavour/flavor/flavoring
$product_ref = {
	lc => "en",
	ingredients_text => "Natural orange flavor, Lemon flavouring"
};

extract_ingredients_from_text($product_ref);

delete $product_ref->{additives_prev_original_tags};
delete $product_ref->{additives_prev_tags};
delete $product_ref->{additives_prev};
delete $product_ref->{additives_prev_n};
delete $product_ref->{minerals_prev_original_tags};
delete $product_ref->{vitamins_prev_tags};
delete $product_ref->{nucleotides_prev_tags};
delete $product_ref->{amino_acids_prev_tags};
delete $product_ref->{minerals_prev_tags};
delete $product_ref->{minerals_prev};

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

# diag explain $product_ref;

$expected_product_ref =
{
	'ingredients' => [
		{
			'id' => 'en:natural-orange-flavouring',
			'rank' => 1,
			'text' => 'Natural orange flavor',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'id' => 'en:lemon-flavouring',
			'rank' => 2,
			'text' => 'Lemon flavouring',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		}
	],
	'ingredients_analysis_tags' => [
		'en:palm-oil-free',
		'en:maybe-vegan',
		'en:maybe-vegetarian'
	],
	'ingredients_hierarchy' => [
		'en:natural-orange-flavouring',
		'en:flavouring',
		'en:natural-flavouring',
		'en:lemon-flavouring'
	],
	'ingredients_n' => 2,
	'ingredients_n_tags' => [
		'2',
		'1-10'
	],
	'ingredients_original_tags' => [
		'en:natural-orange-flavouring',
		'en:lemon-flavouring'
	],
	'ingredients_tags' => [
		'en:natural-orange-flavouring',
		'en:flavouring',
		'en:natural-flavouring',
		'en:lemon-flavouring'
	],
	'ingredients_text' => 'Natural orange flavor, Lemon flavouring',
	'lc' => 'en',
	'known_ingredients_n' => 4,
	'unknown_ingredients_n' => 0
};


delete $product_ref->{nutriments};
is_deeply($product_ref, $expected_product_ref) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "pâte de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce équitable et de l'agriculture biologique (100% du poids total)."
};

extract_ingredients_from_text($product_ref);

delete $product_ref->{additives_prev_original_tags};
delete $product_ref->{additives_prev_tags};
delete $product_ref->{additives_prev};
delete $product_ref->{additives_prev_n};
delete $product_ref->{minerals_prev_original_tags};
delete $product_ref->{vitamins_prev_tags};
delete $product_ref->{nucleotides_prev_tags};
delete $product_ref->{amino_acids_prev_tags};
delete $product_ref->{minerals_prev_tags};
delete $product_ref->{minerals_prev};

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

$expected_product_ref = {
	'ingredients' => [
		{
			'id' => "fr:p\x{e2}te de cacao de Madagascar",
			'labels' => 'en:fair-trade, en:organic',
			'percent' => '75',
			'rank' => 1,
			'text' => "p\x{e2}te de cacao de Madagascar"
		},
		{
			'id' => 'en:cane-sugar',
			'labels' => 'en:fair-trade, en:organic',
			'rank' => 2,
			'text' => 'sucre de canne',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa-butter',
			'labels' => 'en:fair-trade, en:organic',
			'rank' => 3,
			'text' => 'beurre de cacao',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
	'ingredients_analysis_tags' => [
		'en:palm-oil-content-unknown',
		'en:vegan-status-unknown',
		'en:vegetarian-status-unknown'
	],
	'ingredients_hierarchy' => [
		"fr:p\x{e2}te de cacao de Madagascar",
		'en:cane-sugar',
		'en:sugar',
		'en:cocoa-butter',
		'en:cocoa'
	],
	'ingredients_n' => 3,
	'ingredients_n_tags' => [
		'3',
		'1-10'
	],
	'ingredients_original_tags' => [
		"fr:p\x{e2}te de cacao de Madagascar",
		'en:cane-sugar',
		'en:cocoa-butter'
	],
	'ingredients_tags' => [
		'fr:pate-de-cacao-de-madagascar',
		'en:cane-sugar',
		'en:sugar',
		'en:cocoa-butter',
		'en:cocoa'
	],
	'ingredients_text' => "p\x{e2}te de cacao* de Madagascar 75%, sucre de canne*, beurre de cacao*. * issus du commerce \x{e9}quitable et de l'agriculture biologique (100% du poids total).",
	'lc' => 'fr',
	'known_ingredients_n' => 4,
	'unknown_ingredients_n' => 1
};

delete $product_ref->{nutriments};
is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);

$product_ref = {
	lc => "fr",
	ingredients_text => "gélifiant (pectines)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};


is_deeply (
	$product_ref->{ingredients_original_tags},
	[
		"en:gelling-agent",
		"en:e440a",
	]
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "Fraise 12,3% ; Orange 6.5%, Pomme (3,5%)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};


is_deeply (
	$product_ref->{ingredients},
	[
		{
			'id' => 'en:strawberry',
			'percent' => '12.3',
			'rank' => 1,
			'text' => 'Fraise',
			'vegan' => 'yes',
			'vegetarian' => 'yes',
		},
		{
			'id' => 'en:orange',
			'percent' => '6.5',
			'rank' => 2,
			'text' => 'Orange',
			'vegan' => 'yes',
			'vegetarian' => 'yes',
		},
		{
			'id' => 'en:apple',
			'percent' => '3.5',
			'rank' => 3,
			'text' => 'Pomme',
			'vegan' => 'yes',
			'vegetarian' => 'yes',
		}
	]
) or diag explain $product_ref;



$product_ref = {
	lc => "fr",
	ingredients_text => "Fraise origine France, Cassis (origine Afrique du Sud), Framboise (origine : Belgique), Pamplemousse bio, Orange (bio), Citron (issue de l'agriculture biologique), cacao et beurre de cacao (commerce équitable), cerises issues de l'agriculture biologique",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'id' => 'en:strawberry',
			'origin' => 'en:france',
			'rank' => 1,
			'text' => 'Fraise',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:blackcurrant',
			'origin' => 'en:south-africa',
			'rank' => 2,
			'text' => 'Cassis',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:raspberry',
			'origin' => 'en:belgium',
			'rank' => 3,
			'text' => 'Framboise',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:grapefruit',
			'labels' => 'en:organic',
			'rank' => 4,
			'text' => 'Pamplemousse',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:orange',
			'labels' => 'en:organic',
			'rank' => 5,
			'text' => 'Orange',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:lemon',
			'labels' => 'en:organic',
			'rank' => 6,
			'text' => 'Citron',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa',
			'labels' => 'en:fair-trade',
			'rank' => 7,
			'text' => 'cacao',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa-butter',
			'labels' => 'en:fair-trade',
			'rank' => 8,
			'text' => 'beurre de cacao',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cherry',
			'labels' => 'en:organic',
			'rank' => 9,
			'text' => 'cerises',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "émulsifiant : lécithines (tournesol), arôme)(UE), farine de blé 33% (France), sucre, beurre concentré* 6,5% (France)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:emulsifier',
			'ingredients' => [
				{
					'id' => 'en:sunflower-lecithin',
					'text' => "l\x{e9}cithines de tournesol"
				}
			],
			'rank' => 1,
			'text' => "\x{e9}mulsifiant"
		},
		{
			'id' => 'en:flavouring',
			'origin' => 'en:european-union',
			'rank' => 2,
			'text' => "ar\x{f4}me",
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'id' => 'en:wheat-flour',
			'origin' => 'en:france',
			'percent' => '33',
			'rank' => 3,
			'text' => "farine de bl\x{e9}",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sugar',
			'rank' => 4,
			'text' => 'sucre',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'from_palm_oil' => 'no',
			'id' => 'en:butterfat',
			'origin' => 'en:france',
			'percent' => '6.5',
			'rank' => 5,
			'text' => "beurre concentr\x{e9}",
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sunflower-lecithin',
			'text' => "l\x{e9}cithines de tournesol",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "80% jus de pomme biologique, 20% de coing biologique, sel marin, 98% chlorure de sodium (France, Italie)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'id' => 'en:apple-juice',
			'labels' => 'en:organic',
			'percent' => '80',
			'rank' => 1,
			'text' => 'jus de pomme',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:quince',
			'labels' => 'en:organic',
			'percent' => '20',
			'rank' => 2,
			'text' => 'coing',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sea-salt',
			'rank' => 3,
			'text' => 'sel marin',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sodium-chloride',
			'origin' => 'en:france,en:italy',
			'percent' => '98',
			'rank' => 4,
			'text' => 'chlorure de sodium'
		}
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "mono - et diglycérides d'acides gras d'origine végétale, huile d'origine végétale, gélatine (origine végétale)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'from_palm_oil' => 'maybe',
			'id' => 'en:e471',
			'rank' => 1,
			'text' => "mono- et diglyc\x{e9}rides d'acides gras",
			'vegan' => 'en:yes',
			'vegetarian' => 'en:yes'
		},
		{
			'from_palm_oil' => 'maybe',
			'id' => 'en:oil',
			'rank' => 2,
			'text' => 'huile',
			'vegan' => 'en:yes',
			'vegetarian' => 'en:yes'
		},
		{
			'id' => 'en:e428',
			'rank' => 3,
			'text' => "g\x{e9}latine",
			'vegan' => 'en:yes',
			'vegetarian' => 'en:yes'
		}
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "jus d'orange (sans conservateur), saumon (msc), sans gluten",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is ($product_ref->{labels}, "en:gluten-free") or diag explain $product_ref;
is_deeply ($product_ref->{labels_tags}, ["en:gluten-free"]) or diag explain $product_ref;

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'id' => 'en:orange-juice',
			'labels' => 'en:no-preservatives',
			'rank' => 1,
			'text' => 'jus d\'orange',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:salmon',
			'labels' => 'en:sustainable-seafood-msc',
			'rank' => 2,
			'text' => 'saumon',
			'vegan' => 'no',
			'vegetarian' => 'no'
		}
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "tomates pelées cuites, rondelle de citron, dés de courgette, lait cru, aubergines crues, jambon cru en tranches",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'id' => 'en:peeled-tomatoes',
			'processing' => 'en:cooked',
			'rank' => 1,
			'text' => "tomates pel\x{e9}es",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:lemon',
			'processing' => 'en:sliced',
			'rank' => 2,
			'text' => 'citron',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:courgette',
			'processing' => 'en:diced',
			'rank' => 3,
			'text' => 'courgette',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:raw-milk',
			'rank' => 4,
			'text' => 'lait cru',
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:aubergine',
			'processing' => 'en:raw',
			'rank' => 5,
			'text' => 'aubergines',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:raw-ham',
			'processing' => 'en:sliced',
			'rank' => 6,
			'text' => 'jambon cru',
			'vegan' => 'no',
			'vegetarian' => 'no'
		}
	],
) or diag explain $product_ref;

# Bugs #3827, #3706, #3826 - truncated purée
$product_ref = {
	lc => "fr",
	ingredients_text =>
		"19% purée de tomate, 90% boeuf, 100% pur jus de fruit, 45% de matière grasses",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values( $product_ref->{ingredients} );
delete $product_ref->{ingredients_percent_analysis};

is_deeply(
	$product_ref->{ingredients},
	[
		{	'id'         => 'en:crushed-tomato',
			'percent'    => 19,
			'rank'       => 1,
			'text'       => "pur\x{e9}e de tomate",
			'vegan'      => 'yes',
			'vegetarian' => 'yes'
		},
		{	'id'         => 'en:beef',
			'percent'    => '90',
			'rank'       => 2,
			'text'       => 'boeuf',
			'vegan'      => 'no',
			'vegetarian' => 'no'
		},
		{	'id'         => 'en:fruit-juice',
			'percent'    => 100,
			'rank'       => 3,
			'text'       => 'jus de fruit',
			'vegan'      => 'yes',
			'vegetarian' => 'yes'
		},
		{	'from_palm_oil' => 'maybe',
			'id'            => 'en:oil-and-fat',
			'percent'       => '45',
			'rank'          => 4,
			'text'          => "mati\x{e8}re grasses",
			'vegan'         => 'maybe',
			'vegetarian'    => 'maybe'
		}
	],
) or diag explain $product_ref;


# Finnish
$product_ref = {
	lc => "fi",
	ingredients_text => "jauho (12%), suklaa (kaakaovoi (15%), sokeri [10%], maitoproteiini, kananmuna 1%) - emulgointiaineet : E463, E432 ja E472 - happamuudensäätöaineet : E322/E333 E474-E475, happo (sitruunahappo, fosforihappo) - suola"
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is($product_ref->{ingredients_n}, 19);

$expected_product_ref =
{
	'ingredients' => [
		{
			'id' => 'en:flour',
			'percent' => '12',
			'rank' => 1,
			'text' => 'jauho',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:chocolate',
			'ingredients' => [
				{
					'id' => 'en:cocoa-butter',
					'percent' => '15',
					'text' => 'kaakaovoi'
				},
				{
					'id' => 'en:sugar',
					'percent' => '10',
					'text' => 'sokeri'
				},
				{
					'id' => 'en:milk-proteins',
					'text' => 'maitoproteiini'
				},
				{
					'id' => 'en:chicken-egg',
					'percent' => '1',
					'text' => 'kananmuna'
				}
			],
			'rank' => 2,
			'text' => 'suklaa',
			'vegan' => 'maybe',
			'vegetarian' => 'yes'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:emulsifier',
			'ingredients' => [
				{
					'id' => 'en:e463',
					'text' => 'e463'
				}
			],
			'rank' => 3,
			'text' => 'emulgointiaineet'
		},
		{
			'from_palm_oil' => 'maybe',
			'id' => 'en:e432',
			'rank' => 4,
			'text' => 'e432',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'from_palm_oil' => 'maybe',
			'id' => 'en:e472',
			'rank' => 5,
			'text' => 'e472',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:acidity-regulator',
			'ingredients' => [
				{
					'id' => 'en:e322',
					'text' => 'e322'
				},
				{
					'id' => 'en:e333',
					'text' => 'e333'
				}
			],
			'rank' => 6,
			'text' => "happamuudens\x{e4}\x{e4}t\x{f6}aineet"
		},
		{
			'id' => 'en:e474',
			'rank' => 7,
			'text' => 'e474',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'id' => 'en:e475',
			'rank' => 8,
			'text' => 'e475',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:acid',
			'ingredients' => [
				{
					'id' => 'en:e330',
					'text' => 'sitruunahappo'
				},
				{
					'id' => 'en:e338',
					'text' => 'fosforihappo'
				}
			],
			'rank' => 9,
			'text' => 'happo'
		},
		{
			'id' => 'en:salt',
			'rank' => 10,
			'text' => 'suola',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa-butter',
			'percent' => '15',
			'text' => 'kaakaovoi',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sugar',
			'percent' => '10',
			'text' => 'sokeri',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:milk-proteins',
			'text' => 'maitoproteiini',
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:chicken-egg',
			'percent' => '1',
			'text' => 'kananmuna',
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e463',
			'text' => 'e463',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e322',
			'text' => 'e322',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'id' => 'en:e333',
			'text' => 'e333',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e330',
			'text' => 'sitruunahappo',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e338',
			'text' => 'fosforihappo',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
	'ingredients_analysis_tags' => [
		'en:may-contain-palm-oil',
		'en:non-vegan',
		'en:maybe-vegetarian'
	],
	'ingredients_hierarchy' => [
		'en:flour',
		'en:chocolate',
		'en:emulsifier',
		'en:e432',
		'en:e472',
		'en:acidity-regulator',
		'en:e474',
		'en:e475',
		'en:acid',
		'en:salt',
		'en:cocoa-butter',
		'en:cocoa',
		'en:sugar',
		'en:milk-proteins',
		'en:protein',
		'en:animal-protein',
		'en:chicken-egg',
		'en:egg',
		'en:e463',
		'en:e322',
		'en:e333',
		'en:e330',
		'en:e338'
	],
	'ingredients_n' => 19,
	'ingredients_n_tags' => [
		'19',
		'11-20'
	],
	'ingredients_original_tags' => [
		'en:flour',
		'en:chocolate',
		'en:emulsifier',
		'en:e432',
		'en:e472',
		'en:acidity-regulator',
		'en:e474',
		'en:e475',
		'en:acid',
		'en:salt',
		'en:cocoa-butter',
		'en:sugar',
		'en:milk-proteins',
		'en:chicken-egg',
		'en:e463',
		'en:e322',
		'en:e333',
		'en:e330',
		'en:e338'
	],
	'ingredients_tags' => [
		'en:flour',
		'en:chocolate',
		'en:emulsifier',
		'en:e432',
		'en:e472',
		'en:acidity-regulator',
		'en:e474',
		'en:e475',
		'en:acid',
		'en:salt',
		'en:cocoa-butter',
		'en:cocoa',
		'en:sugar',
		'en:milk-proteins',
		'en:protein',
		'en:animal-protein',
		'en:chicken-egg',
		'en:egg',
		'en:e463',
		'en:e322',
		'en:e333',
		'en:e330',
		'en:e338'
	],
	'ingredients_text' => "jauho (12%), suklaa (kaakaovoi (15%), sokeri [10%], maitoproteiini, kananmuna 1%) - emulgointiaineet : E463, E432 ja E472 - happamuudens\x{e4}\x{e4}t\x{f6}aineet : E322/E333 E474-E475, happo (sitruunahappo, fosforihappo) - suola",
	'lc' => 'fi',
	'known_ingredients_n' => 23,
	'unknown_ingredients_n' => 0
};

delete $product_ref->{nutriments};
is_deeply($product_ref, $expected_product_ref) or diag explain($product_ref);


$product_ref = {
	lc => "fi",
	ingredients_text => "hyytelöimisaine (pektiinit)",
};

extract_ingredients_from_text($product_ref);

is_deeply (
	$product_ref->{ingredients_original_tags},
	[
		"en:gelling-agent",
		"en:e440a",
	]
) or diag explain $product_ref;


$product_ref = {
	lc => "fi",
	ingredients_text => "Mansikka 12,3% ; Appelsiini 6.5%, Omena (3,5%)",
};

extract_ingredients_from_text($product_ref);

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'id' => 'en:strawberry',
			'percent' => '12.3',
			'rank' => 1,
			'text' => 'Mansikka',
			'vegan' => 'yes',
			'vegetarian' => 'yes',
		},
		{
			'id' => 'en:orange',
			'percent' => '6.5',
			'rank' => 2,
			'text' => 'Appelsiini',
			'vegan' => 'yes',
			'vegetarian' => 'yes',
		},
		{
			'id' => 'en:apple',
			'percent' => '3.5',
			'rank' => 3,
			'text' => 'Omena',
			'vegan' => 'yes',
			'vegetarian' => 'yes',
		}
	]
) or diag explain $product_ref;


$product_ref = {
	lc => "fi",
	ingredients_text => "Mansikka alkuperä Suomi, Mustaherukka (alkuperä Etelä-Afrikka), Vadelma (alkuperä : Ruotsi), Appelsiini (luomu), kaakao ja kaakaovoi (reilu kauppa)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply ($product_ref->{ingredients},
	[
		{
			'id' => 'en:strawberry',
			'origin' => 'en:finland',
			'rank' => 1,
			'text' => 'Mansikka',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:blackcurrant',
			'origin' => 'en:south-africa',
			'rank' => 2,
			'text' => 'Mustaherukka',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:raspberry',
			'origin' => 'en:sweden',
			'rank' => 3,
			'text' => 'Vadelma',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:orange',
			'labels' => 'en:organic',
			'rank' => 4,
			'text' => 'Appelsiini',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa',
			'labels' => 'en:fair-trade',
			'rank' => 5,
			'text' => 'kaakao',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:cocoa-butter',
			'labels' => 'en:fair-trade',
			'rank' => 6,
			'text' => 'kaakaovoi',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fi",
	ingredients_text => "emulgointiaine : auringonkukkalesitiini, aromi)(EU), vehnäjauho 33% (Ranska), sokeri",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply (
	$product_ref->{ingredients},
	[
		{
		'has_sub_ingredients' => 'yes',
		'id' => 'en:emulsifier',
		'ingredients' => [
			{
				'id' => 'en:sunflower-lecithin',
				'text' => 'auringonkukkalesitiini'
			}
		],
		'rank' => 1,
		'text' => 'emulgointiaine'
		},
		{
			'id' => 'en:flavouring',
			'origin' => 'en:european-union',
			'rank' => 2,
			'text' => 'aromi',
			'vegan' => 'maybe',
			'vegetarian' => 'maybe'
		},
		{
			'id' => 'en:wheat-flour',
			'origin' => 'en:france',
			'percent' => '33',
			'rank' => 3,
			'text' => "vehn\x{e4}jauho",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sugar',
			'rank' => 4,
			'text' => 'sokeri',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:sunflower-lecithin',
			'text' => 'auringonkukkalesitiini',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fi",
	ingredients_text => "appelsiinimehu (säilöntäaineeton), lohi (msc), gluteeniton",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};


is ($product_ref->{labels}, "en:gluten-free") or diag explain $product_ref;
is_deeply ($product_ref->{labels_tags}, ["en:gluten-free"]) or diag explain $product_ref;

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'id' => 'en:orange-juice',
			'labels' => 'en:no-preservatives',
			'rank' => 1,
			'text' => 'appelsiinimehu',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:salmon',
			'labels' => 'en:sustainable-seafood-msc',
			'rank' => 2,
			'text' => 'lohi',
			'vegan' => 'no',
			'vegetarian' => 'no'
		}
	],
) or diag explain $product_ref;


# bug #3432 - mm. should not match Myanmar
$product_ref = {
	lc => "fi",
	ingredients_text => "mausteet (mm. kurkuma, inkivääri, paprika, valkosipuli, korianteri, sinapinsiemen)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is_deeply (
	$product_ref->{ingredients},
	[
		{
			'has_sub_ingredients' => 'yes',
			'id' => 'en:spice',
			'ingredients' => [
				{
					'id' => 'en:e100',
					'text' => 'muun muassa kurkuma'
				},
				{
					'id' => 'en:ginger',
					'text' => "inkiv\x{e4}\x{e4}ri"
				},
				{
					'id' => 'en:bell-pepper',
					'text' => 'paprika'
				},
				{
					'id' => 'en:garlic',
					'text' => 'valkosipuli'
				},
				{
					'id' => 'en:coriander',
					'text' => 'korianteri'
				},
				{
					'id' => 'en:mustard-seed',
					'text' => 'sinapinsiemen'
				}
			],
			'rank' => 1,
			'text' => 'mausteet',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:e100',
			'text' => 'muun muassa kurkuma',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:ginger',
			'text' => "inkiv\x{e4}\x{e4}ri",
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:bell-pepper',
			'text' => 'paprika',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:garlic',
			'text' => 'valkosipuli',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:coriander',
			'text' => 'korianteri',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		},
		{
			'id' => 'en:mustard-seed',
			'text' => 'sinapinsiemen',
			'vegan' => 'yes',
			'vegetarian' => 'yes'
		}
	],
) or diag explain $product_ref;


# FI - organic label as part of the ingredient

$product_ref = {
	lc => "fi",
	ingredients_text => "vihreä luomutee, luomumaito, luomu ohramallas",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};

is ($product_ref->{labels}, undef) or diag explain $product_ref->{labels};
is_deeply ($product_ref->{labels_tags}, undef) or diag explain $product_ref->{labels_tags};

is_deeply(
	$product_ref->{ingredients},
	[
		{	'id'         => 'en:green-tea',
			'labels'     => 'en:organic',
			'rank'       => 1,
			'text'       => "vihre\x{e4} tee",
			'vegan'      => 'yes',
			'vegetarian' => 'yes'
		},
		{	'id'         => 'en:milk',
			'labels'     => 'en:organic',
			'rank'       => 2,
			'text'       => 'maito',
			'vegan'      => 'no',
			'vegetarian' => 'yes'
		},
		{	'id'         => 'en:malted-barley',
			'labels'     => 'en:organic',
			'rank'       => 3,
			'text'       => 'ohramallas',
			'vegan'      => 'yes',
			'vegetarian' => 'yes'
		}
	],
) or diag explain $product_ref;


$product_ref = {
	lc => "fr",
	ingredients_text => "oeufs (d'élevage au sol, Suisse, France)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};


is ($product_ref->{labels}, undef) or diag explain $product_ref->{labels};
is_deeply ($product_ref->{labels_tags}, undef) or diag explain $product_ref->{labels_tags};

is_deeply (
	$product_ref->{ingredients},

	[
		{
		'has_sub_ingredients' => 'yes',
		'id' => 'en:egg',
		'ingredients' => [
			{
				'id' => "fr:d'\x{e9}levage au sol",
				'text' => "d'\x{e9}levage au sol"
			},
			{
				'id' => 'fr:Suisse',
				'text' => 'Suisse'
			},
			{
				'id' => 'fr:France',
				'text' => 'France'
			}
		],
			'rank' => 1,
			'text' => 'oeufs',
			'vegan' => 'no',
			'vegetarian' => 'yes'
		},
		{
			'id' => "fr:d'\x{e9}levage au sol",
			'text' => "d'\x{e9}levage au sol"
		},
		{
			'id' => 'fr:Suisse',
			'text' => 'Suisse'
		},
		{
			'id' => 'fr:France',
			'text' => 'France'
		}
	],

) or diag explain $product_ref;


# Do not mistake single letters for labels, bug #3300

$product_ref = {
	lc => "fr",
	ingredients_text => "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,0,1,2,3,4,5,6,7,8,9,10,100,1000,vt,leaf,something(bio),somethingelse(u)",
};

extract_ingredients_from_text($product_ref);

delete_ingredients_percent_values($product_ref->{ingredients});
delete $product_ref->{ingredients_percent_analysis};


is ($product_ref->{labels}, undef) or diag explain $product_ref->{labels};
is_deeply ($product_ref->{labels_tags}, undef) or diag explain $product_ref->{labels_tags};


done_testing();
