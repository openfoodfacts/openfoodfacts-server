#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/:all/;

# dummy product for testing

my $product_ref = {
	lc => "es",
	ingredients_text =>
	"Leche desnatada de vaca, enzima lactasa y vitaminas A, D, E y ácido fólico.",
};

extract_ingredients_classes_from_text($product_ref);

is_deeply($product_ref->{vitamins_tags}, [
		"en:vitamin-a",
		"en:vitamin-d",
		"en:vitamin-e",
		"en:folic-acid",
	],
) or diag explain $product_ref->{vitamins_tags};



done_testing();
