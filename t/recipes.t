#!/usr/bin/perl -w

use strict;
use warnings;

use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use JSON;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Recipes qw/:all/;

my $testdir = "recipes";

my $usage = <<TXT

The expected results of the tests are saved in $data_root/t/expected_test_results/$testdir

To verify differences and update the expected test results, actual test results
can be saved to a directory by passing --results [path of results directory]

The directory will be created if it does not already exist.

TXT
;

my $resultsdir;

GetOptions ("results=s"   => \$resultsdir)
  or die("Error in command line arguments.\n\n" . $usage);
  
if ((defined $resultsdir) and (! -e $resultsdir)) {
	mkdir($resultsdir, 0755) or die("Could not create $resultsdir directory: $!\n");
}

my @recipes_tests = (

    {
        testid => 'nectars',
        lc => "en",
        parent_ingredients =>   [
            "water", "sugar", "fruit"
        ],
        products => [
            [
                'guava-nectar',
                {
                    lc => "en",
                    ingredients_text => "Water, guava juice 25%, cane sugar 10%, citric acid 2%, some unknown ingredient 1%",
                },
            ],
            [
                'strawberry-nectar',
                {
                    lc => "en",
                    ingredients_text => "Water, strawberry juice 20%, sugar 5%",
                },
            ],
            [
                 'missing-ingredients',
                {
                    lc => "en",
                    ingredients_text => "",
                },               
            ],
            [
                 'impossible-ingredients',
                {
                    lc => "en",
                    ingredients_text => "Orange juice 50%, water, sugar 30%",
                },               
            ],             
        ],
    },

    # Margherita pizzas
    {
        testid => 'fr-margherita-pizzas',
        lc => "fr",
        parent_ingredients =>   [
            "farine", "tomate", "fromage", "eau"
        ],
        products => [
            [
                'fr-margherita-pizza-1',
                {
                    lc => "fr",
                    ingredients_text => "Farine de blé*, purée de tomates* 26%, eau, mozzarella râpée* 17%, huile de tournesol*, levure, sel, plantes aromatiques*, épices*. Traces de poissons et fruits à coque. * Ingrédients issus de l'agriculture biologique.",
                },
            ],        
        ],
    },    

);



my $json = JSON->new->allow_nonref->canonical;

# First level: recipes test with a set of product
foreach my $recipes_test_ref (@recipes_tests) {

    my $recipes_testid = $recipes_test_ref->{testid};
    my $uncanonicalized_parent_ingredients_ref = $recipes_test_ref->{parent_ingredients};

    # Canonicalize the parent ingredients
    my $parent_ingredients_ref = [];
    foreach my $parent (@{$uncanonicalized_parent_ingredients_ref}) {
        push @{$parent_ingredients_ref}, canonicalize_taxonomy_tag($recipes_test_ref->{lc}, "ingredients", $parent);
    }

    my $recipes_ref = [];

    # Second level: product test for each product for the recipes test
    foreach my $test_ref (@{$recipes_test_ref->{products}}) {

        my $testid = $test_ref->[0];
        my $product_ref = $test_ref->[1];

        # Run the test
        
        extract_ingredients_from_text($product_ref);
        $product_ref->{recipe} = compute_product_recipe($product_ref, $parent_ingredients_ref);

        add_product_recipe_to_set($recipes_ref, $product_ref, $product_ref->{recipe});
        
        # Save the result
        
        if (defined $resultsdir) {
            open (my $result, ">:encoding(UTF-8)", "$resultsdir/$recipes_testid.$testid.json") or die("Could not create $resultsdir/$recipes_testid.$testid.json: $!\n");
            print $result $json->pretty->encode($product_ref);
            close ($result);
        }
        
        # Compare the result with the expected result
        
        if (open (my $expected_result, "<:encoding(UTF-8)", "$data_root/t/expected_test_results/$testdir/$recipes_testid.$testid.json")) {

            local $/; #Enable 'slurp' mode
            my $expected_product_ref = $json->decode(<$expected_result>);
            is_deeply ($product_ref, $expected_product_ref) or diag explain $product_ref;
        }
        else {
            diag explain $product_ref;
            fail("could not load expected_test_results/$testdir/$recipes_testid.$testid.json");
        }
    }

    my $analysis_ref = analyze_recipes($recipes_ref, $parent_ingredients_ref);

    # Save the result
        
    if (defined $resultsdir) {
        open (my $result, ">:encoding(UTF-8)", "$resultsdir/$recipes_testid.json") or die("Could not create $resultsdir/$recipes_testid.json: $!\n");
        print $result $json->pretty->encode($analysis_ref);
        close ($result);
    }
    
    # Compare the result with the expected result
    
    if (open (my $expected_result, "<:encoding(UTF-8)", "$data_root/t/expected_test_results/$testdir/$recipes_testid.json")) {

        local $/; #Enable 'slurp' mode
        my $expected_analysis_ref = $json->decode(<$expected_result>);
        is_deeply ($analysis_ref, $expected_analysis_ref) or diag explain $analysis_ref;
    }
    else {
        diag explain $analysis_ref;
        fail("could not load expected_test_results/$testdir/$recipes_testid.json");
    }    
}


done_testing();
