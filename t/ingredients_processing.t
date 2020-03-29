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
	[ { lc => "en", ingredients_text => "raw milk, sliced tomatoes, garlic powder, powdered eggplant, courgette powder"}, 
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
  }

]

	],

	[ { lc => "fr", ingredients_text => "dés de jambon frits, tomates crues en dés, tomates bio pré-cuites, poudre de noisettes"}, 

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
  }
]
	],

	[ { lc => "nl", ingredients_text => "sjalotpoeder, wei-poeder, vanillepoeder, gemalen sjalot, geraspte sjalot, gepelde goudsbloem"}, 
[
  {
    'id' => 'en:shallot',
    'text' => 'sjalot',
    'processing' => 'en:powdered'
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
    'text' => 'sjalot',
    'processing' => 'en:grated'
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
#                  G E R M A N ( D E )
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
	],
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
# Test for process/adjective de:gesalzen, de:ungesalzen
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
	[ { lc => "de", ingredients_text => "hartkäse gehobelt, haselnüsse gehackt, haselnüsse gehackt und geröstet, gehackte und geröstete haselnusskerne, gehobelte und gehackte mandeln" },
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
    'processing' => 'en:pureed',
    'text' => 'gurken'
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
