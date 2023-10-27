#!/usr/bin/perl -w

# Tests of detecting food-processing terms from taxonomies/ingredients_processing.txt

use Modern::Perl '2017';
use utf8;

use Test::More;

my $builder = Test::More->builder;
binmode $builder->output, ":encoding(utf8)";
binmode $builder->failure_output, ":encoding(utf8)";
binmode $builder->todo_output, ":encoding(utf8)";

#use Log::Any::Adapter 'TAP';
use Log::Any::Adapter 'TAP', filter => 'trace';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my @tests = (
##################################################################
	#
	#                           E N G L I S H ( E N  )
	#
##################################################################

	[
		{
			lc => "en",
			ingredients_text => "raw milk, sliced tomatoes, garlic powder, powdered eggplant,
				courgette powder, sieved ham"
		},
		[
			{
				'id' => 'en:raw-milk',
				'text' => 'raw milk'
			},
			{
				'id' => 'en:tomato',
				'processing' => 'en:sliced',
				'text' => 'tomatoes'
			},
			{
				'id' => 'en:garlic',
				'processing' => 'en:powder',
				'text' => 'garlic'
			},
			{
				'id' => 'en:aubergine',
				'processing' => 'en:powder',
				'text' => 'eggplant'
			},
			{
				'id' => 'en:courgette',
				'processing' => 'en:powder',
				'text' => 'courgette'
			},
			{
				'id' => 'en:ham',
				'processing' => 'en:sieved',
				'text' => 'ham'
			}
		]
	],

	# en:dried (children are left out at the moment) What does this mean????
	[
		{lc => "en", ingredients_text => "dried milk"},
		[
			{
				'id' => 'en:milk',
				'processing' => 'en:dried',
				'text' => 'milk'
			}
		]
	],

	# en: smoked (children are left out at the moment)
	[
		{lc => "en", ingredients_text => "smoked milk, not smoked tomatoes"},
		[
			{
				'id' => 'en:milk',
				'processing' => 'en:smoked',
				'text' => 'milk'
			},
			{
				'id' => 'en:tomato',
				'processing' => 'en:not-smoked',
				'text' => 'tomatoes'
			}
		]
	],

	# en: smoked (children are lef out at the moment)
	[
		{
			lc => "en",
			ingredients_text => "sweetened milk, unsweetened tomatoes, sugared ham"
		},
		[
			{
				'id' => 'en:milk',
				'processing' => 'en:sweetened',
				'text' => 'milk'
			},
			{
				'id' => 'en:tomato',
				'processing' => 'en:unsweetened',
				'text' => 'tomatoes'
			},
			{
				'id' => 'en:ham',
				'processing' => 'en:sugared',
				'text' => 'ham'
			}
		]
	],

	# en: halved
	[
		{lc => "en", ingredients_text => "halved milk, tomatoes halves"},
		[
			{
				'id' => 'en:milk',
				'processing' => 'en:halved',
				'text' => 'milk'
			},
			{
				'id' => 'en:tomato',
				'processing' => 'en:halved',
				'text' => 'tomatoes'
			}
		]
	],

	# en:hydrated etc.
	[
		{
			lc => "en",
			ingredients_text =>
				"partially rehydrated egg white, hydrated silica, dehydrated cane juice, hydrated chia seeds, rehydrated tomatoes"
		},
		[
			{
				'id' => 'en:egg-white',
				'processing' => 'en:partially-rehydrated',
				'text' => 'egg white'
			},
			{
				'id' => 'en:e551',
				'processing' => 'en:hydrated',
				'text' => 'silica'
			},
			{
				'id' => 'en:sugarcane-juice',
				'processing' => 'en:dehydrated',
				'text' => 'cane juice'
			},
			{
				'id' => 'en:chia-seed',
				'processing' => 'en:hydrated',
				'text' => 'chia seeds'
			},
			{
				'id' => 'en:tomato',
				'processing' => 'en:rehydrated',
				'text' => 'tomatoes'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "smoked sea salt, smoked turkey"},
		[
			{
				'id' => 'en:sea-salt',
				'processing' => 'en:smoked',
				'text' => 'sea salt'
			},
			{
				'id' => 'en:turkey',
				'processing' => 'en:smoked',
				'text' => 'turkey'
			}
		]
	],

	# ingredient with (processing) in parenthesis
	[
		{lc => "en", ingredients_text => "garlic (powdered)",},
		[
			{
				'id' => 'en:garlic',
				'processing' => 'en:powder',
				'text' => 'garlic'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "pasteurized eggs"},
		[
			{
				'id' => 'en:egg',
				'processing' => 'en:pasteurised',
				'text' => 'eggs'
			}
		]
	],

	[
		{lc => "en", ingredients_text => "dry whey"},
		[
			{
				'id' => 'en:whey',
				'processing' => 'en:dried',
				'text' => 'whey'
			}
		]
	],
##################################################################
	#
	#                           S P A N I S H   ( E S )
	#
##################################################################

	[
		{
			lc => "es",
			ingredients_text => "tomate endulzado, berenjena endulzada, calabacín endulzados, jamón endulzadas"
		},
		[
			{
				'id' => 'en:tomato',
				'processing' => 'en:sweetened',
				'text' => 'tomate'
			},
			{
				'id' => 'en:aubergine',
				'processing' => 'en:sweetened',
				'text' => 'berenjena'
			},
			{
				'id' => 'en:courgette',
				'processing' => 'en:sweetened',
				'text' => 'calabacín'
			},
			{
				'id' => 'en:ham',
				'processing' => 'en:sweetened',
				'text' => 'jamón'
			}
		]
	],

	[
		{lc => "es", ingredients_text => "pimientos amarillos deshidratados"},
		[
			{
				'id' => 'en:yellow-bell-pepper',
				'processing' => 'en:dehydrated',
				'text' => 'pimientos amarillos'
			}
		]
	],

	[
		{lc => "es", ingredients_text => "tofu ahumado, panceta ahumada"},
		[
			{
				'id' => 'en:tofu',
				'processing' => 'en:smoked',
				'text' => 'tofu'
			},
			{
				'id' => 'en:bacon',
				'processing' => 'en:smoked',
				'text' => 'panceta'
			}
		]
	],

	[
		{lc => "es", ingredients_text => "pimientos amarillos deshidratados"},
		[
			{
				'id' => 'en:yellow-bell-pepper',
				'processing' => 'en:dehydrated',
				'text' => 'pimientos amarillos'
			}
		]
	],

##################################################################
	#
	#                           F R E N C H ( F R )
	#
##################################################################

	[
		{
			lc => "fr",
			ingredients_text => "dés de jambon frits, tomates crues en dés,
				tomates bio pré-cuites, poudre de noisettes, banane tamisé"
		},
		[
			{
				'id' => 'en:ham',
				'processing' => 'en:diced,en:fried',
				'text' => 'jambon'
			},
			{
				'id' => 'en:tomato',
				'processing' => 'en:diced,en:raw',
				'text' => 'tomates'
			},
			{
				'id' => 'en:tomato',
				'labels' => 'en:organic',
				'processing' => 'en:pre-cooked',
				'text' => 'tomates'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:powder',
				'text' => 'noisettes'
			},
			{
				'id' => 'en:banana',
				'processing' => 'en:sieved',
				'text' => 'banane'
			}
		]
	],

	[
		{lc => "fr", ingredients_text => "banane coupée et cuite au naturel"},
		[
			{
				'id' => 'en:banana',
				'processing' => 'en:cooked,en:cut',
				'text' => 'banane'
			}
		]
	],

	[
		{lc => "fr", ingredients_text => "banane coupée et cuite au naturel"},
		[
			{
				'id' => 'en:banana',
				'processing' => 'en:cooked,en:cut',
				'text' => 'banane'
			}
		]
	],

	[
		{
			lc => "fr",
			ingredients_text =>
				"crème fraîche pasteurisée, bananes fraiches, fromage frais, crème (dont lait) fraîche, ananas (frais), pâtes fraîches cuites, SUCRE BLOND DE CANNE NON RAFFINE"
		},
		[
			{
				'id' => 'en:pasteurized-creme-fraiche',
				'text' => "cr\x{e8}me fra\x{ee}che pasteuris\x{e9}e"
			},
			{
				'id' => 'en:banana',
				'processing' => 'en:fresh',
				'text' => 'bananes'
			},
			{
				'id' => 'en:soft-white-cheese',
				'text' => 'fromage frais'
			},
			{
				'id' => 'en:cream',
				'ingredients' => [
					{
						'id' => 'en:milk',
						'text' => 'dont lait'
					}
				],
				'text' => "cr\x{e8}me"
			},
			{
				'id' => "fr:fraiche",
				'text' => "fra\x{ee}che"
			},
			{
				'id' => 'en:pineapple',
				'processing' => 'en:fresh',
				'text' => 'ananas'
			},
			{
				'id' => 'en:cooked-fresh-pasta',
				'text' => "p\x{e2}tes fra\x{ee}ches cuites"
			},
			{
				'id' => 'en:blonde-cane-sugar',
				'processing' => 'en:raw',
				'text' => 'SUCRE BLOND DE CANNE'
			}
		]
	],

	# en:hydrated etc.
	[
		{
			lc => "fr",
			ingredients_text =>
				"tomates séchées partiellement réhydratées, lait écrémé partiellement déshydraté, graines de chia hydratées, haricots blancs semi-hydratés"
		},
		[
			{
				'id' => 'en:tomato',
				'processing' => 'en:partially-rehydrated,en:dried',
				'text' => 'tomates'
			},
			{
				'id' => 'en:skimmed-milk',
				'processing' => 'en:partially-dehydrated',
				'text' => "lait \x{e9}cr\x{e9}m\x{e9}"
			},
			{
				'id' => 'en:chia-seed',
				'processing' => 'en:hydrated',
				'text' => 'graines de chia'
			},
			{
				'id' => 'en:white-beans',
				'processing' => 'en:partially-hydrated',
				'text' => 'haricots blancs'
			}
		]
	],

	[
		{
			lc => "fr",
			ingredients_text => "sel marin fumé, jambon fumé, arôme de fumée, lardons fumés au bois de hêtre "
		},
		[
			{
				'id' => 'en:sea-salt',
				'processing' => 'en:smoked',
				'text' => 'sel marin'
			},
			{
				'id' => 'en:ham',
				'processing' => 'en:smoked',
				'text' => 'jambon'
			},
			{
				'id' => 'en:smoke-flavouring',
				'text' => "ar\x{f4}me de fum\x{e9}e"
			},
			{
				'id' => 'en:lardon',
				'processing' => 'en:beech-smoked',
				'text' => 'lardons'
			}
		]
	],

	[
		{lc => "fr", ingredients_text => "piment (en poudre)"},
		[
			{
				'id' => 'en:chili-pepper',
				'processing' => 'en:powder',
				'text' => 'piment'
			}
		]
	],

	# test for jus and concentré with extra "de"
	#	[ { lc => "fr", ingredients_text => "jus concentré de baies de sureau"},
	#		[
	#		]
	#	],

##################################################################
	#
	#                           F I N N I SH ( F I )
	#
##################################################################
	[
		{
			lc => "fi",
			ingredients_text => "kuivattu banaani"
		},
		[
			{
				'id' => 'en:banana',
				'processing' => 'en:dried',
				'text' => 'banaani'
			}
		]
	],
	[
		{
			lc => "fi",
			ingredients_text => "raakamaito, mustikkajauhe, jauhettu vaniljatanko"
		},
		[
			{
				'id' => 'en:raw-milk',
				'text' => 'raakamaito'
			},
			{
				'id' => 'en:bilberry',
				'processing' => 'en:powder',
				'text' => 'mustikka'
			},
			{
				'id' => 'en:vanilla-pod',
				'processing' => 'en:ground',
				'text' => 'vaniljatanko'
			}
		]
	],

##################################################################
	#
	#                           D U T C H ( N L )
	#
##################################################################

	[
		{
			lc => "nl",
			ingredients_text => "uipoeder"
		},
		[
			{
				'id' => 'en:onion',
				'processing' => 'en:powder',
				'text' => 'ui'
			}
		]
	],
	[
		{
			lc => "nl",
			ingredients_text =>
				"sjalotpoeder, wei-poeder, vanillepoeder, gemalen sjalot, geraspte sjalot, gepelde goudsbloem"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:powder',
				'text' => 'sjalot'
			},
			{
				'id' => 'en:whey-powder',
				'text' => 'wei-poeder'
			},
			{
				'id' => 'en:vanilla-powder',
				'text' => 'vanillepoeder'
			},
			{
				'id' => 'en:shallot',
				'processing' => 'en:ground',
				'text' => 'sjalot'
			},
			{
				'id' => 'en:shallot',
				'processing' => 'en:grated',
				'text' => 'sjalot'
			},
			{
				'id' => 'en:marigold',
				'processing' => 'en:peeled',
				'text' => 'goudsbloem'
			}
		]
	],

##################################################################
	#
	#                           G E R M A N ( D E )
	#
##################################################################

	# de:pulver and variants
	[
		{
			lc => "de",
			ingredients_text => "bourbon-vanillepulver, Sauerkrautpulver, acerola-pulver"
		},
		[
			{
				'id' => 'en:bourbon-vanilla-powder',
				'text' => 'bourbon-vanillepulver'
			},
			{
				'id' => 'en:sauerkraut',
				'processing' => 'en:powder',
				'text' => 'Sauerkraut'
			},
			{
				'id' => 'en:acerola',
				'processing' => 'en:powder',
				'text' => 'acerola'
			}
		]
	],

	# de:gehackt and variants
	[
		{
			lc => "de",
			ingredients_text => "gehacktes Buttermilch, gehackter Dickmilch"
		},
		[
			{
				'id' => 'en:buttermilk',
				'processing' => 'en:chopped',
				'text' => 'Buttermilch'
			},
			{
				'id' => 'en:soured-milk',
				'processing' => 'en:chopped',
				'text' => 'Dickmilch'
			}
		]
	],

	# de:gehobelt and variants
	[
		{lc => "de", ingredients_text => "gehobelt passionsfrucht"},
		[
			{
				'id' => 'en:passionfruit',
				'processing' => 'en:sliced',
				'text' => 'passionsfrucht'
			}
		]
	],

	# Test for de:püree (and for process placing de:püree without space)
	[
		{lc => "de", ingredients_text => "Schalottepüree"},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:pureed',
				'text' => 'Schalotte'
			}
		]
	],

	# Test for process de:püree placing with space (not really necessary as it has been tested with the other)
	[
		{lc => "de", ingredients_text => "Schalotte püree"},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:pureed',
				'text' => 'Schalotte'
			}
		]
	],

	# de:gegart and variants
	[
		{
			lc => "de",
			ingredients_text => "Schalotte gegart, gegarte haselnüsse, gegarter mandeln, gegartes passionsfrucht,
				sellerie dampfgegart, dampfgegarte acerola, dampfgegarter spinat"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:gegart',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:gegart',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'de:gegart',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'de:gegart',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:celery',
				'processing' => 'de:dampfgegart',
				'text' => 'sellerie'
			},
			{
				'id' => 'en:acerola',
				'processing' => 'de:dampfgegart',
				'text' => 'acerola'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'de:dampfgegart',
				'text' => 'spinat'
			}
		]
	],

	# Test for en:oiled
	[
		{
			lc => "de",
			ingredients_text => "Schalotte geölt, geölte haselnüsse"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => "en:oiled",
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => "en:oiled",
				'text' => "haselnüsse"
			}
		]
	],

	# de:gepökelt and variants
	[
		{
			lc => "de",
			ingredients_text => "Schalotte gepökelt, gepökeltes haselnüsse,
				passionsfrucht ungepökelt"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:brined',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:brined',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'de:ungepökelt',
				'text' => 'passionsfrucht'
			}
		]
	],

	# de:gepoppt and variants
	[
		{
			lc => "de",
			ingredients_text => "Schalotte gepoppt, gepuffte haselnüsse,
				passionsfrucht gepufft, gepuffter passionsfrucht, gepufftes sellerie"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:puffed',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:puffed',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'en:puffed',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'en:puffed',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:celery',
				'processing' => 'en:puffed',
				'text' => 'sellerie'
			}
		]
	],

	# de:geschält and variants
	[
		{
			lc => "de",
			ingredients_text => "Schalotte geschält, geschälte haselnüsse, geschälter mandeln,
				passionsfrucht ungeschält, ungeschälte sellerie"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:geschält',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:geschält',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:almond',
				'processing' => "de:geschält",
				'text' => 'mandeln'
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'de:ungeschält',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:celery',
				'processing' => 'de:ungeschält',
				'text' => 'sellerie'
			}
		]
	],

	# de:geschwefelt and variants
	[
		{
			lc => "de",
			ingredients_text => "Schalotte geschwefelt, geschwefelte haselnüsse,
				passionsfrucht ungeschwefelt, geschwefelte sellerie"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:geschwefelt',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:geschwefelt',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'de:ungeschwefelt',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:celery',
				'processing' => 'de:geschwefelt',
				'text' => 'sellerie'
			}
		]
	],

	#  de:gesüßt
	[
		{
			lc => "de",
			ingredients_text => "Schalotte gesüßt, gesüßte haselnüsse"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:sweetened',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:sweetened',
				'text' => "haselnüsse"
			}
		]
	],

	# de:gezuckert and variants
	[
		{
			lc => "de",
			ingredients_text =>
				"Schalotte gezuckert, gezuckerte haselnüsse, mandeln leicht gezuckert, passionsfrucht ungezuckert"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:sugared',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:sugared',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:almond',
				'processing' => "de:leicht-gezuckert",
				'text' => 'mandeln'
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'de:ungezuckert',
				'text' => 'passionsfrucht'
			}
		]
	],

	# de:halbiert and variants
	[
		{
			lc => "de",
			ingredients_text => "Schalotte halbiert, halbierte haselnüsse, halbe mandeln"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:halved',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:halved',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:halved',
				'text' => 'mandeln'
			}
		]
	],

	# de:konzentriert (and children) and synonyms
	[
		{
			lc => "de",
			ingredients_text =>
				"konzentriert schalotte, konzentrierter haselnüsse, konzentrierte mandeln, konzentriertes acerolakirschen,
				zweifach konzentriert, 2 fach konzentriert, doppelt konzentriertes, zweifach konzentriertes, 2-fach konzentriert, dreifach konzentriert,
				200fach konzentriertes, eingekochter"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:concentrated',
				'text' => 'schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:concentrated',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:concentrated',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:acerola',
				'processing' => 'en:concentrated',
				'text' => 'acerolakirschen'
			},
			{
				'id' => 'de:zweifach-konzentriert',
				'text' => 'zweifach konzentriert'
			},
			{
				'id' => 'de:2-fach-konzentriert',
				'text' => '2 fach konzentriert'
			},
			{
				'id' => 'de:doppelt-konzentriertes',
				'text' => 'doppelt konzentriertes'
			},
			{
				'id' => 'de:zweifach-konzentriertes',
				'text' => 'zweifach konzentriertes'
			},
			{
				'id' => 'de:2-fach-konzentriert',
				'text' => '2-fach konzentriert'
			},
			{
				'id' => 'de:dreifach-konzentriert',
				'text' => 'dreifach konzentriert'
			},
			{
				'id' => 'de:200fach-konzentriertes',
				'text' => '200fach konzentriertes'
			},
			{
				'id' => 'de:eingekochter',
				'text' => 'eingekochter'
			}
		]
	],

	# de:zerkleinert and variants
	[
		{
			lc => "de",
			ingredients_text =>
				"Schalotte zerkleinert, zerkleinerte haselnüsse, zerkleinerter mandeln, zerkleinertes passionsfrucht,
				sellerie grob zerkleinert,
				acerolakirschen fein zerkleinert, fein zerkleinerte spinat,
				zwiebel zum teil fein zerkleinert,
				haselnüsse feinst zerkleinert,
				überwiegend feinst zerkleinert Feigen"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:zerkleinert',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:zerkleinert',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'de:zerkleinert',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:passionfruit',
				'processing' => 'de:zerkleinert',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:celery',
				'processing' => 'de:grob-zerkleinert',
				'text' => 'sellerie'
			},
			{
				'id' => 'en:acerola',
				'processing' => 'de:fein-zerkleinert',
				'text' => 'acerolakirschen'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'de:fein-zerkleinert',
				'text' => 'spinat'
			},
			{
				'id' => 'en:onion',
				'processing' => 'de:zum-teil-fein-zerkleinert',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:feinst-zerkleinert',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:fig',
				'processing' => "de:\x{fc}berwiegend-feinst-zerkleinert",
				'text' => 'Feigen'
			}
		]
	],

	# combinations
	[
		{
			lc => "de",
			ingredients_text => "haselnüsse gehackt und geröstet,
				gehackte und geröstete haselnuss, gehobelte und gehackte mandeln"
		},
		[
			# change on 17:01
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:toasted,en:chopped',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:chopped,en:toasted',
				'text' => "haselnuss"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:sliced,en:chopped',
				'text' => 'mandeln'
			}
		]
	],

	# Test for de:gemahlen and synonyms
	[
		{
			lc => "de",
			ingredients_text => "Schalotte gemahlen, gemahlene mandeln, gemahlener zwiebel,
				fein gemahlen haselnüsse, grob gemahlen spinat, frischgemahlen sellerie"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:ground',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:ground',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:ground',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:fein-gemahlen',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:spinach',
				'processing' => 'en:coarsely-ground',
				'text' => 'spinat'
			},
			{
				'id' => 'en:celery',
				'processing' => 'de:frischgemahlen',
				'text' => 'sellerie'
			}
		]
	],

	# Test for de:getrocknet and synonyms
	[
		{
			lc => "de",
			ingredients_text => "Schalotte getrocknet, getrocknete mandeln, getrockneter zwiebel,
				 haselnüsse in getrockneter form, halbgetrocknete spinat, halbgetrocknet sellerie, Feigen halb getrocknet,
				 Holunder gefriergetrocknet, gefriergetrocknete Papaya, gefriergetrocknetes Kiwi, sonnengetrocknet Ananas,
				 sonnengetrocknete Pflaumen, an der Sonne getrocknete Grapefruit, Guaven luftgetrocknet, luftgetrockneter Hagebutten,
				 Traube sprühgetrocknet, sprühgetrockneter Tamarinde"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:dried',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:dried',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:dried',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:dried',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:spinach',
				'processing' => 'en:semi-dried',
				'text' => 'spinat'
			},
			{
				'id' => 'en:celery',
				'processing' => 'en:semi-dried',
				'text' => 'sellerie'
			},
			{
				'id' => 'en:fig',
				'processing' => 'en:semi-dried',
				'text' => 'Feigen'
			},
			{
				'id' => 'en:elder',
				'processing' => 'en:freeze-dried',
				'text' => 'Holunder'
			},
			{
				'id' => 'en:papaya',
				'processing' => 'en:freeze-dried',
				'text' => 'Papaya'
			},
			{
				'id' => 'en:kiwi',
				'processing' => 'en:freeze-dried',
				'text' => 'Kiwi'
			},
			{
				'id' => 'en:pineapple',
				'processing' => 'en:sundried',
				'text' => 'Ananas'
			},
			{
				'id' => 'en:plum',
				'processing' => 'en:sundried',
				'text' => 'Pflaumen'
			},
			{
				'id' => 'en:grapefruit',
				'processing' => 'en:sundried',
				'text' => 'Grapefruit'
			},
			{
				'id' => 'en:guava',
				'processing' => 'en:air-dried',
				'text' => 'Guaven'
			},
			{
				'id' => 'en:rose-hip',
				'processing' => 'en:air-dried',
				'text' => 'Hagebutten'
			},
			{
				'id' => 'en:grape',
				'processing' => "en:spray-dried",
				'text' => 'Traube'
			},
			{
				'id' => 'en:tamarind',
				'processing' => "en:spray-dried",
				'text' => 'Tamarinde'
			}
		]
	],

	# Test for de:passiert
	[
		{lc => "de", ingredients_text => "Schalotte passiert"},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:sieved',
				'text' => 'Schalotte'
			}
		]
	],

	# Test for de:ungesalzen
	[
		{
			lc => "de",
			ingredients_text => "hartkäse gesalzen, haselnüsse gesalzene, haselnüsse gesalzenes,
				gesalzener haselnuss, ungesalzen schalotte, ungesalzene mandeln"
		},
		[
			{
				'id' => "en:hard-cheese",
				'processing' => 'en:salted',
				'text' => "hartk\x{e4}se"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:salted',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:salted',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:salted',
				'text' => 'haselnuss'
			},
			{
				'id' => 'en:shallot',
				'processing' => 'en:unsalted',
				'text' => 'schalotte'
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:unsalted',
				'text' => 'mandeln'
			}
		]
	],

	# Test for process de:entsteint
	[
		{lc => "de", ingredients_text => "Schalotte entsteint"},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:pitted',
				'text' => 'Schalotte'
			}
		]
	],

	# Test for process de:eingelegt
	[
		{lc => "de", ingredients_text => "Schalotte eingelegt"},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:pickled',
				'text' => 'Schalotte'
			}
		]
	],

	# Test for de: ingredients, that should NOT be detected through processing
	[
		{lc => "de", ingredients_text => "Markerbsen, Deutsche Markenbutter"},
		[
			{
				'id' => 'en:garden-peas',
				'text' => 'Markerbsen'
			},
			{
				'id' => 'de:deutsche-markenbutter',
				'text' => 'Deutsche Markenbutter'
			}
		]
	],

	# Various tests
	[
		{lc => "de", ingredients_text => "haselnüsse gehackt und geröstet"},
		[
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:toasted,en:chopped',
				'text' => "haselnüsse"
			}
		]
	],

	# Various tests
	#[ { lc => "de", ingredients_text => "gehackte und geröstete haselnüs" },
	#	[
	#		{
	#			'id' => 'en:hazelnut',
	#			'processing' => 'en:toasted, en:chopped',
	#			'text' => "gehackte und geröstete haselnüs"
	#		}
	#	]
	#],

	# Various tests
	[
		{
			lc => "de",
			ingredients_text => "hartkäse gehobelt, haselnüsse gehackt,
			, gehobelte und gehackte mandeln, Dickmilch in scheiben geschnitten"
		},
		[
			{
				'id' => "en:hard-cheese",
				'processing' => 'en:sliced',
				'text' => "hartkäse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:chopped',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:sliced,en:chopped',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:soured-milk',
				'processing' => 'en:sliced',
				'text' => 'Dickmilch'
			}
		]
	],

	# All variants of de:rehydriert
	[
		{
			lc => "de",
			ingredients_text => "Schalotte rehydriert, zwiebel rehydrierte, spinat rehydriertes"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:rehydrated',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:rehydrated',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'en:rehydrated',
				'text' => 'spinat'
			}
		]
	],

	# All variants of de:mariniert
	[
		{
			lc => "de",
			ingredients_text => "Schalotte mariniert, zwiebel marinierte, spinat marinierter,
			mariniertes sellerie"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:marinated',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:marinated',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'en:marinated',
				'text' => 'spinat'
			},
			{
				'id' => 'en:celery',
				'processing' => 'en:marinated',
				'text' => 'sellerie'
			}
		]
	],

	# All variants of de:geschnitten
	[
		{
			lc => "de",
			ingredients_text => "Schalotte geschnitten, zwiebel mittelfein geschnittenen, spinat feingeschnitten,
				fein geschnittenen sellerie, feingeschnittener Mandeln, handgeschnittene haselnüsse"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:cut',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:onion',
				'processing' => 'de:mittelfein-geschnittenen',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'de:feingeschnitten',
				'text' => 'spinat'
			},
			{
				'id' => 'en:celery',
				'processing' => 'de:feingeschnitten',
				'text' => 'sellerie'
			},
			{
				'id' => 'en:almond',
				'processing' => 'de:feingeschnitten',
				'text' => 'Mandeln'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:handgeschnitten',
				'text' => "haselnüsse"
			}
		]
	],

	[
		{
			lc => "de",
			ingredients_text => "Schalottepüree, zwiebel püree, spinat-püree, selleriemark"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:pureed',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:pureed',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'en:pureed',
				'text' => 'spinat'
			},
			{
				'id' => 'en:celery',
				'processing' => 'en:pulp',
				'text' => 'sellerie'
			}
		]
	],

	# de:gerieben and synonyms tests
	[
		{
			lc => "de",
			ingredients_text => "Schalotte gerieben, geriebener zwiebel, geriebene spinat"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:grated',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:grated',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'en:grated',
				'text' => 'spinat'
			}
		]
	],

	# de würfel and synonyms tests
	[
		{
			lc => "de",
			ingredients_text => "Schalottewürfel, spinat gewürfelt, gewürfelte sellerie,
				zwiebel in würfel geschnitten, mandeln in würfel"
		},
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:diced',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:spinach',
				'processing' => 'en:diced',
				'text' => 'spinat'
			},
			{
				'id' => 'en:celery',
				'processing' => 'en:diced',
				'text' => 'sellerie'
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:diced',
				'text' => 'zwiebel'
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:diced',
				'text' => 'mandeln'
			}
		]
	],

##################################################################
	#
	#                           C R O A T I A N ( H R )
	#
##################################################################

	# inspired by 3858881083103
	[
		{lc => "hr", ingredients_text => "papar crni mljeveni"},
		[
			{
				'id' => 'en:black-pepper',
				'processing' => 'en:ground',
				'text' => 'papar crni'
			}
		]
	],
	# inspired by 8017596108852
	[
		{
			lc => "hr",
			ingredients_text =>
				"dehidrirani umak, suncokretovo ulje u prahu, dimljeni slanina, antioksidans (ekstrakt ružmarina)"
		},
		[
			{
				'id' => 'en:sauce',
				'processing' => 'en:dehydrated',
				'text' => 'umak'
			},
			{
				'id' => 'en:sunflower-oil',
				'processing' => 'en:powder',
				'text' => 'suncokretovo ulje'
			},
			{
				'id' => 'en:bacon',
				'processing' => 'en:smoked',
				'text' => 'slanina'
			},
			{
				'id' => 'en:antioxidant',
				'text' => 'antioksidans',
				'ingredients' => [
					{
						'id' => "en:rosemary",
						'processing' => "en:extract",
						'text' => "ru\x{17e}marina"
					}
				],
			},
		]
	],

##################################################################
	#
	#                           POLISH ( PL )
	#
##################################################################

	[
		{
			lc => "pl",
			ingredients_text => "liofilizowane ananasy"
		},
		[
			{
				'id' => 'en:pineapple',
				'processing' => 'en:freeze-dried',
				'text' => 'ananasy'
			}
		]
	],

	# (200 g per 100g of product) etc.
	[
		{
			lc => "pl",
			ingredients_text => "koncentrat pomidorowy (126 g pomidorow na 100 g ketchupu),
			pomidory (210 g pomidorów zużyto na 100 g produktu),
			pomidory (100 g na 100 g produktu),
			pomidory (126 g pomidorów na 100g produktu).
			157 g mięsa użyto do wytworzenia 100 g produktu.
			100 g produktu wyprodukowano ze 133 g mięsa wieprzowego.
			Sporządzono z 40 g owoców na 100 g produktu.
			Z 319 g mięsa wieprzowego wyprodukowano 100 g produktu."
		},
		[
			{
				'id' => 'en:tomato-concentrate',
				'text' => 'koncentrat pomidorowy',
				'ingredients' => [],
			},
			{
				'id' => 'en:tomato',
				'text' => 'pomidory',
				'ingredients' => [],
			},
			{
				'id' => 'en:tomato',
				'text' => 'pomidory',
				'ingredients' => [],
			},
			{
				'id' => 'en:tomato',
				'text' => 'pomidory',
				'ingredients' => [],
			},
		]
	],

	# en:dried (with separate entry)
	[
		{
			lc => "pl",
			ingredients_text => "czosnek suszony, suszony czosnek"
		},
		[
			{
				'id' => 'en:dried-garlic',
				'text' => 'czosnek suszony'
			},
			{
				'id' => 'en:dried-garlic',
				'text' => 'suszony czosnek'
			}
		]
	],

	# en:dried (with processing)
	[
		{
			lc => "pl",
			ingredients_text => "suszony koperek, pomidory suszone, grzyby suszone, koper suszony"
		},
		[
			{
				'id' => 'en:dill',
				'processing' => 'en:dried',
				'text' => 'koperek'
			},
			{
				'id' => 'en:tomato',
				'processing' => 'en:dried',
				'text' => 'pomidory'
			},
			{
				'id' => 'en:mushroom',
				'processing' => 'en:dried',
				'text' => 'grzyby'
			},
			{
				'id' => 'en:dill',
				'processing' => 'en:dried',
				'text' => 'koper'
			},
		]
	],

##################################################################
	#
	#                           JAPANESE ( JA )
	#
##################################################################

	[
		{
			lc => "ja",
			ingredients_text =>
				# sliced
				"スライスアーモンド, "
				#powder
				. "酵母エキスパウダー, クリーミングパウダー, "
				#powder
				. "昆布粉末, 粉末醤油, 粉末酒, かつお節粉末, マカ粉末, 粉末しょうゆ, 発酵黒にんにく末, "
				# roasted
				. "ローストバターパウダー, ロースト-麦芽,"
				# fried garlic powder
				. "フライドガーリックパウダー, "
				# pulp
				. "りんごパルプ, "
		},
		[
			{
				'id' => 'en:flaked-almonds',
				'text' => "\x{30b9}\x{30e9}\x{30a4}\x{30b9}\x{30a2}\x{30fc}\x{30e2}\x{30f3}\x{30c9}"
			},
			{
				'id' => 'en:yeast-extract-powder',
				'text' => "\x{9175}\x{6bcd}\x{30a8}\x{30ad}\x{30b9}\x{30d1}\x{30a6}\x{30c0}\x{30fc}"
			},
			{
				'id' => 'en:creaming-powder',
				'text' => "\x{30af}\x{30ea}\x{30fc}\x{30df}\x{30f3}\x{30b0}\x{30d1}\x{30a6}\x{30c0}\x{30fc}"
			},
			{
				'id' => 'en:kombu',
				'processing' => 'en:powder',
				'text' => "\x{6606}\x{5e03}"
			},
			{
				'id' => 'en:soy-sauce',
				'processing' => 'en:powder',
				'text' => "\x{91a4}\x{6cb9}"
			},
			{
				'id' => "ja:\x{7c89}\x{672b}\x{9152}",
				'text' => "\x{7c89}\x{672b}\x{9152}"
			},
			{
				'id' => 'en:katsuobushi',
				'processing' => 'en:powder',
				'text' => "\x{304b}\x{3064}\x{304a}\x{7bc0}"
			},
			{
				'id' => "en:maca",
				'processing' => 'en:powder',
				'text' => "\x{30de}\x{30ab}"
			},
			{
				'id' => 'en:soy-sauce',
				'processing' => 'en:powder',
				'text' => "\x{3057}\x{3087}\x{3046}\x{3086}"
			},
			{
				'id' => "ja:\x{767a}\x{9175}\x{9ed2}\x{306b}\x{3093}\x{306b}\x{304f}\x{672b}",
				'text' => "\x{767a}\x{9175}\x{9ed2}\x{306b}\x{3093}\x{306b}\x{304f}\x{672b}"
			},
			{
				'id' => 'en:butter',
				'processing' => 'en:powder,en:roasted',
				'text' => "\x{30d0}\x{30bf}\x{30fc}"
			},
			{
				'id' => 'en:malt',
				'processing' => 'en:roasted',
				'text' => "\x{9ea6}\x{82bd}"
			},
			{
				'id' => 'en:garlic',
				'processing' => 'en:powder,en:fried',
				'text' => "\x{30ac}\x{30fc}\x{30ea}\x{30c3}\x{30af}"
			},
			{
				'id' => 'en:apple-pulp',
				'text' => "\x{308a}\x{3093}\x{3054}\x{30d1}\x{30eb}\x{30d7}"
			}
		]

	],

	# Danish (da)

	# for mælketørstof to work, mælke needs to be added as a synonym in the ingredients taxonomy, as the main translation is mælk
	[
		{
			lc => "da",
			ingredients_text =>
				"stegte ris, rispulver, kogte ris, kogte kartofler, kogte kartofler, kartofler, tørrede kartofler, udskårne kartofler, kartoflerpulver, kartoffelpuré, frosne kartofler, malede kartofler, mælketørstof, kartoffelekstrakt, bagt kartoffel, ufrosne bagte kartofler, ristet ananas , ristede bananer, dehydreret purløg, rehydrerede bananer",
		},
		[
			{
				'id' => 'en:rice',
				'processing' => 'en:fried',
				'text' => 'ris'
			},
			{
				'id' => 'en:rice',
				'processing' => 'en:powder',
				'text' => 'ris'
			},
			{
				'id' => 'en:rice',
				'processing' => 'en:cooked',
				'text' => 'ris'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cooked',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cooked',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:potato',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:dried',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cut',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:powder',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:pureed',
				'text' => 'kartoffel'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:frozen',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:ground',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:milk',
				'processing' => 'en:solids',
				'text' => "m\x{e6}lke"
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:extract',
				'text' => 'kartoffel'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:roasted',
				'text' => 'kartoffel'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:unfrozen,en:roasted',
				'text' => 'kartofler'
			},
			{
				'id' => 'en:pineapple',
				'processing' => 'en:roasted',
				'text' => 'ananas'
			},
			{
				'id' => 'en:banana',
				'processing' => 'en:roasted',
				'text' => 'bananer'
			},
			{
				'id' => 'en:chives',
				'processing' => 'en:dehydrated',
				'text' => "purl\x{f8}g"
			},
			{
				'id' => 'en:banana',
				'processing' => 'en:rehydrated',
				'text' => 'bananer'
			}
		]

	],

	# Finnish (fi)
	[
		{
			lc => "fi",
			ingredients_text =>
				"paistettu riisi, riisijauhe, keitetty riisi, keitetyt perunat, keitetty peruna, perunat, kuivatut perunat, leikatut perunat, perunajauhe, perunasose, pakasteperunat, jauhetut perunat, maidon kuiva-aineet, perunauute, uuniperuna, pakastetut uuniperunat, paahdetut ananas , paahdetut banaanit, kuivattu ruohosipuli, rehydratoitu banaani",
		},
		[
			{
				'id' => 'en:rice',
				'processing' => 'en:cooked',
				'text' => 'riisi'
			},
			{
				'id' => 'en:rice',
				'processing' => 'en:powder',
				'text' => 'riisi'
			},
			{
				'id' => 'en:cooked-rice',
				'text' => 'keitetty riisi'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cooked',
				'text' => 'perunat'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cooked',
				'text' => 'peruna'
			},
			{
				'id' => 'en:potato',
				'text' => 'perunat'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:dried',
				'text' => 'perunat'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cut',
				'text' => 'perunat'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:powder',
				'text' => 'peruna'
			},
			{
				'id' => 'en:mashed-potato',
				'text' => 'perunasose'
			},
			{
				'id' => 'fi:pakasteperunat',
				'text' => 'pakasteperunat'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:ground',
				'text' => 'perunat'
			},
			{
				'id' => 'fi:maidon-kuiva-aineet',
				'text' => 'maidon kuiva-aineet'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:extract',
				'text' => 'peruna'
			},
			{
				'id' => 'fi:uuniperuna',
				'text' => 'uuniperuna'
			},
			{
				'id' => 'fi:pakastetut-uuniperunat',
				'text' => 'pakastetut uuniperunat'
			},
			{
				'id' => 'en:pineapple',
				'processing' => 'en:toasted',
				'text' => 'ananas'
			},
			{
				'id' => 'fi:paahdetut-banaanit',
				'text' => 'paahdetut banaanit'
			},
			{
				'id' => 'en:chives',
				'processing' => 'en:dried',
				'text' => 'ruohosipuli'
			},
			{
				'id' => 'en:banana',
				'processing' => 'en:rehydrated',
				'text' => 'banaani'
			}
		]

	],

	# Norwegian bokmal (nb)
	[
		{
			lc => "nb",
			ingredients_text =>
				"stekt ris, rispulver, kokt ris, kokte poteter, kokt potet, poteter, tørkede poteter, kuttede poteter, potetpulver, potetpuré, frosne poteter, malte poteter, melkefaststoffer, potetekstrakt, bakt potet, ufrosne bakte poteter, stekt ananas , ristede bananer, dehydrert gressløk, rehydrerte bananer",
		},
		[
			{
				'id' => 'en:rice',
				'processing' => 'en:cooked',
				'text' => 'ris'
			},
			{
				'id' => 'en:rice',
				'processing' => 'en:powder',
				'text' => 'ris'
			},
			{
				'id' => 'en:rice',
				'processing' => 'en:cooked',
				'text' => 'ris'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cooked',
				'text' => 'poteter'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cooked',
				'text' => 'potet'
			},
			{
				'id' => 'en:potato',
				'text' => 'poteter'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:dried',
				'text' => 'poteter'
			},
			{
				'id' => 'nb:kuttede-poteter',
				'text' => 'kuttede poteter'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:powder',
				'text' => 'potet'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:pureed',
				'text' => 'potet'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:frozen',
				'text' => 'poteter'
			},
			{
				'id' => 'nb:malte-poteter',
				'text' => 'malte poteter'
			},
			{
				'id' => 'nb:melkefaststoffer',
				'text' => 'melkefaststoffer'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:extract',
				'text' => 'potet'
			},
			{
				'id' => 'nb:bakt-potet',
				'text' => 'bakt potet'
			},
			{
				'id' => 'nb:ufrosne-bakte-poteter',
				'text' => 'ufrosne bakte poteter'
			},
			{
				'id' => 'nb:stekt-ananas',
				'text' => 'stekt ananas'
			},
			{
				'id' => 'en:banana',
				'processing' => 'en:toasted',
				'text' => 'bananer'
			},
			{
				'id' => "nb:dehydrert-gressl\x{f8}k",
				'text' => "dehydrert gressl\x{f8}k"
			},
			{
				'id' => 'en:banana',
				'processing' => 'en:rehydrated',
				'text' => 'bananer'
			}
		]

	],

	# Swedish (sv)
	[
		{
			lc => "sv",
			ingredients_text =>
				"stekt ris, rispulver, kokt ris, kokt potatis, kokt potatis, potatis, torkad potatis, skuren potatis, potatispulver, potatispuré, fryst potatis, mald potatis, mjölkfasta ämnen, potatisextrakt, bakad potatis, ofryst bakad potatis, rostad ananas , rostade bananer, torkad gräslök, rehydrerade bananer",
		},
		[
			{
				'id' => 'en:rice',
				'processing' => 'en:fried',
				'text' => 'ris'
			},
			{
				'id' => 'en:rice',
				'processing' => 'en:powder',
				'text' => 'ris'
			},
			{
				'id' => 'en:cooked-rice',
				'text' => 'kokt ris'
			},
			{
				'id' => 'en:cooked-potato',
				'text' => 'kokt potatis'
			},
			{
				'id' => 'en:cooked-potato',
				'text' => 'kokt potatis'
			},
			{
				'id' => 'en:potato',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:dried',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:cut',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:powder',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:pureed',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:frozen',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:ground',
				'text' => 'potatis'
			},
			{
				'id' => "sv:mj\x{f6}lkfasta-\x{e4}mnen",
				'text' => "mj\x{f6}lkfasta \x{e4}mnen"
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:extract',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:roasted',
				'text' => 'potatis'
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:unfrozen,en:roasted',
				'text' => 'potatis'
			},
			{
				'id' => 'en:pineapple',
				'processing' => 'en:roasted',
				'text' => 'ananas'
			},
			{
				'id' => 'sv:rostade-bananer',
				'text' => 'rostade bananer'
			},
			{
				'id' => 'en:chives',
				'processing' => 'en:dried',
				'text' => "gr\x{e4}sl\x{f6}k"
			},
			{
				'id' => 'sv:rehydrerade-bananer',
				'text' => 'rehydrerade bananer'
			}
		]

	],

	# Arabic

	[
		{
			lc => "ar",
			ingredients_text => "بصل، مسحوق بصل، بصل مطبوخ، بصل مجمد",
		},
		[
			{
				'id' => 'en:onion',
				'text' => "\x{628}\x{635}\x{644}"
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:powder',
				'text' => "\x{628}\x{635}\x{644}"
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:cooked',
				'text' => "\x{628}\x{635}\x{644}"
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:frozen',
				'text' => "\x{628}\x{635}\x{644}"
			}
		]

	],

	# Bulgarian

	[
		{
			lc => "bg",
			ingredients_text => "печен лук, замразени картофи, ягоди на прах, пюре от чесън",
		},
		[
			{
				'id' => 'en:onion',
				'processing' => 'en:roasted',
				'text' => "\x{43b}\x{443}\x{43a}"
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:frozen',
				'text' => "\x{43a}\x{430}\x{440}\x{442}\x{43e}\x{444}\x{438}"
			},
			{
				'id' => 'en:strawberry',
				'processing' => 'en:powder',
				'text' => "\x{44f}\x{433}\x{43e}\x{434}\x{438}"
			},
			{
				'id' => 'en:garlic',
				'processing' => 'en:pureed',
				'text' => "\x{447}\x{435}\x{441}\x{44a}\x{43d}"
			}
		]
	],

	# Greek

	[
		{
			lc => "el",
			ingredients_text => "κρεμμύδι στο φούρνο, παγωμένη πατάτα, κρεμμύδι σε σκόνη, πουρέ κρεμμυδιού",
		},
		[
			{
				'id' => 'en:onion',
				'processing' => 'en:roasted',
				'text' => "\x{3ba}\x{3c1}\x{3b5}\x{3bc}\x{3bc}\x{3cd}\x{3b4}\x{3b9}"
			},
			{
				'id' => 'en:potato',
				'processing' => 'en:frozen',
				'text' => "\x{3c0}\x{3b1}\x{3c4}\x{3ac}\x{3c4}\x{3b1}"
			},
			{
				'id' => 'en:onion',
				'processing' => 'en:powder',
				'text' => "\x{3ba}\x{3c1}\x{3b5}\x{3bc}\x{3bc}\x{3cd}\x{3b4}\x{3b9}"
			},
			{
				'id' =>
					"el:\x{3c0}\x{3bf}\x{3c5}\x{3c1}\x{3ad}-\x{3ba}\x{3c1}\x{3b5}\x{3bc}\x{3bc}\x{3c5}\x{3b4}\x{3b9}\x{3bf}\x{3cd}",
				'text' =>
					"\x{3c0}\x{3bf}\x{3c5}\x{3c1}\x{3ad} \x{3ba}\x{3c1}\x{3b5}\x{3bc}\x{3bc}\x{3c5}\x{3b4}\x{3b9}\x{3bf}\x{3cd}"
			}
		]

	],
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_ingredients_ref = $test_ref->[1];

	print STDERR "ingredients_text: " . $product_ref->{ingredients_text} . "\n";

	parse_ingredients_text_service($product_ref, {});

	is_deeply($product_ref->{ingredients}, $expected_ingredients_ref)

		# using print + join instead of diag so that we don't have
		# hashtags. It makes copy/pasting the resulting structure
		# inside the test file much easier when tests results need
		# to be updated. Caveat is that it might interfere with
		# test output.
		or print STDERR join("\n", explain $product_ref->{ingredients});
}

done_testing();
