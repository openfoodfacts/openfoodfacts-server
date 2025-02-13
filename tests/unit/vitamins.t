#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Data::Dumper;
$Data::Dumper::Terse = 1;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Ingredients qw/extract_additives_from_text/;

# dummy product for testing

my $product_ref = {
	lc => "es",
	ingredients_text => "Leche desnatada de vaca, enzima lactasa y vitaminas A, D, E y ácido fólico.",
};

extract_additives_from_text($product_ref);

is($product_ref->{vitamins_tags}, ["en:vitamin-a", "en:vitamin-d", "en:vitamin-e", "en:folic-acid",],)
	or diag Dumper $product_ref->{vitamins_tags};

done_testing();
