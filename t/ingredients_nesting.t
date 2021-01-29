#!/usr/bin/perl -w

# Tests of parsing nested ingredients, such as "ingredient (component 1, component 2)", etc.

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
				'origins' => 'en:spain',
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
				'origins' => 'en:spain',
				'percent' => '60',
				'text' => 'tomate'
			},
			{
				'id' => 'en:water',
				'text' => 'eau'
			},
			{
				'id' => 'en:salt',
				'origins' => 'en:france,en:italy',
				'text' => 'Sel'
			}
		]
	],


	[ { lc => "fr", ingredients_text => "Céréales 63,7% (BLE complet 50,5%*, semoule de maïs*), sucre*, sirop de BLE*, cacao maigre en poudre 3,9%*, cacao en poudre 1,7%*, sel, arôme naturel. *Ingrédients issus de l'agriculture biologique."},
		[
			{
				'id' => 'en:cereal',
				'ingredients' => [
					{
						'id' => 'en:whole-wheat',
						'labels' => 'en:organic',
						'percent' => '50.5',
						'text' => 'BLE complet'
					},
					{
						'id' => 'en:cornmeal',
						'labels' => 'en:organic',
						'text' => "semoule de ma\x{ef}s"
					}
				],
				'percent' => '63.7',
				'text' => "C\x{e9}r\x{e9}ales"
			},
			{
				'id' => 'en:sugar',
				'labels' => 'en:organic',
				'text' => 'sucre'
			},
			{
				'id' => 'en:wheat-syrup',
				'labels' => 'en:organic',
				'text' => 'sirop de BLE'
			},
			{
				'id' => 'en:fat-reduced-cocoa-powder',
				'labels' => 'en:organic',
				'percent' => '3.9',
				'text' => 'cacao maigre en poudre'
			},
			{
				'id' => 'en:cocoa-powder',
				'labels' => 'en:organic',
				'percent' => '1.7',
				'text' => 'cacao en poudre'
			},
			{
				'id' => 'en:salt',
				'text' => 'sel'
			},
			{
				'id' => 'en:natural-flavouring',
				'text' => "ar\x{f4}me naturel"
			}
		]
	],


	[ { lc => "es", ingredients_text => "Hortalizas frescas (91 %) (tomate, pimiento. pepino y ajo), aceite de oliva virgen extra (3 %), vinagre de vino y sal."},
		[
			{
				'id' => 'en:vegetable',
				'ingredients' => [
					{
						'id' => 'en:tomato',
						'text' => 'tomate'
					},
					{
						'id' => 'en:bell-pepper',
						'text' => 'pimiento'
					},
					{
						'id' => 'en:cucumber',
						'text' => 'pepino'
					},
					{
						'id' => 'en:garlic',
						'text' => 'ajo'
					}
				],
				'percent' => '91',
				'text' => 'Hortalizas',
				'processing' => 'en:fresh'
			},
			{
				'id' => 'en:extra-virgin-olive-oil',
				'percent' => '3',
				'text' => 'aceite de oliva virgen extra'
			},
			{
				'id' => 'en:wine-vinegar',
				'text' => 'vinagre de vino'
			},
			{
				'id' => 'en:salt',
				'text' => 'sal'
			}
		]
	],


	[ { lc => "fr", ingredients_text => "Tomates bio coupées en tranches cuites"},
		[
			{
				'id' => 'en:tomato',
				'labels' => 'en:organic',
				'processing' => 'en:cooked, en:sliced, en:cut',
				'text' => 'Tomates'
			}
		]
	],


	[ { lc => "fr", ingredients_text => "minéraux (carbonate de calcium, carbonate de magnésium, fer élémentaire)"},
		[
			{
				'id' => 'en:minerals',
				'text' => 'minéraux',
				'ingredients' => [
					{
						'id' => 'en:e170i',
						'text' => 'carbonate de calcium'
					},
					{
						'id' => 'en:e504i',
						'text' => 'carbonate de magnésium'
					},
					{
						'id' => 'en:elemental-iron',
						'text' => 'fer élémentaire'
					}
				],
			},
		]
	],


	[ { lc => "fr", ingredients_text => "minéraux (carbonate de magnésium, fer élémentaire)"},
		[
			{
				'id' => 'en:minerals',
				'text' => 'minéraux',
				'ingredients' => [
					{
						'id' => 'en:e504i',
						'text' => 'carbonate de magnésium'
					},
					{
						'id' => 'en:elemental-iron',
						'text' => 'fer élémentaire'
					}
				],
			},
		]
	],


	[ { lc => "fr", ingredients_text => "MINERAUX (CARBONATE DE MAGNESIUM, FER ELEMENTAIRE)"},
		[
			{
				'id' => 'en:minerals',
				'text' => 'MINERAUX',
				'ingredients' => [
					{
						'id' => 'en:e504i',
						'text' => 'CARBONATE DE MAGNESIUM'
					},
					{
						'id' => 'en:elemental-iron',
						'text' => 'fer élémentaire'
					}
				],
			},
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
