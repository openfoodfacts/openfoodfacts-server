#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';
use Log::Any::Adapter 'TAP', filter => "none";

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my @tests = (
	[ { lc => "en", ingredients_text => "sugar"}, 
[
  {
    'id' => 'en:sugar',
    'percent_max' => 100,
    'percent_min' => 100,
    'text' => 'sugar'
  }
]
	],

        [ { lc => "en", ingredients_text => "sugar, milk"},
[
  {
    'id' => 'en:sugar',
    'percent_max' => 100,
    'percent_min' => 50,
    'text' => 'sugar'
  },
  {
    'id' => 'en:milk',
    'percent_max' => 50,
    'percent_min' => 0,
    'text' => 'milk'
  }
]
        ],

	[ { lc => "en", ingredients_text => "sugar, milk, water"},
[
  {
    'id' => 'en:sugar',
    'percent_max' => 100,
    'percent_min' => '33.3333333333333',
    'text' => 'sugar'
  },
  {
    'id' => 'en:milk',
    'percent_max' => 50,
    'percent_min' => 0,
    'text' => 'milk'
  },
  {
    'id' => 'en:water',
    'percent_max' => '33.3333333333333',
    'percent_min' => 0,
    'text' => 'water'
  }

]
	],

        [ { lc => "en", ingredients_text => "sugar 90%, milk"},
[
  {
    'id' => 'en:sugar',
    'percent' => '90',
    'percent_max' => 90,
    'percent_min' => 90,
    'text' => 'sugar'
  },
  {
    'id' => 'en:milk',
    'percent_max' => 10,
    'percent_min' => 10,
    'text' => 'milk'
  }
]
	],

        [ { lc => "en", ingredients_text => "sugar, milk 10%"},
[
  {
    'id' => 'en:sugar',
    'percent_max' => 90,
    'percent_min' => 90,
    'text' => 'sugar'
  },
  {
    'id' => 'en:milk',
    'percent' => '10',
    'percent_max' => 10,
    'percent_min' => 10,
    'text' => 'milk'
  }
]
        ],

        [ { lc => "en", ingredients_text => "sugar, milk 10%, water"},
[
  {
    'id' => 'en:sugar',
    'percent_max' => 90,
    'percent_min' => 80,
    'text' => 'sugar'
  },
  {
    'id' => 'en:milk',
    'percent' => '10',
    'percent_max' => 10,
    'percent_min' => 10,
    'text' => 'milk'
  },
  {
    'id' => 'en:water',
    'percent_max' => 10,
    'percent_min' => 0,
    'text' => 'water'
  }
]
        ],

        [ { lc => "en", ingredients_text => "sugar, water, milk 10%"},
[
  {
    'id' => 'en:sugar',
    'percent_max' => 80,
    'percent_min' => 45,
    'text' => 'sugar'
  },
  {
    'id' => 'en:water',
    'percent_max' => 45,
    'percent_min' => 10,
    'text' => 'water'
  },
  {
    'id' => 'en:milk',
    'percent' => '10',
    'percent_max' => 10,
    'percent_min' => 10,
    'text' => 'milk'
  }
]
        ],

	# Ingredients with sub-ingredients

        [ { lc => "en", ingredients_text => "chocolate (cocoa)"},
[
  {
    'id' => 'en:chocolate',
    'ingredients' => [
      {
        'id' => 'en:cocoa',
        'percent_max' => 100,
        'percent_min' => 100,
        'text' => 'cocoa'
      }
    ],
    'percent_max' => 100,
    'percent_min' => 100,
    'text' => 'chocolate'
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
        'percent_max' => 100,
        'percent_min' => 25,
        'text' => 'cocoa'
      },
      {
        'id' => 'en:sugar',
        'percent_max' => 50,
        'percent_min' => 0,
        'text' => 'sugar'
      }
    ],
    'percent_max' => 100,
    'percent_min' => 50,
    'text' => 'chocolate'
  },
  {
    'id' => 'en:milk',
    'percent_max' => 50,
    'percent_min' => 0,
    'text' => 'milk'
  }
]
	],

        [ { lc => "en", ingredients_text => "chocolate (cocoa [cocoa paste 70%, cocoa butter], sugar)"},
[
  {
    'id' => 'en:chocolate',
    'ingredients' => [
      {
        'id' => 'en:cocoa',
        'ingredients' => [
          {
            'id' => 'en:cocoa-paste',
            'percent' => '70',
            'percent_max' => 70,
            'percent_min' => 70,
            'text' => 'cocoa paste'
          },
          {
            'id' => 'en:cocoa-butter',
            'percent_max' => 30,
            'percent_min' => 0,
            'text' => 'cocoa butter'
          }
        ],
        'percent_max' => 100,
        'percent_min' => 70,
        'text' => 'cocoa'
      },
      {
        'id' => 'en:sugar',
        'percent_max' => 30,
        'percent_min' => 0,
        'text' => 'sugar'
      }
    ],
    'percent_max' => 100,
    'percent_min' => 100,
    'text' => 'chocolate'
  }

]
	],

# Make sure we can handle impossible values gracefully

# This ingredient string caused an infinite loop:
#  "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel"

        [ { lc => "fr", ingredients_text => "beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%"},
[
  {
    'id' => 'en:cocoa-butter',
    'percent' => '15',
    'percent_max' => 15,
    'percent_min' => 15,
    'text' => 'beurre de cacao'
  },
  {
    'id' => 'en:sugar',
    'percent' => '10',
    'percent_max' => '10',
    'percent_min' => '10',
    'text' => 'sucre'
  },
  {
    'id' => 'en:milk-proteins',
    'percent_max' => 100,
    'percent_min' => 0,
    'text' => "prot\x{e9}ines de lait"
  },
  {
    'id' => 'en:egg',
    'percent' => '1',
    'percent_max' => '1',
    'percent_min' => '1',
    'text' => 'oeuf'
  }

]
	],

        [ { lc => "fr", ingredients_text => "farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%)"},
[
  {
    'id' => 'en:flour',
    'percent' => '12',
    'percent_max' => 12,
    'percent_min' => 12,
    'text' => 'farine'
  },
  {
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
    'percent_max' => 100,
    'percent_min' => 0,
    'text' => 'chocolat'
  }

]
        ],

        [ { lc => "en", ingredients_text => "Flour, chocolate (cocoa, sugar, soy lecithin), egg"},
[
  {
    'id' => 'en:flour',
    'percent_max' => 100,
    'percent_min' => '33.3333333333333',
    'text' => 'Flour'
  },
  {
    'id' => 'en:chocolate',
    'ingredients' => [
      {
        'id' => 'en:cocoa',
        'percent_max' => 50,
        'percent_min' => 0,
        'text' => 'cocoa'
      },
      {
        'id' => 'en:sugar',
        'percent_max' => 25,
        'percent_min' => 0,
        'text' => 'sugar'
      },
      {
        'id' => 'en:soya-lecithin',
        'percent_max' => '16.6666666666667',
        'percent_min' => 0,
        'text' => 'soy lecithin'
      }
    ],
    'percent_max' => 50,
    'percent_min' => 0,
    'text' => 'chocolate'
  },
  {
    'id' => 'en:egg',
    'percent_max' => '33.3333333333333',
    'percent_min' => 0,
    'text' => 'egg'
  }
]

],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_ingredients_ref = $test_ref->[1];

	print STDERR "ingredients_text: " . $product_ref->{ingredients_text} . "\n";

	parse_ingredients_text($product_ref);
	compute_ingredients_percent_values(
		100, 100, $product_ref->{ingredients});

	is_deeply ($product_ref->{ingredients}, $expected_ingredients_ref)
		# using print + join instead of diag so that we don't have
		# hashtags. It makes copy/pasting the resulting structure
		# inside the test file much easier when tests results need
		# to be updated. Caveat is that it might interfere with
		# test output.
		or print STDERR join("\n", explain $product_ref->{ingredients});
}

done_testing();
