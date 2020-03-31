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
#                 English
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
#                           G E R M A N ( D E )
#
##################################################################

	[ { lc => "de", ingredients_text => "bourbon-vanillepulver" }, 
		[
	  		{
	    		'id' => 'en:bourbon-vanilla-powder',
	    		'text' => 'bourbon-vanillepulver'
	  		}
		]
	],

	[ { lc => "de", ingredients_text => "gehacktes Buttermilch"}, 
		[
			{
				'id' => 'en:buttermilk',
				'processing' => 'en:chopped',
				'text' => 'Buttermilch'
			},
		]
	],
	
	[ { lc => "de", ingredients_text => "Sauerkrautpulver" }, 
		[
			{
    			'id' => 'en:sauerkraut',
    			'processing' => 'en:powdered',
    			'text' => 'Sauerkraut'
  			}
		]
	],
	
	[ { lc => "de", ingredients_text => "gehobelt passionsfrucht" }, 
		[
			{
    			'id' => 'en:passion-fruit',
    			'processing' => 'en:sliced',
    			'text' => 'passionsfrucht'
  			}
		]
	],
	
	[ { lc => "de", ingredients_text => "acerola-pulver" }, 
		[
			{
    			'id' => 'en:acerola',
    			'processing' => 'en:powdered',
    			'text' => 'acerola'
			}
		]
	],

	[ { lc => "de", ingredients_text => "gehackter Dickmilch" }, 
		[
			{
	    		'id' => 'en:soured-milk',
	    		'processing' => 'en:chopped',
	    		'text' => 'Dickmilch'
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

	# Test for process de:geölt
		[ { lc => "de", ingredients_text => "Schalotte geölt, geölte haselnüsse, mandeln mit sonnenblumenöl geölt" }, 
			[
				{
					'id' => 'en:shallot',
					'processing' => 'de:geölt',
					'text' => 'Schalotte'
				},
				{
					'id' => 'en:hazelnut',
					'processing' => 'en:geölte',
					'text' => "haseln\x{fc}sse"
				},
				{
					'id' => 'en:almond',
					'processing' => 'de:mit-sonnenblumenöl-geölt',
					'text' => 'mandeln'
				}
			]
		],

# Test for process de:gesüßt 
	[ { lc => "de", ingredients_text => "Schalotte gesüßt, gesüßte haselnüsse" }, 
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:gesüßt',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:gesüßt',
				'text' => "haseln\x{fc}sse"
			}
		]
	],


		de:
		
# Process de:konzentriert (and children) and synonyms
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

	[ { lc => "de", ingredients_text => "hartkäse gehobelt, haselnüsse gehackt, haselnüsse gehackt und geröstet, 
		gehackte und geröstete haselnusskerne, gehobelte und gehackte mandeln" },
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
				'processing' => 'en:roasted, en:chopped',
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
				    'processing' => 'de:gefriergetrocknet',
				    'text' => 'Holunder'
				  },
				  {
				    'id' => 'en:papaya',
				    'processing' => 'de:gefriergetrocknet',
				    'text' => 'Papaya'
				  },
				  {
				    'id' => 'en:kiwi',
				    'processing' => 'de:gefriergetrocknet',
				    'text' => 'Kiwi'
				  },
				  {
				    'id' => 'en:pineapple',
				    'processing' => 'de:sonnengetrocknet',
				    'text' => 'Ananas'
				  },
				  {
				    'id' => 'en:prune',
				    'processing' => 'de:sonnengetrocknet',
				    'text' => 'Pflaumen'
				  },
				  {
				    'id' => 'en:grapefruit',
				    'processing' => 'de:sonnengetrocknet',
				    'text' => 'Grapefruit'
				  },
				  {
				    'id' => 'en:guava',
				    'processing' => 'de:luftgetrocknet',
				    'text' => 'Guaven'
				  },
				  {
				    'id' => 'en:rosehip',
				    'processing' => 'de:luftgetrocknet',
				    'text' => 'Hagebutten'
				  },
				  {
				    'id' => 'en:grape',
				    'processing' => "de:spr\x{fc}hgetrocknet",
				    'text' => 'Traube'
				  },
				  {
				    'id' => 'en:tamarind',
				    'processing' => "de:spr\x{fc}hgetrocknet",
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
				'processing' => 'de:gesalzen',
				'text' => "hartk\x{e4}se"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:gesalzen',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:gesalzen',
				'text' => "haseln\x{fc}sse"
			},
			{
				'id' => 'en:hazelnut',
				'processing' => 'de:gesalzen',
				'text' => 'haselnusskerne'
			},
			{
				'id' => 'en:shallot',
				'processing' => 'de:ungesalzen',
				'text' => 'schalotte'
 			},
			{
				'id' => 'en:almond',
				'processing' => 'de:ungesalzen',
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
				'processing' => 'de:eingelegt',
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
				'processing' => 'en:roasted, en:chopped',
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

# All variants of de:halbiert
	[ { lc => "de", ingredients_text => "Schalotte halbiert, zwiebel halbierte" },
		[
			{
				'id' => 'en:shallot',
				'processing' => 'de:halbiert',
				'text' => 'Schalotte'
			},
			{
				'id' => 'en:onion',
				'processing' => 'de:halbiert',
				'text' => 'zwiebel'
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
	]

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
