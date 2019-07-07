#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Products qw/:all/;

# dummy product for testing

my @tests = (
	[ { lc => "fr", ingredients_text => "lait demi-écrémé 67%" }, [ "en:milk", ] ],
	[ { lc => "fr", ingredients_text => "Eau, gluten et dérivés" }, [ "en:gluten", ] ],
	[ { lc => "fr", ingredients_text => "NOIX DE SAINT-JACQUES MARINÉES: blabla, do not match the title of the product" }, [ ] ],
	[ { lc => "fr", ingredients_text => "NOIX DE SAINT-JACQUES sans corail (8.6 %), ingredients in lower case too, match the ingredient" }, [ "en:molluscs", ] ],
	[ { lc => "fr", ingredients_text => "Noix de Saint-Jacques marinées (8.6 %), ingredients in lower case too, no match" }, [ ] ],
	[ { lc => "fr", ingredients_text => "GRAINES DE SESAME grillées, ingredients in lower case too" }, [ "en:sesame-seeds", ] ],
	[ { lc => "fr", ingredients_text => "FRUITS A COQUE 10%, ingredients in lower case too" }, [ "en:nuts", ] ],
	[ { lc => "fr", ingredients_text => "FRUITS A COQUE - Something else, ingredients in lower case too" }, [ "en:nuts", ] ],

	[ { lc => "es", ingredients_text => "Harina de trigo 59%, margarina [grasa de palma, agua, aceite de colza, sal, emulgente: monoglicéridos y diglicéridos de ácidos grasos, corrector de acidez: ácido cítrico, colorante: carotenos], azúcar 17,8%, dextrosa, sal, gasificantes: carbonatos de sodio, aroma. Puede contener trazas de leche." }, [ "en:gluten", ], ["en:milk"] ],
	[ { lc => "es", ingredients_text => "Chocolate 48% [azúcar, pasta de cacao, manteca de cacao, lactosa, materia grasa láctea anhidra, leche desnatada en polvo, emulgente: lecitinas (girasol), aroma], harina de trigo, azúcar, mantequilla concentrada 6,5%, jarabe de glucosa y fructosa, sal, gasificantes: carbonatos de amonio - carbonatos de sodio - difosfatos, acidulante: ácido cítrico. Puede contener trazas de huevo y frutos de cáscara." }, [ "en:gluten", "en:milk"], ["en:eggs", "en:nuts"] ],

	[ { lc => "de", ingredients_text => "Zucker, Gewürze, Antioxidations-mittel: Ascorbinsâure, Konservierungsstoff: Natriumnitrit. Kann Spuren von Senf und Sellerie enthalten."}, [ ], [ "en:celery", "en:mustard"] ],
	[ { lc => "it", ingredients_text => "Puo contenere tracce di frutta a guscio, sesamo, soia e uova"}, [ ], [ "en:eggs", "en:nuts", "en:sesame-seeds", "en:soybeans"] ],
);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];
	my $expected_traces_tags = $test_ref->[2];

	$product_ref->{"ingredients_text_" . $product_ref->{lc}} = $product_ref->{ingredients_text};

	compute_languages($product_ref);
	detect_allergens_from_text($product_ref);

	is_deeply ($product_ref->{allergens_tags},
		$expected_tags) or diag explain $product_ref;

	if (defined $expected_traces_tags) {
		is_deeply ($product_ref->{traces_tags},
			$expected_traces_tags) or diag explain $product_ref;
	}
}

done_testing();
