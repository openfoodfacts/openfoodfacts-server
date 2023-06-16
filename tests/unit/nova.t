#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Food qw/:all/;

# dummy product for testing

my @tests = (
	[{lc => "fr", ingredients_text_fr => "lait demi-écrémé 67%"}, 1],
	[{lc => "fr", categories_tags => ["en:salts"], ingredients_text_fr => "sel marin"}, 2],
	[{lc => "fr", ingredients_text_fr => "lait, sucre en poudre"}, 3],
	[{lc => "fr", ingredients_text_fr => "lait, édulcorant : aspartame"}, 4],
	[{lc => "fr", ingredients_text_fr => "sauce"}, 3],

	[{lc => "en", ingredients_text_en => "tomatoes", categories_tags => ["en:sandwiches"]}, 3],
	[{lc => "en", ingredients_text_en => "sugar", categories_tags => ["en:sugars"]}, 2],

	# emulsifiers
	[
		{
			lc => "es",
			ingredients_text_es => "Puré de castañas, lecitina de girasol y conservador: sorbato potásico (E202).",
			categories_tags => ["en:sweet-spreads"]
		},
		4
	],

	# cakes
	[{lc => "en", ingredients_text_en => "sugar, flour, eggs", categories_tags => ["en:cakes"]}, 3],

	# starches should be group 2
	[{lc => "en", ingredients_text_en => "starches, salt", categories_tags => ["en:starches"]}, 2],
	[{lc => "en", ingredients_text_en => "starches", categories_tags => ["en:starches"]}, 2],

	# group 2 categories should be group 2 even if we don't have ingredients for them
	[{lc => "en", categories_tags => ["en:starches"]}, 2],
	[{lc => "en", categories_tags => ["en:honeys"]}, 2],

	# products without ingredients: return only 1 for waters that are not flavoured waters
	[{lc => "en", categories_tags => ["en:waters"]}, 1],
	[{lc => "en", categories_tags => ["en:flavoured-waters"]}, undef],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $nova = $test_ref->[1];

	if (not defined $product_ref->{categories}) {
		$product_ref->{categories} = "some category";
	}
	$product_ref->{ingredients_text} = $product_ref->{"ingredients_text_" . $product_ref->{lc}};
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);
	compute_nova_group($product_ref);

	is_deeply($product_ref->{nova_group}, $nova)
		or diag explain $product_ref;
}

done_testing();
