#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my @tests = (
	[ { lc => "en", ingredients_text => "sugar and water"}, 
[
  {
    'id' => 'en:sugar',
    'text' => 'sugar'
  },
  {
    'id' => 'en:water',
    'text' => 'water'
  }
]
	],

	[ { lc => "en", ingredients_text => "chocolate (cocoa, sugar), milk"}, 
[
  {
    'id' => 'en:chocolate',
    'ingredients' => [
      {
        'id' => 'en:cocoa',
        'text' => 'cocoa'
      },
      {
        'id' => 'en:sugar',
        'text' => 'sugar'
      }
    ],
    'text' => 'chocolate'
  },
  {
    'id' => 'en:milk',
    'text' => 'milk'
  }
]

	],
	[ { lc => "en", ingredients_text => "dough (wheat, water, raising agents: E501, salt), chocolate (cocoa (cocoa butter, cocoa paste), sugar), milk"}, 

[
  {
    'id' => 'en:dough',
    'ingredients' => [
      {
        'id' => 'en:wheat',
        'text' => 'wheat'
      },
      {
        'id' => 'en:water',
        'text' => 'water'
      },
      {
        'id' => 'en:raising-agent',
        'ingredients' => [
          {
            'id' => 'en:e501',
            'text' => 'e501'
          }
        ],
        'text' => 'raising agents'
      },
      {
        'id' => 'en:salt',
        'text' => 'salt'
      }
    ],
    'text' => 'dough'
  },
  {
    'id' => 'en:chocolate',
    'ingredients' => [
      {
        'id' => 'en:cocoa',
        'ingredients' => [
          {
            'id' => 'en:cocoa-butter',
            'text' => 'cocoa butter'
          },
          {
            'id' => 'en:cocoa-paste',
            'text' => 'cocoa paste'
          }
        ],
        'text' => 'cocoa'
      },
      {
        'id' => 'en:sugar',
        'text' => 'sugar'
      }
    ],
    'text' => 'chocolate'
  },
  {
    'id' => 'en:milk',
    'text' => 'milk'
  }
]
	],


	[ { lc => "es", ingredients_text => "sal y acidulante (ácido cítrico)"}, 
[
  {
    'id' => 'en:salt',
    'text' => 'sal'
  },
  {
    'id' => 'en:acid',
    'ingredients' => [
      {
        'id' => 'en:e330',
        'text' => "\x{e1}cido c\x{ed}trico"
      }
    ],
    'text' => 'acidulante'
  }

]
	],

	[ { lc => "fr", ingredients_text => "Teneur en légumes : 74 % : tomate ( Espagne) eau"},
[
  {
    'id' => "fr:Teneur en l\x{e9}gumes",
    'percent' => '74',
    'text' => "Teneur en l\x{e9}gumes"
  },
  {
    'id' => 'en:tomato',
    'origin' => 'en:spain',
    'text' => 'tomate'
  },
  {
    'id' => 'en:water',
    'text' => 'eau'
  }
]

	],

	[ { lc => "fr", ingredients_text => "Teneur en légumes : 74 % : tomate (60 %, Espagne) eau, Sel (France, Italie)"},


[
  {
    'id' => "fr:Teneur en l\x{e9}gumes",
    'percent' => '74',
    'text' => "Teneur en l\x{e9}gumes"
  },
  {
    'id' => 'en:tomato',
    'origin' => 'en:spain',
    'percent' => '60',
    'text' => 'tomate'
  },
  {
    'id' => 'en:water',
    'text' => 'eau'
  },
  {
    'id' => 'en:salt',
    'origin' => 'en:france,en:italy',
    'text' => 'Sel'
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
