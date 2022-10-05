#!/usr/bin/perl -w

# "TODO" Tests for known issues, to track if they get fixed while fixing something else.
# See https://perldoc.perl.org/Test/More.html#*TODO%3a-BLOCK*

use strict;
use warnings;

use utf8;

use Test::More;
#use Log::Any::Adapter 'TAP';
use Log::Any::Adapter 'TAP', filter => 'trace';

#use Text::Diff;

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my @tests = (

	# The "contient Gluten" without brackets is making the whole first ingredient and children get deleted.
	[
		"Issue #4232 - fr - 'Farine de blé contient Gluten (...)' - https://github.com/openfoodfacts/openfoodfacts-server/issues/4232",
		{
			lc => "fr",
			ingredients_text => "Farine de blé contient Gluten (avec Farine de blé, Carbonate de calcium, Fer, Niacine, Thiamine), Lait entier • Eau",
			#ingredients_text => "Farine de blé (avec Farine de blé, Carbonate de calcium, Fer, Niacine, Thiamine), Lait entier • Eau",
			#ingredients_text => "Farine de blé (avec Farine de blé, Fer, Niacine, Thiamine), Lait entier • Eau",
		},
		[
			{
				'id' => 'en:wheat-flour',
				'ingredients' => [
					{
						'id' => 'en:wheat-flour',
						'text' => "avec Farine de bl\x{e9}",
					},
					{
						'id' => 'en:e170i',
						'text' => 'Carbonate de calcium',
					},
					{
						'id' => 'en:iron',
						'text' => 'Fer',
					},
					{
						'id' => 'en:e375',
						'text' => 'Niacine',
					},
					{
						'id' => 'en:thiamin',
						'text' => 'Thiamine',
					}
				],
				'text' => "Farine de bl\x{e9}",
			},
			{
				'id' => 'en:whole-milk',
				'text' => 'Lait entier',
			},
			{
				'id' => 'en:water',
				'text' => 'Eau',
			}
		]
	],

	# Same issue as above in english.
	[
		"Issue #4232 - en - 'Wheatflour contains Gluten (...)' - https://github.com/openfoodfacts/openfoodfacts-server/issues/4232",
		{
			lc => "en",
			ingredients_text => "Wheatflour contains Gluten (with Wheatflour, Calcium Carbonate, Iron, Niacin, Thiamin)· Sugar, Palm Oil",
		},
		[
			{
				'id' => 'en:wheat-flour',
				'text' => 'Wheatflour',
				'ingredients' => [
					{
						'id' => 'en:wheat-flour',
						'text' => 'Wheatflour',
					},
					{
						'id' => 'en:e170i',
						'text' => 'Calcium Carbonate',
					},
					{
						'id' => 'en:iron',
						'text' => 'Iron',
					},
					{
						'id' => 'en:e375',
						'text' => 'Niacine',
					},
					{
						'id' => 'en:thiamin',
						'text' => 'Thiamin',
					}
				],
			},
			{
				'id' => 'en:sugar',
				'text' => 'Sugar',
			},
			{
				'id' => 'en:palm-oil',
				'text' => 'Palm Oil',
			}
		]
	],

	# ingredient group: (element1, element2, element3) needs to be parsed as ingredient group (element1, element2, element3)
	#комплексная пищевая добавка: (порошок сыра гауда, данбо, камамбер, голубой сыр, эмульгирующая соль Е 339)
	# using english, because the explain() output \x-escapes utf8.
	[
		"Issue #3959 - 'ingredient with colon before subingredients opening bracket' - https://github.com/openfoodfacts/openfoodfacts-server/issues/3959",
		{
			lc => "en",
			ingredients_text => "meat: (beef, pork, lamb)",
		},
		[
			{
				'id' => 'en:meat',
				'text' => 'meat',
				'ingredients' => [
					{
						'id' => 'en:beef',
						'text' => 'beef',
					},
					{
						'id' => 'en:pork',
						'text' => 'pork',
					},
					{
						'id' => 'en:lamb',
						'text' => 'lamb',
					},
				],
			},
		]
	],

	# interpret animal attribute in brackets as part of the ingredient name, instead of a separate ingredient.
	# présure (animale) -> présure animale
	[
		"Issue #3882 - 'présure (animale) -> présure animale' - https://github.com/openfoodfacts/openfoodfacts-server/issues/3882",
		{
			lc => "fr",
			ingredients_text => "ferments lactiques, présure (animale), sucre",
		},
		[
			{
				'id' => 'en:lactic-ferments',
				'text' => 'ferments lactiques',
			},
			{
				'id' => 'en:animal-based-rennet',
				'text' => 'présure animale',
			},
			{
				'id' => 'en:sugar',
				'text' => 'sucre',
			},
		]
	],




);



foreach my $test_ref (@tests) {

	# tell the testing framework it's okay to fail these
	TODO: {
		local $TODO = $test_ref->[0]; # human readable reason for the test

		my $product_ref = $test_ref->[1];
		my $expected_ingredients_ref = $test_ref->[2];

		print STDERR "ingredients_text: " . $product_ref->{ingredients_text} . "\n";

		parse_ingredients_text($product_ref);

		is_deeply ($product_ref->{ingredients}, $expected_ingredients_ref)
			# using print + join instead of diag so that we don't have
			# hashtags. It makes copy/pasting the resulting structure
			# inside the test file much easier when tests results need
			# to be updated. Caveat is that it might interfere with
			# test output.

			#or print STDERR join("\n", explain $product_ref->{ingredients});
			#or diag explain $product_ref->{ingredients};

			or do {
				print STDERR "# Got:\n";
				print STDERR join("\n", explain $product_ref->{ingredients});
				print STDERR "# Expected:\n";
				print STDERR join("\n", explain $expected_ingredients_ref );
			};

#			or do {
#				my $str_got = join("\n", explain $product_ref->{ingredients});
#				my $str_expected = join("\n", explain $expected_ingredients_ref );
#				print STDERR diff(\$str_expected, \$str_got);
#			};

	}

}

done_testing();
