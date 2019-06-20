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
[ { lc => "en", ingredients_text => "water, sugar, tea, lemon juice, flavouring, acidity regulator (330, 331), vitamin C, antioxidant (304)" }, [ "en:e330", "en:e331", "en:e304" ] ], 
[ { lc => "en", ingredients_text => "REAL SUGARCANE, SALT, ANTIOXIDANT (INS 300), ACIDITY REGULATOR (INS 334), STABILIZER (INS 440, INS 337), WATER (FOR MAINTAINING DESIRED BRIX), CONTAINS PERMITTED NATURAL FLAVOUR & NATURAL IDENTICAL COLOURING SUBSTANCES (INS 141[i])" }, [ "en:e300", "en:e334", "en:e440", "en:e337", "en:e141" ] ], 
[ { lc => "fr", ingredients_text => "Stabilisants: (SIN450i, SIN450iii), antioxydant (SIN316), Agent de conservation: (SIN250)." }, [ "en:e450i", "en:e450iii", "en:e316", "en:e250" ] ], 

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	my $expected_tags = $test_ref->[1];

	$product_ref->{"ingredients_text_" . $product_ref->{lc}} = $product_ref->{ingredients_text};

	extract_ingredients_classes_from_text($product_ref);

	is_deeply ($product_ref->{additives_original_tags}, 
		$expected_tags) or diag explain $product_ref;
}

done_testing();
