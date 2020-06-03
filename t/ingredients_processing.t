#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
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

	[ { lc => "en", ingredients_text => "raw milk, sliced tomatoes, garlic powder, powdered eggplant, 
			courgette powder, sieved ham"}, 
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
	    		'id' => 'en:garlic-powder',
	    		'text' => 'garlic powder'
	  		},
	  		{
	    		'id' => 'en:aubergine',
	    		'processing' => 'en:powdered',
	    		'text' => 'eggplant'
	  		},
	  		{
	    		'id' => 'en:courgette',
	    		'processing' => 'en:powdered',
	    		'text' => 'courgette'
	  		},
	  		{
	    		'id' => 'en:ham',
	    		'processing' => 'en:sieved',
	    		'text' => 'ham'
	  		}
		]
	],

# en:dried (children are lef out at the moment)
	[ { lc => "en", ingredients_text => "dried milk"}, 
		[
			{
				'id' => 'en:milk',
				'processing' => 'en:dried',
				'text' => 'milk'
			}
			]
	],

# en: smoked (children are lef out at the moment)
	[ { lc => "en", ingredients_text => "smoked milk, not smoked tomatoes"}, 
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
	[ { lc => "en", ingredients_text => "sweetened milk, unsweetened tomatoes, sugared ham"}, 
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
	[ { lc => "en", ingredients_text => "halved milk, tomatoes halves"}, 
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

##################################################################
#
#                           S P A N I S H   ( E S )
#
##################################################################

	[ { lc => "es", ingredients_text => "tomate endulzado, berenjena endulzada, calabacín endulzados, jamón endulzadas" }, 
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

	[ { lc => "es", ingredients_text => "pimientos amarillos deshidratados" }, 
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
	[ { lc => "fr", ingredients_text => "dés de jambon frits, tomates crues en dés, 
			tomates bio pré-cuites, poudre de noisettes, banane tamisé"}, 
		[
  {
    'id' => 'en:ham',
    'processing' => 'en:diced, en:fried',
    'text' => 'jambon'
  },
  {
    'id' => 'en:tomato',
    'processing' => 'en:diced, en:raw',
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
    'processing' => 'en:powdered',
    'text' => 'noisettes'
  },
  {
    'id' => 'en:banana',
    'processing' => 'en:sieved',
    'text' => 'banane'
  }
		]
	],

		[ { lc => "fr", ingredients_text => "banane coupée et cuite au naturel"}, 
			[
	  			{
	    			'id' => 'en:banana',
	    			'processing' => 'en:cooked, en:cut',
	    			'text' => 'banane'
	  			}
			]
		],

	[ { lc => "fr", ingredients_text => "banane coupée et cuite au naturel"}, 
		[
			{
				'id' => 'en:banana',
				'processing' => 'en:cooked, en:cut',
				'text' => 'banane'
			}
		]
	],

##################################################################
#
#                           D U T C H ( N L )
	#
##################################################################

	[ { lc => "nl", ingredients_text => "sjalotpoeder, wei-poeder, vanillepoeder, gemalen sjalot, geraspte sjalot, gepelde goudsbloem"}, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:powdered',
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
	[ { lc => "de", ingredients_text => "bourbon-vanillepulver, Sauerkrautpulver, acerola-pulver" }, 
		[
	  		{
	    		'id' => 'en:bourbon-vanilla-powder',
	    		'text' => 'bourbon-vanillepulver'
	  		},
			{
    			'id' => 'en:sauerkraut',
    			'processing' => 'en:powdered',
    			'text' => 'Sauerkraut'
			},
			{
    			'id' => 'en:acerola',
    			'processing' => 'en:powdered',
    			'text' => 'acerola'
			}
		]
	],

# de:gehackt and variants
	[ { lc => "de", ingredients_text => "gehacktes Buttermilch, gehackter Dickmilch"}, 
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
	[ { lc => "de", ingredients_text => "gehobelt passionsfrucht" }, 
		[
			{
    			'id' => 'en:passion-fruit',
    			'processing' => 'en:sliced',
    			'text' => 'passionsfrucht'
  			}
		]
	],


# Test for de:püree (and for process placing de:püree without space)
	[ { lc => "de", ingredients_text => "Schalottepüree" }, 
		[
			{
	    		'id' => 'en:shallot',
	    		'processing' => 'en:pureed',
	    		'text' => 'Schalotte'
			}
		]
	],
	
# Test for process de:püree placing with space (not really necessary as it has been tested with the other)
	[ { lc => "de", ingredients_text => "Schalotte püree" }, 
		[
		  	{
				'id' => 'en:shallot',
				'processing' => 'en:pureed',
				'text' => 'Schalotte'
			}
		]
	],

# de:gegart and variants
	[ { lc => "de", ingredients_text => "Schalotte gegart, gegarte haselnüsse, gegarter mandeln, gegartes passionsfrucht, 
					gurken dampfgegart, dampfgegarte acerola, dampfgegarter spinat" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:gegart',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:gegart',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'de:gegart',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:passion-fruit',
				'processing' => 'de:gegart',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:gherkin',
				'processing' => 'de:dampfgegart',
				'text' => 'gurken'
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

# Test for de:geölt
	[ { lc => "de", ingredients_text => "Schalotte geölt, geölte haselnüsse" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => "de:ge\x{f6}lt",
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => "de:ge\x{f6}lt",
				'text' => "haseln\x{fc}sse"
			}
		]
	],

# de:gepökelt and variants
	[ { lc => "de", ingredients_text => "Schalotte gepökelt, gepökeltes haselnüsse, 
				passionsfrucht ungepökelt" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:gepökelt',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:gepökelt',
				'text' => "haselnüsse"
			},
			{
				'id' => 'en:passion-fruit',
				'processing' => 'de:ungepökelt',
				'text' => 'passionsfrucht'
			}
		]
	],
	
# de:gepoppt and variants
	[ { lc => "de", ingredients_text => "Schalotte gepoppt, gepuffte haselnüsse, 
				passionsfrucht gepufft, gepuffter passionsfrucht, gepufftes gurken" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:puffed',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:puffed',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:passion-fruit',
				'processing' => 'en:puffed',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:passion-fruit',
				'processing' => 'en:puffed',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:gherkin',
				'processing' => 'en:puffed',
				'text' => 'gurken'
			}
		]
	],
	
# de:geschält and variants
	[ { lc => "de", ingredients_text => "Schalotte geschält, geschälte haselnüsse, geschälter mandeln, 
				passionsfrucht ungeschält, ungeschälte gurken" }, 
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
				'id' => 'en:passion-fruit',
				'processing' => 'de:ungeschält',
				'text' => 'passionsfrucht'
			},
			{
				'id' => 'en:gherkin',
				'processing' => 'de:ungeschält',
				'text' => 'gurken'
			}
		]
	],

# de:geschwefelt and variants
	[ { lc => "de", ingredients_text => "Schalotte geschwefelt, geschwefelte haselnüsse, 
				passionsfrucht ungeschwefelt, geschwefelte gurken" },
		[
			{
			    'id' => 'en:shallot',
			    'processing' => 'de:geschwefelt',
			    'text' => 'Schalotte'
			},
			{
			    'id' => 'en:hazelnut',
			    'processing' => 'de:geschwefelt',
			    'text' => "haseln\x{fc}sse"
			},
			{
			    'id' => 'en:passion-fruit',
			    'processing' => 'de:ungeschwefelt',
			    'text' => 'passionsfrucht'
			},
			{
			    'id' => 'en:gherkin',
			    'processing' => 'de:geschwefelt',
			    'text' => 'gurken'
			}
		]
	],

#  de:gesüßt 
	[ { lc => "de", ingredients_text => "Schalotte gesüßt, gesüßte haselnüsse" }, 
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
	[ { lc => "de", ingredients_text => "Schalotte gezuckert, gezuckerte haselnüsse, mandeln leicht gezuckert, passionsfrucht ungezuckert" }, 
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
				'id' => 'en:passion-fruit',
				'processing' => 'de:ungezuckert',
				'text' => 'passionsfrucht'
			}
		]
	],

	# de:halbiert and variants
	[ { lc => "de", ingredients_text => "Schalotte halbiert, halbierte haselnüsse, halbe mandeln" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:halved',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:halved',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:halved',
				'text' => 'mandeln'
			}
		]
	],

# de:konzentriert (and children) and synonyms
	[ { lc => "de", ingredients_text => "konzentriert shallot, konzentrierter haselnüsse, konzentrierte mandeln, konzentriertes acerola, 
		zweifach konzentriert, 2 fach konzentriert, doppelt konzentriertes, zweifach konzentriertes, 2-fach konzentriert, dreifach konzentriert, 
		200fach konzentriertes, eingekochter" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:concentrated',
				'text' => 'shallot'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:concentrated',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:concentrated',
				'text' => 'mandeln'
			},
			{
				'id' => 'en:acerola',
				'processing' => 'en:concentrated',
				'text' => 'acerola'
			},
			{
			    'id' => 'de:zweifach konzentriert',
			    'text' => 'zweifach konzentriert'
			 },
			 {
			    'id' => 'de:2 fach konzentriert',
			    'text' => '2 fach konzentriert'
			 },
			 {
			    'id' => 'de:doppelt konzentriertes',
			    'text' => 'doppelt konzentriertes'
			},
			{
				'id' => 'de:zweifach konzentriertes',
				'text' => 'zweifach konzentriertes'
			 },
			 {
			    'id' => 'de:2-fach konzentriert',
			    'text' => '2-fach konzentriert'
			 },
			 {
			    'id' => 'de:dreifach konzentriert',
			    'text' => 'dreifach konzentriert'
			 },
			 {
			    'id' => 'de:200fach konzentriertes',
			    'text' => '200fach konzentriertes'
			 },
			 {
			    'id' => 'de:eingekochter',
			    'text' => 'eingekochter'
			 }
		]	
	],

# de:zerkleinert and variants
	[ { lc => "de", ingredients_text => "Schalotte zerkleinert, zerkleinerte haselnüsse, zerkleinerter mandeln, zerkleinertes passionsfrucht, 
						gurken grob zerkleinert, 
						acerola fein zerkleinert, fein zerkleinerte spinat, 
						zwiebel zum teil fein zerkleinert,
						haselnüsse feinst zerkleinert,
						überwiegend feinst zerkleinert Feigen" }, 
						[
						  {
						    'id' => 'en:shallot',
						    'processing' => 'de:zerkleinert',
						    'text' => 'Schalotte'
						  },
						  {
						    'id' => 'en:hazelnut',
						    'processing' => 'de:zerkleinert',
						    'text' => "haseln\x{fc}sse"
						  },
						  {
						    'id' => 'en:almond',
						    'processing' => 'de:zerkleinert',
						    'text' => 'mandeln'
						  },
						  {
						    'id' => 'en:passion-fruit',
						    'processing' => 'de:zerkleinert',
						    'text' => 'passionsfrucht'
						  },
						  {
						    'id' => 'en:gherkin',
						    'processing' => 'de:grob-zerkleinert',
						    'text' => 'gurken'
						  },
						  {
						    'id' => 'en:acerola',
						    'processing' => 'de:fein-zerkleinert',
						    'text' => 'acerola'
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
						    'text' => "haseln\x{fc}sse"
						  },
						  {
						    'id' => 'en:fig',
						    'processing' => "de:\x{fc}berwiegend-feinst-zerkleinert",
						    'text' => 'Feigen'
						  }
						]
	],

# combinations
	[ { lc => "de", ingredients_text => "haselnüsse gehackt und geröstet, 
		gehackte und geröstete haselnusskerne, gehobelte und gehackte mandeln" },
		[
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:toasted, en:chopped',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:toasted-hazelnut',
				'processing' => 'en:chopped',
				'text' => "ger\x{f6}stete haselnusskerne"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:sliced, en:chopped',
				'text' => 'mandeln'
			}
		]
	],

# Test for de:gemahlen and synonyms
	[ { lc => "de", ingredients_text => "Schalotte gemahlen, gemahlene mandeln, gemahlener zwiebel, 
			fein gemahlen haselnüsse, grob gemahlen spinat, frischgemahlen gurken" }, 
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
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:spinach',
				'processing' => 'de:grob-gemahlen',
				'text' => 'spinat'
			},
			{
				'id' => 'en:gherkin',
				'processing' => 'de:frischgemahlen',
				'text' => 'gurken'
			}
		]
	],

	# Test for de:getrocknet and synonyms
		[ { lc => "de", ingredients_text => "Schalotte getrocknet, getrocknete mandeln, getrockneter zwiebel, 
				 haselnüsse in getrockneter form, halbgetrocknete spinat, halbgetrocknet gurken, Feigen halb getrocknet, 
				 Holunder gefriergetrocknet, gefriergetrocknete Papaya, gefriergetrocknetes Kiwi, sonnengetrocknet Ananas, 
				 sonnengetrocknete Pflaumen, an der Sonne getrocknete Grapefruit, Guaven luftgetrocknet, luftgetrockneter Hagebutten, 
				 Traube sprühgetrocknet, sprühgetrockneter Tamarinde" }, 
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
				    'text' => "haseln\x{fc}sse"
				  },
				  {
				    'id' => 'en:spinach',
				    'processing' => 'de:halbgetrocknet',
				    'text' => 'spinat'
				  },
				  {
				    'id' => 'en:gherkin',
				    'processing' => 'de:halbgetrocknet',
				    'text' => 'gurken'
				  },
				  {
				    'id' => 'en:fig',
				    'processing' => 'de:halbgetrocknet',
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
				    'id' => 'en:prune',
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
				    'id' => 'en:rosehip',
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
	[ { lc => "de", ingredients_text => "Schalotte passiert" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'en:sieved',
				'text' => 'Schalotte'
			}
		]
	],

# Test for de:ungesalzen
	[ { lc => "de", ingredients_text => "hartkäse gesalzen, haselnüsse gesalzene, haselnüsse gesalzenes, 
	gesalzener haselnusskerne, ungesalzen schalotte, ungesalzene mandeln" },
		[
			{
				'id' => "de:hartk\x{e4}se",
				'processing' => 'en:salted',
				'text' => "hartk\x{e4}se"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:salted',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:salted',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:salted',
				'text' => 'haselnusskerne'
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
	[ { lc => "de", ingredients_text => "Schalotte entsteint" }, 
		[
		  	{
				'id' => 'en:shallot',
				'processing' => 'en:pitted',
				'text' => 'Schalotte'
			}
		]
	],

# Test for process de:eingelegt
	[ { lc => "de", ingredients_text => "Schalotte eingelegt" }, 
		[
		  	{
				'id' => 'en:shallot',
				'processing' => 'en:pickled',
				'text' => 'Schalotte'
			}
		]
	],
	

# Test for de: ingredients, that should NOT be detected through processing
	[ { lc => "de", ingredients_text => "Markerbsen, Deutsche Markenbutter" }, 
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
	[ { lc => "de", ingredients_text => "hartkäse gehobelt, haselnüsse gehackt, haselnüsse gehackt und geröstet, 
		gehackte und geröstete haselnusskerne, gehobelte und gehackte mandeln, Dickmilch in scheiben geschnitten" },
		[
			{
				'id' => "de:hartk\x{e4}se",
				'processing' => 'en:sliced',
				'text' => "hartk\x{e4}se"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:chopped',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'en:toasted, en:chopped',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:toasted-hazelnut',
				'processing' => 'en:chopped',
				'text' => "ger\x{f6}stete haselnusskerne"
			},
			{
				'id' => 'en:almond',
				'processing' => 'en:sliced, en:chopped',
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
	[ { lc => "de", ingredients_text => "Schalotte rehydriert, zwiebel rehydrierte, spinat rehydriertes" },
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
	[ { lc => "de", ingredients_text => "Schalotte mariniert, zwiebel marinierte, spinat marinierter, 
		mariniertes gurken" },
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
				'id' => 'en:gherkin',
				'processing' => 'en:marinated',
				'text' => 'gurken'
			}
		]
	],

# All variants of de:geschnitten
	[ { lc => "de", ingredients_text => "Schalotte geschnitten, zwiebel mittelfein geschnittenen, spinat feingeschnitten, 
		fein geschnittenen gurken, feingeschnittener Mandeln, handgeschnittene haselnüsse" },
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
				'id' => 'en:gherkin',
				'processing' => 'de:feingeschnitten',
				'text' => 'gurken'
			},
			{
				'id' => 'en:almond',
				'processing' => 'de:feingeschnitten',
				'text' => 'Mandeln'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:handgeschnitten',
				'text' => "haseln\x{fc}sse"
			}
		]
	],

	[ { lc => "de", ingredients_text => "Schalottepüree, zwiebel püree, spinat-püree, gurkenmark" },
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
				'id' => 'en:gherkin',
				'processing' => 'en:pulp',
				'text' => 'gurken'
			}
		]
	],

# de:gerieben and synonyms tests
	[ { lc => "de", ingredients_text => "Schalotte gerieben, geriebener zwiebel, geriebene spinat" },
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
	[ { lc => "de", ingredients_text => "Schalottewürfel, spinat gewürfelt, gewürfelte gurken, 
zwiebel in würfel geschnitten, mandeln in würfel" },
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
				'id' => 'en:gherkin',
				'processing' => 'en:diced',
				'text' => 'gurken'
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

	[ { lc => "en", ingredients_text => "smoked sea salt, smoked turkey"},
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

	[ { lc => "fr", ingredients_text => "sel marin fumé, jambon fumé, arôme de fumée, lardons fumés au bois de hêtre "},
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


	[ { lc => "es", ingredients_text => "tofu ahumado, panceta ahumada"},
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

	# ingredient with (processing) in parenthesis
	[ { lc => "en", ingredients_text => "garlic (powdered)",},
[
  {
    'id' => 'en:garlic',
    'processing' => 'en:powdered',
    'text' => 'garlic'
  }
]
	],
	[ { lc => "fr", ingredients_text => "piment (en poudre)"},
[
  {
    'id' => 'en:chili-pepper',
    'processing' => 'en:powdered',
    'text' => 'piment'
  }
]
	],

	[ { lc => "en", ingredients_text => "pasteurized eggs" },
[
  {
    'id' => 'en:egg',
    'processing' => 'en:pasteurised',
    'text' => 'eggs'
  }
]
	],

	[ { lc => "es", ingredients_text => "pimientos amarillos deshidratados" },
[
  {
    'id' => 'en:yellow-bell-pepper',
    'processing' => 'en:dehydrated',
    'text' => 'pimientos amarillos'
  }
]
	],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_ingredients_ref = $test_ref->[1];

	print STDERR "ingredients_text: " . $product_ref->{ingredients_text} . "\n";

	parse_ingredients_text($product_ref);

	is_deeply ($product_ref->{ingredients}, $expected_ingredients_ref)
		# using print + join instead of diag so that we don't have
		# hashtags. It makes copy/pasting the resulting structure
		# inside the test file much easier when tests results need
		# to be updated. Caveat is that it might interfere with
		# test output.
		or print STDERR join("\n", explain $product_ref->{ingredients});
}

done_testing();
