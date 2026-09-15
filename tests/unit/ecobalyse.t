#!/usr/bin/perl -w

use Test2::V0;
use JSON;

use ProductOpener::PerlStandards;
use ProductOpener::Test qw/init_expected_results compare_to_expected_results/;
use ProductOpener::EnvironmentalImpact qw/estimate_environmental_impact_service/;
use ProductOpener::Paths qw/ensure_dir_created_or_die/;
use ProductOpener::ProductsTags qw/compute_field_tags/;
use ProductOpener::Ingredients qw/extract_ingredients_from_text/;
use ProductOpener::LoadData qw/load_data/;

load_data();

my $json = JSON->new->allow_nonref->canonical;

my ($test_id, $test_dir, $expected_result_dir, $update_expected_results) = (init_expected_results(__FILE__));

# Ecobalyse tests

# Note: when updating the expected tests results, the real Ecobalyse API is used to update the expected results
# and to store the mocked Ecobalyse responses in the expected results directory.
# The env variable ECOBALYSE_API_TOKEN needs to be set to a valid Ecobalyse API token for the real API call to work.

my @tests = (
    [
        'fr-pate-aux-noisettes',
        {
            lc => "fr",
            categories => "pâte aux noisettes",
            ingredients_text => "Sucre, huile de palme, NOISETTES 13%, LAIT écrémé en poudre, cacao maigre 7,4%",
            quantity => "400g",
        }
    ],
    # currently returns "null" without ingredients
    [
        'fr-olive-oil-category-no-ingredients-no-packaging',
        {
            lc => "fr",
            categories => "huile d'olive",
            quantity => "0.75l",
        }
    ],
    [
        'fr-olive-oil-category-with-ingredients-no-packaging',
        {
            lc => "fr",
            ingredients_text => "Huile d'olive vierge extra",
            categories => "huile d'olive",
            quantity => "0.75l",
        }
    ],   
    # Canned vegetables: matches canning transformation
    [
        'fr-canned-green-beans',
        {
            lc => "fr",
            ingredients_text => "haricots verts, eau, sel",
            categories => "légumes en conserve",
        }
    ],
    # Frozen green beans: matches freezing transformation
    [
        'fr-frozen-green-beans',
        {
            lc => "fr",
            ingredients_text => "haricots verts",
            categories => "haricots verts surgelés",
        }
    ],
);

# For each test, when the expected results are updated, the Ecobalyse mock response is saved to a file name [testid].json

my $mock_calls = 0;
my $ecobalyse_mock;

if (!$update_expected_results) {
	
    $ecobalyse_mock = mock 'ProductOpener::EnvironmentalImpact' => (
        override => [
            'call_ecobalyse' => sub {
                ++$mock_calls;
                my ($url_recipe, $payload_ref, $testid) = @_;
                my $mock_response_file = "$expected_result_dir/$testid.ecobalyse.json";
                my $response_data = '';
                if (open(my $mock_response, "<:encoding(UTF-8)", $mock_response_file)) {
                    local $/;    #Enable 'slurp' mode
                    $response_data = <$mock_response>;
                    print STDERR "Ecobalyse mock response loaded from $mock_response_file\n";
                }
                else {
                    fail("could not load $mock_response_file");
                }
                return ($response_data, 1);
            }
        ]
    );
}


foreach my $test_ref (@tests) {

	my $testid = $test_ref->[0];
	my $product_ref = $test_ref->[1];

    # We add the testid to the product_ref so that the call_ecobalyse() mock can use it to return a mock response instead of calling the real Ecobalyse API.
    $product_ref->{testid} = $testid;

	# Run the test

    # Prepare test input: tags and ingredients
	if (defined $product_ref->{labels}) {
		compute_field_tags($product_ref, $product_ref->{lc}, "labels");
	}
	if (defined $product_ref->{categories}) {
		compute_field_tags($product_ref, $product_ref->{lc}, "categories");
	}    

	extract_ingredients_from_text($product_ref);

    # Run the environmental impact estimation service, which will prepare the Ecobalyse request payload 
    # and call Ecobalyse API (or the mock if $update_expected_results is false) to get the Ecobalyse response.
    my $updated_product_fields_ref = {};
    my $errors_ref = [];
    $mock_calls = 0;
    estimate_environmental_impact_service($product_ref, $updated_product_fields_ref, $errors_ref);

	# Note: extract_ingredients_from_text will create fields allergens/traces_from_ingredients
	# Those are kept in the unit tests, but in real processing, they are then removed by detect_allergens_from_text

	compare_to_expected_results($product_ref, "$expected_result_dir/$testid.json", $update_expected_results);

    # Save the ecobalyse mocked response
	if ($update_expected_results) {
		is($mock_calls, 0, "Ecobalyse mock not called");
        my $mock_response_file = "$expected_result_dir/$testid.ecobalyse.json";
		open(my $response, ">:encoding(UTF-8)", $mock_response_file)
			or die("Could not create $mock_response_file: $!\n");
		print $response $json->pretty->encode($product_ref->{environmental_impact}->{ecobalyse_response});
		close($response);
	}
	else {
		is($mock_calls, 1, "Ecobalyse mock called");
	}
}

done_testing();
