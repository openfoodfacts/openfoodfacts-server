#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Nutrition qw/generate_nutrient_set_preferred_from_sets/;

# dummy product for testing
my @tests = (
    [[], {}],
    [[{}], {}],
    [
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                source_description => "Information from packaging", 
                last_updated_t => "1200000", 
                nutrients => {
                    sodium => {
                        value_string => "2.0", 
                        value => 2, 
                        unit => "mg", 
                        modifier => "<="
                    }
                }
            }
        ],
        {
            preparation => "as_sold", 
            per => "100g", 
            per_quantity => "100", 
            per_unit => "g", 
            source => "packaging", 
            source_description => "Information from packaging", 
            last_updated_t => "1200000", 
            nutrients => {
                sodium => {
                    value_string => "2.0", 
                    value => 2, 
                    unit => "mg", 
                    modifier => "<=",
                    source => "packaging",
                    source_per => "100g",
                }
            }
        },
    ],
);      

foreach my $test_ref (@tests) {

	my $nutrient_sets_ref = $test_ref->[0];
	my $nutrient_set_preferred = $test_ref->[1];

	is(generate_nutrient_set_preferred_from_sets($nutrient_sets_ref), $nutrient_set_preferred)
;
}

done_testing();
