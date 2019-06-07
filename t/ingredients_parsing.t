#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Products qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;

#use Log::Any::Adapter 'TAP', filter => "none";
#
is (normalize_a_of_b("en", "oil", "olive"), "olive oil");
is (normalize_a_of_b("es", "aceta", "oliva"), "aceta de oliva");
is (normalize_a_of_b("fr", "huile végétale", "olive"), "huile végétale d'olive");

is (normalize_enumeration("en", "phosphates", "calcium and sodium"), "calcium phosphates, sodium phosphates");
is (normalize_enumeration("en", "vegetal oil", "sunflower, palm"), "sunflower vegetal oil, palm vegetal oil");
is (normalize_enumeration("fr", "huile", "colza, tournesol et olive"), "huile de colza, huile de tournesol, huile d'olive");

my @lists =( 
['fr' ,
[
["Sel marin, blé, lécithine de soja", "Sel marin, blé, lécithine de soja"],
["Vitamine A", "Vitamine A"],
["Vitamines A, B et C", "Vitamines, Vitamine A, Vitamine B, Vitamine C"],
["Vitamines (B1, B2, B6, PP)", "Vitamines, Vitamine B1, Vitamine B2, Vitamine B6, Vitamine PP"],
["Huile de palme", "Huile de palme"],
["Huile (palme)", "Huile de palme"],
["Huile (palme, colza)", "Huile de palme, Huile de colza"],
["Huile (palme et colza)", "Huile de palme, Huile de colza"],
["Huiles végétales de palme et de colza", "Huiles végétales de palme, Huiles végétales de colza"],
["Huiles végétales de palme et d'olive", "Huiles végétales de palme, Huiles végétales d'olive"],
["Huiles végétales de palme, de colza et de tournesol", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales de tournesol"],
["Huiles végétales de palme, de colza, de tournesol", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales de tournesol"],
["Huiles végétales de palme, de colza et d'olive", "Huiles végétales de palme, Huiles végétales de colza, huiles végétales d'olive"],
["phosphate et sulfate de calcium", "phosphate de calcium, sulfate de calcium"],
["sulfates de calcium et potassium", "sulfates de calcium, sulfates de potassium"],
["chlorures (sodium et potassium)", "chlorures de sodium, chlorures de potassium"],
["chlorures (sodium, potassium)", "chlorures de sodium, chlorures de potassium"],
],
],
);

foreach my $list_ref (@lists) {
	my $l = $list_ref->[0];
	foreach my $test_ref (@{$list_ref->[1]}) {
		my $ingredients = $test_ref->[0];
		my $preparsed = preparse_ingredients_text($l, $ingredients);
		print STDERR "ingredients: $ingredients\n";
		print STDERR "preparsed: $preparsed\n";
		my $expected = $test_ref->[1];
		is (lc($preparsed), lc($expected)) or print STDERR "original ingredients: $ingredients ($l)\n";
	}	
}

done_testing();
