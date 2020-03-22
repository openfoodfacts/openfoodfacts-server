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

	[ { lc => "nl", ingredients_text => "sjalotpoeder, wei-poeder, vanillepoeder, geraspte emmentaler"}, 
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
    'id' => 'en:grated-emmental-cheese',
    'text' => 'geraspte emmentaler',
    'processing' => 'en:grated'
  },

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

	[ { lc => "de", ingredients_text => "bourbon-vanillepulver, acerola-pulver"}, 
[
  {
    'id' => 'en:bourbon-vanilla-powder',
    'text' => 'bourbon-vanillepulver'
  },
  {
    'id' => 'en:acerola',
    'processing' => 'en:powdered',
    'text' => 'acerola'
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
