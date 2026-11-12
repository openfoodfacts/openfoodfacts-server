#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/clean_ingredients_text extract_additives_from_text extract_ingredients_from_text/;
use ProductOpener::Food qw/compute_nova_group/;

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

	# allergens in parenthesis should not change the nova score but should appear in allergens
	[{lc => "hr", ingredients_text_hr => "Krupica od durum pšenice (gluten), voda."}, 1],

	# added nova:en: 4 property to some processings
	[{lc => "fr", ingredients_text_fr => "Farine de blé modifiée"}, 4],
	[{lc => "en", ingredients_text_en => "Modified cornflour"}, 4],
	[{lc => "en", ingredients_text_en => "Modified whey"}, 4],
	[{lc => "en", ingredients_text_en => "Modified strawberry"}, 4],
	[{lc => "en", ingredients_text_en => "Hydrolysed apple"}, 4],

);

sub compute_nova_group_from_text {

	my ($product_ref) = @_;

	if (not defined $product_ref->{categories_tags}) {
		$product_ref->{categories_tags} = ["en:some-category"];
	}
	$product_ref->{ingredients_text} = $product_ref->{"ingredients_text_" . $product_ref->{lc}};
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);
	extract_additives_from_text($product_ref);
	compute_nova_group($product_ref);
	return;
}

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $nova = $test_ref->[1];

	compute_nova_group_from_text($product_ref);

	is($product_ref->{nova_group}, $nova)
		or diag Dumper $product_ref;
}

# NOVA 4 markers: an ingredient that is also an additive must be counted only once
# https://github.com/openfoodfacts/openfoodfacts-server/issues/12621

my @markers_tests = (
	# "modified starch" is both the ingredient en:modified-starch and the additive en:e14xx
	[{lc => "en", ingredients_text_en => "sugar, thickener: modified starch"}, [["additives", "en:e14xx"]]],
	[{lc => "fr", ingredients_text_fr => "sucre, amidon modifié"}, [["additives", "en:e14xx"]]],
	# different markers are still all counted
	[
		{lc => "en", ingredients_text_en => "sugar, modified starch, emulsifier: E471"},
		[["additives", "en:e14xx"], ["additives", "en:e471"]]
	],
	# the ingredient is still a marker when no additive was found for it
	[
		{lc => "en", ingredients_text_en => "sugar, modified corn starch, maltodextrin"},
		[["ingredients", "en:maltodextrin"], ["ingredients", "en:modified-starch"]]
	],
	# an additive class on its own is still a marker
	[{lc => "fr", ingredients_text_fr => "lait, gélifiant"}, [["ingredients", "en:gelling-agent"]]],
);

foreach my $test_ref (@markers_tests) {

	my $product_ref = $test_ref->[0];
	my $expected_markers_ref = $test_ref->[1];

	compute_nova_group_from_text($product_ref);

	is($product_ref->{nova_group}, 4, $product_ref->{ingredients_text});
	is($product_ref->{nova_groups_markers}{4}, $expected_markers_ref, $product_ref->{ingredients_text})
		or diag Dumper $product_ref->{nova_groups_markers};
}

done_testing();
