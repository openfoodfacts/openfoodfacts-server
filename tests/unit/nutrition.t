#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Nutrition qw/generate_nutrient_set_preferred_from_sets/;

my @tests = (
    [[], {}, "Generated set should be empty given empty list"],
    [[{}], {}, "Generated set should be empty given list with empty sets"],
    [
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
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
        "Generated set should be the same as the only set given list with one set",
    ],
    [ 
        [
            {},
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
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
        "Generated set should be the same as the only non empty set given list with only one non empty set"
    ],
    [
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sodium => {
                        value_string => "2.0", 
                        value => 2, 
                        unit => "mg", 
                        modifier => "<="
                    }
                }
            },
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "usda", 
                nutrients => {
                    sugars => {
                        value_string => "5.2", 
                        value => 5.2, 
                        unit => "mg", 
                    }
                }
            }
        ],
        {
            preparation => "as_sold", 
            per => "100g", 
            per_quantity => "100", 
            per_unit => "g", 
            nutrients => {
                sodium => {
                    value_string => "2.0", 
                    value => 2, 
                    unit => "mg", 
                    modifier => "<=",
                    source => "packaging",
                    source_per => "100g",
                },
                sugars => {
                    value_string => "5.2", 
                    value => 5.2, 
                    unit => "mg", 
                    source => "usda",
                    source_per => "100g",
                }
            }
        },
        "Generated set should have all given nutrients given sets with different nutrients provided"
    ],
    [ 
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sodium => {
                        value_string => "2.0", 
                        value => 2, 
                        unit => "mg", 
                        modifier => "<="
                    }
                }
            },
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "usda", 
                nutrients => {
                    sodium => {
                        value_string => "0.1", 
                        value => 0.1, 
                        unit => "mg",
                    },
                    sugars => {
                        value_string => "5.2", 
                        value => 5.2, 
                        unit => "mg", 
                    }
                }
            }
        ],
        {
            preparation => "as_sold", 
            per => "100g", 
            per_quantity => "100", 
            per_unit => "g", 
            nutrients => {
                sodium => {
                    value_string => "2.0", 
                    value => 2, 
                    unit => "mg", 
                    modifier => "<=",
                    source => "packaging",
                    source_per => "100g",
                },
                sugars => {
                    value_string => "5.2", 
                    value => 5.2, 
                    unit => "mg", 
                    source => "usda",
                    source_per => "100g",
                }
            }
        },
        "Generated set should have nutrients from most important source given sets with same nutrients with different sources"
    ],
    [
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sodium => {
                        value_string => "2.0", 
                        value => 2, 
                        unit => "mg", 
                        modifier => "<="
                    },
                    protein => {
                        value_string => "6.2", 
                        value => 6.2, 
                        unit => "g", 
                    }
                }
            },
            {
                preparation => "prepared", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sodium => {
                        value_string => "0.1", 
                        value => 0.1, 
                        unit => "mg",
                    },
                    sugars => {
                        value_string => "5.2", 
                        value => 5.2, 
                        unit => "mg", 
                    }
                }
            }
        ],
        {
            preparation => "prepared", 
            per => "100g", 
            per_quantity => "100", 
            per_unit => "g", 
            nutrients => {
                sodium => {
                    value_string => "0.1", 
                    value => 0.1, 
                    unit => "mg", 
                    source => "packaging",
                    source_per => "100g",
                },
                sugars => {
                    value_string => "5.2", 
                    value => 5.2, 
                    unit => "mg", 
                    source => "packaging",
                    source_per => "100g",
                }
            }
        },
        "Generated set should have nutrients from most important preparation given sets with same nutrients with different preparations"
    ],
    [
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sodium => {
                        value_string => "2.0", 
                        value => 2, 
                        unit => "mg", 
                        modifier => "<="
                    }
                }
            },
            {
                preparation => "as_sold", 
                per => "serving", 
                per_quantity => "250", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sodium => {
                        value_string => "0.1", 
                        value => 0.1, 
                        unit => "mg",
                    },
                    protein => {
                        value_string => "12",
                        value => 12,
                        unit => "g",
                    }
                }
            },
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sugars => {
                        value_string => "5.2", 
                        value => 5.2, 
                        unit => "mg", 
                    }
                }
            }
        ],
        {
            preparation => "as_sold", 
            per => "100g", 
            per_quantity => "100", 
            per_unit => "g", 
            nutrients => {
                sodium => {
                    value_string => "2.0", 
                    value => 2, 
                    unit => "mg", 
                    modifier => "<=",
                    source => "packaging",
                    source_per => "100g",
                },
                sugars => {
                    value_string => "5.2", 
                    value => 5.2, 
                    unit => "mg", 
                    source => "packaging",
                    source_per => "100g",
                }
            }
        },
        "Generated set should have nutrients from most important per given sets with same nutrients with different per"
    ],
    [
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sugars => {
                        value_string => "5.2", 
                        value => 5.2, 
                        unit => "mg", 
                    }
                }
            },
            {
                preparation => "as_sold", 
                per => "serving", 
                per_quantity => "250", 
                per_unit => "g", 
                source => "manufacturer", 
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
            per => "serving", 
            per_quantity => "250", 
            per_unit => "g", 
            nutrients => {
                sodium => {
                    value_string => "2.0", 
                    value => 2, 
                    unit => "mg",
                    modifier => "<=", 
                    source => "manufacturer",
                    source_per => "serving",
                }
            }
        },
        "Generated set should have nutrients from most important source then per given sets with same nutrients with different sources and per"
    ],
    [
        [
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "manufacturer", 
                nutrients => {
                    sodium => {
                        value_string => "2.0", 
                        value => 2, 
                        unit => "mg", 
                        modifier => "<="
                    }
                }
            },
            {
                preparation => "prepared", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sugars => {
                        value_string => "5.2", 
                        value => 5.2, 
                        unit => "mg", 
                    }
                }
            }
        ],
        {
            preparation => "as_sold", 
            per => "100g", 
            per_quantity => "100", 
            per_unit => "g", 
            nutrients => {
                sodium => {
                    value_string => "2.0", 
                    value => 2, 
                    unit => "mg",
                    modifier => "<=", 
                    source => "manufacturer",
                    source_per => "100g",
                }
            }
        },
        "Generated set should have nutrients from most important source then preparation given sets with same nutrients with different sources and preparations"
    ],
    [
        [
            {
                preparation => "prepared", 
                per => "serving", 
                per_quantity => "250", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sodium => {
                        value_string => "2.0", 
                        value => 2, 
                        unit => "mg", 
                        modifier => "<="
                    }
                }
            },
            {
                preparation => "as_sold", 
                per => "100g", 
                per_quantity => "100", 
                per_unit => "g", 
                source => "packaging", 
                nutrients => {
                    sugars => {
                        value_string => "5.2", 
                        value => 5.2, 
                        unit => "mg", 
                    }
                }
            }
        ],
        {
            preparation => "as_sold", 
            per => "100g", 
            per_quantity => "100", 
            per_unit => "g", 
            nutrients => {
                sugars => {
                    value_string => "5.2", 
                    value => 5.2, 
                    unit => "mg",
                    source => "packaging",
                    source_per => "100g",
                }
            }
        },
        "Generated set should have nutrients from most important per then preparation given sets with same nutrients with different per and preparations"
    ],
);      

foreach my $test_ref (@tests) {

	my $nutrient_sets_ref = $test_ref->[0];
	my $nutrient_set_preferred = $test_ref->[1];
    my $test_name = $test_ref->[2];

	is(generate_nutrient_set_preferred_from_sets($nutrient_sets_ref), $nutrient_set_preferred, $test_name);
}

done_testing();
